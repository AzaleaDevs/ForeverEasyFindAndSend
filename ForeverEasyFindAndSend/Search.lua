local _, ns = ...

local Search = {}
ns.Search = Search

local index = {}
local byRecord = {}

local SEARCH_FIELDS = {
    "actionName",
    "displayName",
    "firstName",
    "surname",
    "race",
    "class",
    "classFile",
}

local function StartsWith(value, prefix)
    return string.sub(value, 1, string.len(prefix)) == prefix
end

local function MatchScore(query, candidate)
    if query.folded == candidate.folded or query.compact == candidate.compact then
        return 1000
    end

    if StartsWith(candidate.folded, query.folded) then
        return 900
    end

    if StartsWith(candidate.compact, query.compact) then
        return 880
    end

    for tokenIndex = 1, #candidate.tokens do
        if StartsWith(candidate.tokens[tokenIndex], query.compact) then
            return 800
        end
    end

    if string.find(candidate.compact, query.compact, 1, true) then
        return 600
    end

    if string.find(candidate.folded, query.folded, 1, true) then
        return 580
    end

    return nil
end

local function AddSearchValue(values, seen, value)
    if type(value) ~= "string" or value == "" then
        return
    end

    local compact = ns.Normalizer.Normalize(value).compact
    if compact ~= "" and not seen[compact] then
        seen[compact] = true
        values[#values + 1] = compact
    end
end

local function BuildEntry(record)
    if type(record.actionName) ~= "string" or record.actionName == "" then
        return nil
    end

    local normalizedName = ns.Normalizer.Normalize(record.actionName)
    local values = {}
    local seen = {}

    for fieldIndex = 1, #SEARCH_FIELDS do
        AddSearchValue(values, seen, record[SEARCH_FIELDS[fieldIndex]])
    end
    if record.level ~= nil then
        AddSearchValue(values, seen, tostring(record.level))
    end

    return {
        record = record,
        normalized = normalizedName,
        searchValues = values,
        sortName = normalizedName.folded,
    }
end

local function GetEntry(record)
    local entry = byRecord[record]
    if not entry then
        entry = BuildEntry(record)
        if entry then
            byRecord[record] = entry
        end
    end
    return entry
end

local function MatchesAllTerms(entry, query)
    if query.compact == "" then
        return true
    end

    for termIndex = 1, #query.tokens do
        local term = query.tokens[termIndex]
        local matched = false

        for valueIndex = 1, #entry.searchValues do
            if string.find(entry.searchValues[valueIndex], term, 1, true) then
                matched = true
                break
            end
        end

        if not matched then
            return false
        end
    end

    return true
end

local function SortResults(results)
    table.sort(results, function(left, right)
        if left.score ~= right.score then
            return left.score > right.score
        end
        if left.sortName ~= right.sortName then
            return left.sortName < right.sortName
        end
        return left.record.actionName < right.record.actionName
    end)
end

local function TrimResults(results, limit)
    if limit and #results > limit then
        for resultIndex = #results, limit + 1, -1 do
            results[resultIndex] = nil
        end
    end
end

function Search.Refresh()
    wipe(index)
    wipe(byRecord)

    local records = ns.Database.GetSearchRecords()
    for recordIndex = 1, #records do
        local entry = BuildEntry(records[recordIndex])
        if entry then
            index[#index + 1] = entry
            byRecord[entry.record] = entry
        end
    end
end

function Search.Find(text, limit)
    local query = ns.Normalizer.Normalize(text)
    local results = {}

    if query.compact == "" then
        return results
    end

    for candidateIndex = 1, #index do
        local candidate = index[candidateIndex]
        local score = MatchScore(query, candidate.normalized)
        if score then
            results[#results + 1] = {
                record = candidate.record,
                score = score,
                sortName = candidate.sortName,
            }
        end
    end

    SortResults(results)
    TrimResults(results, limit)
    return results
end

function Search.Filter(records, text, limit)
    local query = ns.Normalizer.Normalize(text)
    local results = {}

    for recordIndex = 1, #records do
        local record = records[recordIndex]
        local entry = GetEntry(record)
        if entry and MatchesAllTerms(entry, query) then
            local score = MatchScore(query, entry.normalized) or 100
            if query.compact == "" then
                score = record.favorite and 10 or 0
            elseif record.favorite then
                score = score + 5
            end

            results[#results + 1] = {
                record = record,
                score = score,
                sortName = entry.sortName,
            }
        end
    end

    SortResults(results)
    TrimResults(results, limit)
    return results
end

function Search.GetIndexedRecordCount()
    return #index
end
