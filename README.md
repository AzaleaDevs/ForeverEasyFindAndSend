# Forever Easy Find & Send

Forever Easy Find & Send (FEFS) is a World of Warcraft: Forever addon for finding known characters and selecting exact mail recipients without retyping difficult accents, surnames, or special characters.

## Development status

The project is in early alpha development and targets **WoW Forever 1.60.1 build 70205** (`Interface 16001`). Version `0.1.0-alpha.4` is intended for local testing and is not a stable release.

## Alpha features

- Accent-insensitive and separator-tolerant character name search.
- Search-as-you-type mail autocomplete that never replaces the typed query automatically.
- Native whisper autocomplete enrichment for `/w`, with exact recipient selection and no automatic message sending.
- Exact `actionName` insertion only after an explicit native-dropdown selection.
- Native autocomplete results remain available and are deduplicated against FEFS results.
- A shared account-wide character directory stored in SavedVariables.
- Event-driven loading from the player, WoW friends, current guild, and current party or raid.
- A collapsible contacts panel attached to the Send Mail frame.
- General, Guild, and Favorites views with real-time filtering.
- Combined searches using name, surname, race, class, and level, such as `orc shaman` or `60 shaman`.
- Precomputed in-memory search data and batched roster imports for responsive filtering with large guilds.
- Explicit, user-initiated WHO discovery from General through **Search Online**.
- Persistent favorites that do not remove characters from the general directory.
- Class colors and client-provided class icon resources when class metadata is available.
- Localized FEFS interface and messages for English, Spanish, French, and German clients.

FEFS never sends mail automatically and never issues automatic WHO queries. Online discovery runs only when the user clicks **Search Online**.

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

- **GENERAL** lists characters known to FEFS.
- **Search Online** in General submits the current text to WHO only when clicked, then imports legitimate results into the shared local directory.
- **GUILD** lists the current guild roster and its online state.
- **FAVORITES** (localized by the client language) lists persistent starred characters.
- The envelope button places only the exact character `actionName` in the recipient field.
- The star button adds or removes a favorite immediately.
- The side toggle collapses or expands the panel.

The native mail dropdown continues to support Up/Down, Enter, mouse selection, and Escape. Tab retains Forever's native navigation behavior and does not confirm a selection.

Commands:

- `/fefs` or `/fefs status`: version, schema, and mail integration state.
- `/fefs search <text>`: inspect autocomplete search results.
- `/fefs debug`: print per-source synchronization states and counts.
- `/fefs debug perf`: print lightweight in-memory timing and guild-event metrics.

Start a whisper with `/w <query>`. FEFS suggestions appear first in Forever's native autocomplete dropdown and include metadata for recognition. Selecting one changes the chat editor to a whisper addressed to the exact `actionName`; FEFS never sends the message.

## Localization

FEFS uses `GetLocale()` and loads English fallback strings before all consuming modules. `enUS` and `enGB` use English, `esES` and `esMX` use Spanish, `frFR` uses French, and `deDE` uses German. Class names are resolved at presentation time from the client's `C_CreatureInfo.GetClassInfo(classID)` or `LOCALIZED_CLASS_NAMES_MALE[classFile]`, with the stored source string retained only as fallback.

## Development fixtures

The following names remain available only to exercise autocomplete and normalization:

- `Amigo Kebab`
- `Amigö Kebäck`
- `Âmïgø Këbäck`

Fixtures are memory-only, are not shown as real contacts in the side panel, and are never written to SavedVariables.

## Data model and privacy

Known characters share one central database. Records may contain exact action/display names, first name, surname, GUID, level, race, class, class file token, guild, zone, sources, favorite state, and first/last observation times. GUID is preferred for enrichment; otherwise FEFS merges only an exact `actionName`. Similar normalized names are never treated as the same identity. Derived search indexes are rebuilt in memory and are never persisted.

All data remains local in `ForeverEasyFindAndSendDB`. FEFS has no external server, telemetry, analytics, tracking, updater, or addon-to-addon data exchange.

## Known limitations

- Forever 1.60.1 is still evolving; alpha.4 requires validation in build 70205.
- Friends and guild APIs do not expose every metadata field. Unknown race, class, level, or GUID values are omitted rather than inferred.
- Guild online state belongs to the current runtime roster and is not persisted as character identity data.
- Native autocomplete entries only show metadata when the same exact action name is known to FEFS.
- Forever's native autocomplete renderer uses one text style for the entire suggestion row.
- The class icons, native favorite atlas, scroll template, and panel dimensions require visual validation in the real Forever client.
- Legacy SavedVariables migration requires one bridge session with both addon folders enabled.
- WHO is server-limited and may return only a subset of matching online characters. FEFS does not enumerate the server or retry automatically.
- Forever exposes no documented WHO cooldown query in the inspected API, so FEFS applies a conservative local interval in addition to server restrictions.
- Whisper completion uses only FEFS's existing local directory; chat learning, automatic WHO, and global server enumeration are not implemented.
- Native whisper behavior, translated layout widths, and performance timings require validation in the real client.

## Compatibility research

The APIs and FrameXML assumptions used by alpha.3.1 are recorded in [docs/FOREVER_API.md](docs/FOREVER_API.md). Every optional source is runtime-guarded, and unavailable sources are reported rather than simulated.

## Issues and contributions

Bug reports should include the Forever version/build, FEFS version, reproduction steps, enabled addons, `/fefs debug` output, and the complete Lua error.

Contributions are welcome. Do not submit copied or obfuscated addon code, executables, telemetry, or code that bypasses protected client functionality.

## License

Forever Easy Find & Send is released under the [MIT License](LICENSE).
