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
├── views/
│   ├── main.lua         Window chrome, sidebar tabs, pages, component adapter
│   └── components/      Reusable UI kit (LyraHub pattern)
│       ├── shared.lua   corner / stroke / glow / shadow / tween primitives
│       ├── button.lua   rounded button + hover + press squish
│       ├── toggle.lua   pill toggle switch
│       ├── dropdown.lua animated dropdown (with runtime SetItems)
│       ├── slider.lua   horizontal/vertical slider
│       └── textinput.lua rounded text input + clear button
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
4. **`views/main.lua`** — builds the interface (LyraHub-style view layer):
   a full-screen plain `Frame` canvas (not a CanvasGroup — that blurred text and
   clipped the window when dragged), drop shadow, top bar with window buttons,
   pill sidebar tabs (About, Fishing, Mining, Misc, Settings), five scrollable
   pages, a status strip, and the component adapter consumed by feature modules.
   Components live in `views/components/` and are fetched and wired by
   `main.lua`. Duplicate-GUI guard via `_G.__IndoHangout_Gui`.
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
- **Selling** — `Sell Fish Now` plus a **Sell Category** dropdown
  (Sell All / under 50 / 400 / 600 Kg). It uses the same call shape as crystal
  selling — `SellFishRemote:InvokeServer("SellFish", category)` — only the remote
  differs. If that invoke fails it falls back to sweeping the open `SellList`
  one fish at a time.
- **Auto Sell Fish** — picks a `Sell Mode`: **Per Count** (sell once the bag
  reaches N fish) or **Per Minute** (sell on a time interval). The rate is a text
  input, not a slider, and the row label switches between
  `Sell Rate (count)` and `Sell Every (min)` to match the mode. Setters:
  `Fishing.setSellMode`, `Fishing.setSellRate`, `Fishing.getSellRate`.
- **Protected Fish** — a list of fish names that are never sold (persisted in
  profiles, honored by the `SellList` fallback).
- **Locked Spot** — saves/restores a CFrame so the character repositions before
  each cast.

### Mining
- **Auto Mine** — one cycle is: equip the **best pickaxe** in the backpack, tween
  the character to a random crystal inside `Max Distance`, aim the camera at it,
  then mine it with `ReplicatedStorage.Events.RemoteEvent.Pickaxe` by firing
  `Pickaxe:FireServer("Hit")` `HitsPerCrystal` times, `HitDelay` seconds apart
  (3 hits, 1.5s by default). There is no screen clicking — the remote is the only
  input the game needs. Detection scans every crystal in radius (folder children
  and one level of nested folders), not just the nearest one, and uses the
  average position of visible parts so hitboxes cannot skew the distance.
- **Only real crystals are targeted** — a candidate must contain an `HP` child
  (or `HP` attribute), which the folder's decorations, anchors and effects do not
  have. Crystals whose `HP` value has dropped to 0 are treated as depleted and
  skipped.
  The move is a CFrame tween, so the character glides rather than teleports.
- **Scan Crystals** — a button that logs how many crystals the folder holds, how
  many are in range, and the nearest distance, so an empty Auto Mine is easy to
  diagnose.
- **Pickaxe selection** — `(Auto = best)` ranks tools by tier word in the name
  (Mythic → Legendary → Epic → Rare …), then a number in the name, then
  `Level` / `Power` / `Tier` / `Damage` attributes. Choosing a specific pickaxe in
  the dropdown pins it; if it leaves the backpack the module falls back to best.
  This mirrors the automatic rod equip in Fishing.
- **Auto Sell Crystals** — sells via the `SellCrystal` RemoteFunction with a
  configurable cooldown and category (Sell All / under 50 / 400 / 600 Kg), on the
  same **Per Count** / **Per Minute** mode switch as fishing (text-input rate).
  Setters: `Mining.setSellMode`, `Mining.setSellRate`, `Mining.getSellRate`.

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