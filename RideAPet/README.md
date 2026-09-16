# Ride A Pet Automator

Automation toolkit for Ride A Pet on Roblox.

## Features

**🥚 Auto Get Egg**
- Collects eggs from map — **never auto-places them**
- Eggs stay in inventory infinitely for rarest stacking
- Rarity whitelist (Divine, Mythical, Legendary, Epic)
- Rarity priority sorting (rarer eggs first)
- **Rarity distribution tracker** — live counts per tier
- **Session stats** — eggs/min, elapsed time, nearby count
- **Sound alerts** — pitch-shifted sounds on rare finds
- **Nearby egg ESP** — colored highlights + name labels
- **Smart routing** — distance + rarity combined scoring
- **Auto-discard** — optionally discard low-rarity eggs
- **Discord webhook** — notification for rare finds
- **Hotkey** — press `G` to toggle on/off
- Auto-TP to egg spawns

**🐾 Auto Ride**
- Auto-mount best pet from inventory
- Configurable ride speed (10-200)
- Preferred pet selection
- Real-time pet detection

**🛡️ Player ESP**
- Box highlight with name tags
- Toggle on/off with keybind
- Auto-refresh on player join/leave

**⚙️ Settings**
- Anti-Idle — prevent idle kicks
- Theme Toggle (Dark/Light)
- Accent Color Presets
- Persistent Settings — save/load to disk
- Unload Script — clean removal

## File Structure

```
RideAPet/
├── bootstrap.lua       # Loader
├── main.lua            # Entry point
├── config.lua          # Settings and theme
├── gui.lua             # Tabbed UI (Ride / ESP / Settings / Logs)
├── core.lua            # Shared state, utilities, ESP, clicker, settings
├── modules/
│   ├── auto_ride.lua   # Auto ride system with pet detection
│   ├── auto_get_egg.lua # Auto egg collection (NO placement!)
│   ├── esp.lua         # Player ESP with auto-refresh
│   └── ui.lua          # Window drag, minimize, hotkeys
└── README.md
```

## Usage

1. Run `bootstrap.lua`
2. Authenticate with password gate
3. Select features from tabs
4. Press `K` to hide/show UI

## Hotkeys

| Key | Action |
|-----|--------|
| K | Minimize / Restore UI |
| F | Toggle Auto Ride |
| P | Pick clicker target position |
| E | Toggle Player ESP |
| T | Teleport to player |

## Architecture

The codebase uses a modular `ctx` (context) pattern to stay within Luau's 200 local register limit per function scope:

1. `core.lua` creates a shared `ctx` table with all mutable state and utility functions
2. Each module in `modules/` receives `ctx` and adds its own functionality
3. Modules read/write shared state through `ctx` (e.g., `ctx.destroyed`, `ctx.rideEnabled`)
4. `main.lua` orchestrates loading: config → gui → core → modules

## Credits

Created by **Ahzencal**

Discord: Ahzencal
Saweria: https://saweria.co/ahzencal

LyraHub est. 2026
