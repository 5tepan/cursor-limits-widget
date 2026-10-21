# Security / Безопасность

## English

### What stays on your Mac (never in this repo)

| Data | Location |
|---|---|
| Cursor access / refresh tokens | `~/Library/Application Support/Cursor/User/globalStorage/state.vscdb` |
| Usage snapshot (email, spend, tokens) | `~/Library/Application Support/CursorLimits/snapshot.json` |

How account linking works:

- You sign in to **Cursor IDE** as usual.
- Cursor Limits **reads** that local session.
- You never paste tokens, cookies, or passwords into Cursor Limits.
- Nothing is sent to a Cursor Limits server (there isn’t one) — only Cursor’s own APIs are called with your existing session.

### Safe to publish in git

- Source code
- Cursor’s public OAuth **client id** used for token refresh (shared desktop client id, not your secret)
- Fake preview email `you@example.com`

### Do not commit

- `DerivedData/`, `dist/` build outputs
- `snapshot.json`, `.env`, tokens, cookies, copied `state.vscdb`

### Unsigned downloads

Release zips are ad-hoc signed. Prefer installing via `Install.command` from a Release you trust (this repo). Clear quarantine only for builds you trust.

---

## Русский

### Что остаётся на Mac (не в репозитории)

| Данные | Где |
|---|---|
| Токены Cursor | `~/Library/Application Support/Cursor/User/globalStorage/state.vscdb` |
| Снимок usage | `~/Library/Application Support/CursorLimits/snapshot.json` |

Как подключается аккаунт:

- Вы входите в **Cursor IDE** как обычно.
- Cursor Limits **читает** эту локальную сессию.
- Токены, cookie и пароли в приложение вставлять не нужно.
- Отдельного сервера Cursor Limits нет — запросы идут только в API Cursor с вашей сессией.

### Можно пушить в git

- Исходники
- Публичный OAuth **client id** Cursor (общий id клиента, не ваш секрет)
- Фейковый preview-email `you@example.com`

### Не коммитить

- `DerivedData/`, `dist/`
- `snapshot.json`, `.env`, токены, cookie, копии `state.vscdb`

### Неподписанные сборки

Релизные zip подписаны ad-hoc. Ставьте через `Install.command` только из Release, которому доверяете.
