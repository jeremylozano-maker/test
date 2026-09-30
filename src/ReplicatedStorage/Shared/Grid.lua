-- Grid : lit le Damier (13 x 9 cases), convertit cases <-> positions et applique les règles de placement
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Items = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Items"))

local Grid = {}
Grid.__index = Grid

Grid.MaxHeight = 3

local TOLERANCE = 0.5

local function uniqueSorted(values)
	table.sort(values)
	local result = {}
	for _, value in values do
		if #result == 0 or value - result[#result] > TOLERANCE then
			table.insert(result, value)
		end
	end
	return result
end

local function nearestIndex(list, value, maxDistance)
	for index, listValue in list do
		if math.abs(listValue - value) <= maxDistance then
			return index
		end
	end
	return nil
end

local function boundingBox(instance)
	if instance:IsA("Model") then
		return instance:GetBoundingBox()
	end
	return instance.CFrame, instance.Size
end

-- Construit la grille depuis les parts du Damier (serveur)
function Grid.new(damier, core)
	local xs, zs = {}, {}
	local topY = -math.huge
	local cellSize
	for _, descendant in damier:GetDescendants() do
		if descendant:IsA("BasePart") then
			table.insert(xs, descendant.Position.X)
			table.insert(zs, descendant.Position.Z)
			topY = math.max(topY, descendant.Position.Y + descendant.Size.Y / 2)
			cellSize = cellSize or descendant.Size.X
		end
	end

	local self = Grid.FromData({
		Xs = uniqueSorted(xs),
		Zs = uniqueSorted(zs),
		TopY = topY,
		CellSize = cellSize,
		LevelHeight = cellSize,
	})

	-- Le Core occupe sa case sur un ou plusieurs étages ; on peut construire au-dessus
	local coreCFrame, coreSize = boundingBox(core)
	self.CoreX, self.CoreZ = self:WorldToCell(coreCFrame.Position)
	local coreTop = coreCFrame.Position.Y + coreSize.Y / 2
	self.CoreLevels = core:GetAttribute("GridLevels")
		or math.clamp(math.ceil((coreTop - topY) / self.LevelHeight - 0.1), 1, Grid.MaxHeight)
	return self
end

-- Reconstruit une grille à partir de Serialize() (client)
function Grid.FromData(data)
	local self = setmetatable(table.clone(data), Grid)
	self.Cols = #self.Xs
	self.Rows = #self.Zs
	return self
end

function Grid:Serialize()
	return {
		Xs = self.Xs,
		Zs = self.Zs,
		TopY = self.TopY,
		CellSize = self.CellSize,
		LevelHeight = self.LevelHeight,
		CoreX = self.CoreX,
		CoreZ = self.CoreZ,
		CoreLevels = self.CoreLevels,
	}
end

function Grid:WorldToCell(position)
	local spacingX = if #self.Xs > 1 then self.Xs[2] - self.Xs[1] else self.CellSize
	local spacingZ = if #self.Zs > 1 then self.Zs[2] - self.Zs[1] else self.CellSize
	local x = nearestIndex(self.Xs, position.X, spacingX / 2)
	local z = nearestIndex(self.Zs, position.Z, spacingZ / 2)
	if x and z then
		return x, z
	end
	return nil, nil
end

function Grid:IsValidCell(x, z)
	return self.Xs[x] ~= nil and self.Zs[z] ~= nil
end

function Grid:IsCore(x, z)
	return x == self.CoreX and z == self.CoreZ
end

-- Nombre d'étages déjà occupés par le Core sur cette case
function Grid:BaseHeight(x, z)
	return if self:IsCore(x, z) then self.CoreLevels else 0
end

-- Position du bas de l'étage h (1 = posé sur le Damier)
function Grid:SlotBottom(x, z, h)
	return Vector3.new(self.Xs[x], self.TopY + (h - 1) * self.LevelHeight, self.Zs[z])
end

-- stackIds : ids des objets déjà sur la case, du bas vers le haut (sans le Core)
-- Retourne (placement possible ?, étage où l'objet irait)
function Grid:GetPlacement(itemId, x, z, stackIds)
	local item = Items.ById[itemId]
	if not item or not self:IsValidCell(x, z) then
		return false, nil
	end
	local rules = Items.CategoryInfo[item.Category]
	local h = self:BaseHeight(x, z) + #stackIds + 1
	if h > Grid.MaxHeight then
		return false, h
	end
	if rules.GroundOnly and h ~= 1 then
		return false, h
	end
	local topId = stackIds[#stackIds]
	if topId and not Items.CategoryInfo[Items.ById[topId].Category].CanSupport then
		return false, h
	end
	return true, h
end

return Grid
