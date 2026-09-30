-- WaveService : vagues enchaînées (jusqu'à la mort du Core ou STOP), vie du Core, récompenses, mort / revive / checkpoint
-- L'état est publié dans ReplicatedStorage.WaveInfo (attributs) pour l'interface des joueurs.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Waves = require(Shared:WaitForChild("Waves"))
local SkillTree = require(Shared:WaitForChild("SkillTree"))
local DataService = require(script.Parent:WaitForChild("DataService"))
local IslandService = require(script.Parent:WaitForChild("IslandService"))
local EnemyService = require(script.Parent:WaitForChild("EnemyService"))
local DefenseService = require(script.Parent:WaitForChild("DefenseService"))

local WaveService = {}

local waveInfo
local rng = Random.new()

local owner = nil
local phase = "Build" -- "Build" | "Wave" (vagues + pauses entre elles) | "Dead"
local currentWave = 1
local spawnQueue = {}
local spawnTimer = 0
local intermission = 0 -- pause restante avant la prochaine vague
local coreHP, coreMaxHP = 0, 0
local speed = 1
local run = { Kills = 0, Coins = 0, Waves = 0 } -- depuis la dernière mort

local function setInfo(name, value)
	waveInfo:SetAttribute(name, value)
end

local function setPhase(newPhase)
	phase = newPhase
	setInfo("Phase", newPhase)
	IslandService.SetLocked(newPhase ~= "Build")
end

local function refreshCore()
	setInfo("CoreHP", math.max(0, math.ceil(coreHP)))
	setInfo("CoreMaxHP", coreMaxHP)
end

local function resetRun()
	run = { Kills = 0, Coins = 0, Waves = 0 }
end

local function setIntermission(seconds)
	intermission = seconds
	setInfo("NextWaveIn", math.max(0, math.ceil(seconds)))
end

-- Vie du Core remise au max (au START et au Revive ; elle ne remonte pas entre deux vagues)
local function fillCore()
	local data = DataService.Get(owner)
	coreMaxHP = math.floor(Waves.CoreBaseHP * SkillTree.GetCoreHPMultiplier(data.Skills))
	coreHP = coreMaxHP
	refreshCore()
end

-- Point d'apparition au hasard dans l'océan, tout autour de l'île
local function spawnPosition()
	local grid = IslandService.GetGrid()
	local center = Vector3.new((grid.Xs[1] + grid.Xs[#grid.Xs]) / 2, grid.TopY, (grid.Zs[1] + grid.Zs[#grid.Zs]) / 2)
	local radius = math.max(grid.Xs[#grid.Xs] - grid.Xs[1], grid.Zs[#grid.Zs] - grid.Zs[1]) / 2 + Waves.SpawnDistance
	local angle = rng:NextNumber() * math.pi * 2
	return center + Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
end

local function loadOwner(player)
	owner = player
	EnemyService.Clear()
	spawnQueue = {}
	setIntermission(0)
	resetRun()
	speed = 1
	setInfo("Speed", 1)
	local data = player and DataService.Get(player)
	currentWave = data and data.Wave or 1
	setInfo("Wave", currentWave)
	setPhase("Build")
end

local function beginWave()
	spawnQueue = Waves.Build(currentWave)
	spawnTimer = 0
	setIntermission(0)
	setInfo("EnemiesLeft", #spawnQueue)
	setPhase("Wave")
end

local function onWaveCleared()
	local reward = Waves.GetReward(currentWave)
	run.Coins += reward
	run.Waves += 1
	local data = DataService.Get(owner)
	if data then
		data.Stats.BestWave = math.max(data.Stats.BestWave, currentWave)
		data.Wave = currentWave + 1
		DataService.AddCoins(owner, reward)
	end
	setInfo("LastClearedWave", currentWave)
	setInfo("LastReward", reward)
	setInfo("ClearedCount", (waveInfo:GetAttribute("ClearedCount") or 0) + 1)
	currentWave += 1
	setInfo("Wave", currentWave)
	IslandService.RestoreLayout()
	-- la vague suivante s'enchaîne après une courte pause
	setIntermission(Waves.Intermission)
end

local function onDeath()
	EnemyService.Clear()
	spawnQueue = {}
	setIntermission(0)
	setInfo("RunKills", run.Kills)
	setInfo("RunCoins", run.Coins)
	setInfo("RunWaves", run.Waves)
	setInfo("CheckpointWave", Waves.GetCheckpoint(currentWave))
	setPhase("Dead")
end

function WaveService.StartWave(player)
	if player ~= owner or phase ~= "Build" or not DataService.Get(player) then
		return false
	end
	resetRun()
	fillCore()
	beginWave()
	return true
end

-- STOP : arrête l'enchaînement tout de suite ; la vague en cours n'est pas gagnée et sera rejouée
function WaveService.Stop(player)
	if player ~= owner or phase ~= "Wave" then
		return false
	end
	EnemyService.Clear()
	spawnQueue = {}
	setIntermission(0)
	IslandService.RestoreLayout()
	setPhase("Build")
	return true
end

-- Accepter la mort : on garde les coins, la base est remise, reprise au dernier checkpoint
function WaveService.Accept(player)
	if player ~= owner or phase ~= "Dead" then
		return false
	end
	currentWave = Waves.GetCheckpoint(currentWave)
	local data = DataService.Get(player)
	if data then
		data.Wave = currentWave
	end
	setInfo("Wave", currentWave)
	resetRun()
	IslandService.RestoreLayout()
	setPhase("Build")
	return true
end

-- Revive : Core et défenses au max, on relance la vague où on est mort (sera payé en Robux)
function WaveService.Revive(player)
	if player ~= owner or phase ~= "Dead" then
		return false
	end
	IslandService.RestoreLayout()
	fillCore()
	beginWave()
	return true
end

function WaveService.SetSpeed(player, value)
	if player ~= owner or (value ~= 1 and value ~= 2) then
		return false
	end
	speed = value
	setInfo("Speed", value)
	return true
end

local function step(dt)
	if phase ~= "Wave" then
		return
	end
	dt *= speed

	if intermission > 0 then
		setIntermission(intermission - dt)
		if intermission <= 0 then
			beginWave()
		end
		return
	end

	spawnTimer -= dt
	if spawnTimer <= 0 and #spawnQueue > 0 then
		local nextSpawn = table.remove(spawnQueue, 1)
		EnemyService.Spawn(nextSpawn.Type, nextSpawn.HPMultiplier, spawnPosition())
		spawnTimer = Waves.SpawnInterval
	end

	EnemyService.Step(dt)
	DefenseService.Step(dt)

	local alive = EnemyService.Count()
	setInfo("EnemiesLeft", alive + #spawnQueue)
	if coreHP <= 0 then
		onDeath()
	elseif alive == 0 and #spawnQueue == 0 then
		onWaveCleared()
	end
end

function WaveService.Init()
	waveInfo = Instance.new("Folder")
	waveInfo.Name = "WaveInfo"
	waveInfo:SetAttribute("Phase", "Build")
	waveInfo:SetAttribute("Wave", 1)
	waveInfo:SetAttribute("Speed", 1)
	waveInfo:SetAttribute("CoreHP", 0)
	waveInfo:SetAttribute("CoreMaxHP", 0)
	waveInfo:SetAttribute("EnemiesLeft", 0)
	waveInfo:SetAttribute("NextWaveIn", 0)
	waveInfo.Parent = ReplicatedStorage

	EnemyService.OnCoreHit = function(damage)
		coreHP -= damage
		refreshCore()
	end

	EnemyService.OnKilled = function()
		run.Kills += 1
		local data = owner and DataService.Get(owner)
		if data then
			data.Stats.ZombiesKilled += 1
		end
	end

	IslandService.OwnerChanged.Event:Connect(loadOwner)
	RunService.Heartbeat:Connect(step)
end

return WaveService
