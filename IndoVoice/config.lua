-- IndoVoice/config.lua
-- Config table only (NOT a function wrapper)

-- ============================================================================
-- HALLOWEEN THEME PALETTE (centralized)
-- ============================================================================
-- Premium Halloween look: near-black backgrounds, gold / warm-orange accents,
-- clean white text, subtle gold borders. Every UI file must read colors from
-- config.Theme (never hardcode them in gui.lua / core.lua / modules).
--
-- The variant tables below are the single source of truth for the palette.
-- `Theme` is the active palette the whole UI reads; `ThemeVariants` holds the
-- alternatives the Settings theme buttons switch between.
-- ============================================================================
local HALLOWEEN = {
    Background = Color3.fromRGB(12, 12, 12),   -- deep black
    Secondary  = Color3.fromRGB(18, 18, 18),   -- near-black
    Panel      = Color3.fromRGB(20, 20, 20),   -- dark charcoal panel
    Surface    = Color3.fromRGB(32, 30, 26),   -- very dark warm grey
    Sidebar    = Color3.fromRGB(10, 10, 10),
    Topbar     = Color3.fromRGB(16, 16, 16),
    Accent     = Color3.fromRGB(255, 165, 0),  -- warm orange
    AccentSoft = Color3.fromRGB(255, 190, 90),
    AccentDark = Color3.fromRGB(120, 74, 8),
    Gold       = Color3.fromRGB(255, 205, 80),
    Text       = Color3.fromRGB(255, 255, 255),
    SubText    = Color3.fromRGB(190, 190, 190),
    Faint      = Color3.fromRGB(138, 138, 138),
    Border     = Color3.fromRGB(70, 55, 25),
    Ember      = Color3.fromRGB(210, 95, 55),
    Bone       = Color3.fromRGB(255, 225, 150),
    Beam       = Color3.fromRGB(255, 140, 40),
}

-- Warm "Ember" variant used by the alternate theme button (still inside the
-- Halloween palette: charcoal surfaces with brighter gold accents).
local HALLOWEEN_EMBER = {
    Background = Color3.fromRGB(16, 14, 12),
    Secondary  = Color3.fromRGB(22, 20, 17),
    Panel      = Color3.fromRGB(26, 23, 19),
    Surface    = Color3.fromRGB(38, 33, 26),
    Sidebar    = Color3.fromRGB(14, 12, 10),
    Topbar     = Color3.fromRGB(20, 18, 15),
    Accent     = Color3.fromRGB(255, 180, 40),
    AccentSoft = Color3.fromRGB(255, 200, 110),
    AccentDark = Color3.fromRGB(140, 90, 15),
    Gold       = Color3.fromRGB(255, 215, 100),
    Text       = Color3.fromRGB(255, 255, 255),
    SubText    = Color3.fromRGB(200, 190, 170),
    Faint      = Color3.fromRGB(150, 140, 120),
    Border     = Color3.fromRGB(90, 68, 30),
    Ember      = Color3.fromRGB(220, 105, 60),
    Bone       = Color3.fromRGB(255, 230, 170),
    Beam       = Color3.fromRGB(255, 150, 60),
}

-- Maps a palette variant to the flat key set the UI historically reads
-- (lowercase) plus the documented capitalized aliases. Keeping both means no
-- existing module has to change how it looks colors up.
local function toTheme(v)
    return {
        -- Documented Halloween aliases
        Background = v.Background,
        Panel      = v.Panel,
        Accent     = v.Accent,
        Gold       = v.Gold,
        Text       = v.Text,
        SubText    = v.SubText,
        Border     = v.Border,
        Secondary  = v.Secondary,

        -- Keys read across the existing codebase
        accent = v.Accent,
        accent2 = v.AccentSoft,
        accentDark = v.AccentDark,
        accentGlow = v.Gold,
        glow = v.AccentSoft,
        bg = v.Background,
        bg2 = v.Secondary,
        panel = v.Panel,
        panel2 = v.Surface,
        sidebar = v.Sidebar,
        topbar = v.Topbar,
        text = v.Text,
        dim = v.SubText,
        faint = v.Faint,
        divider = v.Border,
        success = v.Gold,
        danger = v.Ember,
        warn = v.Accent,
        tp = v.Bone,
        beam = v.Beam,
    }
