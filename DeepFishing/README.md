# Deep Fishing Automation Suite

Comprehensive automation toolkit for Deep Fishing on Roblox, built on the LyraHub UI framework.

## Quick Start

1. Run `bootstrap.lua` with your script executor
2. Wait for the loading screen to complete
3. Select features from the tabs
4. Press `K` to minimize/restore the UI

---

## File Structure

```
DeepFishing/
├── bootstrap.lua       # Loader — fetches main.lua from GitHub
├── main.lua            # Entry — loads config, LyraHub kit, GUI, core, modules
├── config.lua          # All settings: theme, keybinds, feature defaults
├── gui.lua             # 5-tab GUI with loading animation, draggable window
├── core.lua            # Shared ctx, game module discovery, logging, sell/anti-idle
├── modules/
│   ├── autofish.lua    # Auto fishing loop, rod equip, throw/reel
│   ├── autosell.lua    # Auto sell fish, auto delete low-rarity items
│   ├── autobuy.lua     # Auto buy bait, rod, upgrades with manual fallback
│   ├── movement.lua    # Fly, NoClip, Infinite Jump, Walk Speed
│   └── utility.lua     # Anti-AFK, codes redemption, reward claiming
└── README.md
```

---

## Tabs Overview

| Tab | Icon | Contents |
|-----|------|----------|
| **Fishing** | 🎣 | Auto fish toggles, instant collect, auto-stop, rarity/mutation filters, auto-reward toggles |
| **Shop** | 🛒 | Bait shop (auto buy + manual), rod shop (auto buy + manual), upgrades, sell/delete |
| **Player** | 🏃 | Fly, NoClip, Infinite Jump, Walk Speed, Anti-AFK, Anti Gameplay Pause |
| **Rewards** | 🎁 | Redeem all codes, claim playtime/next day/group rewards (manual + auto) |
| **Settings** | ⚙️ | Keybinds, persistent save/load/reset, project info, scrollable log, unload button |

---

## Module Details

### `modules/autofish.lua` — Auto Fishing

Handles the complete fishing loop: equip rod → throw line → wait for bite → reel in (auto-perfect).

**How it works:**
1. Scans `Backpack` and `Character` for tools matching `Rod`, `Fishing`, `Hook`, or containing a `Cast` child
2. Calls the game's `Throw` remote to cast the line
3. Waits a random 2–8 second bite window
4. Calls the `Reel` remote to auto-complete the catch
5. Increments fish count and updates the GUI status label
6. Loops until disabled or bait runs out

**Toggles exposed via GUI:**

| Toggle | Default | Description |
|--------|---------|-------------|
| Auto Perfect Fish | OFF | Master toggle — starts/stops the fishing loop |
| Instant Collect | ON | Fast collection after reel-in (game handles automatically) |
| Auto Stop When Empty | ON | Stops fishing when no bait items found in Backpack |
| Collect All Rarities | ON | Accept all fish rarities (filter toggle) |
| Collect Mutations | ON | Auto-collect mutated fish variants |

**Remote discovery:** Searches `ReplicatedStorage` and subfolders for `Throw`, `Reel`, `UseBait`.

**Status label:** `gui.Fishing.StatusLabel` — shows "Fishing...", "Fish caught! Total: N", "No bait!", "No rod found!"

---

### `modules/autosell.lua` — Auto Sell & Delete

Manages fish inventory: auto-sell on interval, manual sell button, auto-delete low-rarity items.

**Auto Sell loop:**
- Calls `ctx.performSell()` (defined in `core.lua`) every `config.AutoSell.Interval` seconds (default 300)
- Tracks total sell count in `sellCount`
- Updates `gui.Shop.SellStatusLabel` with success/failure

**Auto Delete loop:**
- Scans `Character` and `Backpack` every 5 seconds for `Tool` instances with a `Rarity` attribute
- Destroys items whose rarity matches `config.AutoDelete.Rarities` (default: Common = true)
- Logs each deletion

**GUI controls:**

| Control | Type | Description |
|---------|------|-------------|
| Auto Sell Fish | Toggle | Starts/stops the auto-sell interval loop |
| Sell All Fish Now | Button | Immediate one-shot sell via remote |
| Auto Delete Low Rarity | Toggle | Starts/stops the delete loop |

**Configuration (`config.lua`):**
```lua
AutoSell = {
    Interval = 300,        -- seconds between auto-sells
    Rarities = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic" },
},
AutoDelete = {
    Rarities = { Common = true, Uncommon = false, Rare = false },
},
```

