local _, ns = ...

local Mail = {}
ns.Mail = Mail

local installed = false

local function GetClassDisplayName(record)
    if type(record.class) ~= "string" or record.class == "" then
        return nil
    end

    if string.match(record.class, "^[A-Z]+$") then
        return string.upper(string.sub(record.class, 1, 1)) .. string.lower(string.sub(record.class, 2))
    end

    return record.class
end

local function FormatSuggestion(record)
    local displayName = record.displayName or record.actionName
    local metadata = {}

    if record.level ~= nil then
        metadata[#metadata + 1] = tostring(record.level)
    end
    if type(record.race) == "string" and record.race ~= "" then
        metadata[#metadata + 1] = record.race
    end

    local className = GetClassDisplayName(record)
    if className then
        metadata[#metadata + 1] = className
    end

    if #metadata == 0 then
        return displayName
    end

    return string.format("%s (%s)", displayName, table.concat(metadata, " · "))
end

local function AppendUnique(target, seenNames, entry, limit)
    if type(entry) ~= "table" or type(entry.name) ~= "string" then
        return
    end

    local actionName = type(entry.actionName) == "string" and entry.actionName or entry.name
    if seenNames[actionName] then
        return
    end

    if #target >= limit then
        return
    end

    seenNames[actionName] = true
    target[#target + 1] = entry
end

local function CreateSelectionHandler(originalHandler)
    return function(editBox, newText, nameInfo, ambiguatedName)
        if type(nameInfo) == "table" and nameInfo.fefsRecord then
            local actionName = nameInfo.actionName or nameInfo.fefsRecord.actionName
            if type(actionName) == "string" and actionName ~= "" then
                editBox:SetText(actionName)
                editBox:SetCursorPosition(string.len(actionName))
                return true
            end
        end

        if type(originalHandler) == "function" then
            return originalHandler(editBox, newText, nameInfo, ambiguatedName)
        end

        return false
    end
end

local function CreateCombinedSource(originalSource)
    return function(text, maxResults, cursorPosition, allowFullMatch, ...)
        local limit = type(maxResults) == "number" and maxResults or 6
        local combined = {}
        local seenNames = {}
        local localResults = ns.Search.Find(text, limit)
        local otherPriority = Enum.AutoCompletePriority.Other

        for resultIndex = 1, #localResults do
            AppendUnique(combined, seenNames, {
                name = FormatSuggestion(localResults[resultIndex].record),
                actionName = localResults[resultIndex].record.actionName,
                priority = otherPriority,
                fefsRecord = localResults[resultIndex].record,
            }, limit)
        end

        local nativeResults = originalSource(text, maxResults, cursorPosition, allowFullMatch, ...)
        if type(nativeResults) == "table" then
            for resultIndex = 1, #nativeResults do
                AppendUnique(combined, seenNames, nativeResults[resultIndex], limit)
            end
        end

        return combined
    end
end

function Mail.TryInstall()
    if installed then
        return true
    end

    local editBox = _G.SendMailNameEditBox
    if not editBox or type(editBox.autoCompleteSource) ~= "function" then
        return false
    end

    editBox.fefsOriginalSource = editBox.autoCompleteSource
    editBox.fefsOriginalCustomAutoCompleteFunction = editBox.customAutoCompleteFunction
    editBox.fefsOriginalAddHighlightedText = editBox.addHighlightedText

    editBox.autoCompleteSource = CreateCombinedSource(editBox.fefsOriginalSource)
    editBox.customAutoCompleteFunction = CreateSelectionHandler(editBox.fefsOriginalCustomAutoCompleteFunction)
    editBox.addHighlightedText = false
    installed = true

    return true
end

function Mail.IsInstalled()
    return installed
end
