-- DefenseService : les armes tirent dans leur portée, les pièges blessent les zombies qui marchent dessus
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Items = require(Shared:WaitForChild("Items"))
local Rarities = require(Shared:WaitForChild("Rarities"))
local IslandService = require(script.Parent:WaitForChild("IslandService"))
local EnemyService = require(script.Parent:WaitForChild("EnemyService"))

local DefenseService = {}

local SLOW_DURATION = 2 -- secondes
local CHAIN_JUMP = 1.5 -- cases entre deux rebonds du Tesla
local HIT_HEIGHT = Vector3.new(0, 2, 0)

local cooldowns = setmetatable({}, { __mode = "k" }) -- [entry] = secondes avant le prochain tir

local function horizontalDistance(a, b)
	return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
end

---------------------------------------------------------------- effets visuels

local function effectPart(props)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	for key, value in props do
		part[key] = value
	end
	part.Parent = workspace
	return part
end

local function projectile(from, to, color, size, duration)
	local ball = effectPart({ Shape = Enum.PartType.Ball, Size = Vector3.one * size, Color = color, CFrame = CFrame.new(from) })
	TweenService:Create(ball, TweenInfo.new(duration, Enum.EasingStyle.Linear), { CFrame = CFrame.new(to) }):Play()
	Debris:AddItem(ball, duration)
end

local function beam(from, to, color)
	local length = (to - from).Magnitude
	local part = effectPart({
		Size = Vector3.new(0.3, 0.3, length),
		CFrame = CFrame.lookAt(from, to) * CFrame.new(0, 0, -length / 2),
		Color = color,
	})
	TweenService:Create(part, TweenInfo.new(0.2), { Transparency = 1 }):Play()
	Debris:AddItem(part, 0.25)
end

local function burst(position, radius, color, delay)
	task.delay(delay, function()
		local sphere = effectPart({
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * radius,
			Color = color,
			Transparency = 0.4,
			CFrame = CFrame.new(position),
		})
		TweenService:Create(sphere, TweenInfo.new(0.35), { Size = Vector3.one * radius * 2, Transparency = 1 }):Play()
		Debris:AddItem(sphere, 0.4)
	end)
end

---------------------------------------------------------------- tirs

local function nearestEnemy(origin, maxRange, minRange, ignore)
	local best, bestDistance
	for _, enemy in EnemyService.GetEnemies() do
		if not enemy.Dead and not (ignore and ignore[enemy]) then
			local distance = horizontalDistance(origin, enemy.Position)
			if distance <= maxRange and distance >= (minRange or 0) and (not bestDistance or distance < bestDistance) then
				best, bestDistance = enemy, distance
			end
		end
	end
	return best
end

-- Tourne l'arme vers la cible (le canon provisoire pointe vers +X)
local function aim(entry, target)
	local position = entry.Model:GetPivot().Position
	local direction = target.Position - position
	entry.Model:PivotTo(CFrame.new(position) * CFrame.Angles(0, math.atan2(-direction.Z, direction.X), 0))
end

local function fire(entry, item, target, grid)
	local stats = item.Stats
	local spacing = grid:GetSpacing()
	local muzzle = entry.Model:GetPivot().Position + Vector3.new(0, grid.CellSize * 0.45, 0)
	local hitPosition = target.Position + HIT_HEIGHT
	local rarityColor = Rarities.Info[item.Rarity].Color

	if item.Family == "Tesla" then
		local hit = {}
		local from = muzzle
		local current = target
		for _ = 1, stats.Chain do
			hit[current] = true
			beam(from, current.Position + HIT_HEIGHT, Color3.fromRGB(120, 200, 255))
			EnemyService.Damage(current, stats.Damage)
			from = current.Position + HIT_HEIGHT
			current = nearestEnemy(current.Position, CHAIN_JUMP * spacing, 0, hit)
			if not current then
				break
			end
		end
	elseif item.Family == "Catapult" or item.Family == "Mortar" then
		local radius = stats.Splash * spacing
		projectile(muzzle, hitPosition, rarityColor, 1.2, 0.4)
		burst(hitPosition, radius, Color3.fromRGB(255, 150, 60), 0.4)
		for _, enemy in EnemyService.GetEnemies() do
			if not enemy.Dead and horizontalDistance(target.Position, enemy.Position) <= radius then
				EnemyService.Damage(enemy, stats.Damage)
			end
		end
	elseif item.Family == "Frost" then
		projectile(muzzle, hitPosition, Color3.fromRGB(150, 230, 255), 0.8, 0.2)
		EnemyService.Slow(target, stats.Slow, SLOW_DURATION)
		EnemyService.Damage(target, stats.Damage)
	else -- Cannon, Turret
		local isTurret = item.Family == "Turret"
		projectile(muzzle, hitPosition, if isTurret then Color3.fromRGB(255, 230, 120) else Color3.fromRGB(40, 40, 40),
			if isTurret then 0.4 else 1, 0.15)
		EnemyService.Damage(target, stats.Damage)
	end
end

local function stepWeapon(entry, item, dt, grid)
	cooldowns[entry] = (cooldowns[entry] or 0) - dt
	if cooldowns[entry] > 0 then
		return
	end
	local stats = item.Stats
	local spacing = grid:GetSpacing()
	local origin = grid:SlotBottom(entry.X, entry.Z, 1)
	local target = nearestEnemy(origin, stats.Range * spacing, stats.MinRange and stats.MinRange * spacing)
	if not target then
		return
	end
	cooldowns[entry] = stats.Cooldown
	aim(entry, target)
	fire(entry, item, target, grid)
end

local function stepTrap(entry, item, dt, grid)
	cooldowns[entry] = (cooldowns[entry] or 0) - dt
	if cooldowns[entry] > 0 then
		return
	end
	local center = grid:SlotBottom(entry.X, entry.Z, 1)
	local halfCell = grid:GetSpacing() / 2 + 0.5
	local triggered = false
	for _, enemy in EnemyService.GetEnemies() do
		if not enemy.Dead and math.abs(enemy.Position.X - center.X) <= halfCell and math.abs(enemy.Position.Z - center.Z) <= halfCell then
			EnemyService.Damage(enemy, item.Stats.Damage)
			triggered = true
		end
	end
	if triggered then
		cooldowns[entry] = item.Stats.Cooldown
	end
end

function DefenseService.Step(dt)
	local grid = IslandService.GetGrid()
	for _, column in IslandService.GetColumns() do
		for _, entry in column do
			local item = Items.ById[entry.Id]
			if item.Category == "Weapon" then
				stepWeapon(entry, item, dt, grid)
			elseif item.Category == "Trap" then
				stepTrap(entry, item, dt, grid)
			end
		end
	end
end

return DefenseService
