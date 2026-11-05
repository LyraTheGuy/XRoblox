-- IndoHangout/config.lua
-- Central configuration: theme, window, feature defaults, remote paths, profiles.
-- Must return a plain table. No logic here.

-- ----------------------------------------------------------------------------
-- MODERN MINIMALIST DARK THEME
-- ----------------------------------------------------------------------------
local THEME = {
    bg        = Color3.fromRGB(16, 16, 19),
    bg2       = Color3.fromRGB(20, 20, 24),
    sidebar   = Color3.fromRGB(12, 12, 15),
    topbar    = Color3.fromRGB(20, 20, 24),
    panel     = Color3.fromRGB(22, 22, 27),
    panel2    = Color3.fromRGB(28, 28, 34),
    surface   = Color3.fromRGB(34, 34, 42),
    accent    = Color3.fromRGB(92, 140, 255),
    accent2   = Color3.fromRGB(126, 165, 255),
    accentDark= Color3.fromRGB(42, 72, 145),
    accentGlow= Color3.fromRGB(160, 190, 255),
    text      = Color3.fromRGB(238, 238, 242),
    dim       = Color3.fromRGB(168, 172, 184),
    faint     = Color3.fromRGB(112, 116, 128),
    border    = Color3.fromRGB(46, 48, 58),
    success   = Color3.fromRGB(86, 201, 120),
    danger    = Color3.fromRGB(222, 92, 92),
    warn      = Color3.fromRGB(232, 184, 82),
}

return {
    Window = {
        Title = "IndoHangout",
        Subtitle = "Automation Suite",
        Size = Vector2.new(660, 440),
    },

    Build = "v1.0.0",

    Theme = THEME,
    ComponentDefaults = {
        CornerRadius = UDim.new(0, 8),
        PressScale = 0.97,
    },

    -- ------------------------------------------------------------------------
    -- EXACT REMOTE PATHS / GAME PATH REFERENCES (per project spec)
    -- ------------------------------------------------------------------------
    Paths = {
        RodRemote = {
            "ReplicatedStorage", "Events", "RemoteEvent", "Rod",
        },
        SellFishRemote = {
            "ReplicatedStorage", "Events", "RemoteFunction", "SellFish",
        },
        SellCrystalRemote = {
            "ReplicatedStorage", "Events", "RemoteFunction", "SellCrystal",
        },
        ReelingGui = { "PlayerGui", "Reeling", "MainFrame", "Frame" },
        SellFishGui = { "PlayerGui", "SellFish", "MainFrame", "SellList" },
        CrystalsFolder = { "Workspace", "MapContent", "Crystals" },
    },

    -- ------------------------------------------------------------------------
    -- FISHING
    -- ------------------------------------------------------------------------
    Fishing = {
        AutoFish = false,
        StreakProtection = true,
        StreakThreshold = 0.07,   -- progress at/below this -> streak save
        AutoSellFish = false,
        SellAtCount = 10,
        ProtectedFish = {},       -- fish names that must never be sold
        LockedSpot = nil,         -- CFrame, saved by "Lock Current Spot"
        SellDelay = 0.6,          -- delay between individual sells
        CooldownBetweenCasts = 1.0,
    },

    -- ------------------------------------------------------------------------
    -- MINING
    -- ------------------------------------------------------------------------
    Mining = {
        AutoMine = false,
        MaxDistance = 12,         -- studs between character and crystal
        HitsPerCrystal = 3,
        AutoSellCrystals = false,
        SellEveryX = 10,
        SellCooldown = 3,         -- seconds
        SellCategory = "Sell All",
        SellCategories = {
            "Sell All",
            "All under 50 Kg",
            "All under 400 Kg",
            "All under 600 Kg",
        },
    },

    -- ------------------------------------------------------------------------
    -- MISC (Fly / WalkSpeed / Noclip)
    -- ------------------------------------------------------------------------
    Misc = {
        Fly = false,
        FlySpeed = 50,
        WalkSpeed = 16,
        WalkSpeedEnabled = false,
        Noclip = false,
    },

    -- ------------------------------------------------------------------------
    -- JSON PROFILE SETTINGS
    -- ------------------------------------------------------------------------
    Profiles = {
        Folder = "IndoHangout/Profiles",
        Format = "IndoHangoutProfile",
        Version = 1,
        MaxNameLength = 24,
        MaxProfiles = 50,
        DefaultName = "Default",
    },

    -- ------------------------------------------------------------------------
    -- SESSION (persistent small data: autoload profile name, run markers)
    -- ------------------------------------------------------------------------
    Session = {
        Folder = "IndoHangoutSession",
        TTL = 7 * 24 * 60 * 60,  -- 7 days
    },

    -- ------------------------------------------------------------------------
    -- AUTH / PASSWORD GATE
    -- ------------------------------------------------------------------------
    -- The expected password is XOR-obfuscated as a byte list so the plaintext
    -- never appears in source. main.lua reconstructs it with XorKey and
    -- compares against the text the user enters.
    Auth = {
        Enabled = true,
        XorKey = 0x5A,
        -- "UkVMRUFTRQ==" XOR 0x5A, byte by byte
        TokenBytes = { 15, 49, 12, 23, 8, 15, 28, 14, 8, 11, 103, 103 },
        Hint = "Enter access password",
        MaxAttempts = 5,
    },
}