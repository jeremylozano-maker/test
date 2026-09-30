-- SkillTreeClient : écran du Skill Tree (hexagones, lignes, fenêtre d'amélioration, zoom / déplacement).
-- Affichage uniquement : le client DEMANDE un achat (Remotes.PurchaseSkill), le serveur décide et renvoie
-- le nouvel état (Coins + niveaux) par Remotes.DataSync.
local Debris = game:GetService("Debris")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local Shared = ReplicatedStorage:WaitForChild("Shared")
local SkillTree = require(Shared:WaitForChild("SkillTree"))
local UIKit = require(Shared:WaitForChild("UIKit"))
local HexUI = require(Shared:WaitForChild("HexUI"))
local HudState = require(Shared:WaitForChild("HudState"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local Config = SkillTree.Config
local Layout = Config.Layout
local create, corner, stroke, makeButton = UIKit.create, UIKit.corner, UIKit.stroke, UIKit.makeButton

local LOCKED_FILL = Color3.fromRGB(42, 45, 60)
local LOCKED_BORDER = Color3.fromRGB(75, 80, 98)
local LINE_OFF = Color3.fromRGB(55, 60, 78)
local GOLD = UIKit.YELLOW
local HUB_COLOR = Color3.fromRGB(255, 190, 60)
local DRAG_THRESHOLD = 6 -- pixels avant qu'un clic devienne un déplacement

local REFUSAL_TEXT = {
	NotEnoughCoins = "❌ Not enough Coins",
	Locked = "🔒 Requirement missing",
	MaxLevel = "⭐ Max level reached",
	ComingSoon = "🚧 Coming soon",
	InvalidSkill = "❌ Invalid skill",
	NoData = "⏳ Loading your data",
}

local state = {
	Snapshot = nil,
	Open = false,
	Hovered = nil, -- skillId affiché dans l'encart d'infos
	Pending = false, -- achat en cours (un seul à la fois)
	NodeStates = {}, -- dernier état affiché, pour animer les déblocages
	Zoom = 1,
	Pan = Vector2.zero,
	Drag = nil,
	LastDragEnd = 0,
	ShownCoins = 0,
}

---------------------------------------------------------------- utilitaires

local sounds = {}
for name, soundId in Config.Sounds do
	if soundId ~= "" then
		sounds[name] = create("Sound", { SoundId = soundId, Volume = 0.5, Parent = SoundService })
	end
end

local function playSound(name)
	if sounds[name] then
		SoundService:PlayLocalSound(sounds[name])
	end
end

local function formatNumber(value)
	local text = tostring(math.floor(value))
	local formatted = text:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (formatted:gsub("^,", ""))
end

local ROMAN = { "I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X",
	"XI", "XII", "XIII", "XIV", "XV", "XVI", "XVII", "XVIII", "XIX", "XX" }

local function skillTitle(skillId, level)
	local skill = Config.Skills[skillId]
	local suffix = if level > 0 and skill.MaxLevel > 1 then " " .. (ROMAN[level] or tostring(level)) else ""
	return skill.Icon .. " " .. string.upper(skill.Name) .. suffix
end

local function getSkills()
	return state.Snapshot and state.Snapshot.Skills or {}
end

local function getCoins()
	return state.Snapshot and state.Snapshot.Coins or 0
end

---------------------------------------------------------------- bouton d'ouverture (en bas, à droite du ROLL)

local hudGui = create("ScreenGui", {
	Name = "SkillsButtonUI",
	ResetOnSpawn = false,
	Parent = player:WaitForChild("PlayerGui"),
})

local openButton = UIKit.makeIconButton({
	Parent = hudGui,
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.new(0.5, 80, 1, -16),
	Size = UDim2.new(0, 104, 0, 96),
	BackgroundColor3 = UIKit.PURPLE,
	Icon = "⬆️",
	Label = "Skills",
	Studs = 2,
})

-- nombre d'améliorations achetables maintenant
local openBadge = UIKit.makeCountBadge(openButton)

-- visible seulement sur l'écran normal (caché pendant la fenêtre des dés et la construction)
local function applyHudMode(hudMode)
	openButton.Visible = hudMode == "Main"
end
HudState.Changed:Connect(applyHudMode)
applyHudMode(HudState.Mode)

---------------------------------------------------------------- écran plein

local gui = create("ScreenGui", {
	Name = "SkillTreeUI",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	DisplayOrder = 5,
	Enabled = false,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	Parent = player.PlayerGui,
})

local background = create("Frame", {
	Parent = gui,
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = Color3.fromRGB(14, 16, 30),
	BackgroundTransparency = 0.06,
	Active = true, -- bloque les clics vers le jeu derrière
}, {
	create("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new(Color3.fromRGB(40, 46, 80), Color3.fromRGB(10, 10, 20)),
	}),
})

local viewport = create("Frame", {
	Parent = gui,
	Position = UDim2.new(0, 0, 0, 118),
	Size = UDim2.new(1, 0, 1, -150),
	BackgroundTransparency = 1,
	ClipsDescendants = true,
})

-- En-tête : titre, Coins, bouton fermer
local titlePill = create("Frame", {
	Parent = gui,
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 62),
	Size = UDim2.new(0, 280, 0, 48),
	BackgroundColor3 = Color3.fromRGB(40, 175, 150),
	BorderSizePixel = 0,
}, { corner(14), stroke(3), UIKit.shine() })
UIKit.addStuds(titlePill, 4)
UIKit.label({
	Parent = titlePill,
	Position = UDim2.new(0, 10, 0, 6),
	Size = UDim2.new(1, -20, 1, -12),
	Text = "🌳 SKILL TREE",
})

local closeButton = makeButton({
	Parent = gui,
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -16, 0, 62),
	Size = UDim2.fromOffset(48, 48),
	BackgroundColor3 = UIKit.RED,
	Text = "✕",
})

