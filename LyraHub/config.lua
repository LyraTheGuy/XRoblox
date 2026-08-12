-- LyraHub/config.lua
-- Model layer: theme palette + window/default settings.
--
-- LyraHub UI kit uses a very dark blue / charcoal palette, white and muted
-- blue text, and black/dark-grey accents with subtle transparency and glow.

local accentColor = Color3.fromRGB(118, 140, 185) -- shared by Theme + Defaults.tint

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
        -- Backgrounds (very dark blue / charcoal grey)
        bg = Color3.fromRGB(9, 11, 17),
        bg2 = Color3.fromRGB(13, 16, 24),
        panel = Color3.fromRGB(17, 20, 30),
        panel2 = Color3.fromRGB(23, 27, 39),
        sidebar = Color3.fromRGB(11, 13, 20),
        topbar = Color3.fromRGB(12, 15, 23),

        -- Text (white / muted dark blue)
        text = Color3.fromRGB(242, 246, 255),
        dim = Color3.fromRGB(150, 158, 182),
        faint = Color3.fromRGB(108, 116, 140),

        -- Accents (black / dark grey with subtle glow)
        accent = accentColor,
        accent2 = Color3.fromRGB(168, 188, 230),
        glow = Color3.fromRGB(140, 165, 215),
        divider = Color3.fromRGB(34, 40, 56),

        -- Semantic colors
        success = Color3.fromRGB(110, 220, 160),
        danger = Color3.fromRGB(255, 110, 120),
        warn = Color3.fromRGB(240, 190, 90),
    },

    -- Demo defaults — single source of truth: the model seeds from here and
    -- the view builds every component with the matching initial state.
    Defaults = {
        enabled = true,
        notifications = true,
        bold = false,
        accent = "Steel",
        scale = 0.7,
        glow = 0.6,
        opacity = 1,
        keybind = Enum.KeyCode.K, -- UI toggle key (also config.Keys.HideUI)
        username = "Player",
        tint = accentColor, -- custom accent color
    },

    -- Accent presets used by the dropdown demo (ordered for display).
    AccentOrder = { "Steel", "Ice", "Violet", "Amber" },
    Accents = {
        Steel = Color3.fromRGB(118, 140, 185),
        Ice = Color3.fromRGB(120, 190, 220),
        Violet = Color3.fromRGB(165, 130, 220),
        Amber = Color3.fromRGB(230, 170, 90),
    },

    ComponentDefaults = {
        CornerRadius = UDim.new(0, 10),
        PressScale = 0.97,
    },
}
