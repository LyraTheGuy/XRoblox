# LyraHub

Automation toolkit for IndoVoice on Roblox. Built with a custom violet-themed GUI on the **LyraHub UI kit** (fetched from the raw GitHub link, same as SilentAutoclick and BuildABeehive), modular architecture, and persistent settings.

## Features

### Auto Fish
- Remote-based fishing engine
- Mouse hold casting with animation verification
- Detects bite via `StartMinigame.OnClientEvent` (captures fish name, rarity, price, weight)
- Waits for minigame GUI detection, then skips with randomized 5-10s delay
- Catches via `CatchEvent:FireServer(true)`
- Auto re-equip rod on timeout
- Performance monitor: rarity breakdown, earnings tracker
- Webhook notifications for rare catches

### Auto Mine
- Click-to-mine system (TP near stone, click anywhere)
- Detects mining start via `StartMinigame.OnClientEvent` on pickaxe
- Skips minigame with randomized 5-10s delay
- Catches via `MineResult:FireServer(true)`
- Fires `MinigameOpenedEvent` and destroys minigame GUI after mining
- Auto-equip pickaxe from backpack
- Auto TP to nearest available stone (skips full stones: `AvailableSlot = 0` or `ConsumedSlot >= MaxSlot`)
- Hotspot Only mode (filters stones with `IsHotspot = true`)
- Hotspot ESP (highlights hotspot stones with yellow Highlight + billboard)
- Ore rarity tracking and stats display
- Webhook notifications for rare ores

### Auto Sell Ore
- Teleports to `OreShop` NPC, sells, teleports back
- Configurable sell interval
- Toggle-per-rarity sell buttons (same style as fish sell)
- Sell Now button for instant sell

### Auto Gacha (BlindBox)
- 10x roll automation
- Auto-reads available boxes from ReplicatedStorage
- Stop-on-rarity: select target rarities and it stops when obtained
- Shows pet name and rarity from each roll
- Webhook alert on jackpot

### Shop Gacha (Pet / Aura / Trail)
- 10x roll automation for shop items
- Type selection (Pet, Aura, Trail)
- Stop-on-rarity with webhook notification
- Auto-destroys gacha animation UI and mutes sounds

### FishZone
- FishZone ESP (highlights active zones)
- Auto TP to active fishing zones with body lock
- Auto Sell fish by selected rarities
- Sell Now (instant TP to FishShop and back)
- Refresh character (Adonis command)

### Player Tools
- Player ESP (box + nametag)
- Teleport to player
- Beam tracer
- Avatar inspect
- Search filter by name/display name

### Auto Clicker
- Silent click via VirtualInputManager
- Adjustable CPS (1-100) with slider
- Pick target position with hotkey
- Custom keybind support

### Rod Shop
- Browse and purchase rods directly from GUI
- Search filter
- Status feedback on purchase success/failure

### Rewards
- Auto Claim Daily Reward (loops every 1 hour)
- Auto Claim Session Reward slots 1-12 (loops every 1 hour)

### Settings
- Anti-Idle (disconnects Roblox idle detection)
- Webhook integration (Discord)
  - Fish caught notifications (filtered by rarity)
  - Ore mined notifications (filtered by rarity)
  - Sell notifications with earnings
  - Gacha jackpot alerts
  - Test webhook button
- Auto-sell rarity selection (toggle per rarity)
- Webhook rarity filter (toggle per rarity)
- Dark / Light theme toggle
- Accent color presets
- Save/Load settings locally (auto-loads on start)

### UI
- Lyra violet/purple theme (kit palette via `config.Theme`)
- Built on the LyraHub UI kit: `main.lua` fetches `shared.lua` + `button.lua` from the raw GitHub link and passes them to `gui.lua` as `(config, components)`
- Kit primitives everywhere: `shared.corner`/`stroke`/`glow`/`gradient`/`shadow`/`tween` replace raw `UICorner`/`UIStroke` decoration
- Gradient background, glow stroke and soft drop shadow on the main window (shadow follows on drag, hides with the window)
- Hover animations on the title-bar buttons
- Wide layout (620x420)
- Draggable from top bar and bottom line
- Minimize to circular "L" orb
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
