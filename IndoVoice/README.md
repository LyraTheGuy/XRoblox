# IndoVoice Automation Suite

Comprehensive automation toolkit for IndoVoice on Roblox.

## Features

**Gathering & Combat**
- Auto Fish — Remote-based with minigame skip and auto re-equip
- Auto Mine — Click-to-mine with hotspot ESP and stone detection
- Auto Sell Ore — Auto teleport to shop and sell by rarity
- Auto TP Stone Hotspot — Auto teleport to hotspot stones only (filters non-hotspots automatically)

**Rewards & Currency**
- Auto Gacha (BlindBox) — 10x rolls with stop-on-rarity
- Shop Gacha — Pet/Aura/Trail automation
- Auto Claim Daily & Session Rewards — Hourly loops
- Auto Clicker — VirtualInputManager with position targeting

**Utilities**
- Rod Shop — Browse and purchase rods
- FishZone ESP — Highlight active zones, auto TP
- Player Admin Menu — Target a player, then drive ESP / Beam / View / TP (see below)
- Follow Player — Follow a player to fish/mine together (stable camera freeze, wall bypass, faces target direction)
- Anti-Idle — Defeat idle detection
- Webhook Integration — Discord notifications (customizable)

**Settings**
- Theme Toggle (Dark/Light)
- Accent Color Presets
- Per-Rarity Auto-Sell & Webhook Filters
- Settings Save/Load (persists across sessions)

**Session & Persistence**
- Password Bypass — type the gate password once; rejoins in the same place skip the gate (per-place session file, 7-day TTL, see `config.Gate.SessionTTL`)
- Auto Re-Execute on Rejoin — the script re-runs itself after server hops / reconnects via `queue_on_teleport` + a one-shot re-exec marker (cleared by manual unload)
- Duplicate-Run Guard — safe re-execution: a second copy never runs while one is alive

## Player Admin Menu (ESP / Beam / View / TP)

The Players tab is a single admin menu owned by `modules/adminmenu.lua`. It reads
players live from the shared Players service, lets you pick a target on the left,
then drives four features from the toolbar:

| Feature | What it does |
|---------|--------------|
| **ESP** | Overlay for the **selected player** by default (switch the panel to *All players* for everyone): a tag showing the **DisplayName only** plus a box / highlight outline. The tag colour still tracks health (green → yellow → red) and staff get a red outline. Refreshes are throttled (never per-frame). |
| **BEAM** | Draws a beam from you to the selected target. Customise colour, thickness, transparency and style (Solid / Pulse / Rainbow). Re-homes itself after respawns. |
| **VIEW** | Scriptable camera on the target: smooth third-person Follow, First-person, or an automatic Orbit. Smoothness, distance, height, orbit speed and radius are sliders. Restores your camera on disable. |
| **TP** | Guarded teleport with a disable-condition submenu showing live status. |

**Quick toggle:** click a player's **name** in the list — that turns ESP + Beam on for
them; click the **same** name again to turn them off. No checkbox needed. VIEW and TP
keep using the selected target.

**Unloading** (Settings → Unload Script, the ✕ button, or `ctx.adminMenuCleanup()`)
destroys every ESP tag / box / highlight, removes the beam and restores your camera.

**TP disable conditions** (all default **ON** so a misclick can never teleport you):
`Require confirm click`, `Cooldown`, `Block if target is dead`, `Block if you are dead`,
`Block if target is staff`, `Block if in a safe zone`, `Block if you are in combat`.
Click a row to toggle it; the status column shows `OK`, `BLOCKED`, `ARMED` or `OFF`.

### Customising

Every tunable lives at the top of `IndoVoice/modules/adminmenu.lua`:

```lua
local ESP_CFG  = { Interval, MaxDistance, Outline, Scope, ShowName,
                   ColorMode, StaticColor, RequireLineOfSight }
local BEAM_CFG = { Interval, Color, Thickness, Transparency, Style }
local VIEW_CFG = { Smoothness, Mode, Distance, Height, OrbitSpeed, OrbitRadius }
local TP       = { RequireConfirm, ConfirmWindow, Cooldown, BlockTargetDead,
                   BlockSelfDead, BlockStaff, BlockSafeZone, BlockInCombat }
```

Features can also be driven programmatically through the shared context:

```lua
ctx.adminMenu.selectTarget(player)
ctx.adminMenu.setESP(true)         -- ESP for the current scope (target / all)
ctx.adminMenu.toggleTarget(player) -- the click-a-name switch: ESP + Beam on/off
ctx.adminMenu.setESPScope("all")   -- "target" (default) or "all"
ctx.adminMenu.setBeam(true)     -- beam to the selected target
ctx.adminMenu.setView(true)     -- camera on the selected target
ctx.adminMenu.teleport(target)  -- guarded teleport (honours every condition)
ctx.adminMenu.getState()        -- { target, espOn, beamOn, viewOn, espCount, espScope }
```

The `E` key (config `Keys.ESP`) toggles the global ESP overlay.

## File Structure

```
├── bootstrap.lua       # Loader
├── main.lua            # Entry point with gate
├── config.lua          # Theme and defaults
├── gate.lua            # Authentication (supports session bypass)
├── session.lua         # Per-place session save/bypass + re-exec flag
├── gui.lua             # Tabbed UI
├── core.lua            # Shared state
├── modules/
│   ├── adminmenu.lua   # Player Admin Menu (ESP / Beam / View / TP)
│   ├── fishing.lua     # Auto Fish
│   ├── mining.lua      # Auto Mine
│   ├── gacha.lua       # Gacha automation
│   ├── rodshop.lua     # Rod purchasing
│   ├── tokenshop.lua   # LuckTicket purchasing
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
│   ├── adminmenu.lua   # Player Admin Menu (ESP / Beam / View / TP)
│   ├── fishing.lua     # Auto Fish system
│   ├── mining.lua      # Auto Mine + Auto Sell Ore
│   ├── gacha.lua       # Auto Gacha (Blind Box)
│   ├── shopgacha.lua   # Shop Gacha (Pet / Aura / Trail)
│   ├── tokenshop.lua   # Token Shop (LuckTicket I - VI)
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

## Recent Changes

### Follow System (Fishing & Mining)
- Fixed camera wobble — BodyGyro locks rotation once, only BodyPosition tracks target
- Fixed wall bouncing — CFrame teleport bypasses invisible walls before freeze
- Fixed follow offset — now uses target's facing direction (`targetHRP.CFrame * CFrame.new(0,0,5)`) instead of world-space Z-axis
- Character stays frozen when target stops (stable camera like Auto Fish TP)

### Auto TP Stone Hotspot
- Now forces hotspot-only filtering when enabled (skips non-hotspot stones)

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