local coinsPill = create("Frame", {
	Parent = gui,
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -76, 0, 62),
	Size = UDim2.new(0, 190, 0, 48),
	BackgroundColor3 = UIKit.PANEL_COLOR,
	BorderSizePixel = 0,
}, { corner(14), stroke(3), UIKit.shine() })
UIKit.addStuds(coinsPill, 3)
local coinsLabel = UIKit.label({
	Parent = coinsPill,
	Position = UDim2.new(0, 10, 0, 6),
	Size = UDim2.new(1, -20, 1, -12),
	Text = "🪙 0",
	TextColor3 = UIKit.YELLOW,
})

UIKit.label({
	Parent = gui,
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -8),
	Size = UDim2.new(0.9, 0, 0, 22),
	Text = if UserInputService.TouchEnabled and not UserInputService.MouseEnabled
		then "Pinch to zoom • Drag to move • Tap a hexagon to buy it"
		else "Wheel: zoom • Drag: move • Click a hexagon to buy it • Key K",
	TextColor3 = UIKit.GREY,
	Font = UIKit.TEXT_FONT,
})

---------------------------------------------------------------- canevas de l'arbre (zoom + déplacement)

-- Taille du canevas : englobe toutes les positions (nœuds, centre, noms de branches) + une marge
local CANVAS_MARGIN = Layout.NodeSize
local minX, maxX, minY, maxY = 0, 0, 0, 0
local function includePosition(position)
	minX, maxX = math.min(minX, position[1]), math.max(maxX, position[1])
	minY, maxY = math.min(minY, position[2]), math.max(maxY, position[2])
end
for _, skillId in SkillTree.GetTreeSkillIds() do
	includePosition(Config.Skills[skillId].Position)
end
for _, branchId in Config.BranchOrder do
	includePosition(Config.Branches[branchId].LabelPosition)
