# Silent AutoClicker

Universal, lightweight silent autoclicker GUI for Roblox. Works on any game — not tied to a specific title's remotes or systems.

## Features

### Auto Clicker
- Silent click via `VirtualInputManager` (no visible cursor movement/jitter), with a `mouse1press`/`mouse1release` fallback for executors without VIM access
- Two click modes:
  - **Follow Cursor** — clicks wherever your mouse currently is
  - **Fixed Position** — locks to a picked coordinate (hotkey `P`)
- Adjustable CPS (1-100) via draggable slider
- Custom keybind support for start/stop (default `F`)

### Live Stats
- **Total Clicks** — running counter since the script started
- **CPS (Actual)** — measured clicks-per-second over a rolling 1s window (reflects real throughput, not just the slider target)
- **FPS** — client frame rate
- **Ping** — live network latency (ms)
- **CPS sparkline** — live bar chart of actual CPS vs the target line (60 samples ≈ 30s of history, updated every 0.5s); the warn-colored line repositions instantly when you drag the CPS slider

### UI
- Built with the **LyraHub UI kit** (same components as the LyraHub folder)
- Compact draggable window (360x420) with gradient background, glow stroke, drop shadow
- **LyraHub components**: rounded buttons (hover + press animations), dropdown for click mode,
  draggable CPS slider, and a keybind picker with pulsing REC indicator + Esc/click-away cancel
- Minimize into a small 4-card panel (Status / CPS / FPS / Ping) — stays visible and readable while collapsed
- The stats panel also hosts a live **actual-CPS-vs-target sparkline** strip below the stat cards
- Minimized panel is independently draggable
- Hide/show entire UI with `K`
- Close button fully disconnects everything (safe to re-run the script)

## File Structure

```
SilentAutoclick/
├── bootstrap.lua       # Tiny loader (fetches from GitHub)
├── main.lua            # Entry point — loads LyraHub kit, config, gui, core, modules
├── config.lua          # Keys, theme (LyraHub shape), default CPS
├── gui.lua             # GUI built with LyraHub components (dropdown/slider/keybind/buttons)
├── core.lua            # Shared state, silent click, toggle, destroy
├── modules/
│   ├── clicker.lua     # Click mode dropdown, CPS slider, keybind picker, click loop
│   ├── stats.lua       # Total Clicks / actual CPS / FPS / Ping + sparkline feed
│   └── ui.lua          # Window drag, minimize/restore, close, hotkeys
└── README.md           # This file

The GUI fetches its component factories from the `LyraHub/` folder in the same
repo (see `main.lua`); only the clicker-specific layout lives in this folder.
```

## Architecture

Same modular `ctx` (context) pattern as IndoVoice/LyraHub, kept intentionally minimal since this is a single-purpose utility:

1. `core.lua` creates a shared `ctx` table with mutable state and utility functions
2. Each module in `modules/` receives `ctx` and adds its own functionality
3. Modules read/write shared state through `ctx` (e.g., `ctx.clicking`, `ctx.clickCPS`)
4. `main.lua` orchestrates loading: config → gui → core → modules

## Usage

Execute `bootstrap.lua` with your script executor. The GUI appears immediately — no login/gate required.

## Hotkeys

| Key | Action |
|-----|--------|
| F | Toggle Auto Clicker (start/stop) |
| P | Pick fixed target position (Fixed mode only) |
| K | Hide / show UI |

## Notes

- "Silent" refers to the click method (`VirtualInputManager`), which avoids moving your real mouse cursor or triggering visible clicks — it does not bypass anti-cheat or hide the script's existence from server-side detection.
- Works on any Roblox experience since it only interacts with client input, not game-specific remotes.
