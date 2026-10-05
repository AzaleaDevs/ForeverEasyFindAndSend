"""Static FEFS whisper integration checks. Requires Python and lupa."""

from pathlib import Path

from lupa import LuaRuntime


root = Path(__file__).resolve().parents[1]
lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute(
    """
    capturedHook = nil
    function hooksecurefunc(target, method, callback)
        assert(target == ChatFrameEditBoxMixin)
        assert(method == "ProcessChatType")
        capturedHook = callback
    end
    Enum = { AutoCompletePriority = { Other = 99 } }
    ChatFrameEditBoxMixin = { ProcessChatType = function() end }
    """
)

ns = lua.table()
record = lua.table_from(
    {
        "actionName": "Zoo Posse",
        "displayName": "Zoo Posse",
        "level": 18,
        "class": "Druid",
        "classFile": "DRUID",
    }
)
result = lua.table_from({"record": record})
ns.Search = lua.table_from({"Find": lambda _text, _limit: lua.table_from([result])})
ns.Formatter = lua.table_from({"GetSuggestion": lambda _record: "Zoo Posse (18 · Druid)"})

lua.execute(
    (root / "ForeverEasyFindAndSend/Integrations/Whisper.lua").read_text(encoding="utf-8"),
    "ForeverEasyFindAndSend",
    ns,
)
assert ns.Whisper.TryInstall()

lua.execute(
    """
    nativeCalls = 0
    function NativeSource(text, maxResults, cursorPosition, allowFullMatch)
        nativeCalls = nativeCalls + 1
        return { { name = "Native Player", priority = 1 } }
    end
    editBox = {
        autoCompleteSource = NativeSource,
        customAutoCompleteFunction = function() return false end,
        addHighlightedText = true,
        SetTellTarget = function(self, value) self.tellTarget = value end,
        SetChatType = function(self, value) self.chatType = value end,
        SetText = function(self, value) self.text = value end,
        UpdateHeader = function(self) self.headerUpdated = true end,
    }
    capturedHook(editBox, "Zoo", "WHISPER", 0)
    dropdownResults = editBox.autoCompleteSource("Zoo", 7, 3, true)
    inlineResults = editBox.autoCompleteSource("Zoo", 1, 3, false)
    selected = editBox.customAutoCompleteFunction(editBox, "ignored", dropdownResults[1], dropdownResults[1].name)
    """
)

g = lua.globals()
assert len(g.dropdownResults) == 2
assert g.dropdownResults[1].name == "Zoo Posse (18 · Druid)"
assert g.dropdownResults[1].actionName == "Zoo Posse"
assert g.dropdownResults[2].name == "Native Player"
assert len(g.inlineResults) == 1 and g.inlineResults[1].name == "Native Player"
assert g.editBox.tellTarget == "Zoo Posse"
assert g.editBox.chatType == "WHISPER"
assert g.editBox.text == ""
assert g.editBox.headerUpdated is True
assert g.selected is True

print("whisper integration checks passed")
