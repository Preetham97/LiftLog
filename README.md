# LiftLog

A clean iOS workout tracker focused on **progressive overload**: every time you log an exercise, the app shows you what you did last session so you can decide what to push.

## Features

- **Routines** — build cycles (Push/Pull/Legs, Upper/Lower, anything). Multiple routines supported; one is active at a time. Comes with a 5-day starter template (chest/back/legs/shoulders/mixed) you can pick from the empty state or the "+" menu. Each exercise has a "BW" toggle for bodyweight lifts (crunches, pushups, pullups) — those hide the weight field and switch every chart and summary to a reps-based metric.
- **Today** — shows the next day in your active routine's cycle, with each exercise's previous session inline. Pre-fills new sets with last-session weights to make small bumps frictionless.
- **Manual cycle control** — accidental "advance" is recoverable: swipe any day → "Set Next".
- **Stats** — per-exercise progress charts:
  - **Estimated 1RM** (Epley) — strength trend.
  - **Total volume** (weight × reps × sets) — work trend.
  - Trend badges on the index show session-over-session change.
- **Exercise history** — full set-by-set log for every exercise, reachable
  from the exercise card on Today (clock icon) or from a stats screen.
- **Calendar history** — dedicated History tab with a month calendar. Days
  with logged sessions get a green dot; tap one for a read-only view of
  what you did.
- **kg / lbs** toggle.
- **Branded splash screen** on launch — logo + tagline fades in, then
  hands off to the app after ~1.3s.

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

## App icon

The 1024×1024 icon lives at `LiftLog/Assets.xcassets/AppIcon.appiconset/AppIcon.png`.
A Core Graphics generator alternative is kept at [Tools/generate_icon.swift](Tools/generate_icon.swift)
for experimenting:

```sh
swift Tools/generate_icon.swift LiftLog/Assets.xcassets/AppIcon.appiconset/AppIcon.png
```

## Project layout

```
LiftLog/
├── LiftLogApp.swift          # App entry + SwiftData container
├── Assets.xcassets/          # App icon
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

Tools/
└── generate_icon.swift       # Core Graphics icon generator
```
