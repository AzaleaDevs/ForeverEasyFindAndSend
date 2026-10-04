# Changelog

All notable changes to Forever Easy Find & Send will be documented in this file.

The project follows [Semantic Versioning](https://semver.org/).

## [Unreleased]

## [0.1.0-alpha.3.1] - 2026-10-04

### Added

- Explicit **Search Online** action in General using Forever's WHO API.
- Persistent enrichment of WHO results with only the name, level, race, class, guild, and zone fields returned by the client.
- WHO request states, a conservative local cooldown, timeout handling, and `/fefs debug` diagnostics.

### Changed

- Precompute normalized character search values in memory instead of rebuilding them for every record on every keypress.
- Maintain GUID and exact-action-name database indexes incrementally.
- Batch login, friend, group, and guild imports so search and UI consumers refresh once per synchronization event.
- Debounce non-empty contact searches by 75 ms and skip unchanged visible-row rendering work.

### Fixed

- Removed the per-keystroke normalization spikes observed with guild rosters near 1,000 characters.
- Removed per-character full database index rebuilds during bulk guild synchronization.

## [0.1.0-alpha.3] - 2026-10-04

### Added

- Account-wide persistent character directory with conservative GUID and exact-action-name deduplication.
- Initial event-driven synchronization from the player, WoW friends, current guild, and current party or raid.
- A collapsible mail contacts panel with General, Guild, and Favorites views.
- Multi-term filtering by name, race, class, and level.
- Class icons, class colors, exact-recipient buttons, and persistent favorite controls.
- `/fefs debug` synchronization diagnostics.

### Changed

- Renamed the addon to Forever Easy Find & Send with technical identifier `ForeverEasyFindAndSend`.
- Renamed the slash command from `/fen` to `/fefs`.
- Renamed the primary SavedVariables table to `ForeverEasyFindAndSendDB` and schema to version 2.
- Enriched mail autocomplete from the shared persistent character database.

### Migration

- Imports the legacy `ForeverEasyNamesDB` without overwriting existing FEFS records when the old addon is loaded during the migration session.
- Keeps development fixtures separate from SavedVariables.

## [0.1.0-alpha.2] - 2026-10-04

### Added

- Optional level, race, and class metadata in mail suggestion rows.

### Changed

- Mail autocomplete now preserves the exact typed query until the user explicitly selects a suggestion.
- Local and native suggestions are deduplicated by the name used for the mail action.
- Forever's native selection behavior remains available for native results.

## [0.1.0-alpha.1] - 2026-10-04

### Added

- Initial WoW Forever addon project structure.
- MIT license and public project documentation.
- Conservative Latin character folding for accent-insensitive search.
- Versioned local character database with conservative GUID and exact-name merging.
- In-memory development fixtures that are never written to SavedVariables.
- Ranked prefix, token, compact-name, and partial matching.
- Mail recipient integration that composes local matches with Blizzard's native autocomplete source.
