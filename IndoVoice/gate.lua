-- IndoVoice/gate.lua
-- Password gate UI — must pass before main loads
--
-- PASSWORD BYPASS SUPPORT (session persistence):
--   The factory now accepts an optional second argument `opts`:
--     gateFactory(config, { trusted = true })
--   When `trusted` is true the gate UI is skipped entirely and the function
--   returns true immediately. main.lua sets this when a saved session shows
--   the password was already typed once before (see session.lua).
return function(config, opts)
    local Players = game:GetService("Players")
    local TweenService = game:GetService("TweenService")
    local lp = Players.LocalPlayer

    -- ------------------------------------------------------------------
    -- PASSWORD BYPASS: skip the whole gate UI when main.lua already
    -- verified a saved session for this place (password typed once before).
    -- ------------------------------------------------------------------
    opts = (type(opts) == "table") and opts or {}
    if opts.trusted == true then
        -- No GUI is built, no blocking loop runs — instant pass-through.
        return true
    end

    local ENCODED_PASS = config.Gate and config.Gate.Password or ""

    -- Simple base64 decode
    local b64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
    local function base64decode(data)
        data = string.gsub(data, "[^" .. b64 .. "=]", "")
        return (data:gsub(".", function(x)
            if x == "=" then return "" end
            local r, f = "", (b64:find(x) - 1)
            for i = 6, 1, -1 do
                r = r .. (f % 2 ^ i - f % 2 ^ (i - 1) > 0 and "1" or "0")
            end
            return r
        end):gsub("%d%d%d?%d?%d?%d?%d?%d?", function(x)
            if #x ~= 8 then return "" end
            local c = 0
            for i = 1, 8 do
                c = c + (x:sub(i, i) == "1" and 2 ^ (8 - i) or 0)
            end
            return string.char(c)
        end))
    end

    local REAL_PASS = base64decode(ENCODED_PASS)

    -- Create Gate GUI
    local GateGui = Instance.new("ScreenGui")
    GateGui.Name = "LyraHub_Gate"
    GateGui.ResetOnSpawn = false
    GateGui.DisplayOrder = 9999
    GateGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    pcall(function() GateGui.Parent = game:GetService("CoreGui") end)
    if not GateGui.Parent then GateGui.Parent = lp:WaitForChild("PlayerGui") end

    -- Background overlay
    local Overlay = Instance.new("Frame")
    Overlay.Size = UDim2.new(1, 0, 1, 0)
    Overlay.BackgroundColor3 = Color3.fromRGB(5, 3, 12)
    Overlay.BackgroundTransparency = 0.15
    Overlay.BorderSizePixel = 0
    Overlay.Parent = GateGui

    -- Main card
    local Card = Instance.new("Frame")
    Card.Size = UDim2.new(0, 360, 0, 320)
    Card.AnchorPoint = Vector2.new(0.5, 0.5)
    Card.Position = UDim2.new(0.5, 0, 0.5, 0)
    Card.BackgroundColor3 = Color3.fromRGB(14, 12, 24)
    Card.BorderSizePixel = 0
    Card.Parent = GateGui
    Instance.new("UICorner", Card).CornerRadius = UDim.new(0, 14)

    local CardStroke = Instance.new("UIStroke", Card)
    CardStroke.Color = Color3.fromRGB(155, 89, 255)
    CardStroke.Thickness = 1.5
    CardStroke.Transparency = 0.3

    -- Title
    local Title = Instance.new("TextLabel")
    Title.Size = UDim2.new(1, 0, 0, 40)
    Title.Position = UDim2.new(0, 0, 0, 20)
    Title.BackgroundTransparency = 1
    Title.Text = "LYRA HUB"
    Title.TextColor3 = Color3.fromRGB(155, 89, 255)
    Title.Font = Enum.Font.GothamBlack
    Title.TextSize = 26
    Title.Parent = Card

    local Subtitle = Instance.new("TextLabel")
    Subtitle.Size = UDim2.new(1, 0, 0, 20)
    Subtitle.Position = UDim2.new(0, 0, 0, 55)
    Subtitle.BackgroundTransparency = 1
    Subtitle.Text = "Gate"
    Subtitle.TextColor3 = Color3.fromRGB(130, 120, 170)
    Subtitle.Font = Enum.Font.GothamBold
    Subtitle.TextSize = 14
    Subtitle.Parent = Card

    -- Password input
    local realInput = "" -- store actual password text
    local InputBox = Instance.new("TextBox")
    InputBox.Size = UDim2.new(0, 280, 0, 38)
    InputBox.AnchorPoint = Vector2.new(0.5, 0)
    InputBox.Position = UDim2.new(0.5, 0, 0, 90)
    InputBox.BackgroundColor3 = Color3.fromRGB(22, 20, 38)
    InputBox.TextColor3 = Color3.fromRGB(240, 235, 255)
    InputBox.PlaceholderText = ""
    InputBox.PlaceholderColor3 = Color3.fromRGB(90, 80, 130)
    InputBox.Text = ""
    InputBox.Font = Enum.Font.GothamBold
    InputBox.TextSize = 14
    InputBox.ClearTextOnFocus = false
    InputBox.BorderSizePixel = 0
    InputBox.Parent = Card
    Instance.new("UICorner", InputBox).CornerRadius = UDim.new(0, 8)
    local InputStroke = Instance.new("UIStroke", InputBox)
    InputStroke.Color = Color3.fromRGB(60, 50, 100)
    InputStroke.Thickness = 1

    -- Mask password input with asterisks
    InputBox:GetPropertyChangedSignal("Text"):Connect(function()
        local currentText = InputBox.Text
        local maskedLen = #realInput

        if #currentText > maskedLen then
            -- New character(s) added
            local newChars = string.sub(currentText, maskedLen + 1)
            realInput = realInput .. newChars
        elseif #currentText < maskedLen then
            -- Character(s) deleted
            realInput = string.sub(realInput, 1, #currentText)
        end

        -- Replace visible text with asterisks
        local masked = string.rep("*", #realInput)
        if InputBox.Text ~= masked then
            InputBox.Text = masked
        end
    end)

    -- Status label
    local StatusLbl = Instance.new("TextLabel")
    StatusLbl.Size = UDim2.new(1, 0, 0, 16)
    StatusLbl.Position = UDim2.new(0, 0, 0, 132)
    StatusLbl.BackgroundTransparency = 1
    StatusLbl.Text = ""
    StatusLbl.TextColor3 = Color3.fromRGB(255, 80, 100)
    StatusLbl.Font = Enum.Font.Gotham
    StatusLbl.TextSize = 11
    StatusLbl.Parent = Card

    -- Enter button
    local EnterBtn = Instance.new("TextButton")
    EnterBtn.Size = UDim2.new(0, 280, 0, 36)
    EnterBtn.AnchorPoint = Vector2.new(0.5, 0)
    EnterBtn.Position = UDim2.new(0.5, 0, 0, 155)
    EnterBtn.BackgroundColor3 = Color3.fromRGB(155, 89, 255)
    EnterBtn.TextColor3 = Color3.new(1, 1, 1)
    EnterBtn.Font = Enum.Font.GothamBold
    EnterBtn.TextSize = 14
    EnterBtn.Text = "Enter"
    EnterBtn.BorderSizePixel = 0
    EnterBtn.Parent = Card
    Instance.new("UICorner", EnterBtn).CornerRadius = UDim.new(0, 8)

    -- Discord button
    local DiscordBtn = Instance.new("TextButton")
    DiscordBtn.Size = UDim2.new(0, 135, 0, 30)
    DiscordBtn.Position = UDim2.new(0, 40, 0, 205)
    DiscordBtn.BackgroundColor3 = Color3.fromRGB(88, 101, 242)
    DiscordBtn.TextColor3 = Color3.new(1, 1, 1)
    DiscordBtn.Font = Enum.Font.GothamBold
    DiscordBtn.TextSize = 11
    DiscordBtn.Text = "DM Ahzencal"
    DiscordBtn.BorderSizePixel = 0
    DiscordBtn.Parent = Card
    Instance.new("UICorner", DiscordBtn).CornerRadius = UDim.new(0, 8)

    -- Saweria button
    local SaweriaBtn = Instance.new("TextButton")
    SaweriaBtn.Size = UDim2.new(0, 135, 0, 30)
    SaweriaBtn.Position = UDim2.new(0, 185, 0, 205)
    SaweriaBtn.BackgroundColor3 = Color3.fromRGB(255, 170, 0)
    SaweriaBtn.TextColor3 = Color3.new(1, 1, 1)
    SaweriaBtn.Font = Enum.Font.GothamBold
    SaweriaBtn.TextSize = 11
    SaweriaBtn.Text = "Saweria"
    SaweriaBtn.BorderSizePixel = 0
    SaweriaBtn.Parent = Card
    Instance.new("UICorner", SaweriaBtn).CornerRadius = UDim.new(0, 8)

    -- Footer
    local Footer = Instance.new("TextLabel")
    Footer.Size = UDim2.new(1, 0, 0, 40)
    Footer.Position = UDim2.new(0, 0, 1, -50)
    Footer.BackgroundTransparency = 1
    Footer.Text = "LyraHub est. 2026 • by Ahzencal"
    Footer.TextColor3 = Color3.fromRGB(80, 70, 120)
    Footer.Font = Enum.Font.Gotham
    Footer.TextSize = 10
    Footer.Parent = Card

    -- Animate in
    Card.BackgroundTransparency = 1
    Title.TextTransparency = 1
    Subtitle.TextTransparency = 1
    InputBox.BackgroundTransparency = 1
    InputBox.TextTransparency = 1
    EnterBtn.BackgroundTransparency = 1
    EnterBtn.TextTransparency = 1
    DiscordBtn.BackgroundTransparency = 1
    DiscordBtn.TextTransparency = 1
    SaweriaBtn.BackgroundTransparency = 1
    SaweriaBtn.TextTransparency = 1
    Footer.TextTransparency = 1
    CardStroke.Transparency = 1
    InputStroke.Transparency = 1

    local fadeIn = TweenInfo.new(0.4, Enum.EasingStyle.Quart)
    TweenService:Create(Card, fadeIn, { BackgroundTransparency = 0 }):Play()
    TweenService:Create(CardStroke, fadeIn, { Transparency = 0.3 }):Play()
    task.wait(0.15)
    TweenService:Create(Title, fadeIn, { TextTransparency = 0 }):Play()
    TweenService:Create(Subtitle, fadeIn, { TextTransparency = 0 }):Play()
    task.wait(0.1)
    TweenService:Create(InputBox, fadeIn, { BackgroundTransparency = 0, TextTransparency = 0 }):Play()
    TweenService:Create(InputStroke, fadeIn, { Transparency = 0 }):Play()
    TweenService:Create(EnterBtn, fadeIn, { BackgroundTransparency = 0, TextTransparency = 0 }):Play()
    task.wait(0.1)
    TweenService:Create(DiscordBtn, fadeIn, { BackgroundTransparency = 0, TextTransparency = 0 }):Play()
    TweenService:Create(SaweriaBtn, fadeIn, { BackgroundTransparency = 0, TextTransparency = 0 }):Play()
    TweenService:Create(Footer, fadeIn, { TextTransparency = 0 }):Play()

    -- Logic
    local authenticated = false

    DiscordBtn.MouseButton1Click:Connect(function()
        pcall(function() setclipboard("Ahzencal") end)
        DiscordBtn.Text = "Copied!"
        task.delay(2, function()
            if DiscordBtn and DiscordBtn.Parent then
                DiscordBtn.Text = "DM Ahzencal"
            end
        end)
    end)

    SaweriaBtn.MouseButton1Click:Connect(function()
        pcall(function() setclipboard("https://saweria.co/ahzencal") end)
        SaweriaBtn.Text = "Copied!"
        task.delay(2, function()
            if SaweriaBtn and SaweriaBtn.Parent then
                SaweriaBtn.Text = "Saweria"
            end
        end)
    end)

    local function tryAuth()
        local input = realInput
        if input == REAL_PASS then
            authenticated = true
            StatusLbl.Text = ""
            EnterBtn.Text = "✓"
            EnterBtn.BackgroundColor3 = Color3.fromRGB(80, 220, 140)
            -- Fade out
            task.wait(0.3)
            local fadeOut = TweenInfo.new(0.35, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
            TweenService:Create(Card, fadeOut, { BackgroundTransparency = 1 }):Play()
            TweenService:Create(CardStroke, fadeOut, { Transparency = 1 }):Play()
            TweenService:Create(Overlay, fadeOut, { BackgroundTransparency = 1 }):Play()
            TweenService:Create(Title, fadeOut, { TextTransparency = 1 }):Play()
            TweenService:Create(Subtitle, fadeOut, { TextTransparency = 1 }):Play()
            TweenService:Create(InputBox, fadeOut, { BackgroundTransparency = 1, TextTransparency = 1 }):Play()
            TweenService:Create(EnterBtn, fadeOut, { BackgroundTransparency = 1, TextTransparency = 1 }):Play()
            TweenService:Create(DiscordBtn, fadeOut, { BackgroundTransparency = 1, TextTransparency = 1 }):Play()
            TweenService:Create(SaweriaBtn, fadeOut, { BackgroundTransparency = 1, TextTransparency = 1 }):Play()
            TweenService:Create(Footer, fadeOut, { TextTransparency = 1 }):Play()
            task.wait(0.4)
            GateGui:Destroy()
        else
            StatusLbl.Text = "Invalid password"
            StatusLbl.TextColor3 = Color3.fromRGB(255, 80, 100)
            -- Shake animation
            local orig = Card.Position
            for i = 1, 3 do
                Card.Position = orig + UDim2.new(0, 6, 0, 0)
                task.wait(0.04)
                Card.Position = orig + UDim2.new(0, -6, 0, 0)
                task.wait(0.04)
            end
            Card.Position = orig
            -- Kick player after brief delay
            task.wait(0.5)
            pcall(function() GateGui:Destroy() end)
            lp:Kick("Access Denied")
        end
    end

    EnterBtn.MouseButton1Click:Connect(tryAuth)
    InputBox.FocusLost:Connect(function(enterPressed)
        if enterPressed then
            tryAuth()
        end
    end)

    -- Block until authenticated
    while not authenticated do
        task.wait(0.1)
    end

    return true
end
