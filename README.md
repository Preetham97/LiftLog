# LiftLog

A clean iOS workout tracker focused on **progressive overload**: every time you log an exercise, the app shows you what you did last session so you can decide what to push.

## Features

- **Routines** — build cycles (Push/Pull/Legs, Upper/Lower, anything). Multiple routines supported; one is active at a time.
- **Today** — shows the next day in your active routine's cycle, with each exercise's previous session inline. Pre-fills new sets with last-session weights to make small bumps frictionless.
- **Manual cycle control** — accidental "advance" is recoverable: swipe any day → "Set Next".
- **Stats** — per-exercise progress charts:
  - **Estimated 1RM** (Epley) — strength trend.
  - **Total volume** (weight × reps × sets) — work trend.
  - Trend badges on the index show session-over-session change.
- **kg / lbs** toggle.

## Stack

- **SwiftUI** + **SwiftData** (iOS 17+)
- **Swift Charts** for progress graphs
- Single-target, no third-party dependencies
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) for the project file — edit `project.yml`, run `xcodegen generate`.

## Build

```sh
xcodegen generate
open LiftLog.xcodeproj
```

Then run on the iOS Simulator (Xcode 15+).

## Project layout

```
LiftLog/
├── LiftLogApp.swift          # App entry + SwiftData container
├── Models/Models.swift       # Routine, RoutineDay, Exercise, WorkoutSession, LoggedExercise, SetEntry
├── Util/
│   ├── Theme.swift           # Shared colors, card modifier, pill labels
│   └── UnitPreference.swift  # kg/lbs toggle + weight formatting
└── Views/
    ├── RootView.swift        # Tab bar
    ├── TodayView.swift       # Hero header + exercise log cards
    ├── RoutinesView.swift    # Routine CRUD + cycle management
    ├── StatsView.swift       # Charts + per-exercise summaries
    └── SettingsView.swift    # Units, about
```
