# Forever Easy Find & Send

Forever Easy Find & Send (FEFS) is a World of Warcraft: Forever addon for finding known characters and selecting exact mail recipients without retyping difficult accents, surnames, or special characters.

## Development status

Version `0.1.0-alpha.4` is the first public Alpha candidate for **WoW Forever 1.60.1** (`Interface 16001`). It is an early release and should be treated as pre-release software.

## Alpha features

- Accent-insensitive and separator-tolerant search for names containing accents, spaces, hyphens, apostrophes, and other supported special characters.
- A shared account-wide directory of characters known to FEFS, stored locally in SavedVariables.
- Event-driven loading from the player, WoW friends, current guild, and current party or raid.
- A collapsible contacts agenda integrated with the Send Mail frame.
- General, Guild, and Favorites tabs with real-time filtering and persistent favorites.
- Combined searches using known name, surname, race, class, and level metadata where available.
- Search-as-you-type mail recipient suggestions that preserve the typed query until an explicit selection.
- A dedicated FEFS suggestion popup for `/w`, with class visuals, metadata, mouse selection, Up/Down navigation, Tab, Enter, and Escape.
- Exact `actionName` selection for mail and whispers, without sending mail or chat messages automatically.
- Precomputed in-memory search data and batched roster imports for responsive filtering with large guilds.
- Explicit, user-initiated WHO discovery from General through **Search Online**.
- Class colors and client-provided class icon resources when class metadata is available.
- Localized FEFS interface and messages for English, Spanish, French, and German clients.

FEFS never sends mail or chat messages automatically and never issues automatic WHO queries. Online discovery runs only when the user clicks **Search Online**. It has no external server, telemetry, analytics, or tracking.

## Installation

1. Close World of Warcraft or return to the character selection screen.
2. Copy the `ForeverEasyFindAndSend` directory into the Forever client's `Interface/AddOns` directory.
3. Confirm this file exists directly at:
   `Interface/AddOns/ForeverEasyFindAndSend/ForeverEasyFindAndSend.toc`
4. Enable **Forever Easy Find & Send** in the AddOns list.
5. Log in and open a mailbox.

## Updating from ForeverEasyNames alpha.2

WoW stores SavedVariables in a file associated with the addon's technical identifier. A renamed addon cannot directly open another addon's SavedVariables file.

To migrate existing alpha.2 character data:

1. Keep the old `ForeverEasyNames` folder installed and enabled.
2. Install and enable `ForeverEasyFindAndSend` at the same time.
3. Log in once. The optional dependency makes the old addon load first, then FEFS imports missing legacy records without overwriting FEFS data.
4. Log out normally so `ForeverEasyFindAndSendDB` is saved.
5. Disable or remove the old `ForeverEasyNames` folder before normal use.

The legacy database is not deleted or modified. If there is no legacy data to preserve, install only the new folder.

## Usage

At login, FEFS reports that character information is loading. It prints one concise completion summary. If the guild roster does not arrive before the initial timeout, the summary explicitly reports it as pending; later roster events still update the database and UI.

Open the Send Mail tab to use the contacts panel:

- **GENERAL** lists only characters already known to FEFS from local game data or explicit user actions; it is not a global server directory.
- **Search Online** in General submits the current text to WHO only when clicked, then imports legitimate results into the shared local directory.
- **GUILD** lists the current guild roster and its online state.
- **FAVORITES** (localized by the client language) lists persistent starred characters.
- The envelope button places only the exact character `actionName` in the recipient field.
- The star button adds or removes a favorite immediately.
- The side toggle collapses or expands the panel.

The mail recipient dropdown continues to support Forever's native controls. FEFS preserves the typed query until a suggestion is explicitly selected.

Commands:

- `/fefs` or `/fefs status`: version, schema, and mail integration state.
- `/fefs search <text>`: inspect autocomplete search results.
- `/fefs debug`: print per-source synchronization states and counts.
- `/fefs debug perf`: print lightweight in-memory timing and guild-event metrics.
- `/fefs debug whisper`: enable opt-in whisper input diagnostics for troubleshooting.
- `/fefs debug whisper off`: disable whisper diagnostics. This debug mode is off by default.

Start a whisper with `/w <query>`. Up to five matches from the local FEFS directory appear in a dedicated suggestion popup with available class and character metadata. Use the mouse, Up/Down, Tab, or Enter to select the exact `actionName`; Escape closes the popup. Selection changes the chat editor to WHISPER mode but never sends the message.

## Localization

FEFS uses `GetLocale()` and loads English fallback strings before all consuming modules. `enUS` and `enGB` use English, `esES` and `esMX` use Spanish, `frFR` uses French, and `deDE` uses German. Class names are resolved at presentation time from the client's `C_CreatureInfo.GetClassInfo(classID)` or `LOCALIZED_CLASS_NAMES_MALE[classFile]`, with the stored source string retained only as fallback.

## Data model and privacy

Known characters share one central database. Records may contain exact action/display names, first name, surname, GUID, level, race, class, class file token, guild, zone, sources, favorite state, and first/last observation times. GUID is preferred for enrichment; otherwise FEFS merges only an exact `actionName`. Similar normalized names are never treated as the same identity. Derived search indexes are rebuilt in memory and are never persisted.

All data remains local in `ForeverEasyFindAndSendDB`. FEFS has no external server, telemetry, analytics, tracking, updater, or addon-to-addon data exchange.

## Known limitations

- Forever 1.60.1 is still evolving, so later client builds may require compatibility updates.
- Friends and guild APIs do not expose every metadata field. Unknown race, class, level, or GUID values are omitted rather than inferred.
- Guild online state belongs to the current runtime roster and is not persisted as character identity data.
- Mail autocomplete entries only show FEFS metadata when the same exact action name is known locally.
- Legacy SavedVariables migration requires one bridge session with both addon folders enabled.
- WHO is server-limited and may return only a subset of matching online characters. FEFS does not enumerate the server or retry automatically.
- Forever exposes no documented WHO cooldown query in the inspected API, so FEFS applies a conservative local interval in addition to server restrictions.
- Whisper completion uses only FEFS's existing local directory; chat learning, automatic WHO, and global server enumeration are not implemented.
- Translated layout widths and performance characteristics may vary with client updates and roster size.

## Compatibility research

The APIs and FrameXML assumptions used by alpha.4 are recorded in [docs/FOREVER_API.md](docs/FOREVER_API.md). Every optional source is runtime-guarded, and unavailable sources are reported rather than simulated.

## Issues and contributions

Bug reports should include the Forever version/build, FEFS version, reproduction steps, enabled addons, `/fefs debug` output, and the complete Lua error.

Contributions are welcome. Do not submit copied or obfuscated addon code, executables, telemetry, or code that bypasses protected client functionality.

## License

Forever Easy Find & Send is released under the [MIT License](LICENSE).