end
local CANVAS_WIDTH = (maxX - minX) * Layout.CellSize + CANVAS_MARGIN * 2
local CANVAS_HEIGHT = (maxY - minY) * Layout.CellSize + CANVAS_MARGIN * 2
-- position du centre de l'arbre (0,0) dans le canevas
local CANVAS_CENTER = Vector2.new(-minX * Layout.CellSize + CANVAS_MARGIN, -minY * Layout.CellSize + CANVAS_MARGIN)

local canvas = create("Frame", {
	Parent = viewport,
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(CANVAS_WIDTH, CANVAS_HEIGHT),
	BackgroundTransparency = 1,
})
local canvasScale = create("UIScale", { Parent = canvas })

local function toCanvas(position)
	return CANVAS_CENTER + Vector2.new(position[1], position[2]) * Layout.CellSize
end

local function applyView()
	canvas.Position = UDim2.new(0.5, state.Pan.X, 0.5, state.Pan.Y)
	canvasScale.Scale = state.Zoom
end

local function fitZoom()
	local size = viewport.AbsoluteSize
	local fit = math.min(size.X / CANVAS_WIDTH, size.Y / CANVAS_HEIGHT)
	return math.clamp(fit, Layout.MinZoom, 1.1)
end

local function zoomBy(factor)
	state.Zoom = math.clamp(state.Zoom * factor, Layout.MinZoom, Layout.MaxZoom)
	applyView()
end

---------------------------------------------------------------- lignes (prérequis)

local lines = {} -- { { Fill, Child, Color } }

local function addLine(from, to, childId)
	local color = Config.Branches[Config.Skills[childId].Branch].Color
	HexUI.makeLine(canvas, from, to, 14, UIKit.DARK, 1)
	local fill = HexUI.makeLine(canvas, from, to, 8, LINE_OFF, 2)
	table.insert(lines, { Fill = fill, Child = childId, Color = color, Active = false })
end

for _, skillId in SkillTree.GetTreeSkillIds() do
	local skill = Config.Skills[skillId]
	local target = toCanvas(skill.Position)
	local prerequisites = skill.Prerequisites or {}
	if #prerequisites == 0 then
		addLine(CANVAS_CENTER, target, skillId) -- racine de branche : reliée au centre
	end
	for _, requirement in prerequisites do
		addLine(toCanvas(Config.Skills[requirement.Skill].Position), target, skillId)
	end
end

---------------------------------------------------------------- hexagone central + noms des branches

local hub = create("Frame", {
	Parent = canvas,
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromOffset(CANVAS_CENTER.X, CANVAS_CENTER.Y),
	Size = UDim2.fromOffset(Layout.HubSize, Layout.HubSize),
	BackgroundTransparency = 1,
	ZIndex = 3,
})
HexUI.makeLayer(hub, 1.2, HUB_COLOR, 0.7, 1, false)
HexUI.makeLayer(hub, 1, UIKit.DARK, 0, 2, false)
HexUI.makeLayer(hub, 0.88, HUB_COLOR, 0, 3, true)
local hubScale = create("UIScale", { Parent = hub })
UIKit.label({
	Parent = hub,
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.36),
	Size = UDim2.fromScale(0.5, 0.26),
	Text = "🌳",
	ZIndex = 4,
})
UIKit.label({
	Parent = hub,
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.58),
	Size = UDim2.fromScale(0.62, 0.16),
	Text = "SKILL TREE",
	ZIndex = 4,
})
local hubLevelLabel = UIKit.label({
	Parent = hub,
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.74),
	Size = UDim2.fromScale(0.5, 0.11),
	Text = "",
	Font = UIKit.TEXT_FONT,
	ZIndex = 4,
})

for _, branchId in Config.BranchOrder do
	local branch = Config.Branches[branchId]
	local position = toCanvas(branch.LabelPosition)
	local pill = create("Frame", {
		Parent = canvas,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(position.X, position.Y),
		Size = UDim2.fromOffset(170, 38),
		BackgroundColor3 = branch.Color,
		BorderSizePixel = 0,
		ZIndex = 3,
	}, { corner(12), stroke(3), UIKit.shine() })
	UIKit.label({
		Parent = pill,
		Position = UDim2.new(0, 8, 0, 4),
		Size = UDim2.new(1, -16, 1, -8),
		Text = branch.Icon .. " " .. branch.Name,
		ZIndex = 4,
	})
