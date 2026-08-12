# LyraHub — Modern MVC UI Kit (Roblox)

A modular, production-ready Roblox GUI framework built with a clean
**Model-View-Controller** architecture. Dark-blue/charcoal theme with white and
muted-blue text, black/dark-grey accents, subtle transparency, soft glow and
smooth transitions throughout.

## ✨ Features

- **620×420 window** (IndoVoice-style wide layout) with drag, minimize, hide
  keybind and full teardown
- **Rounded buttons** with hover color-shift + springy press squish (`UIScale`)
- **Toggle switches** with sliding knob + cross-fading track
- **Dropdown menu** with animated height/fade/scale open-close + rotating chevron
- **Horizontal & vertical sliders** with fill track + drag handling
- **Keybind picker** — click to capture with a pulsing REC indicator, Esc or
  click-away cancels, live-rebinds the UI key
- **Text input** — placeholder, focus highlight, clear button, commit on blur
- **Color picker** — HSV popup with gradient hue/sat/val sliders, hex readout and copy-to-clipboard
- Subtle glow strokes, soft drop shadows, gradient backgrounds, live tweens
- **Observable state store** — controllers publish via `model.set()`, views and
  other controllers react via `model.onChange()`

## 📁 Folder structure (MVC)

```
LyraHub/
├── bootstrap.lua          # Tiny loader — paste this into the executor
├── main.lua               # Composition root: builds the dependency graph
├── config.lua             # THEME + window size + demo defaults (single source of truth)
├── models/
│   └── state.lua          # Observable store: set / get / onChange / destroy
├── views/
│   ├── main.lua           # Window chrome + 3 tab pages (pure presentation)
│   └── components/
│       ├── shared.lua     # corner / stroke / glow / gradient / shadow / tween
│       ├── button.lua     # rounded button factory (hover + press animations)
│       ├── toggle.lua     # pill switch factory
│       ├── dropdown.lua   # animated list factory
│       ├── slider.lua     # horizontal/vertical slider factory
│       ├── keybind.lua    # key capture picker factory
│       ├── textinput.lua  # text field factory
│       └── colorpicker.lua# HSV color picker factory
└── controllers/
    ├── main.lua           # Drag, minimize/expand, hide keybind, teardown
    └── demo.lua           # Component ⇄ store bindings, tiles, quick actions
```

## 🚀 Loading

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
