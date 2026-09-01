-- ============================================================
-- >>> UPDATED VERSION v3 (FIXED) <<<  (last modified 2026-08-06 22:09 WIB)
-- Fix: checkbox refs now stored in a local Lua table instead of on the
-- Frame instance (Roblox Instances can't hold arbitrary custom
-- properties -> caused "CheckBoxes is not a valid member of Frame").
-- Also: removed the FlowerShopScript stock check entirely -- the loop
-- now just fires the remote directly for every checked flower.
-- ============================================================

-- modules/auto_buy_seed.lua
-- Auto Buy Seed feature: buys every checked flower on an interval (default every 2 minutes).

return function(ctx)
	ctx.setButtonState(ctx.gui.BuySeedButton, ctx.AutoBuySeed, "Buy Seed")
	ctx.updateStatus()

	local lastRun = os.clock()

	-- FLOWER_LIST + selectedFlowers come from ctx (core.lua always defines them
	-- before this module runs), so no fallback copy is needed here.
	ctx.selectedFlowers = ctx.selectedFlowers or { Bamboo = true }

	ctx.gui.BuySeedButton.MouseButton1Click:Connect(function()
		ctx.AutoBuySeed = not ctx.AutoBuySeed
		ctx.setButtonState(ctx.gui.BuySeedButton, ctx.AutoBuySeed, "Buy Seed")
		ctx.updateStatus()
		if ctx.gui.Toast and ctx.gui.Toast.show then
			local msg = ctx.AutoBuySeed and "Auto Buy Seed enabled" or "Auto Buy Seed disabled"
			ctx.gui.Toast.show({
				Text = msg,
				Variant = ctx.AutoBuySeed and "success" or "info",
				Duration = 1.5,
			})
		end
	end)

	-- ===== Build checkbox list UI =====
	-- The checklist lives inside gui.FlowerCheckListHost (a dedicated panel in
	-- the scrollable Buy tab) so it is never clipped by the content frame.
	local parent = ctx.gui.FlowerCheckListHost or ctx.gui.BuySeedButton.Parent

	-- Local Lua table (NOT stored on the Instance) mapping flowerName -> checkbox button
	local checkBoxesByFlower = {}

	local listFrame = parent:FindFirstChild("FlowerCheckListFrame")
	if not listFrame then
		listFrame = Instance.new("Frame")
		listFrame.Name = "FlowerCheckListFrame"
		listFrame.Size = UDim2.new(1, 0, 1, 0)
		listFrame.Position = UDim2.new(0, 0, 0, 0)
		listFrame.BackgroundTransparency = 1
		listFrame.BorderSizePixel = 0
		listFrame.Parent = parent

		local header = Instance.new("TextLabel")
		header.Name = "Header"
		header.Size = UDim2.new(1, -8, 0, 22)
		header.Position = UDim2.new(0, 4, 0, 2)
		header.BackgroundTransparency = 1
		header.Font = Enum.Font.GothamBold
		header.TextSize = 14
		header.TextXAlignment = Enum.TextXAlignment.Left
		header.TextColor3 = Color3.fromRGB(255, 255, 255)
		header.Text = "Flowers to Auto Buy"
		header.Parent = listFrame

		local selectAllBtn = Instance.new("TextButton")
		selectAllBtn.Name = "SelectAllBtn"
		selectAllBtn.Size = UDim2.new(0, 70, 0, 20)
		selectAllBtn.Position = UDim2.new(1, -150, 0, 2)
		selectAllBtn.BackgroundColor3 = Color3.fromRGB(60, 140, 220)
		selectAllBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
		selectAllBtn.Font = Enum.Font.Gotham
		selectAllBtn.TextSize = 12
		selectAllBtn.Text = "All"
		selectAllBtn.Parent = listFrame

		local clearAllBtn = Instance.new("TextButton")
		clearAllBtn.Name = "ClearAllBtn"
		clearAllBtn.Size = UDim2.new(0, 70, 0, 20)
		clearAllBtn.Position = UDim2.new(1, -76, 0, 2)
		clearAllBtn.BackgroundColor3 = Color3.fromRGB(180, 70, 70)
		clearAllBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
		clearAllBtn.Font = Enum.Font.Gotham
		clearAllBtn.TextSize = 12
		clearAllBtn.Text = "None"
		clearAllBtn.Parent = listFrame

		local scroll = Instance.new("ScrollingFrame")
		scroll.Name = "FlowerScroll"
		scroll.Size = UDim2.new(1, -8, 1, -28)
		scroll.Position = UDim2.new(0, 4, 0, 26)
		scroll.BackgroundTransparency = 1
		scroll.BorderSizePixel = 0
		scroll.ScrollBarThickness = 6
		scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
		scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
		scroll.Parent = listFrame

		local listLayout = Instance.new("UIListLayout")
		listLayout.SortOrder = Enum.SortOrder.LayoutOrder
		listLayout.Padding = UDim.new(0, 2)
		listLayout.Parent = scroll

		local function setCheckboxVisual(box, checked)
			if checked then
				box.BackgroundColor3 = Color3.fromRGB(70, 200, 100)
				box.Text = "X"
			else
				box.BackgroundColor3 = Color3.fromRGB(60, 60, 65)
				box.Text = ""
			end
		end

		for index, flowerName in ipairs(ctx.FLOWER_LIST) do
			local row = Instance.new("Frame")
			row.Name = "Row_" .. flowerName
			row.Size = UDim2.new(1, -6, 0, 22)
			row.BackgroundTransparency = 1
			row.LayoutOrder = index
			row.Parent = scroll

			local box = Instance.new("TextButton")
			box.Name = "CheckBox"
			box.Size = UDim2.new(0, 18, 0, 18)
			box.Position = UDim2.new(0, 0, 0, 2)
			box.Font = Enum.Font.GothamBold
			box.TextSize = 12
			box.TextColor3 = Color3.fromRGB(255, 255, 255)
			box.AutoButtonColor = false
			box.Parent = row

			local label = Instance.new("TextLabel")
			label.Name = "Label"
			label.Size = UDim2.new(1, -26, 1, 0)
			label.Position = UDim2.new(0, 24, 0, 0)
			label.BackgroundTransparency = 1
			label.Font = Enum.Font.Gotham
			label.TextSize = 13
			label.TextXAlignment = Enum.TextXAlignment.Left
			label.TextColor3 = Color3.fromRGB(230, 230, 230)
			label.Text = flowerName
			label.Parent = row

			setCheckboxVisual(box, ctx.selectedFlowers[flowerName] == true)

			box.MouseButton1Click:Connect(function()
				local newState = not (ctx.selectedFlowers[flowerName] == true)
				ctx.selectedFlowers[flowerName] = newState
				setCheckboxVisual(box, newState)
			end)

			checkBoxesByFlower[flowerName] = box
		end

		selectAllBtn.MouseButton1Click:Connect(function()
			for _, flowerName in ipairs(ctx.FLOWER_LIST) do
				ctx.selectedFlowers[flowerName] = true
				setCheckboxVisual(checkBoxesByFlower[flowerName], true)
			end
		end)

		clearAllBtn.MouseButton1Click:Connect(function()
			for _, flowerName in ipairs(ctx.FLOWER_LIST) do
				ctx.selectedFlowers[flowerName] = false
				setCheckboxVisual(checkBoxesByFlower[flowerName], false)
			end
		end)
	end

	-- ===== Buy logic (no stock check -- just fire the remote) =====
	local function getSelectedFlowerList()
		local selected = {}
		for _, flowerName in ipairs(ctx.FLOWER_LIST) do
			if ctx.selectedFlowers[flowerName] then
				table.insert(selected, flowerName)
			end
		end
		return selected
	end

	task.spawn(function()
		while task.wait(0.25) do
			if ctx.Destroyed then
				break
			end
			if not ctx.AutoBuySeed then
				lastRun = os.clock()
				continue
			end

			ctx.syncIntervals()

			local now = os.clock()
			if now - lastRun < (ctx.buySeedInterval or 120) then
				continue
			end
			lastRun = now

			local selected = getSelectedFlowerList()

			for _, seedId in ipairs(selected) do
				if ctx.Destroyed or not ctx.AutoBuySeed then
					break
				end

				pcall(function()
					ctx.FlowerRemote:FireServer("BuyFlower", seedId)
					ctx.addCount("buy_seed", 1)
				end)

				task.wait(0.15)
			end

			ctx.updateStats()
		end
	end)
end
