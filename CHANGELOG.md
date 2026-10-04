# Changelog

All notable changes to Forever Easy Find & Send will be documented in this file.

The project follows [Semantic Versioning](https://semver.org/).

## [Unreleased]

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
