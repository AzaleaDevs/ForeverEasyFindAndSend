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

g.editBox.scripts.OnArrowPressed(g.editBox, "DOWN")
g.editBox.scripts.OnArrowPressed(g.editBox, "UP")
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

g.editBox.text = "/party zoo"
g.editBox.hooks.OnTextChanged(g.editBox, True)
assert not popup_state["shown"]

print("whisper popup integration checks passed")
