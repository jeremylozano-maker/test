-- RollClient : UI du Roll, de l'Inventaire et de l'Index (affichage uniquement, le serveur décide)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Items = require(Shared:WaitForChild("Items"))
local Rarities = require(Shared:WaitForChild("Rarities"))
local SkillTree = require(Shared:WaitForChild("SkillTree"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local WHITE = Color3.new(1, 1, 1)
local GREY = Color3.fromRGB(110, 110, 120)
local HEADER_COLOR = Color3.fromRGB(255, 220, 120)
local PANEL_COLOR = Color3.fromRGB(28, 32, 46)
local BUTTON_COLOR = Color3.fromRGB(45, 50, 70)
local DARK = Color3.fromRGB(15, 15, 25)
local TITLE_FONT = Enum.Font.FredokaOne
local TEXT_FONT = Enum.Font.GothamBold

local state = {
	Snapshot = nil,
	Pending = nil, -- snapshot reçu pendant une animation (évite de spoiler le résultat)
	Revealing = false,
	Busy = false,
	AutoRoll = false,
	RevealToken = 0,
}

---------------------------------------------------------------- helpers UI

local function create(className, props, children)
	local instance = Instance.new(className)
	for key, value in props do
		if key ~= "Parent" then
			instance[key] = value
		end
	end
	for _, child in children or {} do
		child.Parent = instance
	end
	instance.Parent = props.Parent
	return instance
end

local function corner(radius)
	return create("UICorner", { CornerRadius = UDim.new(0, radius or 12) })
end

local function stroke(thickness, color)
	return create("UIStroke", {
		Thickness = thickness or 3,
		Color = color or DARK,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

local function makeButton(props)
	props.BackgroundColor3 = props.BackgroundColor3 or BUTTON_COLOR
	props.TextColor3 = WHITE
	props.Font = TITLE_FONT
	props.TextScaled = true
	props.AutoButtonColor = true
	return create("TextButton", props, {
		corner(14),
		stroke(3),
		create("UIPadding", {
			PaddingTop = UDim.new(0, 6),
			PaddingBottom = UDim.new(0, 6),
			PaddingLeft = UDim.new(0, 8),
			PaddingRight = UDim.new(0, 8),
		}),
	})
end

---------------------------------------------------------------- écran

local gui = create("ScreenGui", {
	Name = "IslandUI",
	ResetOnSpawn = false,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	Parent = player:WaitForChild("PlayerGui"),
})

local flashGui = create("ScreenGui", {
	Name = "RollFlash",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	DisplayOrder = 10,
	Parent = player.PlayerGui,
})

local flash = create("Frame", {
	Parent = flashGui,
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = WHITE,
	BackgroundTransparency = 1,
	Active = false,
})

local coinsLabel = create("TextLabel", {
	Parent = gui,
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 10),
	Size = UDim2.new(0, 190, 0, 44),
	BackgroundColor3 = PANEL_COLOR,
	Text = "🪙 0",
	TextColor3 = HEADER_COLOR,
	Font = TITLE_FONT,
	TextScaled = true,
}, { corner(12), stroke(3) })

local rollButton = makeButton({
	Parent = gui,
	Name = "RollButton",
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -20),
	Size = UDim2.new(0, 220, 0, 70),
	BackgroundColor3 = Color3.fromRGB(60, 170, 90),
	Text = "🎲 ROLL",
})

local cooldownBack = create("Frame", {
	Parent = rollButton,
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, 2),
	Size = UDim2.new(1, 0, 0, 6),
	BackgroundColor3 = DARK,
	BorderSizePixel = 0,
}, { corner(3) })

local cooldownFill = create("Frame", {
	Parent = cooldownBack,
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = WHITE,
	BorderSizePixel = 0,
}, { corner(3) })

local autoButton = makeButton({
	Parent = gui,
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.new(0.5, 125, 1, -20),
	Size = UDim2.new(0, 110, 0, 50),
	Text = "AUTO: OFF",
	Visible = false,
})

local inventoryButton = makeButton({
	Parent = gui,
	AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.new(1, -12, 0.5, -34),
	Size = UDim2.new(0, 145, 0, 56),
	Text = "🎒 Inventory",
})

local indexButton = makeButton({
	Parent = gui,
	AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.new(1, -12, 0.5, 34),
	Size = UDim2.new(0, 145, 0, 56),
	Text = "📖 Index",
})

---------------------------------------------------------------- panneaux (Inventaire / Index)

local function makePanel(title)
	local panel = create("Frame", {
		Parent = gui,
		Name = title,
		Visible = false,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -170, 0.5, 0),
		Size = UDim2.fromScale(0.32, 0.72),
		BackgroundColor3 = PANEL_COLOR,
	}, {
		corner(16),
		stroke(3),
		create("UISizeConstraint", { MinSize = Vector2.new(240, 220), MaxSize = Vector2.new(420, 560) }),
	})
	local titleLabel = create("TextLabel", {
		Parent = panel,
		Position = UDim2.new(0, 14, 0, 8),
		Size = UDim2.new(1, -64, 0, 38),
		BackgroundTransparency = 1,
		Text = title,
		TextColor3 = WHITE,
		Font = TITLE_FONT,
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	local closeButton = makeButton({
		Parent = panel,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -8, 0, 8),
		Size = UDim2.new(0, 38, 0, 38),
		BackgroundColor3 = Color3.fromRGB(200, 60, 60),
		Text = "X",
	})
	closeButton.Activated:Connect(function()
		panel.Visible = false
	end)
	local list = create("ScrollingFrame", {
		Parent = panel,
		Position = UDim2.new(0, 10, 0, 56),
		Size = UDim2.new(1, -20, 1, -66),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
	}, {
		create("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	return panel, titleLabel, list
end

local function clearList(list)
	for _, child in list:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

local function addRow(list, order, text, color, isHeader)
	create("TextLabel", {
		Parent = list,
		LayoutOrder = order,
		Size = UDim2.new(1, -8, 0, if isHeader then 30 else 26),
		BackgroundTransparency = 1,
		Text = text,
		TextColor3 = color,
		Font = if isHeader then TITLE_FONT else TEXT_FONT,
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
end

local inventoryPanel, _, inventoryList = makePanel("🎒 INVENTORY")
local indexPanel, indexTitle, indexList = makePanel("📖 INDEX")

local function renderInventory()
	clearList(inventoryList)
	local inventory = state.Snapshot and state.Snapshot.Inventory or {}
	local order = 0
	for _, category in Items.Categories do
		order += 1
		addRow(inventoryList, order, Items.CategoryInfo[category].Label, HEADER_COLOR, true)
		local any = false
		for _, item in Items.ByCategory[category] do
			local count = inventory[item.Id] or 0
			if count > 0 then
				any = true
				order += 1
				local text = string.format("%s %s ×%d", item.Icon, item.Name, count)
				addRow(inventoryList, order, text, Rarities.Info[item.Rarity].Color)
			end
		end
		if not any then
			order += 1
			addRow(inventoryList, order, "  —", GREY)
		end
	end
end

local function renderIndex()
	clearList(indexList)
	local index = state.Snapshot and state.Snapshot.Index or {}
	local found = 0
	local order = 0
	for _, category in Items.Categories do
		order += 1
		addRow(indexList, order, Items.CategoryInfo[category].Label, HEADER_COLOR, true)
		for _, item in Items.ByCategory[category] do
			order += 1
			if index[item.Id] then
				found += 1
				local text = string.format("✓ %s %s  (%s)", item.Icon, item.Name, item.Rarity)
				addRow(indexList, order, text, Rarities.Info[item.Rarity].Color)
			else
				addRow(indexList, order, "? " .. item.Name, GREY)
			end
		end
	end
	indexTitle.Text = string.format("📖 INDEX  %d/%d", found, #Items.List)
end

local function applySnapshot(snapshot)
	state.Snapshot = snapshot
	coinsLabel.Text = "🪙 " .. snapshot.Coins
	autoButton.Visible = SkillTree.HasAutoRoll(snapshot.Skills)
	if not autoButton.Visible then
		state.AutoRoll = false
	end
	if inventoryPanel.Visible then
		renderInventory()
	end
	if indexPanel.Visible then
		renderIndex()
	end
end

inventoryButton.Activated:Connect(function()
	indexPanel.Visible = false
	inventoryPanel.Visible = not inventoryPanel.Visible
	if inventoryPanel.Visible then
		renderInventory()
	end
end)

indexButton.Activated:Connect(function()
	inventoryPanel.Visible = false
	indexPanel.Visible = not indexPanel.Visible
	if indexPanel.Visible then
		renderIndex()
	end
end)

---------------------------------------------------------------- révélation du roll

local REVEAL_POSITION = UDim2.fromScale(0.5, 0.38)

local reveal = create("Frame", {
	Parent = gui,
	Visible = false,
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = REVEAL_POSITION,
	Size = UDim2.fromScale(0.5, 0.22),
	BackgroundColor3 = PANEL_COLOR,
}, {
	corner(18),
	create("UISizeConstraint", { MinSize = Vector2.new(260, 110), MaxSize = Vector2.new(480, 170) }),
})
local revealStroke = stroke(5, WHITE)
revealStroke.Parent = reveal
local revealScale = create("UIScale", { Parent = reveal, Scale = 1 })

local rarityLabel = create("TextLabel", {
	Parent = reveal,
	Position = UDim2.fromScale(0.05, 0.06),
	Size = UDim2.fromScale(0.9, 0.28),
	BackgroundTransparency = 1,
	Text = "",
	TextColor3 = WHITE,
	Font = TITLE_FONT,
	TextScaled = true,
})

local nameLabel = create("TextLabel", {
	Parent = reveal,
	Position = UDim2.fromScale(0.05, 0.38),
	Size = UDim2.fromScale(0.9, 0.5),
	BackgroundTransparency = 1,
	Text = "",
	TextColor3 = WHITE,
	Font = TITLE_FONT,
	TextScaled = true,
}, { create("UIStroke", { Thickness = 2, Color = DARK }) })

local newBadge = create("TextLabel", {
	Parent = reveal,
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, 10, 0, -14),
	Size = UDim2.new(0, 80, 0, 32),
	Rotation = 12,
	BackgroundColor3 = Color3.fromRGB(255, 70, 70),
	Text = "NEW!",
	TextColor3 = WHITE,
	Font = TITLE_FONT,
	TextScaled = true,
	Visible = false,
}, { corner(8), stroke(2) })

local function playFlash(color, strength)
	flash.BackgroundColor3 = color
	flash.BackgroundTransparency = 1 - strength
	TweenService:Create(flash, TweenInfo.new(0.6), { BackgroundTransparency = 1 }):Play()
end

local function shake(duration, strength)
	local start = os.clock()
	while os.clock() - start < duration do
		reveal.Position = REVEAL_POSITION + UDim2.fromOffset(math.random(-strength, strength), math.random(-strength, strength))
		task.wait(0.03)
	end
	reveal.Position = REVEAL_POSITION
end

local function rainbow(duration)
	local start = os.clock()
	while os.clock() - start < duration do
		local color = Color3.fromHSV((os.clock() * 0.8) % 1, 0.8, 1)
		nameLabel.TextColor3 = color
		revealStroke.Color = color
		task.wait(0.03)
	end
end

local function playReveal(result)
	local item = Items.ById[result.ItemId]
	local info = Rarities.Info[item.Rarity]
	state.Revealing = true
	state.RevealToken += 1
	local token = state.RevealToken

	reveal.Visible = true
	newBadge.Visible = false
	rarityLabel.Text = "🎲 Rolling..."
	rarityLabel.TextColor3 = WHITE

	-- défilement qui ralentit : plus c'est rare, plus c'est long
	for tick = 1, info.RevealTicks do
		local fake = Items.List[math.random(#Items.List)]
		local fakeColor = Rarities.Info[fake.Rarity].Color
		nameLabel.Text = fake.Icon .. " " .. fake.Name
		nameLabel.TextColor3 = fakeColor
		revealStroke.Color = fakeColor
		local progress = tick / info.RevealTicks
		task.wait(0.03 + (info.RevealMaxDelay - 0.03) * progress * progress)
	end

	nameLabel.Text = item.Icon .. " " .. item.Name
	nameLabel.TextColor3 = info.Color
	revealStroke.Color = info.Color
	rarityLabel.Text = string.upper(item.Rarity)
	rarityLabel.TextColor3 = info.Color
	newBadge.Visible = result.IsNew

	revealScale.Scale = 1 + 0.08 * info.Rank
	TweenService:Create(revealScale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()

	if info.Rank >= 4 then
		playFlash(info.Color, 0.2 + 0.1 * (info.Rank - 4))
	end
	if info.Rank >= 5 then
		task.spawn(shake, 0.4 + 0.3 * (info.Rank - 5), 6 + 4 * (info.Rank - 5))
	end
	if item.Rarity == "Mythic" then
		task.delay(0.35, playFlash, WHITE, 0.6)
		rainbow(1.5)
		nameLabel.TextColor3 = info.Color
		revealStroke.Color = info.Color
	end

	task.wait(0.4 + 0.2 * info.Rank)
	state.Revealing = false
	if state.Pending then
		applySnapshot(state.Pending)
		state.Pending = nil
	end

	task.delay(2.5, function()
		if state.RevealToken == token and not state.Busy then
			reveal.Visible = false
		end
	end)
end

---------------------------------------------------------------- roll

local function runCooldownBar(duration)
	cooldownFill.Size = UDim2.fromScale(0, 1)
	TweenService:Create(cooldownFill, TweenInfo.new(math.max(duration, 0.05), Enum.EasingStyle.Linear), {
		Size = UDim2.fromScale(1, 1),
	}):Play()
end

local function doRoll()
	if state.Busy or not state.Snapshot then
		return
	end
	state.Busy = true
	rollButton.Text = "🎲 ..."

	local started = os.clock()
	local cooldown = state.Snapshot.RollCooldown or SkillTree.BaseRollCooldown
	runCooldownBar(cooldown)

	local ok, result = pcall(Remotes.Roll.InvokeServer, Remotes.Roll)
	if ok and result and result.Ok then
		playReveal(result)
	elseif ok and result and result.Reason == "Cooldown" then
		task.wait(result.Remaining or 0.2)
	end

	local remaining = cooldown - (os.clock() - started)
	if remaining > 0 then
		task.wait(remaining)
	end
	rollButton.Text = "🎲 ROLL"
	state.Busy = false
end

rollButton.Activated:Connect(function()
	task.spawn(doRoll)
end)

autoButton.Activated:Connect(function()
	state.AutoRoll = not state.AutoRoll
	autoButton.Text = if state.AutoRoll then "AUTO: ON" else "AUTO: OFF"
	autoButton.BackgroundColor3 = if state.AutoRoll then Color3.fromRGB(60, 170, 90) else BUTTON_COLOR
end)

task.spawn(function()
	while true do
		if state.AutoRoll and not state.Busy then
			task.spawn(doRoll)
		end
		task.wait(0.1)
	end
end)

---------------------------------------------------------------- synchro avec le serveur

Remotes.DataSync.OnClientEvent:Connect(function(snapshot)
	if state.Revealing then
		state.Pending = snapshot
	else
		applySnapshot(snapshot)
	end
end)

task.spawn(function()
	local snapshot = Remotes.GetSnapshot:InvokeServer()
	if snapshot and not state.Snapshot then
		applySnapshot(snapshot)
	end
end)
