# Architecture

Cursor Limits is a **menu-bar host** plus a **WidgetKit extension**. Both share
the `Shared/` sources. The host refreshes usage; the widget only reads a
snapshot from disk.

```
┌─────────────────────┐     HTTPS      ┌──────────────────┐
│  CursorLimits.app   │ ─────────────► │ Provider APIs    │
│  MenuBar + Settings │                │ (Cursor, Claude…)│
└─────────┬───────────┘                └──────────────────┘
          │ write
          ▼
 ~/Library/Application Support/CursorLimits/
   app-snapshot.json
   preferences.json
   diagnostics.json
          │
          │ read (also mirrored into widget container)
          ▼
┌─────────────────────┐
│ CursorLimitsWidget  │  WidgetKit timeline
└─────────────────────┘
```

## Refresh

1. On launch: enable all providers, refresh in parallel, **disable** those with
   `authMissing` (no local session).
2. Timer every 5 minutes + manual Refresh: only **enabled** providers.
3. Primary provider: **automatic** (highest `primaryFraction`) or **manual**
   (Settings). Primary is first in the menu bar and the main widget block.

## Providers

Each source implements `UsageProvider` (`id`, `isAvailable()`, `refresh()` →
`ProviderUsage`). See [providers.md](providers.md).

## External readers (file bridge)

The Application Support `app-snapshot.json` is a **stable contract** for other
local UIs (e.g. a read-only Cyclop Limits tab). Those readers must not call
provider APIs — only Cursor Limits refreshes. See [snapshot-contract.md](snapshot-contract.md).

Deep links: `cursorlimits://refresh`, `cursorlimits://settings`.

## Why dual-write

The widget runs sandboxed. The host writes the same `app-snapshot.json` into the
real Application Support folder and into the widget’s container path so the
gallery extension can read usage without App Groups. Legacy `snapshot.json` is
only read for one-shot migration — it is no longer rewritten on each refresh.

## Signing

- Local install (`install-local.sh`): prefers Apple Development (widgets).
- CI package (`package.sh` with `CI=true`): ad-hoc (`-`) so GitHub Actions can
  build without certificates. Notarization is optional future work.
