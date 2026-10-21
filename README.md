# Cursor Limits

Menu bar app + macOS widgets that show your **Cursor** subscription usage, spend, and token stats.

Меню-бар приложение и виджеты macOS с лимитами подписки **Cursor**, расходами и статистикой токенов.

---

## English

### Install (download)

1. Open the latest **[Release](../../releases/latest)** and download `CursorLimits-*-macos.zip`.
2. Unzip, then double-click **`Install.command`**  
   (or drag `CursorLimits.app` into **Applications**).
3. If macOS blocks the app: right-click → **Open** → **Open**.  
   Or run: `xattr -dr com.apple.quarantine /Applications/CursorLimits.app`
4. A menu bar icon appears.

> Builds are **ad-hoc signed** (not Apple notarized). Gatekeeper may warn once — that is expected for open-source unsigned apps.

### Connect your account (simple & safe)

**No API keys. No cookie paste. No passwords typed into this app.**

1. Install [Cursor](https://cursor.com/download) if needed.
2. Open Cursor and **sign in**.
3. Click the Cursor Limits menu bar icon → **Check connection**.

The app only reads the session Cursor already stores on your Mac  
(`~/Library/Application Support/Cursor/...`). Tokens are not uploaded to us and are not stored as a separate secret file by this app (only a local usage snapshot under `~/Library/Application Support/CursorLimits/`).

Optional: Settings → **Launch at login**.

### Widgets

Right-click the desktop → **Edit Widgets** → add **Cursor Limits** (Small / Medium / Large).

| Size | Shows |
|---|---|
| Small | Plan, usage ring, days until reset |
| Medium | Auto + API bars, spent, tokens |
| Large | Above + token breakdown, top models |

### Build from source

```bash
brew install xcodegen
./scripts/package.sh          # → dist/CursorLimits-*-macos.zip
# or develop:
xcodegen generate && open CursorLimits.xcodeproj
```

Publish a release: `git tag v1.0.0 && git push origin v1.0.0` (GitHub Action builds the zip).

### Privacy

See [SECURITY.md](SECURITY.md). Usage data stays on your Mac. Do not commit `snapshot.json` or Cursor’s `state.vscdb`.

---

## Русский

### Установка (скачать)

1. Откройте последний **[Release](../../releases/latest)** и скачайте `CursorLimits-*-macos.zip`.
2. Распакуйте и дважды нажмите **`Install.command`**  
   (или перетащите `CursorLimits.app` в **Программы**).
3. Если macOS блокирует: ПКМ → **Открыть** → **Открыть**.  
   Или: `xattr -dr com.apple.quarantine /Applications/CursorLimits.app`
4. В меню-баре появится иконка.

> Сборка **подписана ad-hoc** (без нотаризации Apple). Предупреждение Gatekeeper при первом запуске — нормально для open-source без Developer ID.

### Подключение аккаунта (просто и безопасно)

**Без API-ключей, без вставки cookie, без пароля в этом приложении.**

1. При необходимости установите [Cursor](https://cursor.com/download).
2. Откройте Cursor и **войдите** в аккаунт.
3. Нажмите иконку Cursor Limits → **Проверить подключение**.

Приложение только читает локальную сессию Cursor на вашем Mac. Токены никуда не отправляются «нам» и отдельно приложением как секрет не сохраняются (пишется лишь локальный снимок usage в `~/Library/Application Support/CursorLimits/`).

Опционально: Настройки → **Запускать при входе в систему**.

### Виджеты

ПКМ на рабочем столе → **Редактировать виджеты** → **Cursor Limits** (Small / Medium / Large).

| Размер | Что видно |
|---|---|
| Small | План, кольцо %, дни до сброса |
| Medium | Auto + API, потрачено, токены |
| Large | То же + разбивка токенов, топ моделей |

### Сборка из исходников

```bash
brew install xcodegen
./scripts/package.sh          # → dist/CursorLimits-*-macos.zip
# или разработка:
xcodegen generate && open CursorLimits.xcodeproj
```

Релиз: `git tag v1.0.0 && git push origin v1.0.0` (GitHub Action соберёт zip).

### Приватность

См. [SECURITY.md](SECURITY.md). Данные usage остаются на Mac. Не коммитьте `snapshot.json` и `state.vscdb`.