end

---------------------------------------------------------------- nœuds hexagonaux

local nodes = {} -- [skillId] = { Button, Scale, Glow, Border, Fill, Icon, Name, Level, Lock, Max, Ready }
local showInfo, hideInfo, requestUpgrade -- définis plus bas

local function nodeLabel(parent, y, height, text, font)
	return UIKit.label({
		Parent = parent,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, y),
		Size = UDim2.fromScale(0.62, height),
		Text = text,
		Font = font or UIKit.TITLE_FONT,
		ZIndex = 5,
	})
end

local function createNode(skillId)
	local skill = Config.Skills[skillId]
	local position = toCanvas(skill.Position)
	local button = create("TextButton", {
		Parent = canvas,
		Name = skillId,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(position.X, position.Y),
		Size = UDim2.fromOffset(Layout.NodeSize, Layout.NodeSize),
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Text = "",
		ZIndex = 4,
	})
	local node = {
		Button = button,
		Scale = create("UIScale", { Parent = button }),
		Glow = HexUI.makeLayer(button, 1.24, Color3.new(1, 1, 1), 1, 1, false),
		Border = HexUI.makeLayer(button, 1, UIKit.DARK, 0, 2, false),
		Fill = HexUI.makeLayer(button, 0.86, LOCKED_FILL, 0, 3, true),
		Icon = nodeLabel(button, 0.28, 0.26, skill.Icon),
		Name = nodeLabel(button, 0.53, 0.14, skill.Name),
		Level = nodeLabel(button, 0.7, 0.13, "0/" .. skill.MaxLevel, UIKit.TEXT_FONT),
		Lock = nodeLabel(button, 0.28, 0.26, "🔒"),
	}
	node.Max = create("TextLabel", {
		Parent = button,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.92),
		Size = UDim2.fromOffset(54, 22),
		BackgroundColor3 = GOLD,
		BorderSizePixel = 0,
		Text = "MAX",
		TextColor3 = UIKit.DARK,
		Font = UIKit.TITLE_FONT,
		TextScaled = true,
		ZIndex = 6,
		Visible = false,
	}, { corner(8), stroke(2), UIKit.padding(2) })
	node.Ready = create("Frame", {
		Parent = button,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.82, 0.18),
		Size = UDim2.fromOffset(20, 20),
		BackgroundColor3 = UIKit.GREEN,
		ZIndex = 6,
		Visible = false,
	}, { corner(10), stroke(2) })

	button.MouseEnter:Connect(function()
		TweenService:Create(node.Scale, TweenInfo.new(0.12), { Scale = 1.1 }):Play()
		playSound("Hover")
		showInfo(skillId)
	end)
	button.MouseLeave:Connect(function()
		TweenService:Create(node.Scale, TweenInfo.new(0.12), { Scale = 1 }):Play()
		hideInfo(skillId)
	end)
	-- un clic = un achat (pas de fenêtre de confirmation)
	button.Activated:Connect(function()
		-- un glisser pour déplacer l'arbre ne doit pas acheter
		if (state.Drag and state.Drag.Moved) or os.clock() - state.LastDragEnd < 0.15 then
			return
		end
		playSound("Click")
		showInfo(skillId)
		requestUpgrade(skillId)
	end)
	nodes[skillId] = node
end

for _, skillId in SkillTree.GetTreeSkillIds() do
	createNode(skillId)
end

-- petites étoiles qui partent du nœud (achat)
local function burst(skillId, color)
	local center = toCanvas(Config.Skills[skillId].Position)
	for index = 1, 10 do
		local angle = index / 10 * math.pi * 2
		local star = UIKit.label({
			Parent = canvas,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(center.X, center.Y),
			Size = UDim2.fromOffset(26, 26),
			Text = "✦",
			TextColor3 = color,
			ZIndex = 8,
		})
		local distance = math.random(60, 100)
		TweenService:Create(star, TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Position = UDim2.fromOffset(center.X + math.cos(angle) * distance, center.Y + math.sin(angle) * distance),
			TextTransparency = 1,
			TextStrokeTransparency = 1,
		}):Play()
		Debris:AddItem(star, 0.6)
	end
