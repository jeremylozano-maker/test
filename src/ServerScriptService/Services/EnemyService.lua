-- EnemyService : zombies (apparition, déplacement vers l'objet le plus proche, attaque, dégâts)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Enemies = require(Shared:WaitForChild("Enemies"))
local Items = require(Shared:WaitForChild("Items"))
local IslandService = require(script.Parent:WaitForChild("IslandService"))

local EnemyService = {}

EnemyService.OnKilled = nil -- function(enemy)
EnemyService.OnCoreHit = nil -- function(damage)

local RETARGET_INTERVAL = 0.5

local enemies = {}
local folder
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

---------------------------------------------------------------- modèles

local function addPart(model, size, cframe, color)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = model
	return part
end

-- Zombie provisoire autour de (0,0,0) = ses pieds, bras tendus vers l'avant (-Z)
local function buildPlaceholder(def)
	local s = def.Size
	local model = Instance.new("Model")
	local skin = def.Color
	local clothes = Color3.fromRGB(70, 60, 90)
	addPart(model, Vector3.new(1.6, 1.6, 0.8) * s, CFrame.new(0, 0.8 * s, 0), clothes)
	addPart(model, Vector3.new(2, 2, 1) * s, CFrame.new(0, 2.6 * s, 0), clothes:Lerp(skin, 0.3))
	addPart(model, Vector3.new(1.2, 1.2, 1.2) * s, CFrame.new(0, 4.2 * s, 0), skin)
	addPart(model, Vector3.new(0.5, 0.5, 1.8) * s, CFrame.new(-0.75 * s, 3.2 * s, -0.9 * s), skin)
	addPart(model, Vector3.new(0.5, 0.5, 1.8) * s, CFrame.new(0.75 * s, 3.2 * s, -0.9 * s), skin)
	model.WorldPivot = CFrame.new()
	return model
end

local function buildModel(typeId, def)
	local modelsFolder = ReplicatedStorage:FindFirstChild("EnemyModels")
	local template = modelsFolder and modelsFolder:FindFirstChild(typeId)
	local model
	if template then
		model = template:Clone()
		for _, descendant in model:GetDescendants() do
			if descendant:IsA("BasePart") then
				descendant.Anchored = true
				descendant.CanCollide = false
				descendant.CanQuery = false
			end
		end
		local boxCFrame, boxSize = model:GetBoundingBox()
		model.WorldPivot = boxCFrame * CFrame.new(0, -boxSize.Y / 2, 0)
	else
		model = buildPlaceholder(def)
	end
	model.Name = typeId

	-- barre de vie au-dessus de la tête
	local _, size = model:GetBoundingBox()
	local adornee = model:FindFirstChildWhichIsA("BasePart", true)
	local adorneeHeight = model:GetPivot():PointToObjectSpace(adornee.Position).Y
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(46, 6)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, size.Y + 0.8 - adorneeHeight, 0)
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = 150
	billboard.Adornee = adornee
	local back = Instance.new("Frame")
	back.Size = UDim2.fromScale(1, 1)
	back.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
	back.BorderSizePixel = 0
	back.Parent = billboard
	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = Color3.fromRGB(90, 220, 90)
	fill.BorderSizePixel = 0
	fill.Parent = back
	billboard.Parent = model
	return model, fill
end

---------------------------------------------------------------- IA

local function horizontalDistance(a, b)
	return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
end

-- Objet destructible le plus proche (le bas de chaque colonne), sinon nil = le Core
local function findTarget(enemy, grid)
	local best, bestDistance
	for _, column in IslandService.GetColumns() do
		local entry = column[1]
		if entry and not entry.Destroyed and not grid:IsCore(entry.X, entry.Z)
			and Items.CategoryInfo[Items.ById[entry.Id].Category].Targetable then
			local distance = horizontalDistance(enemy.Position, grid:SlotBottom(entry.X, entry.Z, 1))
			if not bestDistance or distance < bestDistance then
				best, bestDistance = entry, distance
			end
		end
	end
	return best
end

