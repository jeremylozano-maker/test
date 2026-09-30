-- Main : crée les Remotes et démarre les services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local SkillTree = require(Shared:WaitForChild("SkillTree"))

local Services = ServerScriptService:WaitForChild("Services")
local DataService = require(Services:WaitForChild("DataService"))
local RollService = require(Services:WaitForChild("RollService"))
local IslandService = require(Services:WaitForChild("IslandService"))

local remotes = Instance.new("Folder")
remotes.Name = "Remotes"

local function makeRemote(className, name)
	local remote = Instance.new(className)
	remote.Name = name
	remote.Parent = remotes
	return remote
end

local getSnapshot = makeRemote("RemoteFunction", "GetSnapshot")
local rollRemote = makeRemote("RemoteFunction", "Roll")
local dataSync = makeRemote("RemoteEvent", "DataSync")
local placeRemote = makeRemote("RemoteFunction", "PlaceItem")
local deleteRemote = makeRemote("RemoteFunction", "DeleteItem")
remotes.Parent = ReplicatedStorage

-- Ce que le client a le droit de voir de ses données
local function snapshot(data)
	return {
		Coins = data.Coins,
		Inventory = data.Inventory,
		Index = data.Index,
		Skills = data.Skills,
		Stats = data.Stats,
		RollCooldown = SkillTree.GetRollCooldown(data.Skills),
		Luck = SkillTree.GetLuck(data.Skills),
	}
end

DataService.Changed.Event:Connect(function(player, data)
	dataSync:FireClient(player, snapshot(data))
end)

getSnapshot.OnServerInvoke = function(player)
	local data = DataService.WaitFor(player, 15)
	return data and snapshot(data)
end

rollRemote.OnServerInvoke = function(player)
	return RollService.Roll(player)
end

placeRemote.OnServerInvoke = function(player, itemId, x, z)
	return IslandService.Place(player, itemId, x, z)
end

deleteRemote.OnServerInvoke = function(player, x, z, h)
	return IslandService.Delete(player, x, z, h)
end

DataService.Init()
RollService.Init()
IslandService.Init()
