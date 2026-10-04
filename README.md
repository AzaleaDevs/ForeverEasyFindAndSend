# Forever Easy Find & Send

Forever Easy Find & Send is a World of Warcraft: Forever addon that provides accent-insensitive character search, enhanced mail autocomplete, and a local character directory.

## Development status

The project is in early alpha development and targets **WoW Forever 1.60.1** (`Interface 16001`). The first milestone is a prototype for the mail recipient field.

## Alpha features

- Accent-insensitive and separator-tolerant character name search.
- Mail recipient suggestions through Forever's native autocomplete UI.
- Search-as-you-type behavior that leaves the recipient query unchanged.
- Optional level, race, and class metadata in suggestion rows.
- Exact insertion of the selected character name only after an explicit click or Enter.
- A temporary in-memory fixture with difficult names for local testing.

The fixture is development data. It is not written to SavedVariables and will be removed after real character sources are implemented.

## Installation

1. Close World of Warcraft or return to the character selection screen.
2. Copy the `ForeverEasyFindAndSend` directory into the Forever client's `Interface/AddOns` directory.
3. Start Forever and enable **Forever Easy Find & Send** in the AddOns list.
4. Log in and open a mailbox.

## Usage

Open the Send Mail tab and type part of a test character name in the **To:** field. For example, `ami`, `keback`, or `amigokeback`.

Typing does not replace or complete the current query. Use Up/Down to change the highlighted suggestion, Enter or a mouse click to select it, and Escape to close the suggestions. Only the exact character name is inserted; displayed metadata is never part of the recipient.

The following development-only characters are available in `0.1.0-alpha.2`:

- `Amigo Kebab`
- `Amigö Kebäck`
- `Âmïgø Këbäck`

Use `/fefs status` to print the addon version and mail integration state. Use `/fefs search <text>` to inspect search results in chat.

## Known limitations

- Character acquisition from friends, guild, groups, chat, and WHO is not implemented.
- The dropdown uses Forever's native row renderer, so the metadata uses the same text styling as the character name.
- Tab follows the native autocomplete navigation behavior and does not confirm a selection.
- The prototype has only been designed for WoW Forever 1.60.1 build 70205.
- SavedVariables persistence must still be validated on the current Forever client.

## Privacy

Forever Easy Find & Send does not use external servers, telemetry, analytics, or tracking. Learned character data is stored locally through WoW SavedVariables.

## Roadmap

- Replace development fixtures with legitimate local character sources.
- Add whisper/chat integration after mail autocomplete is validated.
- Add an explicit, user-initiated WHO search while respecting client restrictions and throttling.

## Issues and contributions

Bug reports should include the Forever version and build, Forever Easy Find & Send version, reproduction steps, enabled addons, and the complete Lua error if one is shown.

Contributions are welcome. Do not submit copied or obfuscated addon code, executable files, telemetry, or code that attempts to bypass protected client functionality.

## License

Forever Easy Find & Send is released under the [MIT License](LICENSE).
