# Changelog

Notable changes to StudyTimer are documented here.

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