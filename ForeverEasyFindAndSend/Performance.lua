local _, ns = ...

local Performance = {}
ns.Performance = Performance

local SLOW_THRESHOLD_MS = 50
local SLOW_BUFFER_SIZE = 10

local available = type(debugprofilestop) == "function"
local enabled = false
local metrics = {}
local metricOrder = {}
local slowCalls = {}
local slowWriteIndex = 0
local slowCount = 0
local completionOrder = 0
local guildEvents = 0
local guildEventsCoalesced = 0

local function GetMetric(name)
    local metric = metrics[name]
    if not metric then
        metric = { calls = 0, last = 0, max = 0, total = 0 }
        metrics[name] = metric
        metricOrder[#metricOrder + 1] = name
    end
    return metric
end

local function CopyContext(fields)
    if type(fields) ~= "table" then
        return nil
    end

    local context
    for key, value in pairs(fields) do
        local valueType = type(value)
        if valueType == "number" or valueType == "string" or valueType == "boolean" then
            context = context or {}
            context[key] = value
        end
    end
    return context
end

local function AddSlowCall(name, elapsed, fields)
    slowWriteIndex = (slowWriteIndex % SLOW_BUFFER_SIZE) + 1
    slowCount = math.min(slowCount + 1, SLOW_BUFFER_SIZE)
    slowCalls[slowWriteIndex] = {
        order = completionOrder,
        timestamp = type(GetTime) == "function" and GetTime() or 0,
        operation = name,
        duration = elapsed,
        context = CopyContext(fields),
    }
end

local function FormatContext(context)
    if type(context) ~= "table" then
        return ""
    end

    local keys = {}
    for key in pairs(context) do
        keys[#keys + 1] = key
    end
    table.sort(keys)

    local values = {}
    for index = 1, #keys do
        local key = keys[index]
        values[#values + 1] = tostring(key) .. "=" .. tostring(context[key])
    end
    return table.concat(values, " ")
end

function Performance.IsAvailable()
    return available
end

function Performance.IsEnabled()
    return enabled
end

function Performance.SetEnabled(value)
    if value == true and not available then
        enabled = false
        return false
    end

    enabled = value == true
    return true
end

function Performance.Start()
    if enabled and available then
        return debugprofilestop()
    end
end

function Performance.Stop(name, startedAt, fields)
    if not enabled or not available or type(startedAt) ~= "number" then
        return 0
    end

    local elapsed = math.max(0, debugprofilestop() - startedAt)
    local metric = GetMetric(name)
    metric.calls = metric.calls + 1
    metric.last = elapsed
    metric.max = math.max(metric.max, elapsed)
    metric.total = metric.total + elapsed

    if type(fields) == "table" then
        for key, value in pairs(fields) do
            metric[key] = value
        end
    end

    completionOrder = completionOrder + 1
    if elapsed >= SLOW_THRESHOLD_MS then
        AddSlowCall(name, elapsed, fields)
    end
    return elapsed
end

function Performance.Elapsed(startedAt)
    if enabled and available and type(startedAt) == "number" then
        return math.max(0, debugprofilestop() - startedAt)
    end
    return 0
end

function Performance.GuildEvent(coalesced)
    if not enabled then
        return
    end

    guildEvents = guildEvents + 1
    if coalesced then
        guildEventsCoalesced = guildEventsCoalesced + 1
    end
end

function Performance.ContactRefresh(reason, startedAt, logical, rendered)
    if not enabled or type(startedAt) ~= "number" then
        return
    end

    Performance.Stop("MailContacts.Refresh", startedAt, {
        reason = type(reason) == "string" and reason or "other",
        logical = logical == true,
        rendered = rendered == true,
    })
end

function Performance.Reset()
    wipe(metrics)
    wipe(metricOrder)
    wipe(slowCalls)
    slowWriteIndex = 0
    slowCount = 0
    completionOrder = 0
    guildEvents = 0
    guildEventsCoalesced = 0
end

function Performance.GetMetrics()
    return metrics
end

function Performance.GetSlowCalls()
    local ordered = {}
    if slowCount == 0 then
        return ordered
    end

    local first = slowCount == SLOW_BUFFER_SIZE and (slowWriteIndex % SLOW_BUFFER_SIZE) + 1 or 1
    for offset = 0, slowCount - 1 do
        local index = ((first + offset - 1) % SLOW_BUFFER_SIZE) + 1
        ordered[#ordered + 1] = slowCalls[index]
    end
    return ordered
end

function Performance.GetSlowThreshold()
    return SLOW_THRESHOLD_MS
end

function Performance.Print()
    local L = ns.L
    if not available then
        ns.Print(L.PERF_UNAVAILABLE)
        return
    end

    ns.Print(string.format(L.PERF_HEADER, enabled and L.PERF_ON or L.PERF_OFF, SLOW_THRESHOLD_MS))
    ns.Print(string.format(L.PERF_GUILD_EVENTS, guildEvents, guildEventsCoalesced))
    for index = 1, #metricOrder do
        local name = metricOrder[index]
        local metric = metrics[name]
        ns.Print(string.format(L.PERF_OPERATION, name, metric.calls, metric.last, metric.max, metric.total))
    end

    local recent = Performance.GetSlowCalls()
    ns.Print(string.format(L.PERF_SLOW_HEADER, #recent, SLOW_BUFFER_SIZE))
    for index = 1, #recent do
        local slow = recent[index]
        ns.Print(string.format(
            L.PERF_SLOW_ENTRY,
            slow.order,
            slow.timestamp,
            slow.operation,
            slow.duration,
            FormatContext(slow.context)
        ))
    end
end
