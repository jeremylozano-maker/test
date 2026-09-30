-- RollClient : UI du Roll, des Coins, de l'Inventaire et de l'Index (affichage uniquement, le serveur décide)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Items = require(Shared:WaitForChild("Items"))
local Rarities = require(Shared:WaitForChild("Rarities"))
local SkillTree = require(Shared:WaitForChild("SkillTree"))
local UIKit = require(Shared:WaitForChild("UIKit"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local create, corner, stroke, makeButton = UIKit.create, UIKit.corner, UIKit.stroke, UIKit.makeButton

local RARITY_SHORT = { Common = "COM", Uncommon = "UNC", Rare = "RARE", Epic = "EPIC", Legendary = "LEG", Mythic = "MYTH" }

local state = {
	Snapshot = nil,
	Pending = nil, -- snapshot reçu pendant une animation (évite de spoiler le résultat)
	Revealing = false,
	Busy = false,
	AutoRoll = false,
	RevealToken = 0,
}

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
	BackgroundColor3 = UIKit.WHITE,
	BackgroundTransparency = 1,
	Active = false,
})

-- Coins (en haut au centre)
local coinsFrame = create("Frame", {
	Parent = gui,
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 12),
	Size = UDim2.new(0, 200, 0, 46),
	BackgroundColor3 = UIKit.PANEL_COLOR,
	BorderSizePixel = 0,
}, { corner(14), stroke(3), UIKit.shine() })
UIKit.addStuds(coinsFrame, 3)

local coinsLabel = UIKit.label({
	Parent = coinsFrame,
	Position = UDim2.new(0, 10, 0, 6),
	Size = UDim2.new(1, -20, 1, -12),
	Text = "🪙 0",
	TextColor3 = UIKit.YELLOW,
})

-- Bouton ROLL (en bas au centre)
local rollButton = makeButton({
	Parent = gui,
	Name = "RollButton",
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -22),
	Size = UDim2.new(0, 230, 0, 74),
	BackgroundColor3 = UIKit.GREEN,
	Text = "🎲 ROLL",
	Studs = 4,
})

local _, cooldownFill = UIKit.makeBar({
	Parent = rollButton,
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, 2),
	Size = UDim2.new(1, 0, 0, 8),
}, UIKit.WHITE)

local autoButton = makeButton({
	Parent = gui,
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.new(0.5, 130, 1, -22),
	Size = UDim2.new(0, 120, 0, 54),
	Text = "AUTO: OFF",
	Visible = false,
	Studs = 2,
})

-- Boutons à droite
local inventoryButton = makeButton({
	Parent = gui,
	AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.new(1, -14, 0.5, -34),
	Size = UDim2.new(0, 150, 0, 56),
	BackgroundColor3 = UIKit.BLUE,
	Text = "🎒 Inventory",
	Studs = 3,
})

local indexButton = makeButton({
	Parent = gui,
	AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.new(1, -14, 0.5, 34),
	Size = UDim2.new(0, 150, 0, 56),
	BackgroundColor3 = UIKit.PURPLE,
	Text = "📖 Index",
	Studs = 3,
})

---------------------------------------------------------------- fenêtres Inventaire / Index

local function makeSidePanel(title, accent)
	local panel, body, titleLabel = UIKit.makePanel({
		Parent = gui,
		Title = title,
		Accent = accent,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -178, 0.5, 0),
		Size = UDim2.fromScale(0.32, 0.72),
		MinSize = Vector2.new(260, 240),
		MaxSize = Vector2.new(430, 580),
	})
	return panel, body, titleLabel
end

local inventoryPanel, inventoryBody = makeSidePanel("🎒 INVENTORY", UIKit.BLUE)
local inventoryList = UIKit.makeList({ Parent = inventoryBody, Size = UDim2.fromScale(1, 1) })

