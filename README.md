# StudyTimer

A small, native macOS menu-bar timer. The menu-bar item displays the remaining time as text and stays out of the Dock.

## Build and run

Requires macOS 14 or later and Swift 6.

```sh
./scripts/build-app.sh
open dist/StudyTimer.app
```

The app is ad-hoc signed for local use. Distribution outside your Mac requires signing and notarization with an Apple Developer account.

## Use

- Enter `35:00`, `45`, or `1:30:00` to start a timer. Add an optional tag after `#`, such as `35:00 #working`.
- Use `+` to queue the next timer. Enable Loop to repeat completed timers after the queued timers.
- Open Activity from the bottom-left chart button to review tags and sessions, add manual records, or delete entries.
- Settings include sound, volume, notifications, sleep prevention, and configurable keyboard shortcuts. The create shortcut starts the most recent session duration, or 25 minutes when there is no history.

Timer history, queue, and preferences are stored locally in macOS user defaults.