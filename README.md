# ClineQuota

A tiny macOS menu bar app that shows your **Cline Pass** quota usage in real time — always visible, no need to dig into the Cline GUI.

```
Cline 🟢19% 🟢7% 🟢3%
```

That's: **5-hour session / weekly / monthly** utilization, refreshed automatically.

Clicking the menu bar item shows progress bars, reset times, and quick actions:

- 🟢/🟠/🔴 traffic-light indicator per quota (thresholds: 70% / 90%)
- Progress bar + exact reset date/time for each window
- **Aggiorna ora** (Refresh now)
- Link to [app.cline.bot](https://app.cline.bot)

## Why

Cline's native account panel is buried in the extension UI. This app polls the official API
(`api.cline.bot/api/v1/users/me/plan/usage-limits`) and keeps the numbers in your macOS menu bar,
visible over every window.

## Requirements

- macOS with **Xcode Command Line Tools** (`xcode-select --install`) — needed only to build
- A Cline account with an active **Cline Pass** (or free tier) plan

## Build & run

```bash
./build.sh
open ClineQuota.app
```

Start at login (optional):

```bash
osascript -e 'tell application "System Events" to make login item at end with properties {path:"/full/path/to/ClineQuota.app", hidden:false}'
```

## Authentication

The app needs a token, resolved in this order:

1. **`CLINE_API_KEY` environment variable** — create one at
   [app.cline.bot](https://app.cline.bot) → Account → API Keys.
   To make it persistent, set it in a `launchctl setenv CLINE_API_KEY ...` call or your shell profile
   and launch the app from that context.
2. **Automatic (default)**: if you use the **Cline desktop app**, the OAuth token is read from
   `~/.cline/data/settings/providers.json`. Cline refreshes this token itself, so the app keeps
   working without any configuration.

No token is stored or sent anywhere except `api.cline.bot`.

## Configuration

| Environment variable | Default | Description |
|---|---|---|
| `CLINE_API_KEY` | _(unset)_ | Cline API key, overrides OAuth token |
| `CLINE_QUOTA_INTERVAL` | `60` | Poll interval in seconds |

## Notes

- The binary is **not code-signed**. If Gatekeeper blocks a downloaded build, run
  `xattr -dr com.apple.quarantine ClineQuota.app` — or just build from source (one command).
- If Cline desktop is not running when the OAuth token expires, the app shows ⚠️ until you open
  Cline once (it renews the token) or you set `CLINE_API_KEY`.

## Credits & contributing

Built as a weekend tool and donated to the Cline community. Issues and PRs welcome — e.g.
localization (currently Italian labels), notifications at thresholds, credit balance display.

## License

MIT
