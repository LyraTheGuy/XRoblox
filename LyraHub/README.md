# LyraHub — Roblox UI Kit

Production-ready Roblox GUI framework with a clean Model-View-Controller architecture. Dark theme with cyan accents.

## Components

- **Buttons** — Rounded with hover/press animations
- **Toggles** — Sliding switch with smooth transitions
- **Dropdowns** — Animated list with chevron rotation
- **Sliders** — Horizontal and vertical with drag handling
- **Keybind** — Key capture picker with recording indicator
- **Text Input** — Placeholder, focus highlight, clear button
- **Color Picker** — HSV popup with hex readout
- **Toast** — Notification popups
- **Window** — Draggable with minimize/hide controls

## File Structure

```
├── bootstrap.lua       # Loader
├── main.lua            # Composition root
├── config.lua          # Theme and defaults
├── models/
│   └── state.lua       # Observable store (set/get/onChange)
├── views/
│   ├── main.lua        # Window chrome and tabs
│   └── components/
│       ├── shared.lua      # Utilities (corner/stroke/glow/gradient/shadow)
│       ├── button.lua      # Button factory
│       ├── toggle.lua      # Toggle factory
│       ├── dropdown.lua    # Dropdown factory
│       ├── slider.lua      # Slider factory
│       ├── keybind.lua     # Keybind factory
│       ├── textinput.lua   # Text input factory
│       ├── colorpicker.lua # Color picker factory
│       ├── toast.lua       # Toast factory
│       └── updatecheck.lua # Version checker
├── controllers/
│   ├── main.lua        # Window drag, minimize, hide keybind
│   └── demo.lua        # Example bindings
└── README.md
```

## Usage

Import components and state store into your project:

```lua
local kit = require(lyrahub_url)
local model = kit.model
local components = kit.components

local btn = components.button({ ... })
model.set("key", value)
model.onChange("key", function(newVal) ... end)
```


Paste `bootstrap.lua` into your executor. It fetches everything from this repo
(branch `staging`) and runs the composition root. No other files need to be
touched.

## 🧠 How the MVC layers talk

| Layer | Knows | Does |
|---|---|---|
| **Model** (`models/state.lua`) | nothing | stores values, notifies watchers on change |
| **View** (`views/`) | `config` + component factories | builds UI, exposes handles via `view.*` |
| **Controller** (`controllers/`) | `view` + `model` + `config` | wires events, updates the view when the model changes |

The window itself is model-driven: the main controller reacts to
`visible` / `minimized` / `uiOpen` keys, so the demo controller can close the
whole UI with a single `model.set("uiOpen", false)`.

## 🎛 Component API

Every component factory takes `(config, shared)` and returns a function
`(opts) -> view`. The returned view exposes a small controller-facing API:

| Component | Opts (common: `Parent, Position, Size, AnchorPoint, ZIndex`) | View API |
|---|---|---|
| `button` | `Text, TextColor, Color, BackgroundTransparency, HoverColor, CornerRadius, Glow, GlowTransparency, PressScale, OnClick` | `Instance, SetText, SetEnabled` |
| `toggle` | `Default, OnColor, OffColor, KnobOnColor, KnobOffColor, KnobSize, KnobPad, OnChanged` | `Instance, Get, Set, Toggle, OnChanged` |
| `dropdown` | `Items, Default, ItemHeight, OnSelected` | `Instance, Header, GetSelected, SetSelected, Close, OnSelected` |
| `slider` | `Orientation ("horizontal"/"vertical"), Default (0..1), TrackThickness, FillColor, KnobSize, OnChanged` | `Instance, Knob, Get, Set, OnChanged` |
| `keybind` | `Default (Enum.KeyCode), OnChanged` | `Instance, Get, Set, Cancel, OnChanged` |
| `textinput` | `Default, Placeholder, OnChanged` | `Instance, Box, GetText, SetText, OnChanged` |
| `colorpicker` | `Default (Color3), OnChanged` | `Instance, Swatch, Get, Set, Close, OnChanged` |

`Set(..., false)` / `SetSelected(..., false)` suppress the change notification —
use it for model→component sync to avoid echo loops.

## 🎨 Customizing

- **Theme**: edit every color/radius in `config.lua → Theme`.
- **Window size / title / hide key**: `config.lua → Window` and `Keys`.
- **Demo defaults**: `config.lua → Defaults` is the single source of truth for
  both the store and the initial component states — change it once.
- **New accent presets**: add an entry to `AccentOrder` + `Accents`.
- **New component**: drop a factory in `views/components/`, register it in
  `main.lua`'s component loop, use it in `views/main.lua`.
- **New tab**: add a name to `TabOrder` in `views/main.lua`, build a page, and
  wire behavior in a controller.
- **Rebindable UI key**: set `Defaults.keybind` in `config.lua` (or let the user
  change it live on the Input tab — the main controller reads it from the model).
- **Pickers auto-dismiss**: keybind capture and the color popup (with their
  full-screen scrims) close themselves when the window is hidden or minimized.

## ✅ Conventions

- Views never write state; controllers never build UI.
- Every `model.set()` with a changed value notifies watchers — keep sync
  handlers idempotent (`Set(v, false)`).
- All component listeners are `pcall`-wrapped so one bad handler never breaks
  the component.
