local _, ns = ...

local Sources = {}
ns.Sources = Sources

local INITIAL_TIMEOUT_SECONDS = 5

local states = {
    player = "pending",
    friends = "pending",
    guild = "pending",
    group = "pending",
}

local guildEntries = {}
local friendCount = 0
local guildCount = 0
local initialSyncStarted = false
local initialSyncFinished = false
local guildRequestSent = false

local function CleanValue(value)
    if value == nil or value == "" then
        return nil
    end

    return value
end

local function SplitName(actionName)
    if type(actionName) ~= "string" then
        return nil, nil
    end

    local separator = " "
    if Constants and Constants.CharacterNameSeparatorConsts then
        separator = Constants.CharacterNameSeparatorConsts.CHARACTERNAME_SURNAME_SEPARATOR or separator
    end

    local separatorStart = string.find(actionName, separator, 1, true)
    if not separatorStart then
        return actionName, nil
    end

    local firstName = string.sub(actionName, 1, separatorStart - 1)
    local surname = string.sub(actionName, separatorStart + string.len(separator))
    return CleanValue(firstName), CleanValue(surname)
end

local function RefreshConsumers()
    ns.Search.Refresh()
    if ns.MailContacts then
        ns.MailContacts.Refresh()
    end
end

local function UpsertUnit(unit, source)
    if type(GetUnitName) ~= "function" or not UnitExists(unit) then
        return nil
    end

    local actionName = CleanValue(GetUnitName(unit, true))
    if not actionName then
        return nil
    end

    local firstName, surname = UnitName(unit)
    local className, classFile, classID = UnitClass(unit)
    local raceName = UnitRace(unit)
    local level = UnitLevel(unit)

    return ns.Database.Upsert({
        actionName = actionName,
        displayName = actionName,
        firstName = CleanValue(firstName),
        surname = CleanValue(surname),
        guid = CleanValue(UnitGUID(unit)),
        level = level and level > 0 and level or nil,
        race = CleanValue(raceName),
        class = CleanValue(className),
        classFile = CleanValue(classFile),
        classID = classID,
        source = source,
    })
end

local function SyncPlayer()
    states.player = UpsertUnit("player", "player") and "available" or "unavailable"
end

local function SyncFriends()
    if not C_FriendList
        or type(C_FriendList.GetNumFriends) ~= "function"
        or type(C_FriendList.GetFriendInfoByIndex) ~= "function" then
        states.friends = "unavailable"
        friendCount = 0
        return
    end

    local count = C_FriendList.GetNumFriends() or 0
    local processed = 0

    for friendIndex = 1, count do
        local info = C_FriendList.GetFriendInfoByIndex(friendIndex)
        if type(info) == "table" and CleanValue(info.name) then
            local firstName, surname = SplitName(info.name)
            local character = ns.Database.Upsert({
                actionName = info.name,
                displayName = info.name,
                firstName = firstName,
                surname = surname,
                guid = CleanValue(info.guid),
                level = info.level and info.level > 0 and info.level or nil,
                class = CleanValue(info.className),
                source = "friends",
            })
            if character then
                processed = processed + 1
            end
        end
    end

    friendCount = processed
    states.friends = "available"
end

local function SyncGroup()
    states.group = "available"
    UpsertUnit("player", "player")

    local prefix
    local count
    if IsInRaid() then
        prefix = "raid"
        count = MAX_RAID_MEMBERS or 40
    else
        prefix = "party"
        count = GetNumSubgroupMembers()
    end

    for memberIndex = 1, count do
        UpsertUnit(prefix .. memberIndex, "group")
    end
end

