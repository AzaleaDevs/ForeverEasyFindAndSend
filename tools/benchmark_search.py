"""Local FEFS search benchmark. Requires Python and lupa; never runs in WoW."""

from __future__ import annotations

import argparse
import statistics
import subprocess
import time
from pathlib import Path

from lupa import LuaRuntime


ROOT = Path(__file__).resolve().parents[1]
MODULES = ("Performance.lua", "Normalizer.lua", "Formatter.lua", "Search.lua")


def source(path: str, revision: str | None) -> str:
    relative = f"ForeverEasyFindAndSend/{path}"
    if revision:
        return subprocess.check_output(
            ["git", "show", f"{revision}:{relative}"], cwd=ROOT, text=True, encoding="utf-8"
        )
    return (ROOT / relative).read_text(encoding="utf-8")


def runtime(record_count: int, revision: str | None):
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.globals().debugprofilestop = lambda: time.perf_counter() * 1000
    lua.execute("function wipe(t) for k in pairs(t) do t[k] = nil end return t end")
    lua.execute("function CaseAccentInsensitiveParse(value) return (value:gsub('[A-Z]', string.lower)) end")
    lua.execute(
        "C_CreatureInfo = { GetClassInfo = function(id) "
        "return { className = ({'Warrior','Paladin','Hunter','Rogue','Priest','Death Knight','Shaman','Mage','Warlock','Monk','Druid','Demon Hunter','Evoker'})[id] or 'Warrior' } end }"
    )
    lua.execute("LOCALIZED_CLASS_NAMES_MALE = { WARRIOR='Warrior', MAGE='Mage', SHAMAN='Shaman' }")
    ns = lua.table()
    ns.Print = lambda _message: None
    for module in MODULES:
        lua.execute(source(module, revision), "ForeverEasyFindAndSend", ns)
    normalized_ok = lua.eval(
        "function(normalizer, value) return normalizer.Normalize(value).compact == 'amigokeback' end"
    )
    assert normalized_ok(ns.Normalizer, "Âmïgø Këbäck")
    lua.execute(
        """
        function MakeRecords(count)
            local records = {}
            local files = { "WARRIOR", "MAGE", "SHAMAN" }
            local classes = { "Warrior", "Mage", "Shaman" }
            local races = { "Human", "Troll", "Orc" }
            for i = 1, count do
                local kind = ((i - 1) % 3) + 1
                local name = "Character" .. i .. " Surname" .. i
                records[i] = {
                    actionName=name, displayName=name, firstName="Character" .. i,
                    surname="Surname" .. i, level=(i % 60) + 1, race=races[kind],
                    class=classes[kind], classFile=files[kind], classID=kind == 1 and 1 or (kind == 2 and 8 or 7),
                    favorite=i % 17 == 0,
                }
            end
            return records
        end
        """
    )
    records = lua.globals().MakeRecords(record_count)
    ns.Database = lua.table_from({"GetSearchRecords": lambda: records})
    return ns, records


def measure(record_count: int, revision: str | None, repeats: int):
    refresh, find, filter_times = [], [], []
    for _ in range(repeats):
        ns, records = runtime(record_count, revision)
        started = time.perf_counter()
        ns.Search.Refresh()
        refresh.append((time.perf_counter() - started) * 1000)
        started = time.perf_counter()
        found = ns.Search.Find("character", 20)
        find.append((time.perf_counter() - started) * 1000)
        assert len(found) == 20
        started = time.perf_counter()
        filtered = ns.Search.Filter(records, "60 warrior")
        filter_times.append((time.perf_counter() - started) * 1000)
        assert len(filtered) > 0
    return tuple(statistics.median(values) for values in (refresh, find, filter_times))


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--baseline-ref")
    parser.add_argument("--repeats", type=int, default=5)
    args = parser.parse_args()
    print("records,variant,refresh_ms,find_ms,filter_ms")
    for count in (1000, 5000, 10000, 20000):
        variants = (("baseline", args.baseline_ref), ("current", None)) if args.baseline_ref else (("current", None),)
        for label, revision in variants:
            values = measure(count, revision, args.repeats)
            print(f"{count},{label},{values[0]:.2f},{values[1]:.2f},{values[2]:.2f}")


if __name__ == "__main__":
    main()
