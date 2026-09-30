-- SkillService : achat des niveaux du Skill Tree avec les Coins (validé par le serveur)
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SkillTree = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("SkillTree"))
local DataService = require(script.Parent:WaitForChild("DataService"))

local SkillService = {}

function SkillService.Purchase(player, skillId)
	local data = DataService.Get(player)
	if not data or typeof(skillId) ~= "string" or not SkillTree.Skills[skillId] then
		return false
	end
	local level = data.Skills[skillId] or 0
	local cost = SkillTree.GetCost(skillId, level)
	if not cost or data.Coins < cost then
		return false
	end
	data.Coins -= cost
	data.Skills[skillId] = level + 1
	DataService.Notify(player)
	return true
end

return SkillService
