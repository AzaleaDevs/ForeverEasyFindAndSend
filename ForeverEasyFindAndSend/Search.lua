local _, ns = ...

local Search = {}
ns.Search = Search

local index = {}

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

local function BuildFieldValues(record)
    local values = {}
    local fields = {
        "actionName",
        "displayName",
        "firstName",
        "surname",
        "race",
        "class",
        "classFile",
    }

    for fieldIndex = 1, #fields do
        local value = record[fields[fieldIndex]]
        if type(value) == "string" and value ~= "" then
            values[#values + 1] = value
        end
    end

    if record.level ~= nil then
        values[#values + 1] = tostring(record.level)
    end

    return values
end

local function MatchesAllTerms(record, query)
    if query.compact == "" then
        return true
    end

    local values = BuildFieldValues(record)
    local normalizedValues = {}
    for valueIndex = 1, #values do
        if type(values[valueIndex]) == "string" and values[valueIndex] ~= "" then
            normalizedValues[#normalizedValues + 1] = ns.Normalizer.Normalize(values[valueIndex]).compact
        end
    end

    for termIndex = 1, #query.tokens do
        local term = query.tokens[termIndex]
        local matched = false

        for valueIndex = 1, #normalizedValues do
            if string.find(normalizedValues[valueIndex], term, 1, true) then
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

    local records = ns.Database.GetSearchRecords()
    for recordIndex = 1, #records do
        local record = records[recordIndex]
        if type(record.actionName) == "string" and record.actionName ~= "" then
            index[#index + 1] = {
                record = record,
                normalized = ns.Normalizer.Normalize(record.actionName),
            }
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
                sortName = candidate.normalized.folded,
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
        if type(record.actionName) == "string" and MatchesAllTerms(record, query) then
            local normalizedName = ns.Normalizer.Normalize(record.actionName)
            local score = MatchScore(query, normalizedName) or 100
            if query.compact == "" then
                score = record.favorite and 10 or 0
            elseif record.favorite then
                score = score + 5
            end

            results[#results + 1] = {
                record = record,
                score = score,
                sortName = normalizedName.folded,
            }
        end
    end

    SortResults(results)
    TrimResults(results, limit)

    return results
end
