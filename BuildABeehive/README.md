# Build A Beehive Automator

Automation toolkit for Build A Beehive on Roblox.

## Features

- **Auto Collect** — Extract honey from all hives in your plot
- **Auto Sell** — Sell honey on a timer
- **Auto Deposit Aurora** — Deposit aurora on demand or loop
- **Auto Buy Seed** — Purchase selected flowers automatically
- **Persistent Stats** — Counter values saved and restored per session
- **Live Dashboard** — FPS, ping, player count, and hive stats

## File Structure

```
├── bootstrap.lua           # Loader
├── main.lua                # Entry point
├── config.lua              # Settings and theme
├── gui.lua                 # UI with tabs (Overview / Actions / Buy)
├── core.lua                # Shared state and remotes
├── modules/
│   ├── auto_collect.lua    # Honey collection
│   ├── auto_sell.lua       # Honey selling
│   ├── auto_deposit_aurora.lua  # Aurora deposits
│   └── auto_buy_seed.lua   # Seed purchasing
└── README.md
```

## Usage

1. Run `bootstrap.lua`
2. Select features from tabs
3. Adjust intervals and settings
4. Press `K` to hide/show UI


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