local function SyncGuild()
    wipe(guildEntries)
    guildCount = 0

    if not IsInGuild() then
        states.guild = "none"
        return
    end

    if type(GetNumGuildMembers) ~= "function" or type(GetGuildRosterInfo) ~= "function" then
        states.guild = "unavailable"
        return
    end

    local memberCount = GetNumGuildMembers() or 0
    for memberIndex = 1, memberCount do
        local name, _, _, level, className, _, _, _, isOnline, _, classFile, _, _, _, _, _, guid =
            GetGuildRosterInfo(memberIndex)

        name = CleanValue(name)
        if name then
            local firstName, surname = SplitName(name)
            local character = ns.Database.Upsert({
                actionName = name,
                displayName = name,
                firstName = firstName,
                surname = surname,
                guid = CleanValue(guid),
                level = level and level > 0 and level or nil,
                class = CleanValue(className),
                classFile = CleanValue(classFile),
                source = "guild",
            })

            if character then
                guildEntries[#guildEntries + 1] = {
                    record = character,
                    isOnline = isOnline == true,
                }
                guildCount = guildCount + 1
            end
        end
    end

    states.guild = "available"
end

local function GuildSummary()
    if states.guild == "available" then
        return string.format("%d hermandad", guildCount)
    elseif states.guild == "none" then
        return "sin hermandad"
    elseif states.guild == "unavailable" then
        return "hermandad no disponible"
    end

    return "hermandad pendiente"
end

local function FinishInitialSync()
    if not initialSyncStarted or initialSyncFinished then
        return
    end

    initialSyncFinished = true
    local stats = ns.Database.GetStats()
    ns.Print(string.format(
        "Listo: %d contactos · %s · %d favoritos.",
        stats.contacts,
        GuildSummary(),
        stats.favorites
    ))
end

local function MaybeFinishInitialSync()
    if initialSyncStarted and states.guild ~= "pending" then
        FinishInitialSync()
    end
end

local function RequestGuildRoster()
    if not IsInGuild() then
        states.guild = "none"
        MaybeFinishInitialSync()
        return
    end

    if not C_GuildInfo or type(C_GuildInfo.GuildRoster) ~= "function" then
        states.guild = "unavailable"
        MaybeFinishInitialSync()
        return
    end

    if not guildRequestSent then
        guildRequestSent = true
        C_GuildInfo.GuildRoster()
    end
end

function Sources.StartInitialSync()
    if initialSyncStarted then
        return
    end

    initialSyncStarted = true
    ns.Print("Cargando información de jugadores...")

    SyncPlayer()

    if C_FriendList and type(C_FriendList.ShowFriends) == "function" then
        C_FriendList.ShowFriends()
    end
    SyncFriends()
    SyncGroup()

    if IsInGuild()
        and type(GetNumGuildMembers) == "function"
        and (GetNumGuildMembers() or 0) > 0 then
        SyncGuild()
    end
    RequestGuildRoster()
    RefreshConsumers()
    MaybeFinishInitialSync()

    if not initialSyncFinished then
        if C_Timer and type(C_Timer.After) == "function" then
            C_Timer.After(INITIAL_TIMEOUT_SECONDS, FinishInitialSync)
        else
            FinishInitialSync()
        end
    end
end

function Sources.OnEvent(event, ...)
    if event == "FRIENDLIST_UPDATE" then
        SyncFriends()
    elseif event == "GROUP_ROSTER_UPDATE" then
        SyncGroup()
    elseif event == "GUILD_ROSTER_UPDATE" then
        SyncGuild()
        MaybeFinishInitialSync()
    elseif event == "PLAYER_GUILD_UPDATE" then
        guildRequestSent = false
        SyncGuild()
        RequestGuildRoster()
    elseif event == "PLAYER_ENTERING_WORLD" then
        SyncPlayer()
        SyncGroup()
    else
        return
    end

    RefreshConsumers()
end

function Sources.GetGuildEntries()
    return guildEntries
end

function Sources.GetState()
    return states
end

function Sources.PrintDebug()
    ns.Print(string.format(
        "debug: player=%s, friends=%s (%d), guild=%s (%d), group=%s",
        states.player,
        states.friends,
        friendCount,
        states.guild,
        guildCount,
        states.group
    ))
end
