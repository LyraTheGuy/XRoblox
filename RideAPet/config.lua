-- RideAPet/config.lua
-- Config table only (NOT a function wrapper)

return {
    Gate = {
        Password = "UklERVBBIFBFVA==", -- base64 encoded password
    },

    Keys = {
        ToggleRide = Enum.KeyCode.F,
        HideUI = Enum.KeyCode.K,
        PickPosition = Enum.KeyCode.P,
        ESP = Enum.KeyCode.E,
        Teleport = Enum.KeyCode.T,
    },

    Safety = {
        AdminDetector = true,
        NotifyOnStaffJoin = true,
    },

    Window = {
        Title = "LyraHub",
        Subtitle = "Ride A Pet Automation",
        Size = Vector2.new(620, 420),
    },

    -- Build marker compared by the update-checker against the live raw config
    Build = "v1.0",

    Ride = {
        DefaultSpeed = 50,
        MinSpeed = 10,
        MaxSpeed = 200,
        AutoMount = true,
        PreferredPet = "", -- leave empty for any pet
    },

    Egg = {
        -- Rarity tiers (highest → lowest)
        Rarities = {
            "Divine",
            "Mythical",
            "Legendary",
            "Epic",
            "Rare",
            "Uncommon",
            "Common",
        },
        -- Only collect eggs matching these rarities (empty = collect ALL)
        WhitelistRarities = {
            "Divine",
            "Mythical",
            "Legendary",
            "Epic",
        },
        -- Blacklist specific pet names (never collect these)
        BlacklistPets = {},
        -- Collect interval in seconds between each egg grab
        CollectInterval = 0.5,
        -- Auto-TP to egg spawn locations before collecting
        AutoTPToEggs = true,
        -- Max eggs before warning (0 = unlimited)
        MaxEggs = 0,
    },

    Theme = {
        accent = Color3.fromRGB(155, 89, 255),
        accent2 = Color3.fromRGB(200, 160, 255),
        accentDark = Color3.fromRGB(110, 60, 200),
        accentGlow = Color3.fromRGB(180, 130, 255),
        glow = Color3.fromRGB(180, 130, 255),
        bg = Color3.fromRGB(12, 10, 20),
        bg2 = Color3.fromRGB(18, 15, 30),
        panel = Color3.fromRGB(22, 20, 38),
        panel2 = Color3.fromRGB(30, 27, 50),
        sidebar = Color3.fromRGB(16, 13, 28),
        topbar = Color3.fromRGB(20, 17, 34),
        text = Color3.fromRGB(240, 235, 255),
        dim = Color3.fromRGB(130, 120, 170),
        faint = Color3.fromRGB(100, 92, 140),
        divider = Color3.fromRGB(42, 38, 66),
        success = Color3.fromRGB(80, 220, 140),
        danger = Color3.fromRGB(255, 80, 100),
        warn = Color3.fromRGB(255, 200, 80),
        tp = Color3.fromRGB(100, 180, 255),
        beam = Color3.fromRGB(255, 130, 90),
    },

    ThemePresets = {
        Color3.fromRGB(0,170,255),
        Color3.fromRGB(132,97,255),
        Color3.fromRGB(255,96,140),
        Color3.fromRGB(67,214,125),
        Color3.fromRGB(255,170,0),
        Color3.fromRGB(255,120,84),
    },

    Webhook = {
        Enabled = false,
        URL = "",
        LogRarities = {"Legendary"},
    },

    ComponentDefaults = {
        CornerRadius = UDim.new(0, 10),
        PressScale = 0.97,
    },
}
