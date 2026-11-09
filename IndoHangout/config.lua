-- IndoHangout/config.lua
-- Central configuration: theme, window, feature defaults, remote paths, profiles.
-- Must return a plain table. No logic here.

-- ----------------------------------------------------------------------------
-- THEME — Winter (Sangaskara) palette: black-navy surfaces, snow-white and
-- Sangaskara blue accents. Matches IndoVoice's config.Theme palette.
-- ----------------------------------------------------------------------------
local THEME = {
    bg        = Color3.fromRGB(7, 10, 16),
    bg2       = Color3.fromRGB(11, 16, 24),
    sidebar   = Color3.fromRGB(5, 8, 13),
    topbar    = Color3.fromRGB(10, 15, 22),
    panel     = Color3.fromRGB(15, 21, 31),
    panel2    = Color3.fromRGB(24, 32, 46),
    surface   = Color3.fromRGB(24, 32, 46),
    accent    = Color3.fromRGB(56, 132, 255),
    accent2   = Color3.fromRGB(128, 180, 255),
    accentDark= Color3.fromRGB(20, 48, 96),
    accentGlow= Color3.fromRGB(226, 240, 255),
    text      = Color3.fromRGB(255, 255, 255),
    dim       = Color3.fromRGB(183, 197, 214),
    faint     = Color3.fromRGB(118, 134, 154),
    border    = Color3.fromRGB(36, 50, 72),
    divider   = Color3.fromRGB(36, 50, 72),  -- alias used by the views/components kit
    glow      = Color3.fromRGB(128, 180, 255), -- subtle bloom used by the views/components kit
    success   = Color3.fromRGB(64, 176, 232),
    danger    = Color3.fromRGB(219, 84, 108),
    warn      = Color3.fromRGB(116, 164, 214),
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
        PickaxeRemote = {
            "ReplicatedStorage", "Events", "RemoteEvent", "Pickaxe",
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
        SellCategory = "Sell All",
        SellCategories = {
            "Sell All",
            "All under 50 Kg",
            "All under 400 Kg",
            "All under 600 Kg",
        },
        SellMode = "Count",       -- "Count" (bag size) or "Minute" (interval)
        SellEveryMinutes = 1,     -- used when SellMode == "Minute"
        CooldownBetweenCasts = 1.0,
    },

    -- ------------------------------------------------------------------------
    -- MINING
    -- ------------------------------------------------------------------------
    Mining = {
        AutoMine = false,
        MaxDistance = 12,         -- detection radius; every crystal inside is a candidate
        HitsPerCrystal = 3,       -- clicks per crystal
        HitDelay = 1.5,           -- seconds between those clicks
        StandOffset = 4,          -- studs to stand away from the crystal
        AutoSellCrystals = false,
        SellEveryX = 10,
        SellMode = "Count",       -- "Count" (crystals held) or "Minute" (interval)
        SellEveryMinutes = 1,     -- used when SellMode == "Minute"
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
    -- PASSWORD GATE
    -- ------------------------------------------------------------------------
    -- Password is stored base64-encoded so the plaintext never appears in
    -- source. gate.lua decodes and compares. "UkVMRUFTRQ==" = "RELEASE".
    Gate = {
        Enabled = true,
        Password = "UkVMRUFTRQ==",
        Title = "IndoHangout",
        Subtitle = "Access Gate",
        Footer = "IndoHangout",
    },
}