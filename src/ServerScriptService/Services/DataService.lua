-- DataService : chargement, sauvegarde et modification des données joueur (serveur uniquement)
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local DataService = {}

local STORE_NAME = "BuildYourIslandRNG_v1"
local AUTOSAVE_INTERVAL = 60

local store = DataStoreService:GetDataStore(STORE_NAME)
local profiles = {} -- [player] = data
local canSave = {} -- [player] = bool

-- Déclenché à chaque modification : (player, data)
DataService.Changed = Instance.new("BindableEvent")

local function defaultData()
	return {
		Version = 1,
		Coins = 0,
		Wave = 1, -- prochaine vague à jouer
		Inventory = {}, -- [itemId] = quantité non placée
		Index = {}, -- [itemId] = true
		Skills = { AutoRoll = 0, Luck = 0, RollSpeed = 0, CoreHP = 0, Sword = 0 },
		Island = {}, -- { { Id, X, Z, H }, ... }
		Stats = { TotalRolls = 0, BestWave = 0, ZombiesKilled = 0, CoinsEarned = 0 },
	}
end

-- Ajoute les champs manquants (anciennes sauvegardes)
local function reconcile(data, template)
	for key, value in template do
		if data[key] == nil then
			data[key] = value
		elseif type(value) == "table" and type(data[key]) == "table" then
			reconcile(data[key], value)
		end
	end
end

local function keyFor(player)
	return "Player_" .. player.UserId
end

local function loadPlayer(player)
	local ok, result
	for attempt = 1, 3 do
		ok, result = pcall(store.GetAsync, store, keyFor(player))
		if ok then
			break
		end
		task.wait(attempt)
	end
	if not player.Parent then
		return
	end

	if ok then
		canSave[player] = true
	elseif RunService:IsStudio() then
		warn("[DataService] DataStore indisponible : active 'Enable Studio Access to API Services'. Données temporaires, rien ne sera sauvegardé.")
		result = nil
		canSave[player] = false
	else
		player:Kick("Impossible de charger tes données. Réessaie dans un instant.")
		return
	end

	local data = result or defaultData()
	reconcile(data, defaultData())
	profiles[player] = data
	DataService.Changed:Fire(player, data)
end

local function savePlayer(player)
	local data = profiles[player]
	if not data or not canSave[player] then
		return
	end
	local ok, err = pcall(store.UpdateAsync, store, keyFor(player), function()
		return data
	end)
	if not ok then
		warn("[DataService] Sauvegarde échouée pour " .. player.Name .. " : " .. tostring(err))
	end
end

local function releasePlayer(player)
	savePlayer(player)
	profiles[player] = nil
	canSave[player] = nil
end

function DataService.Get(player)
	return profiles[player]
end

-- Attend que les données soient chargées (nil si le joueur part ou timeout)
function DataService.WaitFor(player, timeout)
	local start = os.clock()
	while not profiles[player] and player.Parent and os.clock() - start < (timeout or 15) do
		task.wait(0.1)
	end
	return profiles[player]
end

function DataService.Notify(player)
	local data = profiles[player]
	if data then
		DataService.Changed:Fire(player, data)
	end
end

function DataService.AddItem(player, itemId, amount)
	local data = profiles[player]
	if not data then
		return false
	end
	data.Inventory[itemId] = (data.Inventory[itemId] or 0) + amount
	data.Index[itemId] = true
	DataService.Notify(player)
	return true
end

function DataService.RemoveItem(player, itemId, amount)
	local data = profiles[player]
	local count = data and data.Inventory[itemId] or 0
	if count < amount then
		return false
	end
	data.Inventory[itemId] = if count == amount then nil else count - amount
	DataService.Notify(player)
	return true
end

function DataService.AddCoins(player, amount)
	local data = profiles[player]
	if not data then
		return false
	end
	data.Coins += amount
	if amount > 0 then
		data.Stats.CoinsEarned += amount
	end
	DataService.Notify(player)
	return true
end

function DataService.Init()
	Players.PlayerAdded:Connect(loadPlayer)
	for _, player in Players:GetPlayers() do
		task.spawn(loadPlayer, player)
	end
	Players.PlayerRemoving:Connect(releasePlayer)

	game:BindToClose(function()
		local pending = 0
		for player in profiles do
			pending += 1
			task.spawn(function()
				savePlayer(player)
				pending -= 1
			end)
		end
		local start = os.clock()
		while pending > 0 and os.clock() - start < 25 do
			task.wait(0.1)
		end
	end)

	task.spawn(function()
		while true do
			task.wait(AUTOSAVE_INTERVAL)
			for player in profiles do
				task.spawn(savePlayer, player)
			end
		end
	end)
end

return DataService
