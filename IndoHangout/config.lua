-- IndoHangout/config.lua
-- Central configuration: theme, window, feature defaults, remote paths, profiles.
-- Must return a plain table. No logic here.

-- ----------------------------------------------------------------------------
-- THEME — identical to IndoVoice's Halloween palette (gold/orange on near-black)
-- ----------------------------------------------------------------------------
local THEME = {
    bg        = Color3.fromRGB(12, 12, 12),
    bg2       = Color3.fromRGB(18, 18, 18),
    sidebar   = Color3.fromRGB(10, 10, 10),
    topbar    = Color3.fromRGB(16, 16, 16),
    panel     = Color3.fromRGB(20, 20, 20),
    panel2    = Color3.fromRGB(32, 30, 26),
    surface   = Color3.fromRGB(32, 30, 26),
    accent    = Color3.fromRGB(255, 165, 0),
    accent2   = Color3.fromRGB(255, 190, 90),
    accentDark= Color3.fromRGB(120, 74, 8),
    accentGlow= Color3.fromRGB(255, 205, 80),
    text      = Color3.fromRGB(255, 255, 255),
    dim       = Color3.fromRGB(190, 190, 190),
    faint     = Color3.fromRGB(138, 138, 138),
    border    = Color3.fromRGB(70, 55, 25),
    divider   = Color3.fromRGB(70, 55, 25),  -- alias used by the views/components kit
    glow      = Color3.fromRGB(255, 190, 90), -- subtle bloom used by the views/components kit
    success   = Color3.fromRGB(255, 205, 80),
    danger    = Color3.fromRGB(210, 95, 55),
    warn      = Color3.fromRGB(255, 165, 0),
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