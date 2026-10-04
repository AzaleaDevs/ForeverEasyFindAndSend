# WoW Forever API notes

Target: WoW Forever 1.60.1 build 70205, Interface 16001.

This document records the evidence used by Forever Easy Find & Send. It is not a claim that every Mainline API exists in Forever.

## Confirmed in the user's client

- `SendMailNameEditBox` exists.
- `SendMailNameEditBox.autoCompleteSource` is a function.
- `SendMailNameEditBox.autoCompleteContext` is `"mail"`.
- `C_FriendList.GetFriendInfoByIndex` exists.
- `C_FriendList.SendWho` and `C_FriendList.GetWhoInfo` exist.
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

### WHO API inspected for alpha.3.1

The generated Forever FriendList documentation declares:

- `C_FriendList.SendWho(filter, origin?, filters?)`. It is marked restricted, requires the friend list, and permits secret arguments only when untainted.
- `C_FriendList.GetNumWhoResults()` returning `numWhos, totalNumWhos`.
- `C_FriendList.GetWhoInfo(index)` returning a `WhoInfo` table.
- `WHO_LIST_UPDATE` as the result event.

`WhoInfo` contains `fullName`, `fullGuildName`, `level`, `raceStr`, `classStr`, `area`, optional `filename`, `gender`, and optional `timerunningSeasonID`. FEFS alpha.3.1 consumes only `fullName`, `fullGuildName`, `level`, `raceStr`, `classStr`, `area`, and `filename`.

Forever's own `WhoFrameEditBoxMixin:OnEnterPressed()` calls `C_FriendList.SendWho(text, Enum.SocialWhoOrigin.Social)`. FEFS follows that signature only from the General panel button's click handler. The inspected API and FrameXML expose no cooldown-query function. FEFS therefore allows one pending request, applies a 10-second local minimum interval, times out its UI state after 15 seconds, and never retries automatically.

## Alpha.3.1 synchronization policy

- SavedVariables initialize during the addon's `ADDON_LOADED`.
- Player, friends, and the current group are read once at login and refreshed on their official events.
- One guild roster request is sent at initial login when guilded.
- Later guild roster requests only occur after `PLAYER_GUILD_UPDATE`.
- Guild data is consumed only from `GUILD_ROSTER_UPDATE` or an already populated roster cache.
- No `OnUpdate` polling is used.
- WHO requests are never made by login, events, timers, typing, or empty local results. Only a direct click on **Search Online** calls `SendWho`.
- FEFS consumes `WHO_LIST_UPDATE` only while its own request is pending and stores returned records with the `who` source.
- Database identity indexes are updated incrementally. Bulk source imports batch consumer invalidation into one search/UI refresh.

All source APIs are checked before use. Missing APIs place that source in an explicit unavailable state.

## Requires real-client validation

- Existence and exact name representation of `GetGuildRosterInfo()` in build 70205, especially for Forever surnames.
- Visual layout of the side panel at different UI scales.
- Visual states of the native `friends-icon-favorites` atlases in the Forever mail panel.
- Class icon texture appearance for every class available in Forever.
- The timing of the first `FRIENDLIST_UPDATE` and `GUILD_ROSTER_UPDATE` on fresh login.
- WHO server throttling behavior and result timing. No queryable cooldown was found, so the local interval is deliberately conservative and remains subject to server enforcement.

FEFS preserves the exact name returned by each source as `actionName`; it does not reconstruct that value from normalized search data.