---

### `modules/autobuy.lua` — Auto Buy Bait / Rod / Upgrades

Automatically purchases the best available bait, rod, and upgrades via game remotes.

**Remote discovery:** Searches `ReplicatedStorage` for `BuyBait`/`BuyBestBait`, `BuyRod`/`BuyBestRod`, `BuyUpgrade`/`BuyUpgrades`.

**Auto-buy intervals:**

| Item | Interval | Remote searched |
|------|----------|-----------------|
| Best Bait | 60 seconds | `BuyBait` or `BuyBestBait` |
| Best Rod | 120 seconds | `BuyRod` or `BuyBestRod` |
| Upgrades | 180 seconds | `BuyUpgrade` or `BuyUpgrades` |

**GUI controls (6 buttons):**

| Control | Type | Description |
|---------|------|-------------|
| Auto Buy Best Bait | Toggle | Auto-purchase loop (60s interval) |
| Buy Best Bait Now | Button | Immediate one-shot buy |
| Auto Buy Best Rod | Toggle | Auto-purchase loop (120s interval) |
| Buy Best Rod Now | Button | Immediate one-shot buy |
| Auto Buy Upgrades | Toggle | Auto-purchase loop (180s interval) |
| Buy Upgrades Now | Button | Immediate one-shot buy |

**Exposed functions on `ctx`:**
- `ctx.buyBestBait()` → `boolean, result`
- `ctx.buyBestRod()` → `boolean, result`
- `ctx.buyUpgrades()` → `boolean, result`

---

### `modules/movement.lua` — Fly, NoClip, Infinite Jump

Movement hacks for navigation and exploration.

**Fly:**
- Creates `BodyVelocity` + `BodyGyro` on `HumanoidRootPart`
- WASD for horizontal movement (camera-relative)
- Space = up, LeftShift = down
- Updates every `RenderStepped` frame
- Speed controlled by `ctx.flySpeed` (default 50, configurable)
- Re-applies automatically on character respawn

**NoClip:**
- Connects to `RunService.Stepped`
- Sets `CanCollide = false` on every `BasePart` in character descendants
- Runs every physics step while enabled

**Infinite Jump:**
- Connects to `UserInputService.JumpRequest`
- Forces `HumanoidStateType.Jumping` on every jump request
- Allows unlimited mid-air jumps

**Walk Speed:**
- Sets `Humanoid.WalkSpeed` directly
- Re-applies on character respawn
- Default: 16 (configurable via `config.Movement.WalkSpeed`)

**GUI controls:**

| Control | Type | Description |
|---------|------|-------------|
| Fly | Toggle | Enables/disables BodyVelocity flight |
| NoClip | Toggle | Enables/disables collision bypass |
| Infinite Jump | Toggle | Enables/disables unlimited jumps |

**Respawn handling:** `lp.CharacterAdded` listener re-applies walk speed and re-enables fly if active.

---

### `modules/utility.lua` — Anti-AFK, Codes, Rewards

Anti-detection and reward automation.

**Anti-AFK:**
- Primary: Uses `getconnections(lp.Idled)` to disable idle detection
- Fallback: `VirtualUser:CaptureController()` + `ClickButton2()` on `lp.Idled` event
- Auto-starts on load if `config.AntiAfk.Enabled = true`

**Anti Gameplay Pause:**
- Calls `StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, true)`
- Blocks Roblox pause notifications

**Codes Redemption:**
- Maintains a list of known Deep Fishing codes (10 codes)
- Finds `RedeemCode`/`Redeem`/`Code` remote in `ReplicatedStorage`
- Iterates codes with 0.5s delay between attempts
- Tracks redeemed vs skipped counts
- Updates `gui.Rewards.CodesStatusLabel`

**Reward Claiming (manual + auto):**

| Reward | Remote Name | Auto Interval | GUI Button |
|--------|-------------|---------------|------------|
| Playtime Gift | `ClaimPlaytime` | 1 hour | Claim Playtime Gift |
| Next Day Reward | `ClaimNextDay` | 1 hour | Claim Next Day Reward |
| Group Reward | `ClaimGroup` | 1 hour | Claim Group Reward |
| Free Rewards | `ClaimFreeReward` | 1 hour | Toggle in Fishing tab |
| Big Fish | `ClaimBigFish` | 5 minutes | Toggle in Fishing tab |

