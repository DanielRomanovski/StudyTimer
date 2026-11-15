# Changelog

Notable changes to StudyTimer are documented here.

## [1.0.3] - 2026-11-15

### Added

- Right-click status-item event routing for the Quit menu.
- Built-in sound previews, custom audio import, and repeat-until-dismissed completion alerts.
- Durable Application Support storage with migration from existing user defaults.

### Fixed

- Preserve the active timer, remaining time, pause/run state, and queued timers across quitting and reopening the app. Canceling with `x` still clears the active timer and queue.

### Changed

- Crop icon artwork more tightly to reduce empty margins in the app icon.
- Clarify setting descriptions, show the hashtag prefix in manual activity entry, and remove the completed-session count from the timer popover.
- Center the Donate button in Settings and dismiss the timer popover when clicking outside it.

## [1.0.1] - 2026-11-15

### Added

- Right-click the menu-bar countdown to open a Quit StudyTimer command.
- A Settings toggle to start the app at login using macOS Login Items.
- Donate links in Settings and at the top of the README.
- A drag-to-Applications disk image for installation.

## [1.0.0] - 2026-11-15

### Added

- Named timer presets with editable timer sequences, per-step tags, and saved loop behavior.
- Reset and cancel controls for the active timer. Cancel also clears the queued timers.
- Aggregated total time per hashtag in the Activity sidebar.
- README screenshots for the timer, Activity, Presets, and Settings views.
- A custom macOS app icon generated from the supplied artwork.
- A downloadable Apple Silicon app bundle on GitHub Releases.

### Changed

- Use a native AppKit status item to display the countdown directly in the macOS menu bar.
- Defer Activity and Settings window presentation until the timer popover closes.
- Accept longer `MM:SS` durations and common unit forms such as `45 min`.
- Show inline timer-input guidance instead of playing the system error sound.
- Preserve existing local data when loading state that predates saved presets.
- Document the one-time Gatekeeper confirmation needed for this ad-hoc-signed release.