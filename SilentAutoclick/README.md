# Silent Hub — Autoclicker

Universal autoclicker for any Roblox game.

## Features

**● Auto Clicker**
- Silent clicking via VirtualInputManager
- Follow cursor or fixed position modes
- Adjustable CPS (1-100) with slider and presets
- Configurable click delay (1-360s)
- Real-time stats: clicks, CPS, FPS, ping

**🏃 Movement**
- Fly — WASD + Space/Shift flight
- NoClip — walk through walls
- Infinite Jump — unlimited jumps

**🛡️ Utility**
- Anti AFK — prevent idle kicks
- Anti Gameplay Pause — block pause notifications
- Persistent Settings — save/load/reset to disk

## File Structure

```
SilentAutoclick/
├── bootstrap.lua       # Loader
├── main.lua            # Entry point
├── config.lua          # All settings
├── gui.lua             # Single-page scrollable GUI
├── core.lua            # Shared state, clicker, game interaction, persistence
├── modules/
│   ├── clicker.lua     # Auto clicker loop + timing
│   ├── stats.lua       # Live stats + sparkline
│   ├── ui.lua          # Window drag, minimize, hotkeys
│   └── movement.lua    # Fly, NoClip, Infinite Jump
└── README.md
```

## Usage

1. Run `bootstrap.lua` with your script executor
2. All features are visible on one scrollable page
3. Press `K` to minimize/restore the UI

## GUI Layout

Single-page scrollable design — no tabs, everything visible at once:

| Section | Controls |
|---------|----------|
| ● Auto Clicker | Status, mode dropdown, toggle, keybind |
| ◎ Click Timing | Delay input, CPS slider, presets |
| 🏃 Movement | Fly, NoClip, Infinite Jump |
| 🛡️ Utility | Anti-AFK, persistence (save/load/reset), unload, stats |

## Hotkeys

| Key | Action |
|-----|--------|
| F | Toggle auto clicker |
| P | Pick fixed target position |
| K | Minimize / Restore UI |
| WASD + Space/Shift | Fly movement |
