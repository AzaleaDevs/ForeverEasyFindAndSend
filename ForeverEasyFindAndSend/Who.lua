local _, ns = ...

local Who = {}
ns.Who = Who

local MIN_REQUEST_INTERVAL = 10
local REQUEST_TIMEOUT = 15

local pending = false
local cooldownUntil = 0
local requestGeneration = 0
local lastQuery = ""
local statusText = ""
local lastError

local function Now()
    return type(GetTime) == "function" and GetTime() or 0
end

local function Trim(value)
    if type(value) ~= "string" then
        return ""
    end
    return string.match(value, "^%s*(.-)%s*$") or ""
end

local function CleanValue(value)
    if value == nil or value == "" then
        return nil
    end
    return value
end

local function SplitName(actionName)
    local separator = " "
    if Constants and Constants.CharacterNameSeparatorConsts then
        separator = Constants.CharacterNameSeparatorConsts.CHARACTERNAME_SURNAME_SEPARATOR or separator
    end

    local separatorStart = string.find(actionName, separator, 1, true)
    if not separatorStart then
        return actionName, nil
    end

    return CleanValue(string.sub(actionName, 1, separatorStart - 1)),
        CleanValue(string.sub(actionName, separatorStart + string.len(separator)))
end

local function APIsAvailable()
    return C_FriendList
        and type(C_FriendList.SendWho) == "function"
        and type(C_FriendList.GetNumWhoResults) == "function"
        and type(C_FriendList.GetWhoInfo) == "function"
end

local function NotifyUI()
    if ns.MailContacts and ns.MailContacts.UpdateWhoState then
        ns.MailContacts.UpdateWhoState()
    end
end

local function ScheduleStateUpdate(delay, generation)
    if not C_Timer or type(C_Timer.After) ~= "function" then
        return
    end

    C_Timer.After(delay, function()
        if not generation or generation == requestGeneration then
            NotifyUI()
        end
    end)
end

function Who.CanRequest(query)
    query = Trim(query)
    return APIsAvailable() and query ~= "" and not pending and Now() >= cooldownUntil
end

function Who.GetState(query)
    if not APIsAvailable() then
        return false, ns.L.SEARCH_ONLINE, ns.L.WHO_UNAVAILABLE
    end
    if pending then
        return false, ns.L.SEARCHING, statusText
    end
    if Trim(query) == "" then
        return false, ns.L.SEARCH_ONLINE, ""
    end
    if Now() < cooldownUntil then
        if Trim(query) == lastQuery and statusText ~= "" then
            return false, ns.L.SEARCH_ONLINE, statusText
        end
        return false, ns.L.SEARCH_ONLINE, ns.L.WHO_COOLDOWN
    end
    if Trim(query) ~= lastQuery then
        return true, ns.L.SEARCH_ONLINE, ""
    end
    return true, ns.L.SEARCH_ONLINE, statusText
end

function Who.Request(query)
    query = Trim(query)
    if not Who.CanRequest(query) then
        NotifyUI()
        return false
    end

    requestGeneration = requestGeneration + 1
    local generation = requestGeneration
    lastQuery = query
    pending = true
    cooldownUntil = Now() + MIN_REQUEST_INTERVAL
    statusText = ns.L.SEARCHING_ONLINE
    NotifyUI()

    local origin = Enum and Enum.SocialWhoOrigin and Enum.SocialWhoOrigin.Social
    local succeeded, errorMessage
    if origin ~= nil then
        succeeded, errorMessage = pcall(C_FriendList.SendWho, query, origin)
    else
        succeeded, errorMessage = pcall(C_FriendList.SendWho, query)
    end

    if not succeeded then
        pending = false
        statusText = ns.L.WHO_START_FAILED
        lastError = tostring(errorMessage)
        NotifyUI()
        return false, errorMessage
    end
    lastError = nil

    ScheduleStateUpdate(MIN_REQUEST_INTERVAL)
    if C_Timer and type(C_Timer.After) == "function" then
        C_Timer.After(REQUEST_TIMEOUT, function()
            if generation == requestGeneration and pending then
                pending = false
                statusText = ns.L.WHO_TIMEOUT
                NotifyUI()
            end
        end)
    end

    return true
end

function Who.OnEvent(event)
    if event ~= "WHO_LIST_UPDATE" or not pending or not APIsAvailable() then
        return
    end

    local startedAt = ns.Performance and ns.Performance.Start()

    pending = false
    requestGeneration = requestGeneration + 1

    local numWhos, totalNumWhos = C_FriendList.GetNumWhoResults()
    numWhos = tonumber(numWhos) or 0
    totalNumWhos = tonumber(totalNumWhos) or numWhos
    local imported = 0

    ns.Database.BeginBatch()
    local succeeded, errorMessage = pcall(function()
        for resultIndex = 1, numWhos do
            local info = C_FriendList.GetWhoInfo(resultIndex)
            if type(info) == "table" and CleanValue(info.fullName) then
                local firstName, surname = SplitName(info.fullName)
                local character = ns.Database.Upsert({
                    actionName = info.fullName,
                    displayName = info.fullName,
                    firstName = firstName,
                    surname = surname,
                    level = info.level and info.level > 0 and info.level or nil,
                    race = CleanValue(info.raceStr),
                    class = CleanValue(info.classStr),
                    classFile = CleanValue(info.filename),
                    guild = CleanValue(info.fullGuildName),
                    zone = CleanValue(info.area),
                    source = "who",
                })
                if character then
                    imported = imported + 1
                end
            end
        end
    end)
    if not succeeded then
        statusText = ns.L.WHO_PROCESS_FAILED
        lastError = tostring(errorMessage)
    elseif imported == 0 then
        lastError = nil
        statusText = ns.L.WHO_NO_RESULTS
    elseif totalNumWhos > numWhos then
        lastError = nil
        statusText = string.format(ns.L.WHO_RESULTS_PARTIAL, imported, totalNumWhos)
    else
        lastError = nil
        statusText = string.format(ns.L.WHO_RESULTS, imported)
    end

    ns.Database.RequestRefresh(false)
    ns.Database.EndBatch()
    if startedAt then
        ns.Performance.Stop("WHO.Process", startedAt, {
            results = numWhos,
            reported = totalNumWhos,
            imported = imported,
            succeeded = succeeded,
        })
    end
end

function Who.PrintDebug()
    ns.Print(string.format(
        ns.L.DEBUG_WHO,
        tostring(APIsAvailable()),
        tostring(pending),
        lastQuery,
        math.max(0, cooldownUntil - Now())
    ))
    if lastError then
        ns.Print(string.format(ns.L.DEBUG_WHO_ERROR, lastError))
    end
end
