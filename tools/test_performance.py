"""Behavior checks for the opt-in FEFS performance profiler."""

from pathlib import Path

from lupa import LuaRuntime


ROOT = Path(__file__).resolve().parents[1]
PERFORMANCE = ROOT / "ForeverEasyFindAndSend" / "Performance.lua"
CORE = ROOT / "ForeverEasyFindAndSend" / "Core.lua"


def runtime():
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.execute(
        """
        profileClock = 0
        profileClockReads = 0
        printed = {}
        function debugprofilestop()
            profileClockReads = profileClockReads + 1
            return profileClock
        end
        function GetTime() return profileClock / 1000 end
        function wipe(target)
            for key in pairs(target) do target[key] = nil end
            return target
        end
        """
    )
    ns = lua.table()
    ns.Print = lambda message: lua.globals().printed.__setitem__(len(lua.globals().printed) + 1, message)
    ns.L = lua.table_from(
        {
            "PERF_UNAVAILABLE": "unavailable",
            "PERF_HEADER": "perf %s %.0f",
            "PERF_ON": "on",
            "PERF_OFF": "off",
            "PERF_GUILD_EVENTS": "guild %d %d",
            "PERF_OPERATION": "%s %d %.2f %.2f %.2f",
            "PERF_SLOW_HEADER": "slow %d %d",
            "PERF_SLOW_ENTRY": "slow-entry %d %.1f %s %.2f %s",
        }
    )
    lua.execute(PERFORMANCE.read_text(encoding="utf-8"), "ForeverEasyFindAndSend", ns)
    return lua, ns


def measure(lua, performance, name, duration, fields=None):
    started = performance.Start()
    lua.globals().profileClock += duration
    performance.Stop(name, started, fields)


def test_disabled_by_default():
    lua, ns = runtime()
    is_empty = lua.eval("function(target) return next(target) == nil end")
    assert ns.Performance.IsEnabled() is False
    assert ns.Performance.Start() is None
    assert lua.globals().profileClockReads == 0
    ns.Performance.Stop("disabled", None)
    assert is_empty(ns.Performance.GetMetrics())
    assert len(lua.globals().printed) == 0


def test_aggregation_threshold_and_no_spam():
    lua, ns = runtime()
    assert ns.Performance.SetEnabled(True)
    assert ns.Performance.GetSlowThreshold() == 50

    measure(lua, ns.Performance, "Search.Find", 20)
    measure(lua, ns.Performance, "Search.Find", 60, lua.table_from({"scanned": 1018}))
    metric = ns.Performance.GetMetrics()["Search.Find"]
    assert metric.calls == 2
    assert metric.last == 60
    assert metric.max == 60
    assert metric.total == 80
    slow = ns.Performance.GetSlowCalls()
    assert len(slow) == 1
    assert slow[1].context.scanned == 1018
    assert len(lua.globals().printed) == 0


def test_ring_buffer_is_bounded_and_ordered():
    lua, ns = runtime()
    ns.Performance.SetEnabled(True)
    for index in range(12):
        measure(lua, ns.Performance, "Sources.GuildSync", 50 + index)

    slow = ns.Performance.GetSlowCalls()
    assert len(slow) == 10
    assert slow[1].order == 3
    assert slow[10].order == 12
    assert slow[10].duration == 61


def test_reset_and_print_are_explicit():
    lua, ns = runtime()
    is_empty = lua.eval("function(target) return next(target) == nil end")
    ns.Performance.SetEnabled(True)
    measure(lua, ns.Performance, "WHO.Process", 75)
    ns.Performance.GuildEvent(False)
    ns.Performance.GuildEvent(True)
    ns.Performance.Print()
    assert len(lua.globals().printed) >= 4

    ns.Performance.Reset()
    assert is_empty(ns.Performance.GetMetrics())
    assert len(ns.Performance.GetSlowCalls()) == 0
    assert ns.Performance.IsEnabled() is True


def test_command_wiring():
    source = CORE.read_text(encoding="utf-8")
    assert 'perfAction == "on"' in source
    assert 'perfAction == "off"' in source
    assert 'perfAction == "reset"' in source
    assert "ns.Performance.Print()" in source
    assert "ns.Performance.SetEnabled(true)" in source
    assert "ns.Performance.SetEnabled(false)" in source
    assert "ns.Performance.Reset()" in source


def test_hot_path_coverage():
    sources = "\n".join(path.read_text(encoding="utf-8") for path in (ROOT / "ForeverEasyFindAndSend").rglob("*.lua"))
    for operation in (
        "Sources.GuildSync",
        "Sources.GuildScan",
        "Sources.FriendsSync",
        "Sources.GroupSync",
        "Database.Batch",
        "Database.Upsert",
        "Search.Refresh",
        "Search.Find",
        "Search.Filter",
        "MailContacts.Refresh",
        "Mail.AutoComplete",
        "Whisper.UpdateSuggestions",
        "WHO.Process",
        "Event.",
    ):
        assert operation in sources, f"missing profiler coverage for {operation}"


if __name__ == "__main__":
    test_disabled_by_default()
    test_aggregation_threshold_and_no_spam()
    test_ring_buffer_is_bounded_and_ordered()
    test_reset_and_print_are_explicit()
    test_command_wiring()
    test_hot_path_coverage()
    print("performance profiler checks passed")
