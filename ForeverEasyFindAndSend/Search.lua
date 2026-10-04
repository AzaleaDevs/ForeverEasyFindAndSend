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

    table.sort(results, function(left, right)
        if left.score ~= right.score then
            return left.score > right.score
        end
        if left.sortName ~= right.sortName then
            return left.sortName < right.sortName
        end
        return left.record.actionName < right.record.actionName
    end)

    if limit and #results > limit then
        for resultIndex = #results, limit + 1, -1 do
            results[resultIndex] = nil
        end
    end

    return results
end