end

return {
    Gate = {
        Password = "T0NUT0JFUkhBTFU=", -- base64 encoded password
        -- Password bypass: after one successful login the session is saved
        -- per place (executor filesystem / getgenv). Rejoins in the SAME
        -- place skip the gate and auto-execute. 0 = never expire.
        SessionTTL = 7 * 24 * 60 * 60, -- 7 days (seconds)
    },

    Keys = {
        ToggleClicker = Enum.KeyCode.F,
        HideUI = Enum.KeyCode.K,
        PickPosition = Enum.KeyCode.P,
        ESP = Enum.KeyCode.E,
    },

    Safety = {
        AdminDetector = true,
        NotifyOnStaffJoin = true,
    },

    Window = {
        Title = "LyraHub",
        Subtitle = "IndoVoice Automation",
        Size = Vector2.new(620, 420), -- wide layout
    },

    -- Version marker compared by the update-checker against the live raw config
    Build = "Spooky Version",

    Clicker = {
        DefaultCPS = 20,
        PositionMode = "pick",
        FixedX = nil,
        FixedY = nil,
    },

    FishZone = {
        Path = workspace:WaitForChild("Main"):WaitForChild("FishingZone"),
        FloatHeight = 10,
        BlacklistThreshold = 2,
        BlacklistedPositions = {
            Vector3.new(-198, 16.5000153, -5079),
            Vector3.new(-629.866821, 19.5, 4640.11377),
            Vector3.new(-625, 16.5000153, -4902),
        },
    },

    -- Auto Fish timing values. Kept here (instead of hardcoded inside
    -- modules/fishing.lua) so they are part of the persisted settings and can
    -- be restored from a saved profile. Defaults match the previous hardcoded
    -- constants exactly, so behaviour is unchanged.
    FishTiming = {
        PreCastDelay = 0.3,
        CastHoldMin = 0.4,
        CastHoldMax = 0.6,
        VerifyCastTimeout = 2.5,
        BaitLandedTimeout = 30,
        MinigameTimeout = 30,
        PostEndDelay = 0.3,
        BreakInterval = 3600, -- 60 min
        BreakDuration = 300,  -- 5 min
    },

    -- ========================================================================
    -- SAVED SETTINGS PROFILES (see modules/SettingsProfiles.lua)
    -- ========================================================================
    Profiles = {
        Folder = "LyraHubProfiles",   -- executor workspace folder
        Format = "LyraHubProfile",    -- on-disk format marker
        Version = 1,                  -- data format version
        MaxNameLength = 24,
        MaxProfiles = 50,
        DefaultName = "Default",
    },

    -- ========================================================================
    -- THEME
    -- ========================================================================
    Theme = toTheme(HALLOWEEN),

    -- Theme buttons in Settings switch the live Theme between these variants.
    ThemeVariants = {
        Dark = toTheme(HALLOWEEN),
        Ember = toTheme(HALLOWEEN_EMBER),
    },

    -- Warm/gold swatches used by the Players tab beam + ESP colour pickers.
    ThemePresets = {
        Color3.fromRGB(255, 165, 0),
        Color3.fromRGB(255, 205, 80),
        Color3.fromRGB(255, 140, 40),
        Color3.fromRGB(210, 95, 55),
        Color3.fromRGB(255, 225, 150),
        Color3.fromRGB(180, 120, 40),
    },

    AutoSell = {
        Interval = 3600,
        Rarities = {
            "Legend",
            "Epic",
            "Rare",
            "Uncommon",
            "Common"
        }
    },

    Webhook = {
        Enabled = false,
        URL = "", -- Paste your Discord webhook URL here
        LogRarities = {"Ancient"}, -- Only log these rarities
        LogSells = true,
    },

    ComponentDefaults = {
        CornerRadius = UDim.new(0, 10),
        PressScale = 0.97,
    },
}
