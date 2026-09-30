-- RollService : le serveur décide du résultat de chaque roll et vérifie le cooldown.
-- Les compétences (Luck, Mythic Hunter, Roll Speed, Better Rolls, Roll Mastery) viennent de SkillTree.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local RollMath = require(Shared:WaitForChild("RollMath"))
local SkillTree = require(Shared:WaitForChild("SkillTree"))
local Rarities = require(Shared:WaitForChild("Rarities"))
local DataService = require(script.Parent:WaitForChild("DataService"))

local RollService = {}

local LATENCY_TOLERANCE = 0.1
local RARE_RANK = 3 -- Roll Mastery garantit Rare ou mieux

local lastRoll = {} -- [player] = os.clock()
local rng = Random.new()

-- Tire un objet pour le joueur et l'ajoute à son inventaire
local function rollOneItem(player, data)
	local skills = data.Skills
	local pityThreshold = SkillTree.GetPityThreshold(skills)
	local guaranteed = pityThreshold ~= nil and data.Stats.RollsSinceRare + 1 >= pityThreshold
	local item = RollMath.RollItem(SkillTree.GetLuck(skills), rng, SkillTree.GetHighRarityBonus(skills),
		if guaranteed then RARE_RANK else nil)

	if Rarities.Info[item.Rarity].Rank >= RARE_RANK then
		data.Stats.RollsSinceRare = 0
	else
		data.Stats.RollsSinceRare += 1
	end
	local isNew = not data.Index[item.Id]
	data.Stats.TotalRolls += 1
	DataService.AddItem(player, item.Id, 1)
	return item, isNew
end

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

	local item, isNew = rollOneItem(player, data)
	local result = { Ok = true, ItemId = item.Id, IsNew = isNew }

	-- Better Rolls : chance d'un 2e objet gratuit
	if rng:NextNumber() < SkillTree.GetDoubleRollChance(data.Skills) then
		local bonusItem, bonusIsNew = rollOneItem(player, data)
		result.BonusItemId = bonusItem.Id
		result.BonusIsNew = bonusIsNew
	end
	return result
end

function RollService.Init()
	Players.PlayerRemoving:Connect(function(player)
		lastRoll[player] = nil
	end)
end

return RollService
