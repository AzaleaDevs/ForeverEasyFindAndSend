"""Static FEFS whisper popup integration checks. Requires Python and lupa."""

from pathlib import Path

from lupa import LuaRuntime


root = Path(__file__).resolve().parents[1]
lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute(
    """
    SLASH_WHISPER1 = "/w"
    SLASH_WHISPER2 = "/whisper"
    SLASH_SMART_WHISPER1 = "/tell"
    ChatFrameEditBoxMixin = { ProcessChatType = function() end }
    function wipe(target) for key in pairs(target) do target[key] = nil end return target end
    processHook = nil
    nativeHideCalls = 0
    function hooksecurefunc(target, method, callback)
        assert(target == ChatFrameEditBoxMixin and method == "ProcessChatType")
        processHook = callback
    end
    function AutoComplete_HideIfAttachedTo(editBox)
        nativeHideCalls = nativeHideCalls + 1
    end

    editBox = {
        text = "/w zoo",
        scripts = {},
        hooks = {},
        autoCompleteSource = function() return { { name = "Native Player" } } end,
        customAutoCompleteFunction = function() return false end,
    }
    function editBox:GetText() return self.text end
    function editBox:GetScript(name) return self.scripts[name] end
    function editBox:SetScript(name, callback) self.scripts[name] = callback end
    function editBox:HookScript(name, callback) self.hooks[name] = callback end
    function editBox:SetTellTarget(value) self.tellTarget = value end
    function editBox:SetChatType(value) self.chatType = value end
    function editBox:SetText(value) self.text = value end
    function editBox:UpdateHeader() self.headerUpdated = true end
    function editBox:SetFocus() self.focused = true end
    function editBox:GetPropagateKeyboardInput() return self.propagateKeyboard ~= false end
    function editBox:SetPropagateKeyboardInput(value) self.propagateKeyboard = value end
    nativeKeyDownCalls = 0
    editBox.scripts.OnKeyDown = function() nativeKeyDownCalls = nativeKeyDownCalls + 1 end
    chatFrame = { editBox = editBox }
    ChatFrame1 = chatFrame
    CHAT_FRAMES = { "ChatFrame1" }
    """
)

ns = lua.table()
record = lua.table_from({"actionName": "Zoo Posse", "displayName": "Zoo Posse", "level": 18})
search_result = lua.table_from({"record": record})
search_state = {"query": None, "limit": None}


def find(query, limit):
    search_state["query"] = query
    search_state["limit"] = limit
    return lua.table_from([search_result])


popup_state = {"shown": False, "handler": None, "moves": [], "selected": 0}


def show(_edit_box, results):
    popup_state["shown"] = len(results) > 0
    return popup_state["shown"]


def hide(_edit_box=None):
    popup_state["shown"] = False
    return True


def move(_edit_box, direction):
    if not popup_state["shown"]:
        return False
    popup_state["moves"].append(direction)
    return True


def select(_edit_box):
    if not popup_state["shown"]:
        return False
    popup_state["selected"] += 1
    return True


ns.Search = lua.table_from({"Find": find})
ns.WhisperSuggestions = lua.table_from(
    {
        "SetSelectionHandler": lambda handler: popup_state.__setitem__("handler", handler),
        "Show": show,
        "Hide": hide,
        "IsShownFor": lambda _edit_box: popup_state["shown"],
        "MoveSelection": move,
        "Select": select,
    }
)

lua.execute(
    (root / "ForeverEasyFindAndSend/Integrations/Whisper.lua").read_text(encoding="utf-8"),
    "ForeverEasyFindAndSend",
    ns,
)
assert ns.Whisper.TryInstall()

g = lua.globals()
g.editBox.hooks.OnTextChanged(g.editBox, True)
assert search_state == {"query": "zoo", "limit": 5}
assert popup_state["shown"]
assert g.nativeHideCalls == 1
assert g.editBox.autoCompleteSource()[1].name == "Native Player"
assert g.editBox.customAutoCompleteFunction() is False

g.editBox.scripts.OnKeyDown(g.editBox, "DOWN")
assert g.editBox.propagateKeyboard is False
g.editBox.scripts.OnKeyUp(g.editBox, "DOWN")
assert g.editBox.propagateKeyboard is True
g.editBox.scripts.OnKeyDown(g.editBox, "UP")
assert popup_state["moves"] == [1, -1]
g.editBox.scripts.OnTabPressed(g.editBox)
g.editBox.scripts.OnEnterPressed(g.editBox)
assert popup_state["selected"] == 2

popup_state["shown"] = True
popup_state["handler"](g.editBox, record)
assert g.editBox.tellTarget == "Zoo Posse"
assert g.editBox.chatType == "WHISPER"
assert g.editBox.text == ""
assert g.editBox.headerUpdated is True
assert g.editBox.focused is True

g.editBox.text = "/w zoo"
g.editBox.hooks.OnTextChanged(g.editBox, True)
assert popup_state["shown"]
g.editBox.scripts.OnEscapePressed(g.editBox)
assert not popup_state["shown"]
assert g.editBox.text == "/w zoo"

