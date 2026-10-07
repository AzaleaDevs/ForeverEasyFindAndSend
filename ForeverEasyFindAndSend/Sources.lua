local _, ns = ...

local Sources = {}
ns.Sources = Sources

local INITIAL_TIMEOUT_SECONDS = 5
local GUILD_EVENT_DEBOUNCE_SECONDS = 0.25

local states = {
    player = "pending",
    friends = "pending",
    guild = "pending",
    group = "pending",
}

local guildEntries = {}
local guildSnapshot = {}
local friendCount = 0
local guildCount = 0
local initialSyncStarted = false
local initialSyncFinished = false
local guildRequestSent = false
local guildSyncScheduled = false

local EVENT_OPERATION = {
    FRIENDLIST_UPDATE = "Sources.FriendsEvent",
    GROUP_ROSTER_UPDATE = "Sources.GroupEvent",
    PLAYER_GUILD_UPDATE = "Sources.PlayerGuildEvent",
    PLAYER_ENTERING_WORLD = "Sources.EnteringWorldEvent",
}

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

local function RunBatch(operation, callback)
    local startedAt = ns.Performance and ns.Performance.Start()
    ns.Database.BeginBatch()
    local succeeded, result1, result2 = pcall(callback)
    ns.Database.RequestRefresh(false)
    ns.Database.EndBatch()

    if startedAt then
        local fields = { succeeded = succeeded }
        if operation == "Sources.GuildSync" then
            fields.processed = result1 or 0
            fields.modified = result2 or 0
        end
        ns.Performance.Stop(operation, startedAt, fields)
    end

    if not succeeded then
        error(result1, 0)
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
    local startedAt = ns.Performance and ns.Performance.Start()
    states.player = UpsertUnit("player", "player") and "available" or "unavailable"
    if startedAt then
        ns.Performance.Stop("Sources.PlayerSync", startedAt, { state = states.player })
    end
end

local function SyncFriends()
    local startedAt = ns.Performance and ns.Performance.Start()
    if not C_FriendList
        or type(C_FriendList.GetNumFriends) ~= "function"
        or type(C_FriendList.GetFriendInfoByIndex) ~= "function" then
        states.friends = "unavailable"
        friendCount = 0
        if startedAt then
            ns.Performance.Stop("Sources.FriendsSync", startedAt, { processed = 0, state = states.friends })
        end
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
    if startedAt then
        ns.Performance.Stop("Sources.FriendsSync", startedAt, {
            available = count,
            processed = processed,
            state = states.friends,
        })
    end
end

local function SyncGroup()
    local startedAt = ns.Performance and ns.Performance.Start()
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
    if startedAt then
        ns.Performance.Stop("Sources.GroupSync", startedAt, { members = count })
    end
end

local function SyncGuild()
    local startedAt = ns.Performance and ns.Performance.Start()
    wipe(guildEntries)
    guildCount = 0
    local processed = 0
    local modified = 0

    if not IsInGuild() then
        wipe(guildSnapshot)
        states.guild = "none"
        if startedAt then
            ns.Performance.Stop("Sources.GuildScan", startedAt, { processed = 0, modified = 0, state = states.guild })
        end
        return 0, 0
    end

    if type(GetNumGuildMembers) ~= "function" or type(GetGuildRosterInfo) ~= "function" then
        states.guild = "unavailable"
        if startedAt then
            ns.Performance.Stop("Sources.GuildScan", startedAt, { processed = 0, modified = 0, state = states.guild })
        end
        return 0, 0
    end

    local memberCount = GetNumGuildMembers() or 0
    if memberCount == 0 then
        states.guild = "pending"
        if startedAt then
            ns.Performance.Stop("Sources.GuildScan", startedAt, { processed = 0, modified = 0, state = states.guild })
        end
        return 0, 0
    end

    local nextSnapshot = {}
    for memberIndex = 1, memberCount do
        local name, _, _, level, className, _, _, _, isOnline, _, classFile, _, _, _, _, _, guid =
            GetGuildRosterInfo(memberIndex)

        name = CleanValue(name)
        if name then
            processed = processed + 1
            guid = CleanValue(guid)
            className = CleanValue(className)
            classFile = CleanValue(classFile)
            level = level and level > 0 and level or nil
            local identity = guid or name
            local signature = table.concat({
                name,
                tostring(guid or ""),
                tostring(level or ""),
                tostring(className or ""),
                tostring(classFile or ""),
                tostring(isOnline == true),
            }, "\031")
            local previous = guildSnapshot[identity]
            local character = previous and previous.signature == signature and previous.record

            if not character then
                local firstName, surname = SplitName(name)
                character = ns.Database.Upsert({
                    actionName = name,
                    displayName = name,
                    firstName = firstName,
                    surname = surname,
                    guid = guid,
                    level = level,
                    class = className,
                    classFile = classFile,
                    source = "guild",
                })
                if character then
                    modified = modified + 1
                end
            end

            if character then
                nextSnapshot[identity] = { signature = signature, record = character }
                guildEntries[#guildEntries + 1] = {
                    record = character,
                    isOnline = isOnline == true,
                }
                guildCount = guildCount + 1
            end
        end
    end

    guildSnapshot = nextSnapshot
    states.guild = "available"
    if startedAt then
        ns.Performance.Stop("Sources.GuildScan", startedAt, {
            members = memberCount,
            processed = processed,
            modified = modified,
            state = states.guild,
        })
    end
    return processed, modified
