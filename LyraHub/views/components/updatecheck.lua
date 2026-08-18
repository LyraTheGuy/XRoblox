-- LyraHub/views/components/updatecheck.lua
-- View layer: compares the running build against the live raw config and
-- shows a top-center "Update available" chip when GitHub is ahead. Runs
-- non-blocking; every failure is silent (offline = no nagging).

return function(theme, shared)
    -- Accept the full config table (colors nested under .Theme) or a flat
    -- theme table. Kit convention: factory(config, shared).
    if theme.Theme then
        theme = setmetatable({ ComponentDefaults = theme.ComponentDefaults }, { __index = theme.Theme })
    end

    local Players = game:GetService("Players")
    local lp = Players.LocalPlayer

    local function Check(opts)
        opts = opts or {}
        local localBuild = opts.LocalBuild
        local configURL = opts.ConfigURL
        if not localBuild or not configURL then
            return
        end

        task.spawn(function()
            local liveBuild = nil
            local ok = pcall(function()
                local src = game:HttpGet(configURL)
                -- Extract the Build marker from the source instead of executing
                -- the live config: executing it could block forever on top-level
                -- workspace lookups (e.g. WaitForChild) and never return.
                local buildMarker = src:match('Build%s*=%s*"([%w%.]+)"')
                if buildMarker then
                    liveBuild = buildMarker
                end
            end)
            if not ok or not liveBuild or liveBuild == localBuild then
                return -- offline, unparsable, or already current
            end

            -- Top-center update chip
            local gui = Instance.new("ScreenGui")
            gui.Name = "LyraUpdateChip"
            gui.ResetOnSpawn = false
            gui.DisplayOrder = 9997
            pcall(function() gui.Parent = game:GetService("CoreGui") end)
            if not gui.Parent then
                gui.Parent = lp:WaitForChild("PlayerGui")
            end

            local chip = Instance.new("TextButton")
            chip.Size = UDim2.new(0, 320, 0, 34)
            chip.Position = UDim2.new(0.5, 0, 0, 16)
            chip.AnchorPoint = Vector2.new(0.5, 0)
            chip.BackgroundColor3 = theme.panel2
            chip.BackgroundTransparency = 0.05
            chip.AutoButtonColor = false
            chip.BorderSizePixel = 0
            chip.Text = ""
            chip.Parent = gui
            shared.corner(chip, UDim.new(0, 10))
            shared.stroke(chip, theme.accent, 1, 0.25)

            local lbl = Instance.new("TextLabel")
            lbl.Size = UDim2.new(1, -16, 1, 0)
            lbl.Position = UDim2.new(0, 8, 0, 0)
            lbl.BackgroundTransparency = 1
            lbl.Text = "⬆ Update available — " .. tostring(localBuild) .. " → " .. tostring(liveBuild)
            lbl.TextColor3 = theme.text
            lbl.Font = Enum.Font.GothamBold
            lbl.TextSize = 12
            lbl.Parent = chip

            chip.BackgroundTransparency = 1
            lbl.TextTransparency = 1
            shared.tween(chip, { BackgroundTransparency = 0.05 }, 0.3)
            shared.tween(lbl, { TextTransparency = 0 }, 0.35)

            chip.MouseButton1Click:Connect(function()
                pcall(function() gui:Destroy() end)
            end)
            task.delay(opts.Duration or 15, function()
                pcall(function() gui:Destroy() end)
            end)
        end)
    end

    return { Check = Check, check = Check }
end
