# WoW Forever API notes

Target: WoW Forever 1.60.1 build 70205, Interface 16001.

This document records the evidence used by Forever Easy Find & Send. It is not a claim that every Mainline API exists in Forever.

## Confirmed in the user's client

- `SendMailNameEditBox` exists.
- `SendMailNameEditBox.autoCompleteSource` is a function.
- `SendMailNameEditBox.autoCompleteContext` is `"mail"`.
- `C_FriendList.GetFriendInfoByIndex` exists.
- `C_FriendList.SendWho` and `C_FriendList.GetWhoInfo` exist, but alpha.3 does not call them.
- `GetUnitName("player", true)` returns the exact full action name.
- `UnitName("player")` returns first name and surname separately.
- The exposed surname separator is a space.

## Confirmed in the Forever FrameXML branch

Reference inspected: [Gethe/wow-ui-source, `forever` branch](https://github.com/Gethe/wow-ui-source/tree/forever).

- The generated FriendList API documentation defines:
  - `C_FriendList.ShowFriends()`
  - `C_FriendList.GetNumFriends()`
  - `C_FriendList.GetFriendInfoByIndex(index)`
  - `FRIENDLIST_UPDATE`
- `FriendInfo` includes `name`, `connected`, optional `className`, `guid`, and `level`.
- The generated GuildInfo API documentation defines:
  - `C_GuildInfo.GuildRoster()`
  - `GUILD_ROSTER_UPDATE`
  - `PLAYER_GUILD_UPDATE`
- Forever's MailFrame calls `GetNumGuildMembers()` and `C_GuildInfo.GuildRoster()` to prepare mail autocomplete.
- The current [Forever API reference for `GetGuildRosterInfo`](https://warcraft.wiki.gg/wiki/API:GetGuildRosterInfo) lists the 17-value roster signature used by alpha.3. The call remains runtime-guarded because it is not part of the generated namespaced documentation inspected above.
- `PLAYER_LOGIN`, `PLAYER_ENTERING_WORLD`, and `GROUP_ROSTER_UPDATE` are event-driven synchronization points.
- `BackdropTemplate`, `SearchBoxTemplate`, `FauxScrollFrameTemplate`, `CLASS_ICON_TCOORDS`, and `RAID_CLASS_COLORS` are present.

## Alpha.3 synchronization policy

- SavedVariables initialize during the addon's `ADDON_LOADED`.
- Player, friends, and the current group are read once at login and refreshed on their official events.
- One guild roster request is sent at initial login when guilded.
- Later guild roster requests only occur after `PLAYER_GUILD_UPDATE`.
- Guild data is consumed only from `GUILD_ROSTER_UPDATE` or an already populated roster cache.
- No `OnUpdate` polling is used.
- No WHO request is made.

All source APIs are checked before use. Missing APIs place that source in an explicit unavailable state.

## Requires real-client validation

- Existence and exact name representation of `GetGuildRosterInfo()` in build 70205, especially for Forever surnames.
- Visual layout of the side panel at different UI scales.
- Visual states of the native `friends-icon-favorites` atlases in the Forever mail panel.
- Class icon texture appearance for every class available in Forever.
- The timing of the first `FRIENDLIST_UPDATE` and `GUILD_ROSTER_UPDATE` on fresh login.

FEFS preserves the exact name returned by each source as `actionName`; it does not reconstruct that value from normalized search data.
