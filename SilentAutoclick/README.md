# Silent AutoClicker

Universal, lightweight autoclicker for Roblox with VirtualInputManager support.

## Features

- **Silent Click** — VirtualInputManager-based clicking with fallback support
- **Click Modes** — Follow cursor or fixed position targeting
- **CPS Control** — Adjustable 1-100 CPS with live feedback
- **Stats** — Real-time clicks, CPS, FPS, and ping display
- **Minimizable** — Compact pill mode while active
- **Keybind Control** — Customizable F (toggle), P (target), K (hide/show)

## File Structure

```
├── bootstrap.lua       # Loader
├── main.lua            # Entry point
├── config.lua          # Settings and theme
├── gui.lua             # UI components
├── core.lua            # Click engine and state
├── modules/
│   ├── clicker.lua     # Click mode, CPS, keybinds
│   ├── stats.lua       # Performance metrics
│   └── ui.lua          # Window controls
└── README.md
```

## Usage

1. Run `bootstrap.lua`
2. Press `F` to toggle clicking
3. Use mode dropdown to select **Follow Cursor** or **Fixed Position**
4. Adjust CPS slider (1-100)
5. Press `P` to pick target (Fixed Position only)
6. Press `K` to hide/show UI


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
