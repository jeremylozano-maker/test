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
local ItemVisuals = require(Shared:WaitForChild("ItemVisuals"))
local UIKit = require(Shared:WaitForChild("UIKit"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local create, corner, stroke, makeButton = UIKit.create, UIKit.corner, UIKit.stroke, UIKit.makeButton

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
	Inventory = {},
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

local gui = create("ScreenGui", {
	Name = "BuildUI",
	ResetOnSpawn = false,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	Parent = player:WaitForChild("PlayerGui"),
})

local buildButton = makeButton({
	Parent = gui,
	AnchorPoint = Vector2.new(0, 0.5),
	Position = UDim2.new(0, 12, 0.5, -34),
	Size = UDim2.new(0, 145, 0, 56),
	Text = "🔨 BUILD",
})

local deleteButton = makeButton({
	Parent = gui,
	AnchorPoint = Vector2.new(0, 0.5),
	Position = UDim2.new(0, 12, 0.5, 34),
	Size = UDim2.new(0, 145, 0, 56),
	Text = "🗑️ DELETE",
})

-- Sur mobile : on touche une case, puis on confirme avec ce bouton
local confirmButton = makeButton({
	Parent = gui,
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -100),
	Size = UDim2.new(0, 200, 0, 56),
	Text = "✔ PLACE",
	Visible = false,
})

local buildPanel = create("Frame", {
	Parent = gui,
	Visible = false,
	AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.new(1, -170, 0.5, 0),
	Size = UDim2.fromScale(0.3, 0.72),
	BackgroundColor3 = UIKit.PANEL_COLOR,
}, {
	corner(16),
	stroke(3),
	create("UISizeConstraint", { MinSize = Vector2.new(230, 220), MaxSize = Vector2.new(400, 560) }),
})

-- Onglets en haut de la fenêtre : un par catégorie
local TABS = {
	{ Category = "Block", Text = "🧱 BLOCKS" },
	{ Category = "Weapon", Text = "⚔️ WEAPONS" },
	{ Category = "Trap", Text = "🔺 TRAPS" },
}

local tabBar = create("Frame", {
	Parent = buildPanel,
	Position = UDim2.new(0, 10, 0, 10),
	Size = UDim2.new(1, -20, 0, 40),
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

local buildList = create("ScrollingFrame", {
	Parent = buildPanel,
	Position = UDim2.new(0, 10, 0, 58),
	Size = UDim2.new(1, -20, 1, -68),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ScrollBarThickness = 6,
	CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
}, {
	create("UIListLayout", { Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder }),
})

local selectItem -- défini plus bas

local function renderBuildPanel()
	for category, button in tabButtons do
		button.BackgroundColor3 = if category == state.Tab then UIKit.GREEN else UIKit.BUTTON_COLOR
	end
	for _, child in buildList:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	local order = 0
	for _, item in Items.ByCategory[state.Tab] do
		local count = state.Inventory[item.Id] or 0
		if count > 0 then
			order += 1
			local isSelected = item.Id == state.SelectedId
			local button = makeButton({
				Parent = buildList,
				LayoutOrder = order,
				Size = UDim2.new(1, -8, 0, 40),
				Text = string.format("%s %s ×%d", item.Icon, item.Name, count),
				TextColor3 = Rarities.Info[item.Rarity].Color,
				TextXAlignment = Enum.TextXAlignment.Left,
				BackgroundColor3 = if isSelected then Color3.fromRGB(40, 90, 55) else UIKit.BUTTON_COLOR,
			})
			button.Activated:Connect(function()
				selectItem(if isSelected then nil else item.Id)
			end)
		end
	end
	if order == 0 then
		create("TextLabel", {
			Parent = buildList,
			Size = UDim2.new(1, -8, 0, 60),
			BackgroundTransparency = 1,
			Text = "Rien dans cette catégorie.\nFais des 🎲 ROLL !",
			TextColor3 = UIKit.GREY,
			Font = UIKit.TEXT_FONT,
			TextScaled = true,
		})
	end
end

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

	local ok, h = grid:GetPlacement(state.SelectedId, x, z, columnIds(x, z))
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

local function closeOtherPanels()
	local islandUI = player.PlayerGui:FindFirstChild("IslandUI")
	if not islandUI then
		return
	end
	for _, child in islandUI:GetChildren() do
		if child:IsA("Frame") and (string.find(child.Name, "INVENTORY", 1, true) or string.find(child.Name, "INDEX", 1, true)) then
			child.Visible = false
		end
	end
end

local function setMode(mode)
	if state.Mode == mode then
		mode = nil
	end
	if mode and (gridInfo:GetAttribute("OwnerUserId") ~= player.UserId or waveInfo:GetAttribute("Phase") ~= "Build") then
		return
	end
	state.Mode = mode
	state.TouchPoint = nil
	state.Target = nil
	deleteHighlight.Adornee = nil
	selectItem(nil)

	buildPanel.Visible = mode == "Build"
	buildButton.BackgroundColor3 = if mode == "Build" then UIKit.GREEN else UIKit.BUTTON_COLOR
	deleteButton.BackgroundColor3 = if mode == "Delete" then UIKit.RED else UIKit.BUTTON_COLOR
	confirmButton.Text = if mode == "Delete" then "🗑️ REMOVE" else "✔ PLACE"
	if mode then
		closeOtherPanels()
		-- on range l'épée pour que le clic serve à construire
		local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid:UnequipTools()
		end
	end
end

-- Pas de construction pendant une vague
waveInfo:GetAttributeChangedSignal("Phase"):Connect(function()
	if waveInfo:GetAttribute("Phase") ~= "Build" then
		setMode(nil)
	end
end)

buildButton.Activated:Connect(function()
	setMode("Build")
end)

deleteButton.Activated:Connect(function()
	setMode("Delete")
end)

confirmButton.Activated:Connect(confirmAction)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	if input.UserInputType == Enum.UserInputType.MouseButton1 and state.Mode then
		confirmAction()
	elseif input.KeyCode == Enum.KeyCode.B then
		setMode("Build")
	elseif input.KeyCode == Enum.KeyCode.X then
		setMode("Delete")
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
	if state.SelectedId and (state.Inventory[state.SelectedId] or 0) <= 0 then
		selectItem(nil)
	elseif state.Mode == "Build" then
		renderBuildPanel()
	end
end

Remotes.DataSync.OnClientEvent:Connect(applySnapshot)

task.spawn(function()
	local snapshot = Remotes.GetSnapshot:InvokeServer()
	if snapshot then
		applySnapshot(snapshot)
	end
end)
