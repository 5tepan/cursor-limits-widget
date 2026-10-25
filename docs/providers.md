# Providers

| ID | Display name | Credential source | Usage API |
|---|---|---|---|
| `cursor` | Cursor | Cursor `state.vscdb` (`cursorAuth/*`; may be `cursor-safe-storage:v1:` sealed via Keychain `Cursor Safe Storage`) | Cursor Connect / cookie APIs |
| `claude` | Claude Code | `~/.claude` / CLI Keychain | Anthropic OAuth usage |
| `codex` | Codex | `~/.codex/auth.json` | ChatGPT wham usage |
| `ollama-cloud` | Ollama Cloud | OpenCode `auth.json` key `ollama-cloud`, or `OLLAMA_API_KEY` | `ollama.com/api/balance` |
| `opencode-go` | OpenCode Go | OpenCode auth keys named `opencode-go` (strict), or `OPENCODE_GO_API_KEY` | `opencode.ai/zen/go/v1/usage` |
| `copilot` | Copilot | `gh auth`, `hosts.yml`, Keychain, or GitHub device flow | GitHub Copilot entitlement |

## Adding a provider

1. Add a case to `ProviderID` in `Shared/Providers/ProviderModels.swift`.
2. Implement `UsageProvider` under `Shared/Providers/`.
3. Register in `ProviderRegistry.all`.
4. Map HTTP failures through `ProviderFetchError` + human-readable
   `ProviderErrorCopy` (full detail only in redacted diagnostics).
5. Document the credential path here and in SECURITY.md if new hosts are called.

OpenCode Go **must not** pick up unrelated keys (e.g. OpenRouter / Ollama) —
matching is by explicit provider aliases only.
