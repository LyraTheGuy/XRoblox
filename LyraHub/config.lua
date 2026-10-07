-- LyraHub/config.lua
-- Model layer: theme palette + window/default settings.
--
-- Halloween palette: near-black / charcoal backgrounds, gold + warm-orange
-- accents, clean white text and subtle gold borders. No purple / blue / pink /
-- green. This mirrors IndoVoice/config.lua so the shared kit widgets (toast,
-- keybind, update chip) match the main UI.

local accentColor = Color3.fromRGB(255, 165, 0) -- warm orange, shared by Theme + Defaults.tint

return {
    Window = {
        Title = "LyraHub",
        Subtitle = "MVC UI Kit v1.2",
        Size = Vector2.new(620, 420), -- IndoVoice-style wide layout
    },

    -- Build marker compared by the update-checker against the live raw config
    Build = "v1.2",

    Keys = {
        HideUI = Enum.KeyCode.K,
    },

    Theme = {
        -- Backgrounds (near-black / charcoal)
        bg = Color3.fromRGB(12, 12, 12),
        bg2 = Color3.fromRGB(18, 18, 18),
        panel = Color3.fromRGB(20, 20, 20),
        panel2 = Color3.fromRGB(32, 30, 26),
        sidebar = Color3.fromRGB(10, 10, 10),
        topbar = Color3.fromRGB(16, 16, 16),

        -- Text (white / muted grey)
        text = Color3.fromRGB(255, 255, 255),
        dim = Color3.fromRGB(190, 190, 190),
        faint = Color3.fromRGB(138, 138, 138),

        -- Accents (gold / warm orange with subtle glow)
        accent = accentColor,
        accent2 = Color3.fromRGB(255, 190, 90),
        glow = Color3.fromRGB(255, 205, 80),
        divider = Color3.fromRGB(70, 55, 25),

        -- Semantic colors
        success = Color3.fromRGB(255, 205, 80),
        danger = Color3.fromRGB(210, 95, 55),
        warn = Color3.fromRGB(255, 165, 0),
    },

    -- Demo defaults — single source of truth: the model seeds from here and
    -- the view builds every component with the matching initial state.
    Defaults = {
        enabled = true,
        notifications = true,
        bold = false,
        accent = "Gold",
        scale = 0.7,
        glow = 0.6,
        opacity = 1,
        keybind = Enum.KeyCode.K, -- UI toggle key (also config.Keys.HideUI)
        username = "Player",
        tint = accentColor, -- custom accent color
    },

    -- Accent presets used by the dropdown demo (ordered for display). Names are
    -- kept for compatibility; colors are all within the Halloween palette.
    AccentOrder = { "Gold", "Amber", "Ember", "Bone" },
    Accents = {
        Gold = Color3.fromRGB(255, 205, 80),
        Amber = Color3.fromRGB(255, 165, 0),
        Ember = Color3.fromRGB(210, 95, 55),
        Bone = Color3.fromRGB(255, 225, 150),
    },

    ComponentDefaults = {
        CornerRadius = UDim.new(0, 10),
        PressScale = 0.97,
    },
}
