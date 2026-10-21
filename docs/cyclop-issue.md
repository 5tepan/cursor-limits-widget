# Draft: issue for akalikbergenov/cyclop

Paste into https://github.com/akalikbergenov/cyclop/issues/new  
(Language: Russian — matches CONTRIBUTING; English summary at the top.)

---

**Title:** Вкладка Limits — read-only зеркало Cursor Limits (без сети)

```markdown
## Summary (EN)

Proposal: optional **Limits** rail tab that **only reads** a local JSON snapshot
written by [Cursor Limits](https://github.com/5tepan/cursor-limits-widget)
(`~/Library/Application Support/CursorLimits/app-snapshot.json`). **No HTTP**
from Cyclop. Toggle in Settings → Show in Panel. Both apps installed.

Happy to open a small PR after discussion — per CONTRIBUTING, filing an issue first.

---

## Зачем

Есть отдельное MIT-приложение [Cursor Limits](https://github.com/5tepan/cursor-limits-widget):
меню-бар + виджеты с usage Cursor / Claude Code / Codex / Ollama Cloud /
OpenCode Go / Copilot. Оно уже пишет агрегат на диск и само ходит в API
провайдеров.

В вырезе Cyclop было бы удобно увидеть **primary %** (и при желании 1–2
соседних провайдера) за секунду — без дублирования auth и без новых исходящих
соединений из Cyclop.

Это стыкуется с философией из CONTRIBUTING / SECURITY:

- **сеть не трогаем** — вкладка только читает файл;
- **рельс для частого** — лимиты смотрят регулярно; вкладка отключается в
  Settings, кому не нужна;
- **фон только пока смотрят** — polling файла, пока вкладка включена (как
  Clipboard), иначе стоп.

## Что предлагаю (scope одного PR)

1. Новая вкладка **Limits** / **Лимиты** на рельсе.
2. Чтение  
   `~/Library/Application Support/CursorLimits/app-snapshot.json`  
   (контракт: schemaVersion, ISO-8601 dates — см.
   [snapshot-contract.md](https://github.com/5tepan/cursor-limits-widget/blob/main/docs/snapshot-contract.md);
   сейчас готовлю/уже в репо).
3. UI: кольцо primary + короткий список окон usage; если файла нет —
   «Установите и запустите Cursor Limits» + кнопка открыть приложение /
   `cursorlimits://settings`.
4. Опционально кнопка «обновить» → `cursorlimits://refresh` (сеть снова на
   стороне Cursor Limits).
5. Toggle в Settings → Show in Panel; en + ru Localizable.
6. **Не** копировать провайдеры / refresh / токены в Cyclop.

## Что это не делает

- Не добавляет исходящие HTTP-запросы в Cyclop (SECURITY.md не трогаем).
- Не требует новых TCC-разрешений.
- Не делает Cursor Limits зависимостью сборки Cyclop — только runtime file
  bridge, если оба установлены.

## Вопросы к автору

1. Ок ли вкладка как opt-in (default off), по аналогии с редкими режимами?
2. Достаточно ли primary + 1–2 провайдера, или только одно кольцо?
3. Готовы ли принять PR после согласия, или предпочтительнее форк?

Готов набросать минимальный PR (LimitsStore + LimitsPane + Settings toggle +
строки), когда скажете «да, в таком виде».
```

---

After the issue is open, link it from README / this file.
