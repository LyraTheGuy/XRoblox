-- LyraHub/controllers/demo.lua
-- Controller layer: demo bindings between the component views and the
-- observable store (two-way), plus dashboard readouts, quick actions and
-- activity logging. This is the only layer that knows both the model and
-- the components — the view stays purely presentational.

return function(view, model, config)
    local theme = config.Theme

    local function fmtPct(v)
        return math.floor((tonumber(v) or 0) * 100) .. "%"
    end

    local function toHex(c)
        return string.format(
            "#%02X%02X%02X",
            math.floor(c.R * 255 + 0.5),
            math.floor(c.G * 255 + 0.5),
            math.floor(c.B * 255 + 0.5)
        )
    end

    local function log(msg)
        if view.LogLabel then
            view.LogLabel.Text = msg
        end
    end

    -- Seed the store from config.Defaults (single source of truth). Done before
    -- any onChange listeners are registered so nothing fires spuriously.
    for key, value in pairs(config.Defaults) do
        model.set(key, value)
    end

    -- Components -> model --------------------------------------------------------
    view.Components.NotifyToggle.OnChanged(function(v)
        model.set("notifications", v)
        log(v and "Notifications: ON" or "Notifications: OFF")
    end)
    view.Components.BoldToggle.OnChanged(function(v)
        model.set("bold", v)
        log(v and "Bold accents: ON" or "Bold accents: OFF")
    end)
    view.Components.AccentDropdown.OnSelected(function(v)
        model.set("accent", v)
        log("Accent: " .. tostring(v))
    end)
    view.Components.ScaleSlider.OnChanged(function(v) model.set("scale", v) end)
    view.Components.GlowSlider.OnChanged(function(v) model.set("glow", v) end)
    view.Components.OpacitySlider.OnChanged(function(v) model.set("opacity", v) end)
    view.Components.KeybindPicker.OnChanged(function(v)
        model.set("keybind", v)
        log("Keybind: " .. (v and v.Name or "-"))
    end)
    view.Components.UserInput.OnChanged(function(v)
        model.set("username", v)
        log("Username: " .. tostring(v))
    end)
    view.Components.ColorPicker.OnChanged(function(v)
        model.set("tint", v)
    end)

    -- Model -> components (two-way; notifyChange=false prevents echo loops) -------
    model.onChange("notifications", function(v) view.Components.NotifyToggle.Set(v, false) end)
    model.onChange("bold", function(v) view.Components.BoldToggle.Set(v, false) end)
    model.onChange("accent", function(v)
        view.Components.AccentDropdown.SetSelected(v, false)
        view.Tiles.Accent.Text = tostring(v or "-")
        view.Components.AccentChip.BackgroundColor3 = (config.Accents and config.Accents[v]) or theme.accent
    end)
    model.onChange("scale", function(v)
        view.Components.ScaleSlider.Set(v, false)
        view.Tiles.Scale.Text = fmtPct(v)
        view.Components.ScaleValue.Text = fmtPct(v)
    end)
    model.onChange("glow", function(v)
        view.Components.GlowSlider.Set(v, false)
        view.Tiles.Glow.Text = fmtPct(v)
        view.Components.GlowValue.Text = fmtPct(v)
    end)
    model.onChange("opacity", function(v)
        view.Components.OpacitySlider.Set(v, false)
        view.Components.OpacityValue.Text = fmtPct(v)
    end)
    model.onChange("keybind", function(v)
        view.Components.KeybindPicker.Set(v, false)
        view.InputStatus.Key.Text = v and v.Name or "-"
    end)
    model.onChange("username", function(v)
        view.Components.UserInput.SetText(v, false)
        view.InputStatus.User.Text = tostring(v or "")
    end)
    model.onChange("tint", function(v)
        view.Components.ColorPicker.Set(v, false)
        view.Components.AccentChip.BackgroundColor3 = v
        view.LogoDot.BackgroundColor3 = v
        view.InputStatus.Color.Text = toHex(v)
    end)
    model.onChange("enabled", function(v)
        view.Components.PrimaryBtn.SetEnabled(v)
        view.Tiles.Status.Text = v and "ENABLED" or "DISABLED"
        view.Tiles.Status.TextColor3 = v and theme.success or theme.danger
    end)

    -- Window lifecycle: dismiss the pickers when the window hides or minimizes
    -- so their full-screen scrims never linger over the game (or block the
    -- minimized panel's expand button).
    local function dismissPickers()
        pcall(view.Components.KeybindPicker.Cancel)
        pcall(view.Components.ColorPicker.Close)
    end
    model.onChange("visible", function(v)
        if not v then dismissPickers() end
    end)
    model.onChange("minimized", function(v)
        if v then dismissPickers() end
    end)

    -- Quick actions ----------------------------------------------------------------
    view.Components.EnableBtn.Instance.MouseButton1Click:Connect(function()
        model.set("enabled", true)
        log("Master switch enabled")
    end)
    view.Components.DisableBtn.Instance.MouseButton1Click:Connect(function()
        model.set("enabled", false)
        log("Master switch disabled")
    end)
    view.Components.ResetBtn.Instance.MouseButton1Click:Connect(function()
        for key, value in pairs(config.Defaults) do
            model.set(key, value)
        end
        log("All settings reset to defaults")
    end)
    view.Components.UnloadBtn.Instance.MouseButton1Click:Connect(function()
        model.set("uiOpen", false)
    end)

    -- Initial sync (views were built from config.Defaults, so tiles + labels are
    -- the only things that need an explicit first paint).
    view.Tiles.Status.Text = model.get("enabled") and "ENABLED" or "DISABLED"
    view.Tiles.Status.TextColor3 = model.get("enabled") and theme.success or theme.danger
    view.Tiles.Accent.Text = tostring(model.get("accent") or "-")
    view.Tiles.Scale.Text = fmtPct(model.get("scale"))
    view.Tiles.Glow.Text = fmtPct(model.get("glow"))
    view.Components.ScaleValue.Text = fmtPct(model.get("scale"))
    view.Components.GlowValue.Text = fmtPct(model.get("glow"))
    view.Components.OpacityValue.Text = fmtPct(model.get("opacity"))
    view.Components.PrimaryBtn.SetEnabled(model.get("enabled"))
    local initKey = model.get("keybind")
    view.InputStatus.Key.Text = initKey and initKey.Name or "-"
    view.InputStatus.User.Text = tostring(model.get("username") or "")
    local initTint = model.get("tint") or theme.accent
    view.InputStatus.Color.Text = toHex(initTint)
    view.Components.AccentChip.BackgroundColor3 = initTint
    view.LogoDot.BackgroundColor3 = initTint
end