end

local function GuildSummary()
    if states.guild == "available" then
        return string.format(ns.L.GUILD_COUNT, guildCount)
    elseif states.guild == "none" then
        return ns.L.NO_GUILD
    elseif states.guild == "unavailable" then
        return ns.L.GUILD_UNAVAILABLE
    end

    return ns.L.GUILD_PENDING
end

local function ContactsSummary(stats)
    local unavailable = {}
    if states.player == "unavailable" then
        unavailable[#unavailable + 1] = ns.L.PLAYER_UNAVAILABLE
    end
    if states.friends == "unavailable" then
        unavailable[#unavailable + 1] = ns.L.FRIENDS_UNAVAILABLE
    end

    local summary = string.format(ns.L.CONTACTS_COUNT, stats.contacts)
    if #unavailable > 0 then
        summary = string.format("%s (%s)", summary, table.concat(unavailable, ", "))
    end

    return summary
end

local function FinishInitialSync()
    if not initialSyncStarted or initialSyncFinished then
        return
    end

    initialSyncFinished = true
    local stats = ns.Database.GetStats()
    ns.Print(string.format(
        ns.L.READY_SUMMARY,
        ContactsSummary(stats),
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
    ns.Print(ns.L.LOADING_PLAYERS)

    RunBatch("Sources.InitialSync", function()
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
    end)
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
    if event == "GUILD_ROSTER_UPDATE" then
        local coalesced = guildSyncScheduled
        if ns.Performance then
            ns.Performance.GuildEvent(coalesced)
        end
        if coalesced then
            return
        end

        guildSyncScheduled = true
        local function RunGuildSync()
            guildSyncScheduled = false
            RunBatch("Sources.GuildSync", function()
                local processed, modified = SyncGuild()
                MaybeFinishInitialSync()
                return processed, modified
            end)
        end
        if C_Timer and type(C_Timer.After) == "function" then
            C_Timer.After(GUILD_EVENT_DEBOUNCE_SECONDS, RunGuildSync)
        else
            RunGuildSync()
        end
        return
    end

    RunBatch(EVENT_OPERATION[event] or "Sources.OtherEvent", function()
        if event == "FRIENDLIST_UPDATE" then
            SyncFriends()
        elseif event == "GROUP_ROSTER_UPDATE" then
            SyncGroup()
        elseif event == "PLAYER_GUILD_UPDATE" then
            guildRequestSent = false
            SyncGuild()
            RequestGuildRoster()
        elseif event == "PLAYER_ENTERING_WORLD" then
            SyncPlayer()
            SyncGroup()
        else
            ns.Database.RequestRefresh(false)
        end
    end)
end

function Sources.GetGuildEntries()
    return guildEntries
end

function Sources.GetState()
    return states
end

function Sources.PrintDebug()
    ns.Print(string.format(
        ns.L.DEBUG_SOURCES,
        states.player,
        states.friends,
        friendCount,
        states.guild,
        guildCount,
        states.group
    ))
end
