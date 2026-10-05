local _, ns = ...

local Whisper = {}
ns.Whisper = Whisper

local MAX_RESULTS = 5
local installed = false
local installedEditBoxes = setmetatable({}, { __mode = "k" })
local keyboardPropagation = setmetatable({}, { __mode = "k" })
local whisperCommands = {}

local function CacheWhisperCommands()
    wipe(whisperCommands)
    for _, chatType in ipairs({ "WHISPER", "SMART_WHISPER" }) do
        for aliasIndex = 1, 10 do
            local alias = _G["SLASH_" .. chatType .. aliasIndex]
            if type(alias) == "string" then
                whisperCommands[string.lower(alias)] = true
            end
        end
    end
end

local function IsWhisperCommand(command)
    if type(command) ~= "string" then
        return false
    end

    return whisperCommands[string.lower(command)] == true
end

local function GetRecipientQuery(editBox)
    local text = editBox:GetText() or ""
    local command, query = string.match(text, "^%s*(/%S+)%s+(.+)$")
    if not IsWhisperCommand(command) then
        return nil
    end

    query = string.match(query or "", "^%s*(.-)%s*$") or ""
    if query == "" then
        return nil
    end
    return query
end

local function HideNativeAutoComplete(editBox)
    if type(AutoComplete_HideIfAttachedTo) == "function" then
        AutoComplete_HideIfAttachedTo(editBox)
    end
end

local function CaptureArrowKey(editBox)
    if keyboardPropagation[editBox] == nil then
        if type(editBox.GetPropagateKeyboardInput) == "function" then
            keyboardPropagation[editBox] = editBox:GetPropagateKeyboardInput()
        else
            keyboardPropagation[editBox] = true
        end
    end
    editBox:SetPropagateKeyboardInput(false)
end

local function ReleaseArrowKey(editBox)
    local propagate = keyboardPropagation[editBox]
    if propagate ~= nil then
        editBox:SetPropagateKeyboardInput(propagate)
        keyboardPropagation[editBox] = nil
    end
end

local function UpdateSuggestions(editBox)
    local query = GetRecipientQuery(editBox)
    if not query then
        ns.WhisperSuggestions.Hide(editBox)
        ReleaseArrowKey(editBox)
        return
    end

    local results = ns.Search.Find(query, MAX_RESULTS)
    if ns.WhisperSuggestions.Show(editBox, results) then
        HideNativeAutoComplete(editBox)
    end
end

local function SelectRecipient(editBox, record)
    local actionName = record and record.actionName
    if not editBox or type(actionName) ~= "string" or actionName == "" then
        return
    end

    ns.WhisperSuggestions.Hide(editBox)
    ReleaseArrowKey(editBox)
    HideNativeAutoComplete(editBox)
    editBox:SetTellTarget(actionName)
    editBox:SetChatType("WHISPER")
    editBox:SetText("")
    editBox:UpdateHeader()
    editBox:SetFocus()
end

local function WrapScript(editBox, scriptName, handler)
    local original = editBox:GetScript(scriptName)
    editBox:SetScript(scriptName, function(self, ...)
        if handler(self, ...) then
            return
        end
        if type(original) == "function" then
            return original(self, ...)
        end
    end)
end

local function InstallEditBox(editBox)
    if not editBox or installedEditBoxes[editBox] then
        return
    end
    installedEditBoxes[editBox] = true

    editBox:HookScript("OnTextChanged", function(self)
        UpdateSuggestions(self)
    end)
    editBox:HookScript("OnChar", function(self)
        if ns.WhisperSuggestions.IsShownFor(self) then
            HideNativeAutoComplete(self)
        end
    end)
    editBox:HookScript("OnEditFocusLost", function(self)
        ns.WhisperSuggestions.Hide(self)
        ReleaseArrowKey(self)
    end)
    editBox:HookScript("OnHide", function(self)
        ns.WhisperSuggestions.Hide(self)
        ReleaseArrowKey(self)
    end)

    WrapScript(editBox, "OnKeyDown", function(self, key)
        if ns.WhisperSuggestions.IsShownFor(self) and (key == "UP" or key == "DOWN") then
            CaptureArrowKey(self)
            return ns.WhisperSuggestions.MoveSelection(self, key == "UP" and -1 or 1)
        end
        return false
    end)
    WrapScript(editBox, "OnKeyUp", function(self, key)
        if key == "UP" or key == "DOWN" then
            ReleaseArrowKey(self)
        end
        return false
    end)
    WrapScript(editBox, "OnTabPressed", function(self)
        return ns.WhisperSuggestions.Select(self)
    end)
    WrapScript(editBox, "OnEnterPressed", function(self)
        return ns.WhisperSuggestions.Select(self)
    end)
    WrapScript(editBox, "OnEscapePressed", function(self)
        if ns.WhisperSuggestions.IsShownFor(self) then
            ns.WhisperSuggestions.Hide(self)
            ReleaseArrowKey(self)
            HideNativeAutoComplete(self)
            return true
        end
        return false
    end)
end

local function InstallExistingEditBoxes()
    if type(CHAT_FRAMES) ~= "table" then
        return
    end
    for frameIndex = 1, #CHAT_FRAMES do
        local frameReference = CHAT_FRAMES[frameIndex]
        local chatFrame = type(frameReference) == "string" and _G[frameReference] or frameReference
        local editBox = chatFrame and chatFrame.editBox
        if not editBox and type(frameReference) == "string" then
            editBox = _G[frameReference .. "EditBox"]
        end
        InstallEditBox(editBox)
    end
end

function Whisper.TryInstall()
    if installed then
        InstallExistingEditBoxes()
        return true
    end
    if type(hooksecurefunc) ~= "function"
        or type(ChatFrameEditBoxMixin) ~= "table"
        or type(ChatFrameEditBoxMixin.ProcessChatType) ~= "function"
        or not ns.WhisperSuggestions then
        return false
    end

    ns.WhisperSuggestions.SetSelectionHandler(SelectRecipient)
    CacheWhisperCommands()
    InstallExistingEditBoxes()
    hooksecurefunc(ChatFrameEditBoxMixin, "ProcessChatType", function(editBox, _, chatType)
        InstallEditBox(editBox)
        if chatType ~= "WHISPER" and chatType ~= "SMART_WHISPER" then
            ns.WhisperSuggestions.Hide(editBox)
            ReleaseArrowKey(editBox)
        end
    end)
    installed = true
    return true
end

function Whisper.IsInstalled()
    return installed
end
