-- IslandService : l'île du joueur ; placement et suppression validés par le serveur
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Items = require(Shared:WaitForChild("Items"))
local Grid = require(Shared:WaitForChild("Grid"))
local ItemVisuals = require(Shared:WaitForChild("ItemVisuals"))
local DataService = require(script.Parent:WaitForChild("DataService"))

local IslandService = {}

-- Pour l'instant une seule île (workspace.Damier) : le premier joueur arrivé la possède
local grid
local gridInfo
local placedFolder
local owner = nil
local columns = {} -- ["x,z"] = { { Id, X, Z, Model }, ... } du bas vers le haut (sans le Core)

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
	local entry = { Id = itemId, X = x, Z = z, Model = model }
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

local function loadLayout(player, data)
	local layout = table.clone(data.Island)
	table.sort(layout, function(a, b)
		return a.H < b.H
	end)
	local refunded = false
	for _, saved in layout do
		local column = grid:IsValidCell(saved.X, saved.Z) and getColumn(saved.X, saved.Z)
		local ok = column and grid:GetPlacement(saved.Id, saved.X, saved.Z, stackIds(column))
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
end

local function releaseIsland(player)
	if owner ~= player then
		return
	end
	placedFolder:ClearAllChildren()
	columns = {}
	owner = nil
	gridInfo:SetAttribute("OwnerUserId", nil)
end

local function isInteger(value)
	return typeof(value) == "number" and value == math.floor(value)
end

function IslandService.Place(player, itemId, x, z)
	if player ~= owner or typeof(itemId) ~= "string" or not isInteger(x) or not isInteger(z) then
		return false
	end
	local column = grid:IsValidCell(x, z) and getColumn(x, z)
	if not column then
		return false
	end
	local ok, h = grid:GetPlacement(itemId, x, z, stackIds(column))
	if not ok or not DataService.RemoveItem(player, itemId, 1) then
		return false
	end
	table.insert(column, spawnEntry(itemId, x, z, h))
	saveLayout(player)
	return true
end

function IslandService.Delete(player, x, z, h)
	if player ~= owner or not isInteger(x) or not isInteger(z) or not isInteger(h) then
		return false
	end
	local column = grid:IsValidCell(x, z) and getColumn(x, z)
	local index = h - grid:BaseHeight(x, z)
	local entry = column and column[index]
	if not entry then
		return false
	end
	table.remove(column, index)
	entry.Model:Destroy()
	relayout(x, z)
	DataService.AddItem(player, entry.Id, 1)
	saveLayout(player)
	return true
end

function IslandService.GetGrid()
	return grid
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
