local _, ns = ...

local Mail = {}
ns.Mail = Mail

local installed = false

local function AppendUnique(target, seenNames, entry, limit)
    if type(entry) ~= "table" or type(entry.name) ~= "string" or seenNames[entry.name] then
        return
    end

    if #target >= limit then
        return
    end

    seenNames[entry.name] = true
    target[#target + 1] = entry
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
                name = localResults[resultIndex].record.actionName,
                priority = otherPriority,
                foreverEasyNamesRecord = localResults[resultIndex].record,
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

    editBox.foreverEasyNamesOriginalSource = editBox.autoCompleteSource
    editBox.autoCompleteSource = CreateCombinedSource(editBox.foreverEasyNamesOriginalSource)
    installed = true

    return true
end

function Mail.IsInstalled()
    return installed
end
