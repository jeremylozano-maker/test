-- BuildClient : modes BUILD et DELETE (fantôme, snap sur la grille, son à chaque case, PC + mobile)
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Items = require(Shared:WaitForChild("Items"))
local Rarities = require(Shared:WaitForChild("Rarities"))
local Grid = require(Shared:WaitForChild("Grid"))
local SkillTree = require(Shared:WaitForChild("SkillTree"))
local ItemVisuals = require(Shared:WaitForChild("ItemVisuals"))
local UIKit = require(Shared:WaitForChild("UIKit"))
local HudState = require(Shared:WaitForChild("HudState"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local create, makeButton = UIKit.create, UIKit.makeButton

-- Remplace par l'id d'un son de la Toolbox si tu veux un autre "ploc" (ex : "rbxassetid://123456")
local PLOC_SOUND_ID = "rbxasset://sounds/clickfast.wav"
local VALID_COLOR = Color3.fromRGB(80, 255, 120)
local INVALID_COLOR = Color3.fromRGB(255, 60, 60)

local gridInfo = ReplicatedStorage:WaitForChild("GridInfo")
local waveInfo = ReplicatedStorage:WaitForChild("WaveInfo")
local grid = Grid.FromData(HttpService:JSONDecode(gridInfo:GetAttribute("Data")))
local placedFolder = workspace:WaitForChild("PlacedObjects")

local plocSound = create("Sound", { SoundId = PLOC_SOUND_ID, Volume = 0.6, Parent = SoundService })

local state = {
	Mode = nil, -- "Build" | "Delete" | nil
	SelectedId = nil,
	Tab = "Block", -- onglet ouvert dans la fenêtre BUILD
	SortIndex = 1, -- tri choisi dans la fenêtre BUILD (voir SORTS)
	Inventory = {},
	Skills = {}, -- niveaux du Skill Tree (Build Capacity / Build Height), envoyés par le serveur
	Ghost = nil,
	Target = nil, -- Build : { X, Z, Valid } / Delete : { Model }
	LastCell = nil,
	TouchPoint = nil,
}

local isTouch = UserInputService.TouchEnabled and not UserInputService.MouseEnabled

local ghostHighlight = create("Highlight", {
	FillColor = VALID_COLOR,
	FillTransparency = 0.5,
	OutlineColor = UIKit.WHITE,
	DepthMode = Enum.HighlightDepthMode.Occluded,
})

local deleteHighlight = create("Highlight", {
	FillColor = INVALID_COLOR,
	FillTransparency = 0.3,
	OutlineColor = INVALID_COLOR,
	Parent = camera,
})

---------------------------------------------------------------- portée des armes

local RANGE_COLOR = Color3.fromRGB(80, 255, 120)
local MIN_RANGE_COLOR = Color3.fromRGB(255, 80, 80)
local cellSpacing = grid:GetSpacing()

-- Disque plat au sol (cylindre couché)
local function makeDisc(color)
	return create("Part", {
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CastShadow = false,
		Shape = Enum.PartType.Cylinder,
		Material = Enum.Material.Neon,
		Color = color,
		Transparency = 0.75,
		Size = Vector3.new(0.1, 1, 1),
	})
end

local rangeDisc = makeDisc(RANGE_COLOR)
local minRangeDisc = makeDisc(MIN_RANGE_COLOR)

local function placeDisc(disc, radius, x, z, lift)
	disc.Size = Vector3.new(0.1, radius * 2, radius * 2)
	disc.CFrame = CFrame.new(grid.Xs[x], grid.TopY + lift, grid.Zs[z]) * CFrame.Angles(0, 0, math.rad(90))
	disc.Parent = camera
end

local function hideRange()
	rangeDisc.Parent = nil
	minRangeDisc.Parent = nil
end

-- Portée en vert (en cases, depuis le centre de la case de l'arme), zone morte du mortier en rouge
local function showRange(itemId, x, z)
	local item = itemId and Items.ById[itemId]
	local range = item and item.Stats.Range
	if not range or not x or not z then
		hideRange()
		return
	end
	placeDisc(rangeDisc, range * cellSpacing, x, z, 0.1)
	if item.Stats.MinRange then
		placeDisc(minRangeDisc, item.Stats.MinRange * cellSpacing, x, z, 0.12)
	else
		minRangeDisc.Parent = nil
	end
end

---------------------------------------------------------------- UI
-- Écran normal : bouton Build en bas (à gauche du ROLL).
-- Mode construction : fenêtre des objets à gauche, Exit | Delete en bas au milieu, compteur au-dessus.

local gui = create("ScreenGui", {
	Name = "BuildUI",
	ResetOnSpawn = false,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	Parent = player:WaitForChild("PlayerGui"),
})

local buildButton = UIKit.makeIconButton({
	Parent = gui,
	AnchorPoint = Vector2.new(1, 1),
	Position = UDim2.new(0.5, -80, 1, -16),
	Size = UDim2.new(0, 104, 0, 96),
	BackgroundColor3 = UIKit.ORANGE,
	Icon = "🔨",
	Label = "Build",
	Studs = 2,
})

local exitButton = UIKit.makeIconButton({
	Parent = gui,
	AnchorPoint = Vector2.new(1, 1),
	Position = UDim2.new(0.5, -8, 1, -16),
	Size = UDim2.new(0, 104, 0, 96),
	BackgroundColor3 = UIKit.ORANGE,
	Icon = "🔨",
	Label = "Exit",
	Visible = false,
	Studs = 2,
})

local DELETE_IDLE = UIKit.darken(UIKit.RED, 0.4)
local deleteButton = UIKit.makeIconButton({
	Parent = gui,
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.new(0.5, 8, 1, -16),
	Size = UDim2.new(0, 104, 0, 96),
	BackgroundColor3 = DELETE_IDLE,
	Icon = "🗑️",
	Label = "Delete",
	Visible = false,
	Studs = 2,
})

-- Compteur "12 / 40" au-dessus de Exit | Delete (rouge quand l'île est pleine)
local counterLabel = UIKit.label({
	Parent = gui,
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -122),
	Size = UDim2.new(0, 260, 0, 56),
	Text = "",
	TextStrokeTransparency = 0,
	Visible = false,
})

-- Sur mobile : on touche une case, puis on confirme avec ce bouton
local confirmButton = makeButton({
	Parent = gui,
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -186),
	Size = UDim2.new(0, 210, 0, 58),
	BackgroundColor3 = UIKit.GREEN,
	Text = "✔ PLACE",
	Visible = false,
	Studs = 3,
})

-- Fenêtre des objets (à gauche)
local buildPanel, buildBody, _, _, buildClose = UIKit.makePanel({
	Parent = gui,
	Title = "🔨 Build Mode",
	Accent = UIKit.ORANGE,
	AnchorPoint = Vector2.new(0, 0.5),
	Position = UDim2.new(0, 16, 0.5, -20),
	Size = UDim2.fromScale(0.3, 0.74),
	MinSize = Vector2.new(300, 320),
	MaxSize = Vector2.new(430, 620),
})

-- Onglets en haut de la fenêtre : un par catégorie
local TABS = {
	{ Category = "Block", Text = "🧱 Blocks" },
	{ Category = "Weapon", Text = "⚔️ Weapons" },
	{ Category = "Trap", Text = "🔺 Traps" },
}

local tabBar = create("Frame", {
	Parent = buildBody,
	Size = UDim2.new(1, 0, 0, 40),
	BackgroundTransparency = 1,
}, {
	create("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}),
})

local tabButtons = {}
for order, tab in TABS do
	tabButtons[tab.Category] = makeButton({
		Parent = tabBar,
		LayoutOrder = order,
		Size = UDim2.new(1 / #TABS, -4, 1, 0),
		Text = tab.Text,
	})
end

-- Grille des objets (3 par ligne)
local itemGrid = create("ScrollingFrame", {
	Parent = buildBody,
	Position = UDim2.new(0, 0, 0, 48),
	Size = UDim2.new(1, 0, 1, -100),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ScrollBarThickness = 6,
	ScrollBarImageColor3 = UIKit.GREY,
	CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
}, {
	create("UIGridLayout", {
		CellSize = UDim2.new(1 / 3, -8, 0, 108),
		CellPadding = UDim2.fromOffset(6, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}),
	create("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingLeft = UDim.new(0, 3), PaddingRight = UDim.new(0, 3) }),
})

-- Bas de la fenêtre : Vider (2 clics) et Tri
local CLEAR_CONFIRM_TIME = 3 -- secondes pour confirmer
local clearButton = makeButton({
	Parent = buildBody,
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.new(0, 0, 1, 0),
	Size = UDim2.new(0.5, -4, 0, 44),
	BackgroundColor3 = UIKit.RED,
	Text = "🧹 Clear plot",
})
local clearConfirmUntil = 0

-- Tri : chaque clic passe au tri suivant (du plus grand au plus petit)
-- Stat = statistique affichée sur chaque case pendant ce tri
local SORTS = {
	{ Label = "⭐ Rareté", Value = function(item) return Rarities.Info[item.Rarity].Rank end },
	{ Label = "❤️ PV", Stat = "HP", Icon = "❤️" },
	{ Label = "💥 Dégâts", Stat = "Damage", Icon = "💥" },
	{ Label = "🎯 Portée", Stat = "Range", Icon = "🎯" },
	{ Label = "📦 Quantité", Value = function(item) return state.Inventory[item.Id] or 0 end },
}

local sortButton = makeButton({
	Parent = buildBody,
	AnchorPoint = Vector2.new(1, 1),
	Position = UDim2.new(1, 0, 1, 0),
	Size = UDim2.new(0.5, -4, 0, 44),
	BackgroundColor3 = UIKit.PURPLE,
	Text = "",
})

local function sortValue(sort, item)
	if sort.Value then
		return sort.Value(item)
	end
	return item.Stats[sort.Stat] or 0
end

-- Objets de l'onglet ouvert que le joueur possède, dans l'ordre du tri choisi
local function sortedTabItems()
	local sort = SORTS[state.SortIndex]
	local list = {}
	for _, item in Items.ByCategory[state.Tab] do
		if (state.Inventory[item.Id] or 0) > 0 then
			table.insert(list, item)
		end
	end
	table.sort(list, function(a, b)
		local valueA, valueB = sortValue(sort, a), sortValue(sort, b)
		if valueA ~= valueB then
			return valueA > valueB
		end
		local rankA, rankB = Rarities.Info[a.Rarity].Rank, Rarities.Info[b.Rarity].Rank
		if rankA ~= rankB then
			return rankA > rankB
		end
		return a.Order < b.Order
	end)
	return list
end

local selectItem, setMode -- définis plus bas

-- Build Capacity : objets posés / maximum
local function isAtCapacity()
	return #placedFolder:GetChildren() >= SkillTree.GetBuildCapacity(state.Skills)
end

-- "12 / 40" ; rouge quand l'île est pleine (améliorable avec Build Capacity dans le Skill Tree)
local function renderCounter()
	counterLabel.Visible = state.Mode ~= nil
	counterLabel.Text = string.format("%d / %d", #placedFolder:GetChildren(), SkillTree.GetBuildCapacity(state.Skills))
	counterLabel.TextColor3 = if isAtCapacity() then Color3.fromRGB(255, 70, 70) else UIKit.WHITE
end

-- Une case de la grille : icône, nom, quantité, bordure de la couleur de la rareté
local function makeTile(item, order, sort)
	local rarityColor = Rarities.Info[item.Rarity].Color
	local isSelected = item.Id == state.SelectedId
	local tile = create("TextButton", {
		Parent = itemGrid,
		LayoutOrder = order,
		BackgroundColor3 = if isSelected then UIKit.darken(UIKit.GREEN, 0.35) else UIKit.PANEL_DARK,
		AutoButtonColor = false,
		Text = "",
		BorderSizePixel = 0,
	}, {
		UIKit.corner(10),
		UIKit.stroke(if isSelected then 4 else 3, if isSelected then UIKit.GREEN else rarityColor),
		UIKit.shine(Color3.fromRGB(190, 190, 205)),
	})
	UIKit.label({ Parent = tile, Position = UDim2.fromScale(0.1, 0.1), Size = UDim2.fromScale(0.8, 0.5), Text = item.Icon })
	UIKit.label({
		Parent = tile,
		Position = UDim2.fromScale(0.04, 0.66),
		Size = UDim2.fromScale(0.92, 0.26),
		Text = item.Name,
		Font = UIKit.TEXT_FONT,
		TextStrokeTransparency = 0,
	})
	UIKit.label({
		Parent = tile,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -4, 0, 2),
		Size = UDim2.fromScale(0.5, 0.22),
		Text = "×" .. state.Inventory[item.Id],
		Rotation = 8,
		TextXAlignment = Enum.TextXAlignment.Right,
		TextStrokeTransparency = 0,
	})
	local statValue = sort.Stat and item.Stats[sort.Stat]
	if statValue then
		UIKit.label({
			Parent = tile,
			Position = UDim2.new(0, 4, 0, 2),
			Size = UDim2.fromScale(0.5, 0.2),
			Text = string.format("%s%g", sort.Icon, statValue),
			TextXAlignment = Enum.TextXAlignment.Left,
			Font = UIKit.TEXT_FONT,
		})
	end
	UIKit.addPressEffect(tile)
	tile.Activated:Connect(function()
		-- choisir un objet depuis le mode Delete repasse en placement
		if state.Mode == "Delete" then
			setMode("Build")
		end
		selectItem(if isSelected then nil else item.Id)
	end)
end

local function renderBuildPanel()
	for category, button in tabButtons do
		button.BackgroundColor3 = if category == state.Tab then UIKit.GREEN else UIKit.BUTTON_COLOR
	end
	local sort = SORTS[state.SortIndex]
	sortButton.Text = "↕️ " .. sort.Label
	UIKit.clearList(itemGrid)
	local items = sortedTabItems()
	for order, item in items do
		makeTile(item, order, sort)
	end
	if #items == 0 then
		UIKit.label({
			Parent = itemGrid,
			Text = "Rien ici.\nFais des 🎲 ROLL !",
			TextColor3 = UIKit.GREY,
			Font = UIKit.TEXT_FONT,
		})
	end
end

sortButton.Activated:Connect(function()
	state.SortIndex = state.SortIndex % #SORTS + 1
	renderBuildPanel()
end)

-- clic sur un onglet : affiche cette catégorie
for category, button in tabButtons do
	button.Activated:Connect(function()
		state.Tab = category
		renderBuildPanel()
	end)
end

---------------------------------------------------------------- fantôme et cibles

local function destroyGhost()
	-- on retire la surbrillance avant de détruire le fantôme, sinon elle est détruite avec lui
	ghostHighlight.Parent = nil
	if state.Ghost then
		state.Ghost:Destroy()
		state.Ghost = nil
	end
end

function selectItem(itemId)
	state.SelectedId = itemId
	state.Target = nil
	state.LastCell = nil
	destroyGhost()
	hideRange()
	if itemId then
		local ghost = ItemVisuals.Create(itemId, grid.CellSize)
		ItemVisuals.MakeGhost(ghost)
		ghostHighlight.Parent = ghost
		state.Ghost = ghost
	end
	renderBuildPanel()
end

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

local function castPointer()
	local ray
	if isTouch then
		if not state.TouchPoint then
			return nil
		end
		ray = camera:ScreenPointToRay(state.TouchPoint.X, state.TouchPoint.Y)
	else
		local mouse = UserInputService:GetMouseLocation()
		ray = camera:ViewportPointToRay(mouse.X, mouse.Y)
	end
	local exclude = {}
	if state.Ghost then
		table.insert(exclude, state.Ghost)
	end
	if player.Character then
		table.insert(exclude, player.Character)
	end
	rayParams.FilterDescendantsInstances = exclude
	return workspace:Raycast(ray.Origin, ray.Direction * 500, rayParams)
end

-- Remonte jusqu'au modèle placé (enfant direct de PlacedObjects)
local function placedModelOf(instance)
	local node = instance
	while node and node.Parent ~= placedFolder do
		node = node.Parent
	end
	return node
end

local function cellFromHit(result)
	local model = placedModelOf(result.Instance)
	if model then
		return model:GetAttribute("GridX"), model:GetAttribute("GridZ")
	end
	local core = workspace:FindFirstChild("Core")
	if core and (result.Instance == core or result.Instance:IsDescendantOf(core)) then
		return grid.CoreX, grid.CoreZ
	end
	local damier = workspace:FindFirstChild("Damier")
	if damier and result.Instance:IsDescendantOf(damier) then
		return grid:WorldToCell(result.Position - result.Normal * 0.1)
	end
	return nil, nil
end

local function columnIds(x, z)
	local models = {}
	for _, model in placedFolder:GetChildren() do
		if model:GetAttribute("GridX") == x and model:GetAttribute("GridZ") == z then
			table.insert(models, model)
		end
	end
	table.sort(models, function(a, b)
		return a:GetAttribute("GridH") < b:GetAttribute("GridH")
	end)
	local ids = {}
	for index, model in models do
		ids[index] = model:GetAttribute("ItemId")
	end
	return ids
end

local function updateBuild()
	local ghost = state.Ghost
	if not ghost then
		return
	end
	local result = castPointer()
	local x, z
	if result then
		x, z = cellFromHit(result)
	end
	if not x then
		ghost.Parent = nil
		hideRange()
		state.Target = nil
		state.LastCell = nil
		return
	end

	local ok, h = grid:GetPlacement(state.SelectedId, x, z, columnIds(x, z), SkillTree.GetMaxBuildHeight(state.Skills))
	ok = ok and not isAtCapacity()
	ghost:PivotTo(CFrame.new(grid:SlotBottom(x, z, h)))
	ghost.Parent = workspace
	ghostHighlight.FillColor = if ok then VALID_COLOR else INVALID_COLOR
	state.Target = { X = x, Z = z, Valid = ok }
	showRange(state.SelectedId, x, z)

	-- PLOC : seulement quand on change de case
	local cellKey = x .. "," .. z
	if cellKey ~= state.LastCell then
		state.LastCell = cellKey
		SoundService:PlayLocalSound(plocSound)
	end
end

local function updateDelete()
	local result = castPointer()
	local model = result and placedModelOf(result.Instance)
	deleteHighlight.Adornee = model
	state.Target = if model then { Model = model } else nil
end

local function confirmAction()
	local target = state.Target
	if not target then
		return
	end
	if state.Mode == "Build" and target.Valid and state.SelectedId then
		local itemId = state.SelectedId
		task.spawn(function()
			Remotes.PlaceItem:InvokeServer(itemId, target.X, target.Z)
		end)
	elseif state.Mode == "Delete" and target.Model then
		local model = target.Model
		deleteHighlight.Adornee = nil
		state.Target = nil
		task.spawn(function()
			Remotes.DeleteItem:InvokeServer(model:GetAttribute("GridX"), model:GetAttribute("GridZ"), model:GetAttribute("GridH"))
		end)
	end
end

---------------------------------------------------------------- modes

-- mode : "Build" (poser), "Delete" (supprimer) ou nil (sortir de la construction)
function setMode(mode)
	if mode and (gridInfo:GetAttribute("OwnerUserId") ~= player.UserId or waveInfo:GetAttribute("Phase") ~= "Build") then
		return
	end
	local wasBuilding = state.Mode ~= nil
	state.Mode = mode
	state.TouchPoint = nil
	state.Target = nil
	deleteHighlight.Adornee = nil
	if mode ~= "Build" then
		selectItem(nil)
	end

	buildPanel.Visible = mode ~= nil
	exitButton.Visible = mode ~= nil
	deleteButton.Visible = mode ~= nil
	deleteButton.BackgroundColor3 = if mode == "Delete" then UIKit.RED else DELETE_IDLE
	confirmButton.BackgroundColor3 = if mode == "Delete" then UIKit.RED else UIKit.GREEN
	confirmButton.Text = if mode == "Delete" then "🗑️ REMOVE" else "✔ PLACE"
	renderCounter()
	if mode then
		renderBuildPanel()
		HudState.SetMode("Build")
		-- on range l'épée pour que le clic serve à construire
		local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid:UnequipTools()
		end
	elseif wasBuilding then
		HudState.SetMode("Main")
	end
end

-- Le bouton Build n'apparaît que sur l'écran normal (caché pendant la fenêtre des dés)
local function applyHudMode(hudMode)
	buildButton.Visible = hudMode == "Main"
end
HudState.Changed:Connect(applyHudMode)
applyHudMode(HudState.Mode)

-- Pas de construction pendant une vague
waveInfo:GetAttributeChangedSignal("Phase"):Connect(function()
	if waveInfo:GetAttribute("Phase") ~= "Build" then
		setMode(nil)
	end
end)

buildButton.Activated:Connect(function()
	setMode("Build")
end)

exitButton.Activated:Connect(function()
	setMode(nil)
end)

-- Delete : passe en suppression, un 2e clic revient au placement
deleteButton.Activated:Connect(function()
	setMode(if state.Mode == "Delete" then "Build" else "Delete")
end)

confirmButton.Activated:Connect(confirmAction)

clearButton.Activated:Connect(function()
	if os.clock() > clearConfirmUntil then
		-- 1er clic : demander confirmation
		clearConfirmUntil = os.clock() + CLEAR_CONFIRM_TIME
		clearButton.Text = "⚠️ Sûr ?"
		task.delay(CLEAR_CONFIRM_TIME, function()
			if os.clock() >= clearConfirmUntil then
				clearButton.Text = "🧹 Clear plot"
			end
		end)
		return
	end
	-- 2e clic : le serveur retire tout et rend les objets à l'inventaire
	clearConfirmUntil = 0
	clearButton.Text = "🧹 Clear plot"
	deleteHighlight.Adornee = nil
	state.Target = nil
	task.spawn(function()
		Remotes.ClearIsland:InvokeServer()
	end)
end)

-- le ✕ de la fenêtre quitte le mode construction
buildClose.Activated:Connect(function()
	setMode(nil)
end)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	if input.UserInputType == Enum.UserInputType.MouseButton1 and state.Mode then
		confirmAction()
	elseif input.KeyCode == Enum.KeyCode.B then
		setMode(if state.Mode == "Build" then nil else "Build")
	elseif input.KeyCode == Enum.KeyCode.X then
		setMode(if state.Mode == "Delete" then "Build" else "Delete")
	end
end)

UserInputService.TouchTapInWorld:Connect(function(position, processed)
	if not processed and state.Mode then
		state.TouchPoint = position
	end
end)

RunService.RenderStepped:Connect(function()
	if state.Mode == "Build" then
		updateBuild()
	elseif state.Mode == "Delete" then
		updateDelete()
	end
	local target = state.Target
	confirmButton.Visible = isTouch and target ~= nil and (state.Mode == "Delete" or target.Valid == true)
end)

---------------------------------------------------------------- inventaire (synchro serveur)

local function applySnapshot(snapshot)
	state.Inventory = snapshot.Inventory or {}
	state.Skills = snapshot.Skills or {}
	renderCounter()
	if state.SelectedId and (state.Inventory[state.SelectedId] or 0) <= 0 then
		selectItem(nil)
	elseif state.Mode then
		renderBuildPanel()
	end
end

Remotes.DataSync.OnClientEvent:Connect(applySnapshot)

-- le compteur suit les objets posés / supprimés
placedFolder.ChildAdded:Connect(renderCounter)
placedFolder.ChildRemoved:Connect(renderCounter)

task.spawn(function()
	local snapshot = Remotes.GetSnapshot:InvokeServer()
	if snapshot then
		applySnapshot(snapshot)
	end
end)
