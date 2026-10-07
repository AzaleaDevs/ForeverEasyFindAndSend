# FEFS alpha.4 synchronous hot-path audit

Baseline: `c41a839a5a06f1a91c843572fc5e0e88fa2ae595`.

The audit does not establish that FEFS causes the reported client freeze. It
identifies synchronous FEFS work and adds opt-in measurements around both the
leaf operation and its complete event/batch path.

## Ranked risk

1. **Guild synchronization.** A coalesced `GUILD_ROSTER_UPDATE` still scans
   every guild member through `GetGuildRosterInfo`, builds a signature string,
   creates a new snapshot entry, and creates a guild-list entry for every
   valid member. Unchanged members avoid `Database.Upsert`, but the scan and
   snapshot allocations remain O(guild members).
2. **Full search/filter passes.** `Search.Refresh` rebuilds and normalizes the
   complete index after a batch with searchable changes. `Search.Filter`
   scans and sorts all matching records when Agenda needs a logical refresh;
   an empty/general query can match all known characters. Both allocate result
   or index tables and strings.
3. **Unconditional source-batch UI invalidation.** `RunBatch` calls
   `Database.RequestRefresh(false)` even for a no-op source event. This does
   not rebuild the search index, but it invalidates visible Agenda and can
   cause an O(n) filter/sort. It also carries legitimate non-database state,
   including guild online/status changes, so it is measured rather than
   removed without ingame evidence.
4. **Friends synchronization.** Every `FRIENDLIST_UPDATE` scans all native
   friends and calls `Database.Upsert` for each. Batching prevents per-record
   index rebuilds, but there is no event coalescing or friends snapshot.
5. **Broad autocomplete queries.** `Search.Find` scans the complete index,
   allocates every match, sorts matches, and only then trims to the requested
   limit. It runs from mail and whisper input, so broad one-character queries
   are the worst case.
6. **WHO processing.** User-triggered and rate-limited, but imports all returned
   results synchronously, then runs one batch notification/index refresh.
7. **Initial load.** Database index rebuilding, optional legacy import,
   `Search.Refresh`, and the initial player/friends/group/guild sync are O(n)
   or O(n + roster sizes), but occur at load/login rather than randomly.

## Confirmed behavior

- Database batching collapses many `Upsert` notifications into one change
  handler call. There is no per-record `Search.Refresh`.
- Repeated guild events are coalesced for 250 ms. The resulting run is still a
  full roster scan.
- An unchanged guild signature skips `Database.Upsert`; it does not skip
  snapshot/list reconstruction.
- Agenda returns before filtering when hidden. Scroll-only refreshes reuse the
  prior `visibleResults` and render at most six rows.
- The native search box, side tabs, atlases, textures, and font strings are
  created once. `SetChecked` runs only when changing tabs, not per refresh.
- SavedVariables are mutated in memory; FEFS performs no explicit synchronous
  disk write.
- Normalization and result/snapshot construction create enough temporary
  strings and tables to make garbage collection a plausible externalized cost,
  but no GC cause is claimed without an ingame trace.

## Profiler scope

The opt-in profiler uses differences between `debugprofilestop()` calls. It
does not call the global-resetting `debugprofilestart()`, use `OnUpdate`, poll,
print during measured gameplay, or alter garbage collector settings.

The Forever FrameXML source at commit
`15666a6e67938a1ab5caf041406464251db111ca` also exposes
`C_AddOnProfiler.MeasureCall`, with elapsed time reported in milliseconds.
FEFS keeps the already proven `debugprofilestop()` clock so instrumentation
does not wrap or replace the invocation/return behavior of measured handlers.

It measures Core events, complete source batches, individual source scans,
database batches and upserts, all Search operations, Agenda refresh, mail and
whisper autocomplete, and WHO result processing. Calls at or above 50 ms are
stored in a ten-entry ring buffer with completion order, `GetTime()` timestamp,
operation, duration, and scalar context.
