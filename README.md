# Cursor Limits

*English · [Русский](README.ru.md)*

Menu bar app and desktop widgets for **AI subscription usage** on your Mac —
Cursor, Claude Code, Codex, Ollama Cloud, OpenCode Go, and GitHub Copilot.

No tokens to paste. The app reads local sessions you already have and calls only
each provider’s official API. Usage stays on this Mac.

[![release](https://img.shields.io/github/v/release/5tepan/cursor-limits-widget?style=flat-square)](https://github.com/5tepan/cursor-limits-widget/releases/latest)
[![license](https://img.shields.io/github/license/5tepan/cursor-limits-widget?style=flat-square)](LICENSE)

**[Download the latest release](https://github.com/5tepan/cursor-limits-widget/releases/latest)** —
`CursorLimits-*-macos.zip` → run **Install.command**.

## Screenshots

<p align="center">
  <img src="docs/images/menubar.jpg" alt="Menu bar — multi-provider usage cards" width="320" />
</p>

<p align="center"><em>Menu bar — live usage for each connected provider</em></p>

<p align="center">
  <img src="docs/images/widgets.jpg" alt="Desktop widgets — small, medium, and large" width="720" />
</p>

<p align="center"><em>Desktop widgets (small / medium / large). <strong>Note:</strong> WidgetKit on the desktop is still unreliable for many installs — especially ad-hoc / CI builds without Apple Development or notarized Developer ID signing. The menu bar is the supported surface today; widgets may not appear or update.</em></p>

## What it does

| Surface | Behaviour |
|---|---|
| **Menu bar** | Live % for the primary provider; expandable cards per connected source |
| **Settings** | Enable providers, pick primary (or auto by highest usage), language, Copilot device flow |
| **Widgets** | Small / medium / large WidgetKit views (primary first; overflow → menu bar) |
| **Launch discovery** | Tries every provider once, turns off those without a local session |

## Requirements

- macOS 14 or newer
- Xcode / CLT + [xcodegen](https://github.com/yonaskolb/XcodeGen) to build from source
- Local sign-in to the tools you care about (Cursor IDE, Claude CLI, Codex, OpenCode, `gh`, …)

## Install

1. Download the zip from [Releases](https://github.com/5tepan/cursor-limits-widget/releases/latest).
2. Unzip → double-click **Install.command** (installs into `/Applications`).
3. If macOS blocks the app: right-click → **Open** → **Open** (CI builds are often ad-hoc signed, not notarized).
4. Sign in to your tools → menu bar icon → refresh. Toggle providers in **Settings**.
5. Desktop → **Edit Widgets** → **Cursor Limits** (app must live in `/Applications`; Apple Development signature helps the gallery).

From source:

```bash
brew install xcodegen
./scripts/install-local.sh    # Debug → /Applications, Development signing preferred
./scripts/package.sh          # Release zip under dist/
```

## Privacy

Tokens are not uploaded to a Cursor Limits backend. See [SECURITY.md](SECURITY.md)
for what is read locally, which hosts are contacted, and how to report issues.

## Docs

- [Architecture](docs/architecture.md) — host, widget, snapshot dual-write
- [Snapshot contract](docs/snapshot-contract.md) — file bridge for external UIs (Cyclop, etc.)
- [Providers](docs/providers.md) — credential paths and how to add one
- [Changelog](CHANGELOG.md) — what’s new per version
- [Release & signing](docs/release.md) — Developer ID / notarization
- [Contributing](CONTRIBUTING.md)

## Limitations

- **Desktop widgets may not work yet** on many Macs (gallery missing, stale data). Prefer a local **Apple Development** build via `./scripts/install-local.sh`; ad-hoc release zips often only deliver a working menu bar.
- Provider APIs change without notice; a failed refresh keeps a redacted local diagnostic, not a hard crash.
- OpenCode Go only accepts explicitly named Go keys — other OpenCode providers (OpenRouter, etc.) are ignored on purpose.

## Layout

```
CursorLimits/          menu bar app + Settings
CursorLimitsWidget/    WidgetKit extension
Shared/                providers, refresh, storage, UI bits
scripts/               install-local, package, Install.command
docs/                  architecture & providers
```

## Licence

[MIT](LICENSE)
