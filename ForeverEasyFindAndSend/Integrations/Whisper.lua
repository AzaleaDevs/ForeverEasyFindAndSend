local _, ns = ...

local Whisper = {}
ns.Whisper = Whisper

local installed = false

local function AppendUnique(target, seenNames, entry, limit)
    if type(entry) ~= "table" or type(entry.name) ~= "string" then
        return
    end

    local actionName = type(entry.actionName) == "string" and entry.actionName or entry.name
    if seenNames[actionName] or #target >= limit then
        return
    end

    seenNames[actionName] = true
    target[#target + 1] = entry
end

local function CreateCombinedSource(nativeSource)
    return function(text, maxResults, cursorPosition, allowFullMatch, ...)
        local limit = type(maxResults) == "number" and maxResults or 6
        local combined = {}
        local seenNames = {}
        local localResults = ns.Search.Find(text, limit)

        for resultIndex = 1, #localResults do
            local record = localResults[resultIndex].record
            AppendUnique(combined, seenNames, {
                name = ns.Formatter.GetSuggestion(record),
                actionName = record.actionName,
                priority = Enum.AutoCompletePriority.Other,
                fefsRecord = record,
            }, limit)
        end

        local nativeResults = nativeSource(text, maxResults, cursorPosition, allowFullMatch, ...)
        if type(nativeResults) == "table" then
            for resultIndex = 1, #nativeResults do
                AppendUnique(combined, seenNames, nativeResults[resultIndex], limit)
            end
        end

        return combined
    end
end

local function CreateSelectionHandler(nativeHandler)
    return function(editBox, newText, nameInfo, ambiguatedName)
        if type(nameInfo) == "table" and nameInfo.fefsRecord then
            local actionName = nameInfo.actionName or nameInfo.fefsRecord.actionName
            if type(actionName) == "string" and actionName ~= "" then
                editBox:SetTellTarget(actionName)
                editBox:SetChatType("WHISPER")
                editBox:SetText("")
                editBox:UpdateHeader()
                return true
            end
        end

        if type(nativeHandler) == "function" then
            return nativeHandler(editBox, newText, nameInfo, ambiguatedName)
        end
        return false
    end
end

local function ConfigureEditBox(editBox, chatType)
    local whisperContext = chatType == "WHISPER" or chatType == "SMART_WHISPER"
    if not whisperContext then
        if editBox.fefsOriginalAddHighlightedText ~= nil then
            editBox.addHighlightedText = editBox.fefsOriginalAddHighlightedText
        end
        return
    end

    local nativeSource = editBox.autoCompleteSource
    if type(nativeSource) ~= "function" then
        return
    end

    if editBox.fefsOriginalAddHighlightedText == nil then
        editBox.fefsOriginalAddHighlightedText = editBox.addHighlightedText == true
    end
    if not editBox.fefsWhisperSelectionInstalled then
        editBox.fefsWhisperNativeSelection = editBox.customAutoCompleteFunction
        editBox.customAutoCompleteFunction = CreateSelectionHandler(editBox.fefsWhisperNativeSelection)
        editBox.fefsWhisperSelectionInstalled = true
    end
    if editBox.fefsWhisperNativeSource ~= nativeSource then
        editBox.fefsWhisperNativeSource = nativeSource
        editBox.fefsWhisperCombinedSource = CreateCombinedSource(nativeSource)
    end

    editBox.autoCompleteSource = editBox.fefsWhisperCombinedSource
    editBox.addHighlightedText = false
end

function Whisper.TryInstall()
    if installed then
        return true
    end
    if type(hooksecurefunc) ~= "function"
        or type(ChatFrameEditBoxMixin) ~= "table"
        or type(ChatFrameEditBoxMixin.ProcessChatType) ~= "function" then
        return false
    end

    hooksecurefunc(ChatFrameEditBoxMixin, "ProcessChatType", function(editBox, _, chatType)
        ConfigureEditBox(editBox, chatType)
    end)
    installed = true
    return true
end

function Whisper.IsInstalled()
    return installed
end
