# Snapshot contract (external readers)

Cursor Limits is the **only** process that refreshes provider APIs and writes the
snapshot. External UIs (WidgetKit, a Cyclop Limits tab, scripts) **read only**.

## Path

```
~/Library/Application Support/CursorLimits/app-snapshot.json
```

- Encoding: UTF-8 JSON, pretty-printed, keys sorted
- Dates: ISO-8601 (`JSONEncoder` / `JSONDecoder` `.iso8601`)
- Do **not** rely on the widget-container mirror; the Application Support path
  above is the public contract

Related (optional): `preferences.json` in the same folder — language, enabled
providers, primary selection. External UIs can ignore it and trust
`primaryProviderID` inside the snapshot.

## Schema

| Field | Type | Notes |
|---|---|---|
| `schemaVersion` | `Int` | Current: **1**. Missing key ⇒ treat as `1` |
| `fetchedAt` | ISO-8601 string | Last aggregate write |
| `providers` | `[ProviderUsage]` | Usually primary first |
| `enabledProviderIDs` | `[String]` | Provider id strings |
| `primaryProviderID` | `String` | Provider id for the “main” ring |

### `ProviderUsage` (stable subset for a notch UI)

| Field | Type | Notes |
|---|---|---|
| `providerID` | string | `cursor`, `claude`, `codex`, `ollama-cloud`, `opencode-go`, `copilot` |
| `status` | string | `ok` \| `missing` \| `authMissing` \| `error` |
| `planName` | string | e.g. `"Pro"` |
| `windows` | array | `{ "label", "fraction"?, "resetsAt"? }` — `fraction` is **0…1 used** |
| `fetchedAt` | ISO-8601 | Per-provider |
| `errorMessage` | string? | Safe for UI; may be localized |
| `displayMessage` | string? | Optional status line |

Cursor-only extras (`tokenStats`, `topModels`, spend fields) may be present;
readers can ignore them.

Primary percent for a ring:

```text
max(windows.fraction)  or  first window fraction
```

(same as `ProviderUsage.primaryFraction` in Swift).

## Compatibility

- Readers should tolerate **unknown** keys and **unknown** `providerID` values
- If `schemaVersion` is greater than the reader understands → show
  “update Cursor Limits / Cyclop” rather than crashing
- Path must stay under `…/Application Support/CursorLimits/` (no silent moves)

## Deep links (handoff)

| URL | Effect |
|---|---|
| `cursorlimits://refresh` | Trigger a refresh in the running app |
| `cursorlimits://settings` | Activate app and open Settings |

Bundle id: `com.5tepan.cursorlimits` (legacy installs used `com.local.CursorLimits`;
widget container data is migrated on first launch).

## Example (truncated)

```json
{
  "schemaVersion" : 1,
  "fetchedAt" : "2026-10-21T17:00:00Z",
  "enabledProviderIDs" : [ "cursor", "ollama-cloud" ],
  "primaryProviderID" : "cursor",
  "providers" : [
    {
      "providerID" : "cursor",
      "status" : "ok",
      "planName" : "Pro",
      "windows" : [
        { "label" : "Auto", "fraction" : 0.22 },
        { "label" : "API", "fraction" : 0.15 }
      ],
      "fetchedAt" : "2026-10-21T17:00:00Z"
    }
  ]
}
```
