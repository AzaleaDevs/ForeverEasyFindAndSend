local _, ns = ...

local Formatter = {}
ns.Formatter = Formatter

local classNamesByID = {}
local classNamesByFile = {}

function Formatter.GetClassName(record)
    if type(record.classID) == "number" then
        local cached = classNamesByID[record.classID]
        if cached then
            return cached
        end
    end

    if type(record.classFile) == "string" and record.classFile ~= "" then
        local cached = classNamesByFile[record.classFile]
        if cached then
            return cached
        end
    end

    if type(record.classID) == "number"
        and C_CreatureInfo
        and type(C_CreatureInfo.GetClassInfo) == "function" then
        local classInfo = C_CreatureInfo.GetClassInfo(record.classID)
        if type(classInfo) == "table" and type(classInfo.className) == "string" and classInfo.className ~= "" then
            classNamesByID[record.classID] = classInfo.className
            if type(record.classFile) == "string" and record.classFile ~= "" then
                classNamesByFile[record.classFile] = classInfo.className
            end
            return classInfo.className
        end
    end

    if type(record.classFile) == "string" and record.classFile ~= "" then
        local localized = LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[record.classFile]
        if type(localized) == "string" and localized ~= "" then
            classNamesByFile[record.classFile] = localized
            if type(record.classID) == "number" then
                classNamesByID[record.classID] = localized
            end
            return localized
        end
    end

    if type(record.class) == "string" and record.class ~= "" then
        return record.class
    end

    return nil
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