-- Hauteur du sol sous le zombie (dans l'eau il est à moitié immergé)
local function groundY(position, enemy)
	local result = workspace:Raycast(position + Vector3.new(0, 40, 0), Vector3.new(0, -120, 0), rayParams)
	if not result then
		return enemy.Position.Y
	end
	if result.Material == Enum.Material.Water then
		return result.Position.Y - 1.2 * enemy.Def.Size
	end
	return result.Position.Y
end

local function stepEnemy(enemy, dt, grid)
	enemy.RetargetIn -= dt
	if enemy.RetargetIn <= 0 or (enemy.Target and enemy.Target.Destroyed) then
		enemy.Target = findTarget(enemy, grid)
		enemy.RetargetIn = RETARGET_INTERVAL
	end

	local target = enemy.Target
	local goal = if target then grid:SlotBottom(target.X, target.Z, 1) else grid:SlotBottom(grid.CoreX, grid.CoreZ, 1)
	local offset = Vector3.new(goal.X - enemy.Position.X, 0, goal.Z - enemy.Position.Z)
	local distance = offset.Magnitude
	local reach = grid:GetSpacing() * 0.5 + enemy.Radius
	local direction = if distance > 0.01 then offset.Unit else Vector3.zAxis
	enemy.SlowTimer = math.max(0, enemy.SlowTimer - dt)

	if distance > reach then
		local speed = enemy.Def.Speed * (if enemy.SlowTimer > 0 then 1 - enemy.SlowFactor else 1)
		local moved = enemy.Position + direction * math.min(speed * dt, distance - reach)
		enemy.Position = Vector3.new(moved.X, groundY(moved, enemy), moved.Z)
	else
		enemy.AttackIn -= dt
		if enemy.AttackIn <= 0 then
			enemy.AttackIn = enemy.Def.AttackCooldown
			if target then
				IslandService.DamageEntry(target, enemy.Def.Damage)
			elseif EnemyService.OnCoreHit then
				EnemyService.OnCoreHit(enemy.Def.Damage)
			end
		end
	end

	enemy.Model:PivotTo(CFrame.lookAt(enemy.Position, enemy.Position + direction))
end

---------------------------------------------------------------- API

function EnemyService.Spawn(typeId, hpMultiplier, position)
	local def = Enemies[typeId]
	local model, fill = buildModel(typeId, def)
	local hp = math.floor(def.HP * hpMultiplier)
	local enemy = {
		Type = typeId,
		Def = def,
		HP = hp,
		MaxHP = hp,
		Position = position,
		Model = model,
		Fill = fill,
		Radius = 1.2 * def.Size,
		Target = nil,
		RetargetIn = 0,
		AttackIn = 0,
		SlowTimer = 0,
		SlowFactor = 0,
		Dead = false,
	}
	model:PivotTo(CFrame.new(position))
	model.Parent = folder
	table.insert(enemies, enemy)
	return enemy
end

function EnemyService.Damage(enemy, amount)
	if enemy.Dead then
		return
	end
	enemy.HP -= amount
	if enemy.HP <= 0 then
		enemy.Dead = true
		enemy.Model:Destroy()
		if EnemyService.OnKilled then
			EnemyService.OnKilled(enemy)
		end
	else
		enemy.Fill.Size = UDim2.fromScale(enemy.HP / enemy.MaxHP, 1)
	end
end

function EnemyService.Slow(enemy, factor, duration)
	local current = if enemy.SlowTimer > 0 then enemy.SlowFactor else 0
	enemy.SlowFactor = math.max(current, factor)
	enemy.SlowTimer = math.max(enemy.SlowTimer, duration)
end

-- Liste brute : ignorer ceux qui ont Dead = true
function EnemyService.GetEnemies()
	return enemies
end

function EnemyService.Count()
	local count = 0
	for _, enemy in enemies do
		if not enemy.Dead then
			count += 1
		end
	end
	return count
end

function EnemyService.Step(dt)
	local grid = IslandService.GetGrid()
	local exclude = { folder }
	local placed = workspace:FindFirstChild("PlacedObjects")
	if placed then
		table.insert(exclude, placed)
	end
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(exclude, player.Character)
		end
	end
	rayParams.FilterDescendantsInstances = exclude

	for index = #enemies, 1, -1 do
		local enemy = enemies[index]
		if enemy.Dead then
			table.remove(enemies, index)
		else
			stepEnemy(enemy, dt, grid)
		end
	end
end

function EnemyService.Clear()
	for _, enemy in enemies do
		enemy.Dead = true
		enemy.Model:Destroy()
	end
	enemies = {}
end

function EnemyService.Init()
	folder = Instance.new("Folder")
	folder.Name = "Enemies"
	folder.Parent = workspace
end

return EnemyService