**GUI controls:**

| Control | Tab | Type | Description |
|---------|-----|------|-------------|
| Anti AFK | Player | Toggle | Enable/disable idle prevention |
| Anti Gameplay Pause | Player | Toggle | Enable/disable pause block |
| Redeem All Codes | Rewards | Button | One-shot code redemption |
| Claim Playtime Gift | Rewards | Button | One-shot claim |
| Claim Next Day Reward | Rewards | Button | One-shot claim |
| Claim Group Reward | Rewards | Button | One-shot claim |
| Auto Claim Free Rewards | Fishing | Toggle | Hourly auto-claim loop |
| Auto Claim Big Fish | Fishing | Toggle | 5-minute auto-claim loop |
| Auto Claim Playtime Gift | Fishing | Toggle | Hourly auto-claim loop |
| Auto Claim Next Day Reward | Fishing | Toggle | Hourly auto-claim loop |
| Auto Claim Group Reward | Fishing | Toggle | Hourly auto-claim loop |

---

## Configuration (`config.lua`)

All feature defaults live in `config.lua`. Key sections:

```lua
return {
    Window = { Title, Subtitle, Size },
    Build = "v1.0",
    Game = { PlaceId = 5125748, GameName = "Deep Fishing" },
    Keys = { HideUI = Enum.KeyCode.K, ToggleFishing = Enum.KeyCode.F },
    Theme = { accent, bg, panel, text, success, danger, warn, ... },
    AutoSell = { Interval = 300, Rarities = {...} },
    AutoDelete = { Rarities = { Common = true, ... } },
    AutoBuy = { BuyBestBait, BuyBestRod, BuyUpgrades, UseBestBaitNow },
    Fishing = { AutoPerfect, InstantCollect, AutoStopWhenEmpty, CollectRarities, CollectMutations },
    Movement = { FlySpeed = 50, WalkSpeed = 16 },
    Rewards = { AutoClaimFreeRewards, AutoClaimBigFish, AutoClaimPlaytimeGift, ... },
    AntiAfk = { Enabled = true },
    ComponentDefaults = { CornerRadius = UDim.new(0, 10), PressScale = 0.97 },
}
```

---

## Persistent Settings

All toggle states, movement values, and stats are saved to `DeepFishing_Settings.json` using the executor file API (`writefile`/`readfile`).

| Button | Action |
|--------|--------|
| **Save Settings** | Saves all current toggles and values to disk |
| **Load Settings** | Restores saved settings and updates all GUI toggles |
| **Reset to Defaults** | Deletes the settings file (reload script to apply defaults) |

**What gets persisted:**
- All auto-fish, auto-sell, auto-buy, movement, reward, and anti-AFK toggles
- Fly speed and walk speed values
- Fish caught count and total earnings stats

**Auto-load:** Settings are automatically loaded from disk on script startup.

---

## Hotkeys

| Key | Action |
|-----|--------|
| `K` | Minimize / Restore UI |
| `WASD` | Fly horizontal movement (when fly enabled) |
| `Space` | Fly up |
| `LeftShift` | Fly down |

---

## Architecture

Follows the same `ctx` (context) pattern as all XRoblox projects:

```
bootstrap.lua  →  main.lua  →  config.lua
                              →  LyraHub kit (shared, button, toast, updatecheck)
                              →  gui.lua(config, components)  →  gui object
                              →  core.lua(gui, config)         →  ctx table
                              →  modules/autofish.lua(ctx)
                              →  modules/autosell.lua(ctx)
                              →  modules/autobuy.lua(ctx)
                              →  modules/movement.lua(ctx)
                              →  modules/utility.lua(ctx)
```

**State flow:**
- `core.lua` creates `ctx` with all mutable flags and utility functions
- Each module receives `ctx`, reads/writes flags, binds GUI events
- `ctx.connections[]` tracks all signal connections for cleanup
- `ctx.destroyed` flag checked in every loop for graceful shutdown
- `_G.__DeepFishing_Destroy` exposed for global unload

**Remote discovery pattern:**
All modules use a `findRemote(name)` helper that searches `ReplicatedStorage` top-level and subfolders, with fallback name variants (e.g., `BuyBait` or `BuyBestBait`).

---

## Credits

Built on **LyraHub** UI framework. Part of the [XRoblox](https://github.com/LyraTheGuy/XRoblox) automation suite.
