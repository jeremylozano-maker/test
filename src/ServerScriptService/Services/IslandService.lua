-- IslandService : l'île du joueur ; placement et suppression validés par le serveur
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Items = require(Shared:WaitForChild("Items"))
local Grid = require(Shared:WaitForChild("Grid"))
local SkillTree = require(Shared:WaitForChild("SkillTree"))
local ItemVisuals = require(Shared:WaitForChild("ItemVisuals"))
local DataService = require(script.Parent:WaitForChild("DataService"))

local IslandService = {}

-- Déclenché quand l'île change de propriétaire : (player ou nil)
IslandService.OwnerChanged = Instance.new("BindableEvent")

-- Pour l'instant une seule île (workspace.Damier) : le premier joueur arrivé la possède
local grid
local gridInfo
local placedFolder
local owner = nil
local locked = false -- true pendant une vague : pas de construction
local columns = {} -- ["x,z"] = { { Id, X, Z, Model, HP, MaxHP }, ... } du bas vers le haut (sans le Core)

local function getColumn(x, z)
	local key = x .. "," .. z
	columns[key] = columns[key] or {}
	return columns[key]
end

local function stackIds(column)
	local ids = {}
	for index, entry in column do
		ids[index] = entry.Id
	end
	return ids
end

local function positionEntry(entry, h)
	entry.Model:PivotTo(CFrame.new(grid:SlotBottom(entry.X, entry.Z, h)))
	entry.Model:SetAttribute("GridX", entry.X)
	entry.Model:SetAttribute("GridZ", entry.Z)
	entry.Model:SetAttribute("GridH", h)
end

local function spawnEntry(itemId, x, z, h)
	local model = ItemVisuals.Create(itemId, grid.CellSize)
	model:SetAttribute("ItemId", itemId)
	local hp = Items.ById[itemId].Stats.HP
	local entry = { Id = itemId, X = x, Z = z, Model = model, HP = hp, MaxHP = hp }
	positionEntry(entry, h)
	model.Parent = placedFolder
	return entry
end

-- Replace chaque objet de la colonne à son étage (gravité)
local function relayout(x, z)
	local base = grid:BaseHeight(x, z)
	for index, entry in getColumn(x, z) do
		positionEntry(entry, base + index)
	end
end

-- Retire un objet de sa colonne ; ce qui était au-dessus descend d'un étage
local function removeEntry(entry)
	local column = getColumn(entry.X, entry.Z)
	local index = table.find(column, entry)
	if not index then
		return
	end
	table.remove(column, index)
	entry.Destroyed = true
	entry.Model:Destroy()
	relayout(entry.X, entry.Z)
end

local function clearAll()
	for _, column in columns do
		for _, entry in column do
			entry.Destroyed = true
		end
	end
	placedFolder:ClearAllChildren()
	columns = {}
end

local function updateHealthBar(entry)
	local billboard = entry.Model:FindFirstChild("HealthBar")
	if not billboard then
		billboard = Instance.new("BillboardGui")
		billboard.Name = "HealthBar"
		billboard.Size = UDim2.fromOffset(44, 6)
		billboard.StudsOffsetWorldSpace = Vector3.new(0, grid.CellSize * 0.7, 0)
		billboard.AlwaysOnTop = true
		billboard.MaxDistance = 120
		billboard.Adornee = entry.Model:FindFirstChildWhichIsA("BasePart", true)
		local back = Instance.new("Frame")
		back.Name = "Back"
		back.Size = UDim2.fromScale(1, 1)
		back.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
		back.BorderSizePixel = 0
		back.Parent = billboard
		local fill = Instance.new("Frame")
		fill.Name = "Fill"
		fill.BackgroundColor3 = Color3.fromRGB(255, 80, 80)
		fill.BorderSizePixel = 0
		fill.Parent = back
		billboard.Parent = entry.Model
	end
	billboard.Back.Fill.Size = UDim2.fromScale(math.clamp(entry.HP / entry.MaxHP, 0, 1), 1)
end

local function saveLayout(player)
	local data = DataService.Get(player)
	if not data then
		return
	end
	local layout = {}
	for _, column in columns do
		for index, entry in column do
			table.insert(layout, { Id = entry.Id, X = entry.X, Z = entry.Z, H = grid:BaseHeight(entry.X, entry.Z) + index })
		end
	end
	data.Island = layout
end

-- Nombre d'objets posés sur l'île (pour la compétence Build Capacity)
local function countEntries()
	local count = 0
	for _, column in columns do
		count += #column
	end
	return count
end

