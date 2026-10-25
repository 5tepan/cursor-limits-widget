# Security

Cursor Limits is a **local** macOS menu-bar app. It does not run a backend, does
not create accounts, and does not upload your tokens.

## What stays on this Mac

| Data | Where | Shared? |
|---|---|---|
| Usage snapshot | `~/Library/Application Support/CursorLimits/app-snapshot.json` (and a copy for the widget container) | No — local only |
| Preferences (language, enabled providers, primary) | `…/preferences.json` | No |
| Redacted error log | `…/diagnostics.json` | No — secrets stripped before write |
| Alert dedupe state | `…/alert-state.json` | No — which thresholds already fired this cycle |
| Optional Copilot OAuth token (device flow) | macOS Keychain service `CursorLimits-GitHub` | No |
| Optional refreshed Cursor access token | macOS Keychain service `CursorLimits-Cursor` | No |

Snapshots and preferences are also written under the widget sandbox container so
WidgetKit can read them. Nothing is sent to a Cursor Limits server — there isn’t one.

## What the app reads

Local credentials that **you already created** by signing into other tools:

- **Cursor** — session in Cursor’s `state.vscdb` (**read-only**; refreshed tokens go to our Keychain, not back into Cursor’s DB). Newer Cursor builds may seal tokens as `cursor-safe-storage:v1:`; we decrypt via the login Keychain item `Cursor Safe Storage` / `Cursor Key` (Electron safeStorage) and never log the plaintext.
- **Claude Code** — `~/.claude` / Keychain entry used by the CLI
- **Codex** — `~/.codex/auth.json`
- **Ollama Cloud / OpenCode Go** — keys in OpenCode `auth.json` (or env vars)
- **GitHub Copilot** — `gh` token, `~/.config/gh/hosts.yml`, or Keychain after device flow

The app never asks you to paste a token into a text field (except confirming
GitHub’s device-flow code in the browser).

## Network

Outbound HTTPS only to the **official** APIs of providers you enabled, for
example:

- `api2.cursor.sh` / `cursor.com` (Cursor usage)
- `api.anthropic.com` (Claude usage)
- `chatgpt.com` (Codex usage)
- `ollama.com` (Ollama Cloud balance)
- `opencode.ai` (OpenCode Go usage)
- `api.github.com` / `github.com` (Copilot entitlement / device flow; optional update check against this repo’s Releases)

No analytics, crash reporters, or third-party CDNs.

## Diagnostics

The in-app “Details” error sheet stores **redacted** text locally (Authorization
headers, Bearer tokens, common key patterns are stripped). Copying from that
sheet re-redacts before the pasteboard.

## Reporting a vulnerability

Please **do not** open a public issue with exploit details or live tokens.

Email or private contact via GitHub Security Advisories on this repository.
Include: macOS version, app version, steps, and whether tokens were exposed.

## Signing / distribution note

Release zips from CI are often **ad-hoc signed** (no Developer ID notarization
unless a maintainer adds one). Gatekeeper may require **Open Anyway**. That is
a distribution limitation, not a request for Accessibility or Full Disk Access.

Release builds enable **Hardened Runtime**. To ship a Gatekeeper-clean zip, see
[docs/release.md](docs/release.md) (`DEVELOPER_ID` + `NOTARY_PROFILE`).

Bundle ID (1.2.0+): `com.5tepan.cursorlimits`.
