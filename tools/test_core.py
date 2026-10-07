"""Static core-module checks for the FEFS distributable. Requires Python and lupa."""

from pathlib import Path

from lupa import LuaRuntime


ROOT = Path(__file__).resolve().parents[1]
ADDON = ROOT / "ForeverEasyFindAndSend"


def load(lua, ns, relative_path):
    lua.execute((ADDON / relative_path).read_text(encoding="utf-8"), "ForeverEasyFindAndSend", ns)


def base_runtime():
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.execute(
        """
        function wipe(target)
            for key in pairs(target) do target[key] = nil end
            return target
        end
        function CaseAccentInsensitiveParse(value)
            return (value:gsub("[A-Z]", string.lower))
        end
        """
    )
    return lua


def test_database():
    lua = base_runtime()
    lua.execute(
        """
        ForeverEasyFindAndSendDB = nil
        ForeverEasyNamesDB = nil
        function GetServerTime() return 1000 end
        """
    )
    ns = lua.table()
    load(lua, ns, "Database.lua")
    ns.Database.Initialize()
    assert ns.Database.GetSchemaVersion() == 2
    assert len(ns.Database.GetPersistentRecords()) == 0
    assert len(ns.Database.GetSearchRecords()) == 0

    record, error, created = ns.Database.Upsert(
        lua.table_from(
            {
                "actionName": "Amigö Kebäck",
                "displayName": "Amigö Kebäck",
                "level": 47,
                "race": "Human",
                "class": "MAGE",
                "classFile": "MAGE",
                "classID": 8,
                "source": "friend",
            }
        )
    )
    assert error is None and created is True
    assert len(ns.Database.GetPersistentRecords()) == 1
    assert len(ns.Database.GetSearchRecords()) == 1
    assert ns.Database.SetFavorite(record, True)
    assert len(ns.Database.GetFavoriteRecords()) == 1
    stats = ns.Database.GetStats()
    assert stats.contacts == 1 and stats.favorites == 1
    print("database checks passed")


def test_search_and_normalization():
    lua = base_runtime()
    lua.execute(
        """
        C_CreatureInfo = {
            GetClassInfo = function(id)
                if id == 8 then return { className = "Mage" } end
                return { className = "Druid" }
            end,
        }
        LOCALIZED_CLASS_NAMES_MALE = { MAGE = "Mage", DRUID = "Druid" }
        """
    )
    ns = lua.table()
    load(lua, ns, "Normalizer.lua")
    load(lua, ns, "Formatter.lua")
    load(lua, ns, "Search.lua")

    normalized, _replacement_count = ns.Normalizer.NormalizeCompact("Amigö Kebäck")
    assert normalized == "amigokeback", normalized.encode("utf-8").hex()
    records = lua.table_from(
        [
            lua.table_from(
                {
                    "actionName": "Amigö Kebäck",
                    "displayName": "Amigö Kebäck",
                    "level": 47,
                    "race": "Human",
                    "class": "MAGE",
                    "classFile": "MAGE",
                    "classID": 8,
                    "favorite": True,
                }
            ),
            lua.table_from(
                {
                    "actionName": "Zoo Posse",
                    "displayName": "Zoo Posse",
                    "level": 18,
                    "race": "Tauren",
                    "class": "DRUID",
                    "classFile": "DRUID",
                    "classID": 11,
                }
            ),
        ]
    )
    ns.Database = lua.table_from({"GetSearchRecords": lambda: records})
    ns.Search.Refresh()
    assert ns.Search.GetIndexedRecordCount() == 2
    assert ns.Search.Find("amigo keback", 5)[1].record.actionName == "Amigö Kebäck"
    assert ns.Search.Find("zoo", 5)[1].record.actionName == "Zoo Posse"
    assert ns.Search.Filter(records, "47 mage", 5)[1].record.actionName == "Amigö Kebäck"
    print("normalizer/search checks passed")


def test_mail():
    lua = base_runtime()
    lua.execute(
        """
        Enum = { AutoCompletePriority = { Other = 1 } }
        SendMailNameEditBox = {
            autoCompleteSource = function()
                return { { name = "Native Player", priority = 1 } }
            end,
            customAutoCompleteFunction = function() return false end,
            addHighlightedText = true,
        }
        function SendMailNameEditBox:SetText(value) self.text = value end
        function SendMailNameEditBox:SetCursorPosition(value) self.cursor = value end
        """
    )
    ns = lua.table()
    record = lua.table_from({"actionName": "Amigö Kebäck", "displayName": "Amigö Kebäck"})
    result = lua.table_from({"record": record})
    ns.Search = lua.table_from({"Find": lambda *_args: lua.table_from([result])})
    ns.Formatter = lua.table_from({"GetSuggestion": lambda value: value.displayName})
    load(lua, ns, "Integrations/Mail.lua")

    assert ns.Mail.TryInstall()
    edit_box = lua.globals().SendMailNameEditBox
    suggestions = edit_box.autoCompleteSource("amigo", 6, 5, True)
    assert suggestions[1].actionName == "Amigö Kebäck"
    assert suggestions[2].name == "Native Player"
    assert edit_box.customAutoCompleteFunction(edit_box, "ignored", suggestions[1], "ignored")
    assert edit_box.text == "Amigö Kebäck"
    assert edit_box.cursor == len("Amigö Kebäck".encode("utf-8"))
    assert edit_box.addHighlightedText is False
    print("mail integration checks passed")


def test_localizations():
    required = (
        "CONTACTS_TITLE",
        "TAB_GENERAL",
        "TAB_GUILD",
        "TAB_FAVORITES",
        "SEARCH_ONLINE",
        "NO_KNOWN_CHARACTERS",
        "SET_MAIL_RECIPIENT",
        "ADD_FAVORITE",
        "REMOVE_FAVORITE",
        "HIDE_CONTACTS",
        "SHOW_CONTACTS",
        "CMD_STATUS",
    )
    for locale in ("enUS", "esES", "frFR", "deDE"):
        lua = base_runtime()
        lua.globals().GetLocale = lambda locale=locale: locale
        ns = lua.table()
        for file_name in ("enUS.lua", "esES.lua", "frFR.lua", "deDE.lua"):
            load(lua, ns, f"Localization/{file_name}")
        for key in required:
            value = ns.L[key]
            assert isinstance(value, str) and value
    print("localization checks passed")


if __name__ == "__main__":
    test_database()
    test_search_and_normalization()
    test_mail()
    test_localizations()
    print("core module checks passed")