end

local function pop(node, fromScale)
	node.Scale.Scale = fromScale
	TweenService:Create(node.Scale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
end

-- Met un nœud à jour selon son état : Locked / ComingSoon / Available / Purchased / Maxed
local function renderNode(skillId)
	local node = nodes[skillId]
	local skill = Config.Skills[skillId]
	local skills = getSkills()
	local level = SkillTree.GetLevel(skills, skillId)
	local nodeState = SkillTree.GetNodeState(skills, skillId)
	local color = Config.Branches[skill.Branch].Color
	local isClosed = nodeState == "Locked" or nodeState == "ComingSoon"

	HexUI.setColor(node.Glow, if nodeState == "Maxed" then GOLD else color)
	HexUI.setTransparency(node.Glow, if isClosed then 1 elseif nodeState == "Maxed" then 0.45 else 0.72)
	HexUI.setColor(node.Border, if isClosed then LOCKED_BORDER elseif nodeState == "Maxed" then GOLD
		elseif nodeState == "Purchased" then UIKit.lighten(color, 0.35) else color)
	HexUI.setColor(node.Fill, if isClosed then LOCKED_FILL elseif nodeState == "Available" then UIKit.darken(color, 0.55)
		elseif nodeState == "Maxed" then UIKit.lighten(color, 0.15) else color)

	local textColor = if isClosed then UIKit.GREY else UIKit.WHITE
	node.Name.TextColor3 = textColor
	node.Level.TextColor3 = textColor
	node.Icon.Visible = not isClosed
	node.Lock.Visible = isClosed
	node.Lock.Text = if nodeState == "ComingSoon" then "🚧" else "🔒"
	node.Level.Text = if nodeState == "ComingSoon" then "SOON" else string.format("%d/%d", level, skill.MaxLevel)
	node.Max.Visible = nodeState == "Maxed"
	node.Ready.Visible = SkillTree.CanUpgrade(skills, getCoins(), skillId) == true

	-- animation quand un nœud se débloque
	local previous = state.NodeStates[skillId]
	if previous == "Locked" and nodeState == "Available" and state.Open then
		pop(node, 1.35)
		playSound("Unlock")
	end
	state.NodeStates[skillId] = nodeState
end

local function renderLines()
	local skills = getSkills()
	for _, line in lines do
		local active = SkillTree.ArePrerequisitesMet(skills, line.Child)
		if active ~= line.Active then
			line.Active = active
			TweenService:Create(line.Fill, TweenInfo.new(0.4), { BackgroundColor3 = if active then line.Color else LINE_OFF }):Play()
		end
	end
end

local function renderHub()
	local total = 0
	for _, skillId in SkillTree.GetTreeSkillIds() do
		total += SkillTree.GetLevel(getSkills(), skillId)
	end
	hubLevelLabel.Text = "Total level " .. total
end

---------------------------------------------------------------- encart d'infos (survol / toucher)
-- Aucun bouton ici : l'achat se fait directement en cliquant sur l'hexagone.

local infoPanel = create("Frame", {
	Parent = gui,
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -36),
	Size = UDim2.new(0.9, 0, 0, 150),
	BackgroundColor3 = UIKit.PANEL_COLOR,
	BorderSizePixel = 0,
	Visible = false,
	ZIndex = 10,
}, {
	corner(16),
	stroke(4),
	UIKit.shine(Color3.fromRGB(165, 165, 185)),
	create("UISizeConstraint", { MaxSize = Vector2.new(560, 150) }),
})
UIKit.addStuds(infoPanel, 5)

