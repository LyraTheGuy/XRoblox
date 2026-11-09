-- IndoVoice/config.lua
-- Config table only (NOT a function wrapper)

-- ============================================================================
-- WINTER THEME PALETTE (centralized)
-- ============================================================================
-- Sangaskara winter look: near-black navy backgrounds, snow-white accents and
-- Sangaskara blue highlights. Every UI file must read colors from
-- config.Theme (never hardcode them in gui.lua / core.lua / modules).
--
-- The variant tables below are the single source of truth for the palette.
-- `Theme` is the active palette the whole UI reads; `ThemeVariants` holds the
-- alternatives the Settings theme buttons switch between.
-- ============================================================================
local WINTER_FROST = {
    Background = Color3.fromRGB(7, 10, 16),    -- midnight black-navy
    Secondary  = Color3.fromRGB(11, 16, 24),   -- raised near-black
    Panel      = Color3.fromRGB(15, 21, 31),   -- deep navy panel
    Surface    = Color3.fromRGB(24, 32, 46),   -- steel-blue surface
    Sidebar    = Color3.fromRGB(5, 8, 13),
    Topbar     = Color3.fromRGB(10, 15, 22),
    Accent     = Color3.fromRGB(56, 132, 255),  -- Sangaskara blue
    AccentSoft = Color3.fromRGB(128, 180, 255),
    AccentDark = Color3.fromRGB(20, 48, 96),
    Snow       = Color3.fromRGB(226, 240, 255), -- snow-white accent
    Ice        = Color3.fromRGB(64, 176, 232),  -- success / ON state
    Frost      = Color3.fromRGB(116, 164, 214), -- warn / waiting
    Danger     = Color3.fromRGB(219, 84, 108),  -- errors and close
    Text       = Color3.fromRGB(255, 255, 255),
    SubText    = Color3.fromRGB(183, 197, 214),
    Faint      = Color3.fromRGB(118, 134, 154),
    Border     = Color3.fromRGB(36, 50, 72),
    Bone       = Color3.fromRGB(214, 232, 255),
    Beam       = Color3.fromRGB(140, 196, 255),
}

-- Brighter "Snow" variant used by the alternate theme button (same winter
-- palette: steel-blue surfaces with brighter ice accents).
local WINTER_SNOW = {
    Background = Color3.fromRGB(13, 18, 27),
    Secondary  = Color3.fromRGB(18, 26, 38),
    Panel      = Color3.fromRGB(24, 33, 48),
    Surface    = Color3.fromRGB(34, 46, 66),
    Sidebar    = Color3.fromRGB(9, 13, 20),
    Topbar     = Color3.fromRGB(16, 23, 34),
    Accent     = Color3.fromRGB(96, 166, 255),
    AccentSoft = Color3.fromRGB(160, 206, 255),
    AccentDark = Color3.fromRGB(30, 72, 136),
    Snow       = Color3.fromRGB(245, 250, 255),
    Ice        = Color3.fromRGB(110, 208, 246),
    Frost      = Color3.fromRGB(146, 190, 230),
    Danger     = Color3.fromRGB(228, 102, 124),
    Text       = Color3.fromRGB(255, 255, 255),
    SubText    = Color3.fromRGB(198, 212, 230),
    Faint      = Color3.fromRGB(142, 160, 182),
    Border     = Color3.fromRGB(54, 76, 108),
    Bone       = Color3.fromRGB(232, 244, 255),
    Beam       = Color3.fromRGB(178, 216, 255),
}

-- Maps a palette variant to the flat key set the UI historically reads
-- (lowercase) plus the documented capitalized aliases. Keeping both means no
-- existing module has to change how it looks colors up.
local function toTheme(v)
    return {
        -- Documented (capitalized) theme aliases
        Background = v.Background,
        Panel      = v.Panel,
        Accent     = v.Accent,
        Gold       = v.Snow, -- snow-white accent (key name kept for compatibility)
        Text       = v.Text,
        SubText    = v.SubText,
        Border     = v.Border,
        Secondary  = v.Secondary,

        -- Keys read across the existing codebase
        accent = v.Accent,
        accent2 = v.AccentSoft,
        accentDark = v.AccentDark,
        accentGlow = v.Snow,
        glow = v.AccentSoft,
        bg = v.Background,
        bg2 = v.Secondary,
        panel = v.Panel,
        panel2 = v.Surface,
        surface = v.Surface,
        sidebar = v.Sidebar,
        topbar = v.Topbar,
        text = v.Text,
        dim = v.SubText,
        faint = v.Faint,
        divider = v.Border,
        border = v.Border,
        success = v.Ice,
        danger = v.Danger,
        warn = v.Frost,
        tp = v.Bone,
        beam = v.Beam,
    }
end

return {
    Gate = {
        Password = "SVRTSEFMTE9XRUVOISEh", -- base64 encoded password
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
    Build = "Winter Version",

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
    Theme = toTheme(WINTER_FROST),

    -- Theme buttons in Settings switch the live Theme between these variants.
    -- "Dark"/"Ember" are legacy aliases so profiles saved before the winter
    -- makeover still restore the matching palette.
    ThemeVariants = {
        Frost = toTheme(WINTER_FROST),
        Snow = toTheme(WINTER_SNOW),
        Dark = toTheme(WINTER_FROST), -- legacy alias -> Frost
        Ember = toTheme(WINTER_SNOW), -- legacy alias -> Snow
    },

    -- Snow/ice swatches used by the Players tab beam + ESP colour pickers.
    ThemePresets = {
        Color3.fromRGB(255, 255, 255),
        Color3.fromRGB(226, 240, 255),
        Color3.fromRGB(128, 180, 255),
        Color3.fromRGB(56, 132, 255),
        Color3.fromRGB(64, 176, 232),
        Color3.fromRGB(20, 48, 96),
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
