import Cocoa
import Foundation

// MARK: - Config
// Auth: 1) CLINE_API_KEY env var (from app.cline.bot -> Account -> API Keys)
//       2) fallback: OAuth token from the Cline desktop app settings
let providersPath = NSHomeDirectory() + "/.cline/data/settings/providers.json"
let apiURL = "https://api.cline.bot/api/v1/users/me/plan/usage-limits"
let pollInterval: TimeInterval = Double(ProcessInfo.processInfo.environment["CLINE_QUOTA_INTERVAL"] ?? "") ?? 60

// MARK: - Model
struct QuotaLimit {
    let type: String      // five_hour | weekly | monthly
    let percent: Int
    let resetsAt: Date?
}

// MARK: - Networking
func readAccessToken() -> String? {
    if let env = ProcessInfo.processInfo.environment["CLINE_API_KEY"], !env.isEmpty {
        return env
    }
    guard let data = FileManager.default.contents(atPath: providersPath),
          let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          let providers = root["providers"] as? [String: Any],
          let cline = providers["cline"] as? [String: Any],
          let settings = cline["settings"] as? [String: Any],
          let auth = settings["auth"] as? [String: Any],
          let token = auth["accessToken"] as? String, !token.isEmpty
    else { return nil }
    return token
}

func fetchLimits(completion: @escaping ([QuotaLimit]?, String?) -> Void) {
    guard let token = readAccessToken() else {
        completion(nil, "token non trovato in providers.json")
        return
    }
    var req = URLRequest(url: URL(string: apiURL)!)
    req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    req.timeoutInterval = 20
    URLSession.shared.dataTask(with: req) { data, resp, err in
        if let err = err { completion(nil, err.localizedDescription); return }
        if let code = (resp as? HTTPURLResponse)?.statusCode, code == 401 {
            completion(nil, "token scaduto (Cline lo rinnovera)"); return
        }
        guard let data = data,
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let d = root["data"] as? [String: Any],
              let limits = d["limits"] as? [[String: Any]]
        else { completion(nil, "risposta non valida"); return }

        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let parsed: [QuotaLimit] = limits.compactMap { l in
            guard let t = l["type"] as? String, let p = l["percentUsed"] as? Int else { return nil }
            var reset: Date? = nil
            if let r = l["resetsAt"] as? String { reset = fmt.date(from: r) ?? ISO8601DateFormatter().date(from: r) }
            return QuotaLimit(type: t, percent: p, resetsAt: reset)
        }
        completion(parsed, nil)
    }.resume()
}

// MARK: - UI helpers
func bar(_ pct: Int, width: Int = 14) -> String {
    let filled = Int((Double(pct) / 100.0 * Double(width)).rounded())
    return String(repeating: "\u{2588}", count: max(0, min(width, filled))) +
           String(repeating: "\u{2591}", count: max(0, width - filled))
}

func label(_ type: String) -> String {
    switch type {
    case "five_hour": return "Sessione (5h)"
    case "weekly":    return "Settimanale"
    case "monthly":   return "Mensile"
    default:          return type
    }
}

func emoji(_ pct: Int) -> String {
    pct >= 90 ? "\u{1F534}" : (pct >= 70 ? "\u{1F7E0}" : "\u{1F7E2}")
}


// MARK: - App
class AppDelegate: NSObject, NSApplicationDelegate {
    let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    var timer: Timer?
    var lastLimits: [QuotaLimit] = []
    var lastError: String?
    var lastUpdate: Date?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem.menu = buildMenu()
        setTitle("Cline …")
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: pollInterval, repeats: true) { _ in self.refresh() }
    }

    func setTitle(_ s: String) {
        statusItem.button?.title = s
        statusItem.button?.font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .regular)
    }

    @objc func refresh() {
        fetchLimits { limits, error in
            DispatchQueue.main.async {
                self.lastError = error
                if let limits = limits { self.lastLimits = limits; self.lastUpdate = Date() }
                self.updateUI()
            }
        }
    }

    func updateUI() {
        if let err = lastError, lastLimits.isEmpty {
            setTitle("Cline \u{26A0}\u{FE0F}")
            statusItem.menu = buildMenu(error: err)
            return
        }
        let order = ["five_hour", "weekly", "monthly"]
        let sorted = lastLimits.sorted { (order.firstIndex(of: $0.type) ?? 9) < (order.firstIndex(of: $1.type) ?? 9) }
        let parts = sorted.map { "\(emoji($0.percent))\($0.percent)%" }
        setTitle("Cline " + parts.joined(separator: " "))
        statusItem.menu = buildMenu()
    }

    func buildMenu(error: String? = nil) -> NSMenu {
        let menu = NSMenu()
        if let err = error {
            menu.addItem(NSMenuItem(title: "\u{26A0}\u{FE0F} \(err)", action: nil, keyEquivalent: ""))
            menu.addItem(.separator())
        }
        let df = DateFormatter(); df.dateFormat = "dd/MM HH:mm"
        for l in lastLimits {
            let reset = l.resetsAt.map { "  ·  reset \(df.string(from: $0))" } ?? ""
            menu.addItem(NSMenuItem(title: "\(emoji(l.percent)) \(label(l.type))", action: nil, keyEquivalent: ""))
            let barItem = NSMenuItem(title: "   \(bar(l.percent)) \(l.percent)%\(reset)", action: nil, keyEquivalent: "")
            barItem.attributedTitle = NSAttributedString(
                string: barItem.title,
                attributes: [.font: NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)])
            menu.addItem(barItem)
        }
        if !lastLimits.isEmpty { menu.addItem(.separator()) }
        if let u = lastUpdate {
            menu.addItem(NSMenuItem(title: "Aggiornato \(df.string(from: u))", action: nil, keyEquivalent: ""))
        }
        let refreshItem = NSMenuItem(title: "Aggiorna ora", action: #selector(refresh), keyEquivalent: "r")
        refreshItem.target = self
        menu.addItem(refreshItem)
        let dash = NSMenuItem(title: "Apri app.cline.bot", action: #selector(openDashboard), keyEquivalent: "")
        dash.target = self
        menu.addItem(dash)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Esci", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        return menu
    }

    @objc func openDashboard() {
        NSWorkspace.shared.open(URL(string: "https://app.cline.bot")!)
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let delegate = AppDelegate()
app.delegate = delegate
app.run()
