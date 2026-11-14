# ScreenShire

**A gentle, local-first macOS companion for understanding your computer day.**

ScreenShire follows foreground app use, lets you see the shape of your time, and keeps Mochi—a small animated cat—at your side. It is designed to be reflective rather than judgmental: foreground time is a record of what was open, not a claim about focus, effort, or worth.

## What it does

- Tracks foreground applications with five-minute idle-time exclusion.
- Groups activity into Work, Code, Study, Create, Social, Music, Entertainment, and Game categories.
- Lets you correct or create app labels; unfamiliar apps stay intentionally uncategorized.
- Shows Mochi in a floating, configurable desktop widget with reduced-motion support.
- Provides a Today dashboard, a calendar-based Memory Garden, and local activity history.
- Adds soft category limits with a single friendly notification—not punitive alerts.
- Creates optional daily Mochi chronicles from aggregate category totals.
- Opens on My daybook, where you can plan small steps for any date and keep a private journal.
- Grows a pocket garden when you complete steps, record a screen-free break, or write a reflection.
- Lets you add an optional Gemini-suggested offline step to tomorrow’s daybook from a daily chronicle. Journal entries and plan text stay on your Mac.

## Privacy

ScreenShire measures foreground-app time only. It does not read screen contents, keystrokes, browser history, document text, or claim to know whether you were focused.

Activity history is stored locally in `~/Library/Application Support/ScreenShire`. Daily chronicle generation is opt-in: only aggregate category totals, goal status, and up to five prior fictional memory notes are sent when a chronicle is requested. The API key is saved in the macOS Keychain.

## Requirements

- macOS 14 or later
- Xcode 16+ / Swift 6+

## Run locally

```sh
swift run ScreenShire
```

Or open `Package.swift` in Xcode and run the **ScreenShire** scheme.

## Test

```sh
swift test
```

## Cat artwork

The included category artwork lives in `Sources/ScreenShire/Resources/Cats`. Idle and uncategorized activity use Mochi's Work scene until an app has a category.

To replace the art, provide three 256×256 transparent PNG frames for each category using this naming pattern:

```text
Cats/work_00_256.png     Cats/code_00_256.png     Cats/study_00_256.png
Cats/music_00_256.png    Cats/entertainment_00_256.png
Cats/social_00_256.png   Cats/create_00_256.png   Cats/game_00_256.png
```

Repeat `_01_256` and `_02_256` for each category.

## Roadmap

- Return Threads: remember where you were before an interruption.
- Future-self postcards: short handoff notes for resuming a project later.
- Attention Weather: humane patterns such as a quiet deep-work morning or a scattered afternoon.
- Intention sessions: lightweight, reflective sessions without turning ScreenShire into a task manager.

## Contributing

Issues and pull requests are welcome. Please keep new features aligned with the project’s core principle: help people notice and steer their attention without surveillance or shame.