local indexPanel, indexBody, indexTitle = makeSidePanel("📖 INDEX", UIKit.PURPLE)
local _, indexFill = UIKit.makeBar({ Parent = indexBody, Size = UDim2.new(1, 0, 0, 14) }, UIKit.PURPLE)
local indexList = UIKit.makeList({ Parent = indexBody, Position = UDim2.new(0, 0, 0, 22), Size = UDim2.new(1, 0, 1, -22) })

local function renderInventory()
	UIKit.clearList(inventoryList)
	local inventory = state.Snapshot and state.Snapshot.Inventory or {}
	local order = 0
	for _, category in Items.Categories do
		order += 1
		UIKit.sectionHeader(inventoryList, order, Items.CategoryInfo[category].Label)
		local any = false
		for _, item in Items.ByCategory[category] do
			local count = inventory[item.Id] or 0
			if count > 0 then
				any = true
				order += 1
				UIKit.itemRow({
					Parent = inventoryList,
					LayoutOrder = order,
					Text = item.Icon .. " " .. item.Name,
					Color = Rarities.Info[item.Rarity].Color,
					Badge = "×" .. count,
				})
			end
		end
		if not any then
			order += 1
			UIKit.label({
				Parent = inventoryList,
				LayoutOrder = order,
				Size = UDim2.new(1, -10, 0, 22),
				Text = "—",
				TextColor3 = UIKit.GREY,
			})
		end
	end
end

local function renderIndex()
	UIKit.clearList(indexList)
	local index = state.Snapshot and state.Snapshot.Index or {}
	local found = 0
	local order = 0
	for _, category in Items.Categories do
		order += 1
		UIKit.sectionHeader(indexList, order, Items.CategoryInfo[category].Label)
		for _, item in Items.ByCategory[category] do
			order += 1
			local discovered = index[item.Id] == true
			if discovered then
				found += 1
			end
			UIKit.itemRow({
				Parent = indexList,
				LayoutOrder = order,
				Text = if discovered then item.Icon .. " " .. item.Name else "❔ " .. item.Name,
				Color = if discovered then Rarities.Info[item.Rarity].Color else UIKit.GREY,
				Badge = if discovered then RARITY_SHORT[item.Rarity] else "???",
				Height = 36,
			})
		end
	end
	indexTitle.Text = string.format("📖 INDEX  %d/%d", found, #Items.List)
	indexFill.Size = UDim2.fromScale(found / #Items.List, 1)
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
	Size = UDim2.fromScale(0.5, 0.24),
	BackgroundColor3 = UIKit.PANEL_COLOR,
	BorderSizePixel = 0,
}, {
	corner(20),
	UIKit.shine(Color3.fromRGB(160, 160, 180)),
	create("UISizeConstraint", { MinSize = Vector2.new(280, 130), MaxSize = Vector2.new(500, 190) }),
})
UIKit.addStuds(reveal, 6)
local revealStroke = stroke(6, UIKit.WHITE)
revealStroke.Parent = reveal
local revealScale = create("UIScale", { Parent = reveal, Scale = 1 })

-- Pastille de rareté en haut
local rarityChip = create("Frame", {
	Parent = reveal,
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 12),
	Size = UDim2.new(0.55, 0, 0.26, 0),
	BackgroundColor3 = UIKit.BUTTON_COLOR,
	BorderSizePixel = 0,
}, { corner(10), stroke(3), UIKit.shine() })

local rarityLabel = UIKit.label({
	Parent = rarityChip,
	Position = UDim2.new(0, 8, 0, 3),
	Size = UDim2.new(1, -16, 1, -6),
	Text = "",
})

local nameLabel = UIKit.label({
	Parent = reveal,
	Position = UDim2.fromScale(0.05, 0.42),
	Size = UDim2.fromScale(0.9, 0.46),
	Text = "",
	TextStrokeTransparency = 0,
})

