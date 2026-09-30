-- SkillService : achat des compétences du Skill Tree (le SERVEUR décide tout).
-- Le client demande seulement "je veux acheter X" ; ici on vérifie compétence, niveau, prérequis et Coins,
-- puis on retire les Coins, on monte le niveau et on renvoie le nouvel état (via DataService -> DataSync).
-- Les données sont dans data.Skills (sauvegardées par DataService avec le reste du profil).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SkillTree = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("SkillTree"))
local DataService = require(script.Parent:WaitForChild("DataService"))

local SkillService = {}

---------------------------------------------------------------- lecture (pour les autres systèmes serveur)

function SkillService.GetSkillLevel(player, skillId)
	local data = DataService.Get(player)
	return if data then SkillTree.GetLevel(data.Skills, skillId) else 0
end

function SkillService.GetSkillBonus(player, skillId)
	return SkillTree.GetSkillBonus(skillId, SkillService.GetSkillLevel(player, skillId))
end

function SkillService.HasSkill(player, skillId)
	return SkillService.GetSkillLevel(player, skillId) >= 1
end

function SkillService.GetSkillCost(skillId, level)
	return SkillTree.GetSkillCost(skillId, level)
end

---------------------------------------------------------------- achat

-- Retourne { Ok = true, SkillId, Level, Cost } ou { Ok = false, Reason }
-- Aucun "wait" dans cette fonction : deux clics rapides sont traités l'un après l'autre,
-- le 2e voit déjà les Coins retirés par le 1er (impossible de payer deux fois le même niveau).
function SkillService.Purchase(player, skillId)
	local data = DataService.Get(player)
	if not data then
		return { Ok = false, Reason = "NoData" }
	end
	if typeof(skillId) ~= "string" then
		return { Ok = false, Reason = "InvalidSkill" }
	end

	local ok, reason, cost = SkillTree.CanUpgrade(data.Skills, data.Coins, skillId)
	if not ok then
		return { Ok = false, Reason = reason, Cost = cost }
	end

	local newLevel = SkillTree.GetLevel(data.Skills, skillId) + 1
	data.Coins -= cost
	data.Skills[skillId] = newLevel
	DataService.Notify(player) -- envoie le nouvel état (Coins + Skills) au client
	return { Ok = true, SkillId = skillId, Level = newLevel, Cost = cost }
end

return SkillService
