# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Project docs: MIT license, security policy, contributing guide, architecture and providers notes
- GitHub Actions build workflow (`package.sh` on `main` / PRs)
- Bilingual README (`README.md` / `README.ru.md`) with screenshots (menu bar + widgets caveat)


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
- Local session read + official API refresh; shared App Group snapshot for host and widgets

[Unreleased]: https://github.com/5tepan/cursor-limits-widget/compare/v1.1.0...HEAD
[1.1.0]: https://github.com/5tepan/cursor-limits-widget/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/5tepan/cursor-limits-widget/releases/tag/v1.0.0
