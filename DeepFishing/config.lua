-- DeepFishing/config.lua
-- Configuration table for Deep Fishing automation

return {
    Window = {
        Title = "LyraHub",
        Subtitle = "Deep Fishing Automation",
        Size = Vector2.new(620, 420),
    },

    -- Build marker compared by the update-checker
    Build = "v1.0",

    -- Game identification
    Game = {
        PlaceId = 5125748,
        GameName = "Deep Fishing",
    },

    -- Keybinds
    Keys = {
        HideUI = Enum.KeyCode.K,
        ToggleFishing = Enum.KeyCode.F,
    },

    -- Theme (deep ocean blue palette)
    Theme = {
        accent = Color3.fromRGB(40, 160, 220),
        accent2 = Color3.fromRGB(80, 200, 255),
        accentDark = Color3.fromRGB(20, 100, 160),
        accentGlow = Color3.fromRGB(60, 180, 240),
        glow = Color3.fromRGB(60, 180, 240),
        bg = Color3.fromRGB(10, 14, 22),
        bg2 = Color3.fromRGB(16, 20, 30),
        panel = Color3.fromRGB(20, 26, 38),
        panel2 = Color3.fromRGB(28, 34, 48),
        sidebar = Color3.fromRGB(14, 18, 28),
        topbar = Color3.fromRGB(18, 22, 34),
        text = Color3.fromRGB(230, 240, 255),
        dim = Color3.fromRGB(120, 140, 170),
        faint = Color3.fromRGB(80, 100, 130),
        divider = Color3.fromRGB(36, 44, 60),
        success = Color3.fromRGB(60, 200, 120),
        danger = Color3.fromRGB(240, 80, 100),
        warn = Color3.fromRGB(255, 190, 60),
        tp = Color3.fromRGB(80, 170, 255),
        beam = Color3.fromRGB(255, 140, 80),
    },

    -- Auto Sell settings
    AutoSell = {
        Interval = 300,
        Rarities = {
            "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic",
        },
    },

    -- Auto Delete settings (rarities to auto-delete)
    AutoDelete = {
        Rarities = {
            Common = true,
            Uncommon = false,
            Rare = false,
        },
    },

    -- Auto Buy settings
    AutoBuy = {
        BuyBestBait = true,
        BuyBestRod = true,
        BuyUpgrades = true,
        UseBestBaitNow = true,
    },

    -- Fishing settings
    Fishing = {
        AutoPerfect = true,
        InstantCollect = true,
        AutoStopWhenEmpty = true,
        CollectRarities = {
            "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic",
        },
        CollectMutations = true,
    },

    -- Movement settings
    Movement = {
        FlySpeed = 50,
        WalkSpeed = 16,
        InfiniteJumpEnabled = false,
        NoClipEnabled = false,
        FlyEnabled = false,
    },

    -- Rewards settings
    Rewards = {
        AutoClaimFreeRewards = true,
        AutoClaimBigFish = true,
        AutoClaimPlaytimeGift = true,
        AutoClaimNextDayReward = true,
        AutoClaimGroupReward = true,
        RedeemAllCodes = true,
    },

    -- Anti-AFK settings
    AntiAfk = {
        Enabled = true,
    },

    -- Component defaults
    ComponentDefaults = {
        CornerRadius = UDim.new(0, 10),
        PressScale = 0.97,
    },
}
