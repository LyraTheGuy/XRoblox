-- RideAPet/gate.lua
-- Password gate UI — must pass before main loads
return function(config)
    local Players = game:GetService("Players")
    local TweenService = game:GetService("TweenService")
    local lp = Players.LocalPlayer

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
    local realInput = ""
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
    InputBox.ZIndex = 5
    InputBox.Parent = Card
    Instance.new("UICorner", InputBox).CornerRadius = UDim.new(0, 8)

    local InputStroke = Instance.new("UIStroke", InputBox)
    InputStroke.Color = Color3.fromRGB(42, 38, 66)
    InputStroke.Thickness = 1

    -- Status label
    local Status = Instance.new("TextLabel")
    Status.Size = UDim2.new(0, 280, 0, 20)
    Status.Position = UDim2.new(0.5, 0, 0, 135)
    Status.BackgroundTransparency = 1
    Status.Text = ""
    Status.TextColor3 = Color3.fromRGB(255, 80, 100)
    Status.Font = Enum.Font.GothamBold
    Status.TextSize = 12
    Status.Parent = Card

    -- Submit button
    local SubmitBtn = Instance.new("TextButton")
    SubmitBtn.Size = UDim2.new(0, 280, 0, 38)
    SubmitBtn.AnchorPoint = Vector2.new(0.5, 0)
    SubmitBtn.Position = UDim2.new(0.5, 0, 0, 165)
    SubmitBtn.BackgroundColor3 = Color3.fromRGB(155, 89, 255)
    SubmitBtn.Text = "Enter"
    SubmitBtn.TextColor3 = Color3.new(1, 1, 1)
    SubmitBtn.Font = Enum.Font.GothamBold
    SubmitBtn.TextSize = 14
    SubmitBtn.BorderSizePixel = 0
    SubmitBtn.ZIndex = 5
    SubmitBtn.Parent = Card
    Instance.new("UICorner", SubmitBtn).CornerRadius = UDim.new(0, 8)

    local function checkPassword()
        local input = InputBox.Text
        if input == REAL_PASS then
            Status.Text = "Access granted!"
            Status.TextColor3 = Color3.fromRGB(80, 220, 140)
            InputStroke.Color = Color3.fromRGB(80, 220, 140)
            task.wait(0.5)
            -- Fade out
            local tweenOut = TweenService:Create(Card, TweenInfo.new(0.3, Enum.EasingStyle.Quart), {BackgroundTransparency = 1})
            local overlayOut = TweenService:Create(Overlay, TweenInfo.new(0.3, Enum.EasingStyle.Quart), {BackgroundTransparency = 1})
            tweenOut:Play()
            overlayOut:Play()
            task.wait(0.35)
            GateGui:Destroy()
            return true
        else
            Status.Text = "Wrong password"
            Status.TextColor3 = Color3.fromRGB(255, 80, 100)
            InputStroke.Color = Color3.fromRGB(255, 80, 100)
            task.delay(1.5, function()
                InputStroke.Color = Color3.fromRGB(42, 38, 66)
                Status.Text = ""
            end)
            return false
        end
    end

    SubmitBtn.MouseButton1Click:Connect(checkPassword)
    InputBox.FocusLost:Connect(function(enterPressed)
        if enterPressed then checkPassword() end
    end)

    -- Animate in
    Card.BackgroundTransparency = 1
    Overlay.BackgroundTransparency = 1
    local tweenIn = TweenService:Create(Card, TweenInfo.new(0.35, Enum.EasingStyle.Quart), {BackgroundTransparency = 0})
    local overlayIn = TweenService:Create(Overlay, TweenInfo.new(0.35, Enum.EasingStyle.Quart), {BackgroundTransparency = 0.15})
    tweenIn:Play()
    overlayIn:Play()

    -- Block until authenticated
    while GateGui and GateGui.Parent do
        task.wait(0.1)
    end
end
