local _, ns = ...

local Whisper = {}
ns.Whisper = Whisper

local MAX_RESULTS = 5
local installed = false
local installedEditBoxes = setmetatable({}, { __mode = "k" })
local arrowKeyModes = setmetatable({}, { __mode = "k" })
local whisperCommands = {}
local debugEnabled = false

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

local function CaptureArrowKeys(editBox)
    if arrowKeyModes[editBox] == nil then
        arrowKeyModes[editBox] = editBox:GetAltArrowKeyMode()
        editBox:SetAltArrowKeyMode(false)
    end
end

local function ReleaseArrowKeys(editBox)
    local altArrowKeyMode = arrowKeyModes[editBox]
    if altArrowKeyMode ~= nil then
        editBox:SetAltArrowKeyMode(altArrowKeyMode)
        arrowKeyModes[editBox] = nil
    end
end

local function UpdateSuggestions(editBox)
    local query = GetRecipientQuery(editBox)
    if not query then
        ns.WhisperSuggestions.Hide(editBox, "recipient query ended")
        ReleaseArrowKeys(editBox)
        return
    end

    local results = ns.Search.Find(query, MAX_RESULTS)
    if ns.WhisperSuggestions.Show(editBox, results) then
        HideNativeAutoComplete(editBox)
        CaptureArrowKeys(editBox)
    else
        ReleaseArrowKeys(editBox)
    end
end

local function SelectRecipient(editBox, record)
    local actionName = record and record.actionName
    if not editBox or type(actionName) ~= "string" or actionName == "" then
        return
    end

    ns.WhisperSuggestions.Hide(editBox, "recipient selected")
    ReleaseArrowKeys(editBox)
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
        Whisper.Debug("edit focus lost")
        ns.WhisperSuggestions.Hide(self, "edit focus lost")
        ReleaseArrowKeys(self)
    end)
    editBox:HookScript("OnHide", function(self)
        Whisper.Debug("edit box hide")
        ns.WhisperSuggestions.Hide(self, "edit box hide")
        ReleaseArrowKeys(self)
    end)

    WrapScript(editBox, "OnArrowPressed", function(self, key)
        if ns.WhisperSuggestions.IsShownFor(self) and (key == "UP" or key == "DOWN") then
            Whisper.Debug("key %s", key)
            return ns.WhisperSuggestions.MoveSelection(self, key == "UP" and -1 or 1)
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
            ns.WhisperSuggestions.Hide(self, "escape")
            ReleaseArrowKeys(self)
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
            ns.WhisperSuggestions.Hide(editBox, "chat type changed")
            ReleaseArrowKeys(editBox)
        end
    end)
    installed = true
    return true
end

function Whisper.IsInstalled()
    return installed
end

function Whisper.SetDebug(enabled)
    debugEnabled = enabled == true
    ns.Print("WHISPER debug " .. (debugEnabled and "enabled" or "disabled"))
end

function Whisper.IsDebugEnabled()
    return debugEnabled
end

function Whisper.Debug(formatString, ...)
    if debugEnabled then
        ns.Print("WHISPER: " .. string.format(formatString, ...))
    end
end