local infoAccent = create("Frame", {
	Parent = infoPanel,
	Position = UDim2.new(0, 10, 0, 10),
	Size = UDim2.new(0, 10, 1, -20),
	BorderSizePixel = 0,
}, { corner(5) })

local function infoText(y, height, color, font)
	return UIKit.label({
		Parent = infoPanel,
		Position = UDim2.new(0, 32, 0, y),
		Size = UDim2.new(1, -44, 0, height),
		Text = "",
		TextColor3 = color or UIKit.WHITE,
		Font = font or UIKit.TITLE_FONT,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
end

local titleText = infoText(8, 30)
local bonusText = infoText(42, 22, Color3.fromRGB(130, 230, 140))
local costText = infoText(68, 22, UIKit.YELLOW)
local statusText = infoText(94, 20, UIKit.RED, UIKit.TEXT_FONT)
local hintText = infoText(118, 22, UIKit.GREEN)

local function prerequisitesText(skillId)
	local parts = {}
	for _, requirement in SkillTree.GetMissingPrerequisites(getSkills(), skillId) do
		table.insert(parts, string.format("%s lvl %d", Config.Skills[requirement.Skill].Name, requirement.Level))
	end
	return "🔒 Requires: " .. table.concat(parts, ", ")
end

local function renderInfo()
	local skillId = state.Hovered
	infoPanel.Visible = skillId ~= nil
	if not skillId then
		return
	end
	local skill = Config.Skills[skillId]
	local skills = getSkills()
	local level = SkillTree.GetLevel(skills, skillId)
	local canUpgrade, reason, cost = SkillTree.CanUpgrade(skills, getCoins(), skillId)

	infoAccent.BackgroundColor3 = Config.Branches[skill.Branch].Color
	titleText.Text = string.format("%s   •   %d/%d", skillTitle(skillId, level), level, skill.MaxLevel)

	if reason == "MaxLevel" then
		bonusText.Text = "Bonus: " .. SkillTree.DescribeBonus(skillId, level)
		costText.Text = ""
		statusText.Text = "⭐ MAX LEVEL"
		statusText.TextColor3 = GOLD
		hintText.Text = ""
		return
	end
	bonusText.Text = string.format("Bonus: %s   ➜   %s",
		SkillTree.DescribeBonus(skillId, level), SkillTree.DescribeBonus(skillId, level + 1))
	cost = cost or SkillTree.GetSkillCost(skillId, level + 1)
	costText.Text = "Cost: 🪙 " .. formatNumber(cost)
	costText.TextColor3 = if getCoins() >= cost then UIKit.YELLOW else UIKit.RED
	statusText.TextColor3 = UIKit.RED
	statusText.Text = if reason == "Locked" then prerequisitesText(skillId) else (REFUSAL_TEXT[reason] or skill.Description)
	if not reason then
		statusText.TextColor3 = UIKit.GREY
	end
	hintText.Text = if canUpgrade then "👆 Click to upgrade" else ""
end

function showInfo(skillId)
	state.Hovered = skillId
	renderInfo()
end

function hideInfo(skillId)
	if skillId == nil or state.Hovered == skillId then
		state.Hovered = nil
		renderInfo()
	end
end

---------------------------------------------------------------- achat au clic

-- petit texte qui monte au-dessus d'un hexagone
local function floatText(skillId, text, color)
	local center = toCanvas(Config.Skills[skillId].Position)
	local label = UIKit.label({
		Parent = canvas,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromOffset(center.X, center.Y - Layout.NodeSize * 0.45),
		Size = UDim2.fromOffset(240, 28),
		Text = text,
		TextColor3 = color,
		ZIndex = 9,
	})
	TweenService:Create(label, TweenInfo.new(0.9), {
		Position = UDim2.fromOffset(center.X, center.Y - Layout.NodeSize * 0.45 - 40),
		TextTransparency = 1,
		TextStrokeTransparency = 1,
	}):Play()
	Debris:AddItem(label, 1)
end

local function shakeNode(skillId)
	local button = nodes[skillId].Button
	local base = button.Position
	for _, offset in { -8, 8, -5, 5, -2, 0 } do
		button.Position = base + UDim2.fromOffset(offset, 0)
		task.wait(0.03)
	end
	button.Position = base
end

local function refuse(skillId, reason)
	playSound("Error")
	floatText(skillId, REFUSAL_TEXT[reason] or "❌ Purchase failed", UIKit.RED)
	task.spawn(shakeNode, skillId)
end

local function celebrate(skillId, level, cost)
	local node = nodes[skillId]
	local skill = Config.Skills[skillId]
	local color = Config.Branches[skill.Branch].Color
	HexUI.setColor(node.Fill, Color3.new(1, 1, 1))
	pop(node, 1.3)
	burst(skillId, if level >= skill.MaxLevel then GOLD else color)
	floatText(skillId, if level >= skill.MaxLevel then "⭐ MAX!" else "-" .. formatNumber(cost) .. " 🪙", GOLD)
	playSound(if level >= skill.MaxLevel then "Max" else "Purchase")
	task.delay(0.12, renderNode, skillId)
end

function requestUpgrade(skillId)
	if state.Pending then
		return
	end
	-- vérification locale uniquement pour le retour visuel ; le serveur revérifie tout
	local canUpgrade, reason = SkillTree.CanUpgrade(getSkills(), getCoins(), skillId)
	if not canUpgrade then
		refuse(skillId, reason)
		return
	end
	state.Pending = true
	local ok, result = pcall(Remotes.PurchaseSkill.InvokeServer, Remotes.PurchaseSkill, skillId)
	state.Pending = false
	if ok and type(result) == "table" and result.Ok then
		celebrate(skillId, result.Level, result.Cost)
	else
		refuse(skillId, if ok and type(result) == "table" then result.Reason else nil)
	end
	renderInfo()
end

---------------------------------------------------------------- Coins (avec animation)

local coinsValue = create("NumberValue", { Parent = gui })
coinsValue.Changed:Connect(function(value)
	coinsLabel.Text = "🪙 " .. formatNumber(value)
end)

local function showCoinChange(delta)
	local floating = UIKit.label({
		Parent = gui,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -76, 0, 114),
		Size = UDim2.fromOffset(190, 26),
		Text = (if delta < 0 then "-" else "+") .. formatNumber(math.abs(delta)),
		TextColor3 = if delta < 0 then UIKit.RED else UIKit.GREEN,
	})
	TweenService:Create(floating, TweenInfo.new(0.8), {
		Position = UDim2.new(1, -76, 0, 140),
		TextTransparency = 1,
		TextStrokeTransparency = 1,
	}):Play()
	Debris:AddItem(floating, 0.85)
end

local function renderCoins()
	local coins = getCoins()
	if state.Open and coins ~= state.ShownCoins then
		showCoinChange(coins - state.ShownCoins)
		TweenService:Create(coinsValue, TweenInfo.new(0.5, Enum.EasingStyle.Quad), { Value = coins }):Play()
	else
		coinsValue.Value = coins
	end
	state.ShownCoins = coins
end

---------------------------------------------------------------- mise à jour générale

local function renderAll()
	for skillId in nodes do
		renderNode(skillId)
	end
	renderLines()
	renderHub()
	renderCoins()
	renderInfo()
	local readyCount = 0
	for skillId in nodes do
		if SkillTree.CanUpgrade(getSkills(), getCoins(), skillId) == true then
			readyCount += 1
		end
	end
	openBadge.Text = tostring(readyCount)
	openBadge.Visible = readyCount > 0
end

---------------------------------------------------------------- ouverture / fermeture

local function setOpen(open)
	if state.Open == open then
		return
	end
	state.Open = open
	if open then
		gui.Enabled = true
		playSound("Open")
		state.Pan = Vector2.zero
		state.Zoom = fitZoom()
		applyView()
		renderAll()
		background.BackgroundTransparency = 1
		TweenService:Create(background, TweenInfo.new(0.25), { BackgroundTransparency = 0.06 }):Play()
		canvasScale.Scale = state.Zoom * 0.85
		TweenService:Create(canvasScale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = state.Zoom }):Play()
		hubScale.Scale = 0.6
		TweenService:Create(hubScale, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	else
		hideInfo(nil)
		state.Drag = nil
		gui.Enabled = false
	end
end

openButton.Activated:Connect(function()
	setOpen(not state.Open)
end)
closeButton.Activated:Connect(function()
	setOpen(false)
end)

---------------------------------------------------------------- navigation : molette, glisser, pincer

local function isInside(guiObject, point)
	local topLeft, size = guiObject.AbsolutePosition, guiObject.AbsoluteSize
	return point.X >= topLeft.X and point.X <= topLeft.X + size.X and point.Y >= topLeft.Y and point.Y <= topLeft.Y + size.Y
end

-- position de l'input dans le repère de l'écran (l'écran du Skill Tree ignore la barre du haut)
local function screenPoint(input)
	return Vector2.new(input.Position.X, input.Position.Y) + GuiService:GetGuiInset()
end

UserInputService.InputBegan:Connect(function(input)
	if not state.Open then
		return
	end
	local isPointer = input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
	if not isPointer then
		return
	end
	local point = screenPoint(input)
	if isInside(viewport, point) then
		state.Drag = { Input = input, Start = point, StartPan = state.Pan, Moved = false }
	end
end)

UserInputService.InputChanged:Connect(function(input)
	if not state.Open then
		return
	end
	if input.UserInputType == Enum.UserInputType.MouseWheel then
		zoomBy(1 + 0.12 * input.Position.Z)
		return
	end
	local drag = state.Drag
	if not drag then
		return
	end
	local isDragInput = input.UserInputType == Enum.UserInputType.MouseMovement
		or (input.UserInputType == Enum.UserInputType.Touch and input == drag.Input)
	if isDragInput then
		local delta = screenPoint(input) - drag.Start
		if delta.Magnitude > DRAG_THRESHOLD then
			drag.Moved = true
		end
		if drag.Moved then
			state.Pan = drag.StartPan + delta
			applyView()
		end
	end
end)

UserInputService.InputEnded:Connect(function(input)
	local drag = state.Drag
	if drag and (input.UserInputType == Enum.UserInputType.MouseButton1 or input == drag.Input) then
		if drag.Moved then
			state.LastDragEnd = os.clock()
		end
		state.Drag = nil
	end
end)

local pinchStartZoom = 1
UserInputService.TouchPinch:Connect(function(_, scale, _, inputState)
	if not state.Open then
		return
	end
	if inputState == Enum.UserInputState.Begin then
		pinchStartZoom = state.Zoom
	elseif inputState == Enum.UserInputState.Change then
		state.Zoom = math.clamp(pinchStartZoom * scale, Layout.MinZoom, Layout.MaxZoom)
		applyView()
	end
end)

-- Touche K : ouvrir / fermer
UserInputService.InputBegan:Connect(function(input, processed)
	if not processed and input.KeyCode == Enum.KeyCode.K then
		setOpen(not state.Open)
	end
end)

---------------------------------------------------------------- animation des nœuds disponibles (lueur qui pulse)

RunService.RenderStepped:Connect(function()
	if not state.Open then
		return
	end
	local pulse = 0.55 + 0.2 * math.sin(os.clock() * 4)
	for skillId, node in nodes do
		if state.NodeStates[skillId] == "Available" then
			HexUI.setTransparency(node.Glow, pulse)
		end
	end
end)

---------------------------------------------------------------- synchro avec le serveur

local function applySnapshot(snapshot)
	state.Snapshot = snapshot
	renderAll()
end

Remotes.DataSync.OnClientEvent:Connect(applySnapshot)

task.spawn(function()
	local snapshot = Remotes.GetSnapshot:InvokeServer()
	if snapshot and not state.Snapshot then
		applySnapshot(snapshot)
	end
end)

renderAll()
