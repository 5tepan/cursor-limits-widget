# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.2.1] - 2026-10-25

### Added

- In-app updates: automatic GitHub Releases check, notification when a newer version is out, Settings → Updates (check / download)
- Decrypt Cursor `cursor-safe-storage:v1:` tokens via Keychain `Cursor Safe Storage` (Electron safeStorage)

### Fixed

- Cursor usage after IDE updates that enable `authTokenEncryptionAtRest` (encrypted `state.vscdb` tokens no longer sent as Bearer)

## [1.2.0] - 2026-10-22

### Added

- Project docs: MIT license, security policy, contributing guide, architecture and providers notes
- GitHub Actions build workflow (`package.sh` on `main` / PRs)
- Bilingual README (`README.md` / `README.ru.md`) with screenshots (menu bar + widgets caveat)
- `schemaVersion` on `app-snapshot.json` + [snapshot contract](docs/snapshot-contract.md) for external readers
- Deep links `cursorlimits://refresh` and `cursorlimits://settings` (Cyclop handoff)
- Multi-provider onboarding checklist; Settings → Rescan providers
- Usage alerts at 70% / 90% / 100% (primary) with optional quiet hours
- Compact menu bar title (`82% · 4d`) and urgency-colored glyph above 70%
- [Release / notarization guide](docs/release.md); Hardened Runtime on Release builds
- Unit tests + CI test job; `UsageFraction`, diagnostics serial queue

### Changed

- Bundle ID → `com.5tepan.cursorlimits` (migrates widget-container data from `com.local.*`)
- Provider discovery runs once (or on Rescan) — no longer re-enables all providers every launch
- Cursor OAuth refresh stores the token in Keychain only (Cursor `state.vscdb` is read-only)
- Cursor API errors are redacted before UI / snapshot (aligned with other providers)
- Stopped writing legacy `snapshot.json` on every save (one-shot migrate on load remains)
- Unified `AppPaths.realHome` for credentials and Application Support
- Refresh requests coalesce instead of dropping; deep links use a single early `AppModel`

### Fixed

- Changelog 1.0.0 incorrectly mentioned App Groups (host dual-writes into Application Support + widget container)

## [1.1.0] - 2026-10-21

### Added

- Multi-provider usage: Cursor, Claude Code, Codex, Ollama Cloud, OpenCode Go, GitHub Copilot
- Settings window: enable providers, primary selection (manual or automatic by highest usage), language
- Launch discovery: probe providers once and disable those without a local session
- Collapsible per-provider cards in the menu bar; human-readable statuses and redacted diagnostics
- App icon; EN / RU localization
- Install and packaging scripts (`Install.command`, `package.sh`, `install-local.sh`)

### Changed

- Menu bar and desktop widget layouts (small / medium / large); primary first, overflow in the menu bar
- Expanded widget content beyond a single percentage

### Fixed

- OpenCode Go credential matching limited to explicitly named Go keys (no accidental OpenRouter / Ollama pickup)
- Packaging / signing path for CI ad-hoc builds

## [1.0.0] - 2026-10-21

### Added

- Initial release: macOS menu bar app + WidgetKit extension for Cursor usage limits
- Local session read + official API refresh; snapshot dual-written to Application Support and the widget container (no App Groups)

[Unreleased]: https://github.com/5tepan/cursor-limits-widget/compare/v1.2.1...HEAD
[1.2.1]: https://github.com/5tepan/cursor-limits-widget/compare/v1.2.0...v1.2.1
[1.2.0]: https://github.com/5tepan/cursor-limits-widget/compare/v1.1.0...v1.2.0
[1.1.0]: https://github.com/5tepan/cursor-limits-widget/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/5tepan/cursor-limits-widget/releases/tag/v1.0.0
