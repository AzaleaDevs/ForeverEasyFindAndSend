local _, ns = ...

local Performance = {}
ns.Performance = Performance

local available = type(debugprofilestop) == "function"
local metrics = {
    guild = { events = 0, runs = 0, coalesced = 0, last = 0, max = 0, processed = 0, modified = 0 },
    searchRefresh = { runs = 0, last = 0, max = 0, indexed = 0, records = 0, classes = 0, build = 0, normalized = 0, cacheHits = 0 },
    searchFind = { runs = 0, last = 0, max = 0, scanned = 0, matched = 0 },
    searchFilter = { runs = 0, last = 0, max = 0, scanned = 0, matched = 0 },
    contactsRefresh = {
        runs = 0, last = 0, max = 0, logical = 0, rendered = 0, skipped = 0,
        search = 0, scroll = 0, invalidation = 0, tab = 0, show = 0, other = 0,
    },
}

function Performance.Start()
    if available then
        return debugprofilestop()
    end
end

function Performance.Stop(name, startedAt, fields)
    local metric = metrics[name]
    if not metric then
        return 0
    end

    local elapsed = 0
    if available and type(startedAt) == "number" then
        elapsed = math.max(0, debugprofilestop() - startedAt)
    end
    metric.runs = metric.runs + 1
    metric.last = elapsed
    metric.max = math.max(metric.max, elapsed)

    if type(fields) == "table" then
        for key, value in pairs(fields) do
            metric[key] = value
        end
    end
    return elapsed
end

function Performance.Elapsed(startedAt)
    if available and type(startedAt) == "number" then
        return math.max(0, debugprofilestop() - startedAt)
    end
    return 0
end

function Performance.GuildEvent(coalesced)
    local metric = metrics.guild
    metric.events = metric.events + 1
    if coalesced then
        metric.coalesced = metric.coalesced + 1
    end
end

function Performance.ContactRefresh(reason, startedAt, logical, rendered)
    local metric = metrics.contactsRefresh
    local elapsed = Performance.Elapsed(startedAt)
    metric.runs = metric.runs + 1
    metric.last = elapsed
    metric.max = math.max(metric.max, elapsed)
    if logical then
        metric.logical = metric.logical + 1
    end
    if rendered then
        metric.rendered = metric.rendered + 1
    else
        metric.skipped = metric.skipped + 1
    end

    local reasonKey = type(reason) == "string" and reason or "other"
    if metric[reasonKey] == nil then
        reasonKey = "other"
    end
    metric[reasonKey] = metric[reasonKey] + 1
end

function Performance.GetMetrics()
    return metrics
end

function Performance.Print()
    local L = ns.L
    if not available then
        ns.Print(L.PERF_UNAVAILABLE)
        return
    end

    ns.Print(L.PERF_HEADER)
    local guild = metrics.guild
    ns.Print(string.format(L.PERF_GUILD, guild.events, guild.runs, guild.coalesced, guild.last, guild.max, guild.processed, guild.modified))
    local refresh = metrics.searchRefresh
    ns.Print(string.format(L.PERF_SEARCH_REFRESH, refresh.runs, refresh.last, refresh.max, refresh.indexed))
    ns.Print(string.format(L.PERF_SEARCH_REFRESH_DETAIL, refresh.records, refresh.classes, refresh.build, refresh.normalized, refresh.cacheHits))
    local find = metrics.searchFind
    ns.Print(string.format(L.PERF_SEARCH_FIND, find.runs, find.last, find.max, find.scanned, find.matched))
    local filter = metrics.searchFilter
    ns.Print(string.format(L.PERF_SEARCH_FILTER, filter.runs, filter.last, filter.max, filter.scanned, filter.matched))
    local contacts = metrics.contactsRefresh
    ns.Print(string.format(L.PERF_CONTACTS_REFRESH, contacts.runs, contacts.last, contacts.max, contacts.logical, contacts.rendered, contacts.skipped))
    ns.Print(string.format(L.PERF_CONTACTS_REASONS, contacts.search, contacts.scroll, contacts.invalidation, contacts.tab, contacts.show, contacts.other))
end
