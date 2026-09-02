# XRoblox — Roblox Automation Suite

A collection of modular, production-ready Roblox automation tools built on the LyraHub UI framework.

## Projects

### 🖱️ SilentAutoclick
Universal autoclicker for any Roblox game.

**Features:** Silent clicking via VirtualInputManager, adjustable CPS (1-100), follow cursor or fixed position modes, real-time stats (clicks, CPS, FPS, ping), minimizable window.

**Quick Start:** Run `bootstrap.lua` → Press F to toggle → Adjust CPS slider → Press P for fixed target mode

---

### 🐝 BuildABeehive
Automation suite for Build A Beehive game.

**Features:** Auto collect honey, auto sell, auto deposit aurora, auto buy seeds, persistent stats tracking, live dashboard.

**Quick Start:** Run `bootstrap.lua` → Select features from tabs → Adjust intervals → Press K to hide/show

---

### 🎣 IndoVoice
Comprehensive automation toolkit for IndoVoice.

**Features:** Auto fishing, auto mining with hotspot ESP, gacha automation, rod shop, player ESP, anti-idle, Discord webhook integration, per-rarity filtering, dark/light theme.

**Quick Start:** Run `bootstrap.lua` → Authenticate → Select features → Configure settings


---

### 🎨 LyraHub
Production-ready Roblox UI framework used by all projects.

**Components:** Buttons, toggles, dropdowns, sliders, keybind picker, text input, color picker, toast notifications, draggable windows.

**Architecture:** Model-View-Controller pattern with observable state store, reusable component factories, smooth animations and transitions.

---

## Architecture

All projects share:
- **Modular design** — Feature modules loaded on demand
- **LyraHub UI Kit** — Consistent, polished interface components
- **Shared state management** — Context-based pattern with observable store
- **Configuration layer** — Centralized settings and theme
- **Persistent storage** — Automatic save/load for preferences and stats

## File Organization

```
XRoblox/
├── SilentAutoclick/     # Universal autoclicker
│   ├── bootstrap.lua
│   ├── main.lua
│   ├── config.lua
│   ├── gui.lua
│   ├── core.lua
│   ├── modules/
│   └── README.md
├── BuildABeehive/       # Game-specific automator
│   ├── bootstrap.lua
│   ├── main.lua
│   ├── config.lua
│   ├── gui.lua
│   ├── core.lua
│   ├── modules/
│   └── README.md
├── IndoVoice/           # Comprehensive toolkit
│   ├── bootstrap.lua
│   ├── main.lua
│   ├── config.lua
│   ├── gate.lua
│   ├── gui.lua
│   ├── core.lua
│   ├── modules/
│   └── README.md
├── LyraHub/             # UI framework
│   ├── bootstrap.lua
│   ├── main.lua
│   ├── config.lua
│   ├── models/
│   ├── views/
│   ├── controllers/
│   └── README.md
└── README.md            # This file
```

## Common Patterns

**Loader Pattern:**
1. `bootstrap.lua` — Fetches dependencies from GitHub
2. `main.lua` — Loads config, GUI, core, and modules
3. `config.lua` — Single source of truth for settings/theme
4. `core.lua` — Shared state, services, and helpers
5. `modules/` — Feature implementations

**State Management:**
```lua
local ctx = {
    gui = ...,           -- GUI views
    config = ...,        -- Configuration
    connections = {},    -- Signal connections (auto-cleanup)
}
-- Modules access and modify ctx
```

**UI Components:**
```lua
local button = components.button({ ... })
local toggle = components.toggle({ ... })
local dropdown = components.dropdown({ ... })
-- All components follow LyraHub patterns
```

## Development

Each project is self-contained but can share:
- LyraHub UI components via GitHub link
- Configuration/theme structure
- State management patterns
- Module loading architecture

To extend a project:
1. Add feature module in `modules/`
2. Load in `main.lua` with `loadModule(name)`
3. Return a function `function(ctx)` that uses shared state
4. Access UI views via `ctx.gui`

## License

All projects are proprietary Roblox automation tools.
