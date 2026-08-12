# BuildABeehive

Automation toolkit for Build A Beehive on Roblox. It uses the same modular `ctx` pattern as the other projects in this repo, with a shared loader, GUI layer, core state layer, and feature modules.

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

### UI
- Small draggable window
- Separate toggles for Collect, Sell, Aurora deposit, and Buy Seed
- Reusable theme fields from `config.lua`

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
2. `main.lua` loads `config.lua`, `gui.lua`, and `core.lua`
3. `core.lua` creates the shared context table (`ctx`)
4. Each module in `modules/` receives `ctx` and wires one feature

## Usage

Run `bootstrap.lua` with your executor. The GUI appears immediately and each module can be toggled independently.

## Notes

- The plot lookup is based on the local player's `Owner` value, so it does not depend on a fixed plot index.
- The modules are split so each automation path can be maintained independently.
- Action counters persist across reloads via `BuildABeehive_Counters.json` (saved with a 1s throttle as actions happen, plus on close and when Reset is pressed). Use the **Reset** button on the Overview tab to zero them.