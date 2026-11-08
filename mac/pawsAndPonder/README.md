# Paws and Ponder

A small Pomodoro timer for macOS that lives in the menu bar, with a floating widget that stays on screen.

## Build the DMG

Requires macOS 27.2 or newer and Xcode installed (Xcode doesn't need to be open).

```bash
scripts/make-dmg.sh
```

This builds a Release version and writes `dist/Paws-and-Ponder.dmg`.

To install, open the DMG and drag the app onto **Applications**.

## Features

**Timer**
- Work and break phases, with the length of each set in minutes (type it or use the stepper)
- Start, pause, reset and skip to the next phase
- Choose whether the break starts automatically after work, and whether work starts automatically after the break
- Changing a length mid-phase applies right away and keeps the time already elapsed
- Optional sound and notification when a phase ends

**Widget**
- Always on top, on every desktop, including over full-screen apps
- Drag it anywhere; it remembers its position
- Start, pause, reset and skip buttons, without taking focus from the app you're using
- Show the time as digits or as a progress bar, and resize the bar by dragging its edge
- Light, dark or system theme
- Optional: show it on every display (default is the main display only)

**Menu bar**
- Menu-bar-only app with a paw icon and no Dock icon
- Menu with Start/Pause, Reset, Skip, Settings, History and Quit

**History** (optional, off by default)
- Records the time you work each day for the last 4 months
- GitHub-style activity grid, shaded by hours worked, with minutes or hours shown on hover
- Nothing is saved while it's turned off

**Light on resources**
- Redraws once a second and uses about 0.5% CPU while running
