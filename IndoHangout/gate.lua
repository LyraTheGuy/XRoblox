-- IndoHangout/gate.lua
-- Password gate UI. Must pass before the main UI loads.
-- Password is stored base64-encoded in config.Gate.Password and decoded here.
return function(config)
    local Players = game:GetService("Players")
    local TweenService = game:GetService("TweenService")
    local lp = Players.LocalPlayer
    local T = (config and config.Theme) or {}
    local G = (config and config.Gate) or {}

    if G.Enabled == false then
        return true
    end

    local ENCODED_PASS = G.Password or ""

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

    local GateGui = Instance.new("ScreenGui")
    GateGui.Name = "IndoHangout_Gate"
    GateGui.ResetOnSpawn = false
    GateGui.DisplayOrder = 9999
    GateGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    pcall(function() GateGui.Parent = game:GetService("CoreGui") end)
    if not GateGui.Parent then GateGui.Parent = lp:WaitForChild("PlayerGui") end

    local Overlay = Instance.new("Frame")
    Overlay.Size = UDim2.new(1, 0, 1, 0)
    Overlay.BackgroundColor3 = T.bg or Color3.fromRGB(16, 16, 19)
    Overlay.BackgroundTransparency = 0.15
    Overlay.BorderSizePixel = 0
    Overlay.Parent = GateGui

    local Card = Instance.new("Frame")
    Card.Size = UDim2.new(0, 340, 0, 260)
    Card.AnchorPoint = Vector2.new(0.5, 0.5)
    Card.Position = UDim2.new(0.5, 0, 0.5, 0)
    Card.BackgroundColor3 = T.panel or Color3.fromRGB(22, 22, 27)
    Card.BorderSizePixel = 0
    Card.Parent = GateGui
    Instance.new("UICorner", Card).CornerRadius = UDim.new(0, 14)

    local CardStroke = Instance.new("UIStroke", Card)
    CardStroke.Color = T.accent or Color3.fromRGB(92, 140, 255)
    CardStroke.Thickness = 1.5
    CardStroke.Transparency = 0.3

    local Title = Instance.new("TextLabel")
    Title.Size = UDim2.new(1, 0, 0, 40)
    Title.Position = UDim2.new(0, 0, 0, 18)
    Title.BackgroundTransparency = 1
    Title.Text = G.Title or "IndoHangout"
    Title.TextColor3 = T.accentGlow or Color3.fromRGB(160, 190, 255)
    Title.Font = Enum.Font.GothamBlack
    Title.TextSize = 24
    Title.Parent = Card

    local Subtitle = Instance.new("TextLabel")
    Subtitle.Size = UDim2.new(1, 0, 0, 18)
    Subtitle.Position = UDim2.new(0, 0, 0, 52)
    Subtitle.BackgroundTransparency = 1
    Subtitle.Text = G.Subtitle or "Access Gate"
    Subtitle.TextColor3 = T.dim or Color3.fromRGB(168, 172, 184)
    Subtitle.Font = Enum.Font.GothamBold
    Subtitle.TextSize = 13
    Subtitle.Parent = Card

    local realInput = ""
    local InputBox = Instance.new("TextBox")
    InputBox.Size = UDim2.new(0, 260, 0, 36)
    InputBox.AnchorPoint = Vector2.new(0.5, 0)
    InputBox.Position = UDim2.new(0.5, 0, 0, 84)
    InputBox.BackgroundColor3 = T.bg2 or Color3.fromRGB(20, 20, 24)
    InputBox.TextColor3 = T.text or Color3.fromRGB(238, 238, 242)
    InputBox.PlaceholderText = "Password"
    InputBox.PlaceholderColor3 = T.faint or Color3.fromRGB(112, 116, 128)
    InputBox.Text = ""
    InputBox.Font = Enum.Font.GothamBold
    InputBox.TextSize = 14
    InputBox.ClearTextOnFocus = false
    InputBox.BorderSizePixel = 0
    InputBox.Parent = Card
    Instance.new("UICorner", InputBox).CornerRadius = UDim.new(0, 8)
    local InputStroke = Instance.new("UIStroke", InputBox)
    InputStroke.Color = T.border or Color3.fromRGB(46, 48, 58)
    InputStroke.Thickness = 1

    InputBox:GetPropertyChangedSignal("Text"):Connect(function()
        local currentText = InputBox.Text
        local maskedLen = #realInput
        if #currentText > maskedLen then
            realInput = realInput .. string.sub(currentText, maskedLen + 1)
        elseif #currentText < maskedLen then
            realInput = string.sub(realInput, 1, #currentText)
        end
        local masked = string.rep("*", #realInput)
        if InputBox.Text ~= masked then
            InputBox.Text = masked
        end
    end)

    local StatusLbl = Instance.new("TextLabel")
    StatusLbl.Size = UDim2.new(1, 0, 0, 16)
    StatusLbl.Position = UDim2.new(0, 0, 0, 124)
    StatusLbl.BackgroundTransparency = 1
    StatusLbl.Text = ""
    StatusLbl.TextColor3 = T.danger or Color3.fromRGB(222, 92, 92)
    StatusLbl.Font = Enum.Font.Gotham
    StatusLbl.TextSize = 11
    StatusLbl.Parent = Card

    local EnterBtn = Instance.new("TextButton")
    EnterBtn.Size = UDim2.new(0, 260, 0, 34)
    EnterBtn.AnchorPoint = Vector2.new(0.5, 0)
    EnterBtn.Position = UDim2.new(0.5, 0, 0, 146)
    EnterBtn.BackgroundColor3 = T.accent or Color3.fromRGB(92, 140, 255)
    EnterBtn.TextColor3 = Color3.new(1, 1, 1)
    EnterBtn.Font = Enum.Font.GothamBold
    EnterBtn.TextSize = 14
    EnterBtn.Text = "Enter"
    EnterBtn.BorderSizePixel = 0
    EnterBtn.Parent = Card
    Instance.new("UICorner", EnterBtn).CornerRadius = UDim.new(0, 8)

    local Footer = Instance.new("TextLabel")
    Footer.Size = UDim2.new(1, 0, 0, 30)
    Footer.Position = UDim2.new(0, 0, 1, -36)
    Footer.BackgroundTransparency = 1
    Footer.Text = G.Footer or "IndoHangout"
    Footer.TextColor3 = T.faint or Color3.fromRGB(112, 116, 128)
    Footer.Font = Enum.Font.Gotham
    Footer.TextSize = 10
    Footer.Parent = Card

    Card.BackgroundTransparency = 1
    Title.TextTransparency = 1
    Subtitle.TextTransparency = 1
    InputBox.BackgroundTransparency = 1
    InputBox.TextTransparency = 1
    EnterBtn.BackgroundTransparency = 1
    EnterBtn.TextTransparency = 1
    Footer.TextTransparency = 1
    CardStroke.Transparency = 1
    InputStroke.Transparency = 1

    local fadeIn = TweenInfo.new(0.35, Enum.EasingStyle.Quart)
    TweenService:Create(Card, fadeIn, { BackgroundTransparency = 0 }):Play()
    TweenService:Create(CardStroke, fadeIn, { Transparency = 0.3 }):Play()
    task.wait(0.1)
    TweenService:Create(Title, fadeIn, { TextTransparency = 0 }):Play()
    TweenService:Create(Subtitle, fadeIn, { TextTransparency = 0 }):Play()
    task.wait(0.08)
    TweenService:Create(InputBox, fadeIn, { BackgroundTransparency = 0, TextTransparency = 0 }):Play()
    TweenService:Create(InputStroke, fadeIn, { Transparency = 0 }):Play()
    TweenService:Create(EnterBtn, fadeIn, { BackgroundTransparency = 0, TextTransparency = 0 }):Play()
    TweenService:Create(Footer, fadeIn, { TextTransparency = 0 }):Play()

    local authenticated = false

    local function tryAuth()
        if realInput == REAL_PASS then
            authenticated = true
            StatusLbl.Text = ""
            EnterBtn.Text = "Unlocked"
            EnterBtn.BackgroundColor3 = T.success or Color3.fromRGB(86, 201, 120)
            task.wait(0.3)
            local fadeOut = TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
            TweenService:Create(Card, fadeOut, { BackgroundTransparency = 1 }):Play()
            TweenService:Create(CardStroke, fadeOut, { Transparency = 1 }):Play()
            TweenService:Create(Overlay, fadeOut, { BackgroundTransparency = 1 }):Play()
            TweenService:Create(Title, fadeOut, { TextTransparency = 1 }):Play()
            TweenService:Create(Subtitle, fadeOut, { TextTransparency = 1 }):Play()
            TweenService:Create(InputBox, fadeOut, { BackgroundTransparency = 1, TextTransparency = 1 }):Play()
            TweenService:Create(EnterBtn, fadeOut, { BackgroundTransparency = 1, TextTransparency = 1 }):Play()
            TweenService:Create(Footer, fadeOut, { TextTransparency = 1 }):Play()
            task.wait(0.35)
            GateGui:Destroy()
        else
            StatusLbl.Text = "Invalid password"
            StatusLbl.TextColor3 = T.danger or Color3.fromRGB(222, 92, 92)
            local orig = Card.Position
            for i = 1, 3 do
                Card.Position = orig + UDim2.new(0, 6, 0, 0)
                task.wait(0.04)
                Card.Position = orig + UDim2.new(0, -6, 0, 0)
                task.wait(0.04)
            end
            Card.Position = orig
        end
    end

    EnterBtn.MouseButton1Click:Connect(tryAuth)
    InputBox.FocusLost:Connect(function(enterPressed)
        if enterPressed then tryAuth() end
    end)

    while not authenticated do
        task.wait(0.1)
    end

    return true
end
