# BuildABeehive

Automation toolkit for Build A Beehive on Roblox. It uses the same modular `ctx` pattern as the other projects in this repo, with a shared loader, GUI layer, core state layer, and feature modules. The UI is built with the **LyraHub UI kit** (shared primitives + the `button` and `textinput` component factories) fetched from the same repo/branch.

## Features

### Auto Collect
- Extracts honey from every hive in the player's plot
- Detects the local player's plot through the `Owner` value instead of a fixed index

### Auto Sell
- Fires the honey sell remote on a timer
- Uses a dedicated toggle in the GUI

### Auto Deposit Aurora
- Fires the aurora deposit remote on demand and on a loop while enabled

### Auto Buy Seed
- Buys every checked flower from a checkbox list on an interval (default every 2 minutes)
- Select All / Clear All buttons; the selected list lives in `ctx.selectedFlowers`

### UI (LyraHub kit)
- IndoVoice-style window with sidebar tabs (Overview / Actions / Buy)
- Rounded buttons with hover/press animations, gradient background, glow stroke, soft drop shadow
- LyraHub `textinput` fields for collect/sell/aurora/buy intervals and the flower id (commit on focus-lost)
- Live stats (FPS, ping, player count, hives) + per-action counters on the main window *and* the minimized panel
- Counter values persist across reloads (`BuildABeehive_Counters.json`, 1s save throttle) with a **Reset** button
- Drag the window by its header; the shadow follows; minimize to a compact pill

## File Structure

```
BuildABeehive/
├── bootstrap.lua        # Tiny loader (fetches from GitHub)
├── main.lua             # Entry point — loads config, gui, core, then modules
├── config.lua           # Shared theme and key settings
├── gui.lua              # Honey automation UI
├── core.lua             # Shared remotes, state, helpers, and cleanup
├── modules/
│   ├── auto_collect.lua        # Auto Collect feature
│   ├── auto_sell.lua           # Auto Sell feature
│   ├── auto_deposit_aurora.lua # Auto Deposit Aurora feature
│   └── auto_buy_seed.lua       # Auto Buy Seed feature
└── README.md             # This file
```

## Architecture

The project follows the same loader pattern used by the other folders in this repository:

1. `bootstrap.lua` resolves the raw GitHub URL and launches `main.lua`
2. `main.lua` derives the `LyraHub/` URL from its own and fetches the kit's `shared` + `button` + `textinput` factories
3. `main.lua` loads `config.lua`, builds the GUI, then `core.lua`
4. `core.lua` creates the shared context table (`ctx`)
5. Each module in `modules/` receives `ctx` and wires one feature

`core.lua` talks to the LyraHub `textinput` views through the component API (`GetText` / `SetText(v, false)` / `OnChanged` / `.Box:IsFocused()`), so programmatic writes never echo back into `OnChanged`.

## Usage

Run `bootstrap.lua` with your executor. The GUI appears immediately and each module can be toggled independently.

## Notes

- The plot lookup is based on the local player's `Owner` value, so it does not depend on a fixed plot index.
- The modules are split so each automation path can be maintained independently.
- Action counters persist across reloads via `BuildABeehive_Counters.json` (saved with a 1s throttle as actions happen, plus on close and when Reset is pressed). Use the **Reset** button on the Overview tab to zero them.