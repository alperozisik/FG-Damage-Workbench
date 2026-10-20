# Changelog

Changes are recorded by release, newest first. Dates use YYYY-MM-DD.
This log starts with v0.3.5; earlier releases remain in GitHub Releases.

## [Unreleased]

## [0.3.6] - 2026-10-20

### Added

- Auto-reroll thresholds in the die context menu, with selected-state indicators and saved-layout persistence.
- Private Undo audit messages for the GM and the request owner, listing discarded dice and results.
- An initially off x2 toggle beside Apply, using the native damage multiplier.

### Fixed

- Staged dice visibility now follows FG's Show results to players policy, while retaining hidden/tower and GM-roll privacy.
- Native reroll modes and die colors survive drops, critical copies and throw transport.
- Native discarded reroll attempts are validated and excluded from totals while retaining their order and history in result tooltips.

### Documentation

- Remove the mouse pointer and blue automation halo from the Critical damage-type screenshot.

## [0.3.5] - 2026-10-19

### Added

- A red native FG chat announcement on campaign load displaying the Damage Workbench version and logo.
- An original crimson die and anvil logo for chat and the usage guides.
- Explicit version coverage in both English and Turkish usage guides.
- A changelog and release checklist for this and future updates.

### Changed

- The source archive includes the changelog and current illustrated usage guides.
- Package builds check that the load-message version matches extension metadata.

[Unreleased]: https://github.com/alperozisik/FG-Damage-Workbench/compare/v0.3.6...HEAD
[0.3.5]: https://github.com/alperozisik/FG-Damage-Workbench/releases/tag/v0.3.5

[0.3.6]: https://github.com/alperozisik/FG-Damage-Workbench/compare/v0.3.5...v0.3.6