local newBadge = create("TextLabel", {
	Parent = reveal,
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, 14, 0, -18),
	Size = UDim2.new(0, 86, 0, 34),
	Rotation = 12,
	BackgroundColor3 = UIKit.RED,
	BorderSizePixel = 0,
	Text = "NEW!",
	TextColor3 = UIKit.WHITE,
	TextStrokeTransparency = 0.3,
	Font = UIKit.TITLE_FONT,
	TextScaled = true,
	Visible = false,
}, { corner(10), stroke(3), UIKit.shine(), UIKit.padding(4) })

-- Better Rolls : pastille "objet bonus" sous la fenêtre de révélation
local bonusChip = create("Frame", {
	Parent = reveal,
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 1, 10),
	Size = UDim2.new(0.8, 0, 0, 34),
	BackgroundColor3 = UIKit.ORANGE,
	BorderSizePixel = 0,
	Visible = false,
}, { corner(10), stroke(3), UIKit.shine() })

local bonusLabel = UIKit.label({
	Parent = bonusChip,
	Position = UDim2.new(0, 8, 0, 4),
	Size = UDim2.new(1, -16, 1, -8),
	Text = "",
})

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

local function setRevealColor(color)
	nameLabel.TextColor3 = color
	revealStroke.Color = color
	rarityChip.BackgroundColor3 = UIKit.darken(color, 0.25)
end

local function rainbow(duration)
	local start = os.clock()
	while os.clock() - start < duration do
		setRevealColor(Color3.fromHSV((os.clock() * 0.8) % 1, 0.8, 1))
		task.wait(0.03)
	end
end

local function playReveal(result)
	local item = Items.ById[result.ItemId]
	local info = Rarities.Info[item.Rarity]
	state.Revealing = true
	state.RevealToken += 1
	local token = state.RevealToken

	-- Quick Reveal : animation plus courte
	local speed = SkillTree.GetRevealDurationMultiplier(state.Snapshot and state.Snapshot.Skills or {})

	reveal.Visible = true
	newBadge.Visible = false
	bonusChip.Visible = false
	rarityLabel.Text = "🎲 Rolling..."
	rarityChip.BackgroundColor3 = UIKit.BUTTON_COLOR

	-- défilement qui ralentit : plus c'est rare, plus c'est long
	for tick = 1, info.RevealTicks do
		local fake = Items.List[math.random(#Items.List)]
		nameLabel.Text = fake.Icon .. " " .. fake.Name
		nameLabel.TextColor3 = Rarities.Info[fake.Rarity].Color
		revealStroke.Color = Rarities.Info[fake.Rarity].Color
		local progress = tick / info.RevealTicks
		task.wait((0.03 + (info.RevealMaxDelay - 0.03) * progress * progress) * speed)
	end

	nameLabel.Text = item.Icon .. " " .. item.Name
	rarityLabel.Text = string.upper(item.Rarity)
	setRevealColor(info.Color)
	newBadge.Visible = result.IsNew
	local bonusItem = result.BonusItemId and Items.ById[result.BonusItemId]
	if bonusItem then
		bonusLabel.Text = string.format("🎁 BONUS : %s %s", bonusItem.Icon, bonusItem.Name)
		bonusChip.BackgroundColor3 = UIKit.darken(Rarities.Info[bonusItem.Rarity].Color, 0.25)
		bonusChip.Visible = true
	end

	revealScale.Scale = 1 + 0.08 * info.Rank
	TweenService:Create(revealScale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()

	if info.Rank >= 4 then
		playFlash(info.Color, 0.2 + 0.1 * (info.Rank - 4))
	end
	if info.Rank >= 5 then
		task.spawn(shake, 0.4 + 0.3 * (info.Rank - 5), 6 + 4 * (info.Rank - 5))
	end
	if item.Rarity == "Mythic" then
		task.delay(0.35, playFlash, UIKit.WHITE, 0.6)
		rainbow(1.5)
		setRevealColor(info.Color)
	end

	task.wait((0.4 + 0.2 * info.Rank) * speed)
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
	autoButton.BackgroundColor3 = if state.AutoRoll then UIKit.GREEN else UIKit.BUTTON_COLOR
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
