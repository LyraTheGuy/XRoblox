# IndoVoice Automation Suite

Comprehensive automation toolkit for IndoVoice on Roblox.

## Features

**Gathering & Combat**
- Auto Fish — Remote-based with minigame skip and auto re-equip
- Auto Mine — Click-to-mine with hotspot ESP and stone detection
- Auto Sell Ore — Auto teleport to shop and sell by rarity

**Rewards & Currency**
- Auto Gacha (BlindBox) — 10x rolls with stop-on-rarity
- Shop Gacha — Pet/Aura/Trail automation
- Auto Claim Daily & Session Rewards — Hourly loops
- Auto Clicker — VirtualInputManager with position targeting

**Utilities**
- Rod Shop — Browse and purchase rods
- FishZone ESP — Highlight active zones, auto TP
- Player ESP — Box highlight, teleport, tracer, inspect
- Anti-Idle — Defeat idle detection
- Webhook Integration — Discord notifications (customizable)

**Settings**
- Theme Toggle (Dark/Light)
- Accent Color Presets
- Per-Rarity Auto-Sell & Webhook Filters
- Settings Save/Load (persists across sessions)

## File Structure

```
├── bootstrap.lua       # Loader
├── main.lua            # Entry point with gate
├── config.lua          # Theme and defaults
├── gate.lua            # Authentication
├── gui.lua             # Tabbed UI
├── core.lua            # Shared state
├── modules/
│   ├── fishing.lua     # Auto Fish
│   ├── mining.lua      # Auto Mine
│   ├── gacha.lua       # Gacha automation
│   ├── rodshop.lua     # Rod purchasing
│   ├── shopgacha.lua   # Shop Gacha
│   ├── antiafk.lua     # Anti-Idle
│   └── ui.lua          # Window controls
└── README.md
```

## Usage

1. Run `bootstrap.lua`
2. Authenticate with password gate
3. Select features from tabs
4. Press `K` to hide/show UI

- Toggle with K key (minimize/restore)
- Loading and unloading animations match main GUI size
- Scrollable tabs for all sections
- Real-time Logs tab with timestamps (max 200 entries)

## File Structure

```
IndoVoice/
├── bootstrap.lua       # Branch-specific tiny loader (fetches from GitHub)
├── main.lua            # Entry point — loads config, LyraHub kit, gui, core, then modules
├── config.lua          # Configuration (keys, theme, zones, sell rarities, webhook)
├── gui.lua             # Full GUI layout and elements
├── core.lua            # Shared state, utilities, players, zones, clicker, webhook, settings
├── modules/
│   ├── fishing.lua     # Auto Fish system
│   ├── mining.lua      # Auto Mine + Auto Sell Ore
│   ├── gacha.lua       # Auto Gacha (Blind Box)
│   ├── shopgacha.lua   # Shop Gacha (Pet / Aura / Trail)
│   ├── rodshop.lua     # Rod Shop purchases
│   └── ui.lua          # UI bindings, heartbeat loop, startup
└── README.md           # This file
```

## Architecture

The codebase uses a modular `ctx` (context) pattern to stay within Luau's 200 local register limit per function scope:

1. `core.lua` creates a shared `ctx` table with all mutable state and utility functions
2. Each module in `modules/` receives `ctx` and adds its own functionality
3. Modules read/write shared state through `ctx` (e.g., `ctx.destroyed`, `ctx.autoFishEnabled`)
4. `main.lua` orchestrates loading: config → gui → core → modules

## Usage

Execute `bootstrap.lua` with your script executor. The GUI loads after a brief animation. All settings persist locally via `LyraHub_Settings.json`.

## Hotkeys

| Key | Action |
|-----|--------|
| K | Minimize / Restore UI |
| F | Toggle Auto Clicker |
| P | Pick clicker target position |

## Credits

Created by **Ahzencal**

Discord: Ahzencal
Saweria: https://saweria.co/ahzencal

LyraHub est. 2026
