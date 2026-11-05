# IndoHangout

Modern-minimalist automation suite for Roblox fishing, mining, and player
movement. Built on the `IndoVoice` architecture: a single shared `ctx` context,
modular feature loaders, and a clean teardown path.

## Quick Start

Load `bootstrap.lua` from an executor with the project hosted at a URL:

```lua
loadstring(game:HttpGet("http://localhost/IndoHangout/bootstrap.lua"))()
```

`bootstrap.lua` fetches `main.lua`, which in turn fetches and compiles the rest
of the project from the same base URL.

## File Structure

```text
IndoHangout/
├── bootstrap.lua        Loader: fetches main.lua, passes BASE_URL via `...`
├── main.lua             Orchestrator: guard, config, gui, core, modules
├── config.lua           Theme, remotes, feature defaults, profile settings
├── session.lua          Lightweight key/value persistence backend
├── core.lua             Shared ctx: state, bind(), cleanup engine, destroyAll
├── gui.lua              UI factory: dark minimalist interface + components
└── modules/
    ├── utils.lua        Generic helpers (resolve, tools, CFrame serialise)
    ├── fishing.lua      Auto fish, streak protection, fish selling, locked spot
    ├── mining.lua       Auto mine, sell crystals
    ├── misc.lua         Fly, WalkSpeed, Noclip
    └── settings.lua     JSON profiles: save / load / delete / autoload
```

## Architecture

1. **`bootstrap.lua`** — fetches `main.lua`, runs it with the project `BASE_URL`.
2. **`main.lua`** — guards against duplicate runs, fetches `config.lua`,
   builds the GUI and `ctx`, then loads each feature module in order and calls
   its `Init()`. On manual unload it releases the global run flag.
3. **`core.lua`** — creates a shared `ctx` table with all mutable state,
   `bind()` connection tracking, a cleanup registry, and `destroyAll()` which:
   - flips every feature flag off,
   - calls each feature's `stopAll()`,
   - restores the humanoid and releases simulated mouse buttons,
   - runs registered cleanup handlers in reverse order,
   - disconnects all tracked connections,
   - destroys the ScreenGui and clears `_G` guards.
4. **`gui.lua`** — builds the interface: title bar, collapsible sidebar, five
   tabs (About, Fishing, Mining, Misc, Settings), shared component builders
   (toggle, slider, dropdown, textbox, button). Duplicate-GUI guard via
   `_G.__IndoHangout_Gui`.
5. **Feature modules** — each returns an instance table with `Init`,
   `Start`, `Stop`, `Destroy`, plus public setters used by the settings module
   and by the GUI. Every module registers a cleanup handler.
6. **`settings.lua`** — collects the live config into a serialisable table,
   writes JSON profiles to `IndoHangout/Profiles/`, applies loaded profiles to
   the live modules, and restores an autoload profile on startup.

## Features

### Fishing
- **Auto Fish** — equips a rod, casts, waits for the `Reeling` minigame, and
  clicks to catch.
- **Streak Protection** — watches the catch progress bar and clicks harder when
  progress dips below the configured threshold.
- **Auto Sell Fish** — sells through the `SellFish` RemoteFunction once the
  inventory reaches `SellAtCount`.
- **Protected Fish** — a list of fish names that are never sold (persisted in
  profiles).
- **Locked Spot** — saves/restores a CFrame so the character repositions before
  each cast.

### Mining
- **Auto Mine** — targets the nearest crystal within `Max Distance` and lands
  three hits (via ProximityPrompt or a simulated click). Only interacts when
  physically close; no teleport cheating.
- **Auto Sell Crystals** — sells via the `SellCrystal` RemoteFunction every
  `Sell Every X` crystals, with a configurable cooldown and category
  (Sell All / under 50 / 400 / 600 Kg).

### Misc
- **Fly** (camera-relative, WASD + Space/Ctrl), **WalkSpeed**, **Noclip**.
  State re-applies after respawn and is fully restored on unload.

### Settings
- Save / Load / Delete JSON profiles, Refresh the list, and set an autoload
  profile applied after the modules initialise.

## Remote / Path References

Configured in `config.lua` under `Paths`:

- `ReplicatedStorage.Events.RemoteEvent.Rod`
- `ReplicatedStorage.Events.RemoteFunction.SellFish`
- `ReplicatedStorage.Events.RemoteFunction.SellCrystal`
- `PlayerGui.Reeling.MainFrame.Frame`
- `PlayerGui.SellFish.MainFrame.SellList`
- `Workspace.MapContent.Crystals`

## Unloading

The close button (✕) and the module stop paths all funnel into
`ctx.destroyAll`, which stops loops, restores the humanoid, releases input,
unloads modules, disconnects connections, and destroys the GUI. Re-executing
the script immediately starts a fresh copy.