g.editBox.text = "/party zoo"
g.editBox.hooks.OnTextChanged(g.editBox, True)
assert not popup_state["shown"]
g.editBox.scripts.OnKeyDown(g.editBox, "DOWN")
assert g.nativeKeyDownCalls == 1
assert g.editBox.propagateKeyboard is True

print("whisper popup integration checks passed")

# Exercise the real popup selection, hover, click, and wrap logic with frame mocks.
ui_lua = LuaRuntime(unpack_returned_tuples=True)
ui_lua.execute(
    """
    function wipe(target) for key in pairs(target) do target[key] = nil end return target end
    UIParent = { GetHeight = function() return 1080 end }
    CLASS_ICON_TCOORDS = { DRUID = { 0, 0.25, 0, 0.25 } }
    RAID_CLASS_COLORS = { DRUID = { r = 1, g = 0.5, b = 0 } }
    createdButtons = {}
    local function Region()
        return setmetatable({}, { __index = function() return function() end end })
    end
    local FrameMethods = {}
    function FrameMethods:SetSize() end
    function FrameMethods:SetHeight() end
    function FrameMethods:SetPoint() end
    function FrameMethods:ClearAllPoints() end
    function FrameMethods:SetFrameStrata() end
    function FrameMethods:SetClampedToScreen() end
    function FrameMethods:SetBackdrop() end
    function FrameMethods:EnableMouse(value) self.mouseEnabled = value end
    function FrameMethods:RegisterForClicks(...) self.registeredClicks = { ... } end
    function FrameMethods:CreateTexture() return Region() end
    function FrameMethods:CreateFontString() return Region() end
    function FrameMethods:SetScript(name, callback) self.scripts[name] = callback end
    function FrameMethods:Show() self.shown = true end
    function FrameMethods:Hide() self.shown = false end
    function FrameMethods:IsShown() return self.shown == true end
    function CreateFrame(frameType, name)
        local frame = setmetatable({ shown = true, scripts = {} }, { __index = FrameMethods })
        if name then _G[name] = frame end
        if frameType == "Button" then createdButtons[#createdButtons + 1] = frame end
        return frame
    end
    popupEditBox = { GetTop = function() return 100 end }
    """
)
ui_ns = ui_lua.table()
ui_ns.Formatter = ui_lua.table_from({"GetMetadata": lambda record_value: f"{record_value.level} · Druid"})
ui_lua.execute(
    (root / "ForeverEasyFindAndSend/UI/WhisperSuggestions.lua").read_text(encoding="utf-8"),
    "ForeverEasyFindAndSend",
    ui_ns,
)
ui_records = []
ui_results = []
for index in range(1, 6):
    ui_record = ui_lua.table_from(
        {"actionName": f"Player {index}", "displayName": f"Player {index}", "level": index, "classFile": "DRUID"}
    )
    ui_records.append(ui_record)
    ui_results.append(ui_lua.table_from({"record": ui_record}))

selected_records = []
ui_lua.globals().pySelect = lambda selected_record: selected_records.append(selected_record)
ui_ns.WhisperSuggestions.SetSelectionHandler(ui_lua.eval("function(_, record) pySelect(record) end"))
assert ui_ns.WhisperSuggestions.Show(ui_lua.globals().popupEditBox, ui_lua.table_from(ui_results))
assert ui_ns.WhisperSuggestions.GetSelectedIndex() == 1
assert len(ui_lua.globals().createdButtons) == 5
for row_index in range(1, 6):
    row = ui_lua.globals().createdButtons[row_index]
    assert row.mouseEnabled is True
    assert row.registeredClicks[1] == "LeftButtonDown"

ui_ns.WhisperSuggestions.MoveSelection(ui_lua.globals().popupEditBox, 1)
ui_ns.WhisperSuggestions.MoveSelection(ui_lua.globals().popupEditBox, 1)
ui_ns.WhisperSuggestions.MoveSelection(ui_lua.globals().popupEditBox, -1)
assert ui_ns.WhisperSuggestions.GetSelectedIndex() == 2
ui_ns.WhisperSuggestions.SetSelectedIndex(ui_lua.globals().popupEditBox, 5)
ui_ns.WhisperSuggestions.MoveSelection(ui_lua.globals().popupEditBox, 1)
assert ui_ns.WhisperSuggestions.GetSelectedIndex() == 1
ui_ns.WhisperSuggestions.MoveSelection(ui_lua.globals().popupEditBox, -1)
assert ui_ns.WhisperSuggestions.GetSelectedIndex() == 5

ui_lua.globals().createdButtons[4].scripts.OnEnter()
assert ui_ns.WhisperSuggestions.GetSelectedIndex() == 4
ui_lua.globals().createdButtons[4].scripts.OnClick()
assert selected_records[-1].actionName == "Player 4"

ui_lua.globals().createdButtons[2].scripts.OnEnter()
ui_ns.WhisperSuggestions.Select(ui_lua.globals().popupEditBox)
assert selected_records[-1].actionName == "Player 2"
assert ui_ns.WhisperSuggestions.GetSelectedIndex() == 2

print("whisper popup UI checks passed")