local function loadLayout(player, data)
	local layout = table.clone(data.Island)
	table.sort(layout, function(a, b)
		return a.H < b.H
	end)
	local refunded = false
	for _, saved in layout do
		local column = grid:IsValidCell(saved.X, saved.Z) and getColumn(saved.X, saved.Z)
		local ok = column and grid:GetPlacement(saved.Id, saved.X, saved.Z, stackIds(column), SkillTree.GetMaxBuildHeight(data.Skills))
		if ok then
			table.insert(column, spawnEntry(saved.Id, saved.X, saved.Z, grid:BaseHeight(saved.X, saved.Z) + #column + 1))
		elseif Items.ById[saved.Id] then
			-- position devenue invalide : l'objet retourne dans l'inventaire
			data.Inventory[saved.Id] = (data.Inventory[saved.Id] or 0) + 1
			refunded = true
		end
	end
	saveLayout(player)
	if refunded then
		DataService.Notify(player)
	end
end

local function claimIsland(player)
	local data = DataService.WaitFor(player, 30)
	if not data or not player.Parent then
		return
	end
	if owner then
		warn("[IslandService] Pas d'île libre pour " .. player.Name)
		return
	end
	owner = player
	gridInfo:SetAttribute("OwnerUserId", player.UserId)
	loadLayout(player, data)
	IslandService.OwnerChanged:Fire(player)
end

local function releaseIsland(player)
	if owner ~= player then
		return
	end
	clearAll()
	owner = nil
	gridInfo:SetAttribute("OwnerUserId", nil)
	IslandService.OwnerChanged:Fire(nil)
end

local function isInteger(value)
	return typeof(value) == "number" and value == math.floor(value)
end

function IslandService.Place(player, itemId, x, z)
	if locked or player ~= owner or typeof(itemId) ~= "string" or not isInteger(x) or not isInteger(z) then
		return false
	end
	local data = DataService.Get(player)
	local column = grid:IsValidCell(x, z) and getColumn(x, z)
	if not column or not data then
		return false
	end
	-- Build Capacity : limite du nombre d'objets posés
	if countEntries() >= SkillTree.GetBuildCapacity(data.Skills) then
		return false
	end
	-- Build Height : nombre d'étages autorisés
	local ok, h = grid:GetPlacement(itemId, x, z, stackIds(column), SkillTree.GetMaxBuildHeight(data.Skills))
	if not ok or not DataService.RemoveItem(player, itemId, 1) then
		return false
	end
	table.insert(column, spawnEntry(itemId, x, z, h))
	saveLayout(player)
	return true
end

function IslandService.Delete(player, x, z, h)
	if locked or player ~= owner or not isInteger(x) or not isInteger(z) or not isInteger(h) then
		return false
	end
	local column = grid:IsValidCell(x, z) and getColumn(x, z)
	local index = h - grid:BaseHeight(x, z)
	local entry = column and column[index]
	if not entry then
		return false
	end
	removeEntry(entry)
	DataService.AddItem(player, entry.Id, 1)
	saveLayout(player)
	return true
end

-- Vide toute l'île : chaque objet posé retourne dans l'inventaire (rien n'est perdu)
function IslandService.ClearAll(player)
	local data = DataService.Get(player)
	if locked or player ~= owner or not data then
		return false
	end
	for _, column in columns do
		for _, entry in column do
			data.Inventory[entry.Id] = (data.Inventory[entry.Id] or 0) + 1
			data.Index[entry.Id] = true
		end
	end
	clearAll()
	saveLayout(player)
	DataService.Notify(player)
	return true
end

function IslandService.GetGrid()
	return grid
end

function IslandService.GetOwner()
	return owner
end

function IslandService.GetColumns()
	return columns
end

function IslandService.SetLocked(value)
	locked = value
end

-- Dégâts d'un zombie sur un objet (bloc ou arme). À 0 PV l'objet est détruit jusqu'à la fin de la vague.
function IslandService.DamageEntry(entry, amount)
	if entry.Destroyed or not entry.HP then
		return
	end
	entry.HP -= amount
	if entry.HP <= 0 then
		removeEntry(entry)
	else
		updateHealthBar(entry)
	end
end

-- Remet l'île exactement comme sauvegardée (fin de vague, mort acceptée, revive)
function IslandService.RestoreLayout()
	if not owner then
		return
	end
	clearAll()
	local data = DataService.Get(owner)
	if data then
		loadLayout(owner, data)
	end
end

function IslandService.Init()
	grid = Grid.new(workspace:WaitForChild("Damier"), workspace:WaitForChild("Core"))

	gridInfo = Instance.new("Folder")
	gridInfo.Name = "GridInfo"
	gridInfo:SetAttribute("Data", HttpService:JSONEncode(grid:Serialize()))
	gridInfo.Parent = ReplicatedStorage

	placedFolder = Instance.new("Folder")
	placedFolder.Name = "PlacedObjects"
	placedFolder.Parent = workspace

	Players.PlayerAdded:Connect(claimIsland)
	for _, player in Players:GetPlayers() do
		task.spawn(claimIsland, player)
	end
	Players.PlayerRemoving:Connect(releaseIsland)
end

return IslandService
