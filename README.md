# MochiCorner

MochiCorner opens directly to your daybook. Each macOS user has a separate local diary on each Mac.

**A gentle, local-first macOS companion for understanding your computer day.**

MochiCorner follows foreground app use, lets you see the shape of your time, and keeps Mochi—a small animated cat—at your side. It is designed to be reflective rather than judgmental: foreground time is a record of what was open, not a claim about focus, effort, or worth.

## What it does

- Tracks foreground applications with five-minute idle-time exclusion.
- Groups activity into Work, Code, Study, Create, Social, Music, Entertainment, and Game categories.
- Lets you correct or create app labels; unfamiliar apps stay intentionally uncategorized.
- Shows Mochi in a floating, configurable desktop widget with reduced-motion support.
- Keeps Mochi and activity tracking running after the dashboard window closes. Use Mochi or the menu-bar paw to reopen the dashboard, pause tracking, or quit.
- Provides a Today dashboard, a calendar-based Memory Garden, and local activity history.
- Adds soft category limits with a single friendly notification—not punitive alerts.
- Creates optional daily Mochi chronicles from aggregate category totals.
- Opens on My daybook, where you can plan small steps for any date and keep a private journal.
- Grows a pocket garden when you complete steps, record a screen-free break, or write a reflection.
- Adds each new chronicle’s suggested step to the following date’s Small steps. Open the dated list directly from the chapter. Private journal prose is excluded from Gemini requests.
- Offers an optional “Turn a thought into gentle steps” helper inside Small steps. You choose which of its one-to-three suggestions to add.

## Privacy

MochiCorner measures foreground-app time only. It does not read screen contents, keystrokes, browser history, document text, or claim to know whether you were focused.

Activity history is stored locally in `~/Library/Application Support/ScreenShire`. Daily chronicle generation is opt-in: category totals, goal status, the mood board, completed step titles, break status and up to five prior fictional memory notes are sent when a chronicle is requested. The gentle-steps helper sends only the thought you enter into that helper. The API key is saved in the macOS Keychain.

## Start MochiCorner

If you already installed it, open **MochiCorner** from Applications.

From this project folder, run:

```sh
make run
```

To create a shareable Mac app archive, run:

```sh
make package
```

The archive is created at `.build/MochiCorner.zip`.

## Build requirements

- macOS 14 or later
- Xcode 16+ / Swift 6+

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
