local _, ns = ...

local Formatter = {}
ns.Formatter = Formatter

function Formatter.GetClassName(record)
    if type(record.class) ~= "string" or record.class == "" then
        return nil
    end

    if string.match(record.class, "^[A-Z]+$") then
        return string.upper(string.sub(record.class, 1, 1)) .. string.lower(string.sub(record.class, 2))
    end

    return record.class
end

function Formatter.GetMetadata(record, status)
    local metadata = {}

    if record.level ~= nil then
        metadata[#metadata + 1] = tostring(record.level)
    end
    if type(record.race) == "string" and record.race ~= "" then
        metadata[#metadata + 1] = record.race
    end

    local className = Formatter.GetClassName(record)
    if className then
        metadata[#metadata + 1] = className
    end
    if type(status) == "string" and status ~= "" then
        metadata[#metadata + 1] = status
    end

    return table.concat(metadata, " · ")
end

function Formatter.GetSuggestion(record)
    local displayName = record.displayName or record.actionName
    local metadata = Formatter.GetMetadata(record)

    if metadata == "" then
        return displayName
    end

    return string.format("%s (%s)", displayName, metadata)
end
