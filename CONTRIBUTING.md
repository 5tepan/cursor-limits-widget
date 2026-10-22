# Contributing

Thanks for taking a look. This is a small open-source macOS app; a short,
focused PR is easier to review than a large rewrite.

## Before you write a lot of code

Open an **issue** for:

- a new AI provider / aggregator;
- anything that needs a new entitlement or broader file access;
- changing the on-disk snapshot schema in a breaking way.

## One PR — one change

Build, docs-only, and feature work in separate PRs when you can. Branch from
`main`.

## Local check

```bash
brew install xcodegen   # once
xcodegen generate
xcodebuild test \
  -project CursorLimits.xcodeproj \
  -scheme CursorLimits \
  -destination 'platform=macOS'
./scripts/install-local.sh
```

You need an **Apple Development** certificate for the widget to appear in the
macOS gallery. Menu bar works with ad-hoc signing after Gatekeeper bypass.

Release zip (what CI builds):

```bash
./scripts/package.sh
# → dist/CursorLimits-*-macos.zip
```

## Code map

| Path | Role |
|---|---|
| `Shared/Providers/` | One file per usage source (`UsageProvider`) |
| `Shared/Services/` | Multi-provider refresh |
| `Shared/Storage/` | Snapshot / preferences on disk |
| `CursorLimits/` | Menu bar UI + Settings |
| `CursorLimitsWidget/` | WidgetKit layouts |
| `scripts/` | Install, package, local build |

New provider: implement `UsageProvider`, register in `ProviderRegistry`, add
`ProviderID`, keep secrets out of logs (`SecretRedactor` / `ProviderDiagnosticsStore`).

## Privacy bar

Do not add telemetry, remote config, or token upload. Network calls belong only
on official provider endpoints. See [SECURITY.md](SECURITY.md).

## Language

Issues and PRs in English or Russian are fine. Commit subjects: what changed for
the user (“show Ollama Cloud in the widget”), not only “fix stuff”.

## Licence

By contributing you agree your changes are under the MIT License in
[LICENSE](LICENSE).
