-- BuildABeehive/config.lua
-- Config table only (NOT a function wrapper)
-- Uses the LyraHub config shape so the LyraHub component factories work as-is.

return {
    Window = {
        Title = "Build A Beehive",
        Subtitle = "Honey automation · LyraHub UI",
        Size = Vector2.new(620, 420),
    },

    Keys = {
        HideUI = Enum.KeyCode.K,
    },

    Theme = {
        -- Backgrounds
        bg = Color3.fromRGB(16, 16, 22),
        bg2 = Color3.fromRGB(22, 22, 30),
        panel = Color3.fromRGB(24, 24, 32),
        panel2 = Color3.fromRGB(32, 32, 42),
        sidebar = Color3.fromRGB(18, 18, 26),
        topbar = Color3.fromRGB(20, 20, 28),

        -- Text
        text = Color3.fromRGB(235, 235, 245),
        dim = Color3.fromRGB(130, 130, 145),
        faint = Color3.fromRGB(105, 105, 122),

        -- Accents (cyan identity)
        accent = Color3.fromRGB(0, 170, 255),
        accent2 = Color3.fromRGB(90, 200, 255),
        glow = Color3.fromRGB(90, 200, 255),
        divider = Color3.fromRGB(38, 38, 50),

        -- Semantic
        success = Color3.fromRGB(80, 220, 140),
        danger = Color3.fromRGB(255, 80, 100),
        warn = Color3.fromRGB(255, 200, 80),
    },

    ComponentDefaults = {
        CornerRadius = UDim.new(0, 10),
        PressScale = 0.97,
    },
}
