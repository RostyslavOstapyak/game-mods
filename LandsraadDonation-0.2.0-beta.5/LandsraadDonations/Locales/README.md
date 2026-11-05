# Переклади Landsraad Donation / Translation packs

Мова меню автоматично береться з активної мови тексту гри через Unreal GetCurrentLanguage. Мова Windows, Steam або окремий перемикач моду не використовуються. Мод ніколи не викликає SetCurrentLanguage/SetCurrentCulture.

Вбудовані мови: `uk.tsv` (українська), `en.tsv` (English). Для `uk-UA` використовується `uk`, для `en-US` — `en`. Інша мова використовує власний файл, файл базової мови або English. Відсутні ключі в частковому перекладі також беруться з English.

## Add a language

1. Copy `en.tsv` to a lower-case IETF language filename, e.g. `de.tsv`, `fr.tsv` or `pt-br.tsv`, in this folder.
2. Keep UTF-8 encoding, the key before each TAB, and all `%s` / `%d` placeholders in the same order. Change only the text after the TAB. Preserve leading/trailing spaces in fragments.
3. `\n` means a line break, `\t` a TAB, `\\` a literal backslash. Lines starting with # are comments. Translation files are data, never executed as Lua.
4. Restart the game after installing/changing a pack. Select the corresponding text language in the game's settings and reopen the mod. No mod-specific language selector is needed.
5. Item names, house names and reward names come from the game's own localized data; do not replace them in these packs.

`source.tsv` records original strings for translator context and backend-status matching. Do not rename keys or edit that file for an ordinary translation. `ui.*` keys are interface text; `msg.*` keys include donation status/error fragments. IDs are stable; append new IDs rather than renumbering existing keys.

Malformed/oversized packs are ignored with a log message and English fallback. Packs are bounded to256 KiB/4096 entries. Unknown technical diagnostics from the engine or dependencies may retain their original language; their text is not part of this mod's translation API.

## Developer API

`local L = dofile(DIR .. '/localization.lua')`

- `L.refresh()` — read the game's current language on the game thread; returns whether the language tag changed. Never changes game settings.
- `L.t('ui.004')` — localized string (`How it works` / `Як це працює`). Optional second argument substitutes named `{value}` placeholders in new keys.
- `L.message(text)` — localize known backend status/error text at the presentation boundary, without changing journals or transaction data.
- `L.tag` — active game language tag; `L.code` — selected pack (may be `en` fallback).

Changing language clears display-name caches and prepares the item catalog in the new game language on next opening. Persisted house requests and donation configuration are preserved.
