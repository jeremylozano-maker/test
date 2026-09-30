-- RollService : le serveur décide du résultat de chaque roll et vérifie le cooldown
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local RollMath = require(Shared:WaitForChild("RollMath"))
local SkillTree = require(Shared:WaitForChild("SkillTree"))
local DataService = require(script.Parent:WaitForChild("DataService"))

local RollService = {}

local LATENCY_TOLERANCE = 0.1

local lastRoll = {} -- [player] = os.clock()
local rng = Random.new()

function RollService.Roll(player)
	local data = DataService.Get(player)
	if not data then
		return { Ok = false, Reason = "Loading" }
	end

	local now = os.clock()
	local cooldown = SkillTree.GetRollCooldown(data.Skills)
	local last = lastRoll[player]
	if last and now - last < cooldown - LATENCY_TOLERANCE then
		return { Ok = false, Reason = "Cooldown", Remaining = cooldown - (now - last) }
	end
	lastRoll[player] = now

	local item = RollMath.RollItem(SkillTree.GetLuck(data.Skills), rng)
	local isNew = not data.Index[item.Id]
	data.Stats.TotalRolls += 1
	DataService.AddItem(player, item.Id, 1)

	return { Ok = true, ItemId = item.Id, IsNew = isNew }
end

function RollService.Init()
	Players.PlayerRemoving:Connect(function(player)
		lastRoll[player] = nil
	end)
end

return RollService
