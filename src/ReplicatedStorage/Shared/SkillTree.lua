-- SkillTree : calculs du Skill Tree (coûts, bonus, prérequis, effets), à partir de SkillTreeConfig.
-- Utilisé par le serveur (source de vérité) ET par le client (uniquement pour l'affichage).
-- `skills` = la table des niveaux du joueur : { Luck = 3, AutoRoll = 1, ... } (0 si absent)
local Config = require(script.Parent:WaitForChild("SkillTreeConfig"))

local SkillTree = {}

SkillTree.Config = Config
SkillTree.Skills = Config.Skills
SkillTree.BaseRollCooldown = Config.Base.RollCooldown
SkillTree.MinRollCooldown = Config.Base.MinRollCooldown

---------------------------------------------------------------- niveaux, coûts, bonus

function SkillTree.GetLevel(skills, skillId)
	return skills and skills[skillId] or 0
end

-- Coût pour acheter le niveau `level` (1 = premier niveau). nil si ce niveau n'existe pas.
function SkillTree.GetSkillCost(skillId, level)
	local skill = Config.Skills[skillId]
	if not skill or level < 1 or level > skill.MaxLevel then
		return nil
	end
	local cost = skill.Cost
	if cost.Base then
		return math.floor(cost.Base * (cost.Growth or 1) ^ (level - 1))
	end
	return cost[level] or cost[#cost]
end

-- Coût du prochain niveau à partir du niveau actuel (nil si déjà au max)
function SkillTree.GetCost(skillId, currentLevel)
	return SkillTree.GetSkillCost(skillId, currentLevel + 1)
end

-- Bonus total d'une compétence au niveau donné (0 au niveau 0)
function SkillTree.GetSkillBonus(skillId, level)
	local skill = Config.Skills[skillId]
	if not skill or not skill.Bonus or level <= 0 then
		return 0
	end
	local bonus = skill.Bonus
	if bonus.PerLevel then
		return bonus.PerLevel * math.min(level, skill.MaxLevel)
	end
	return bonus[math.min(level, #bonus)] or 0
end

---------------------------------------------------------------- prérequis et état des nœuds

-- Liste des prérequis pas encore atteints : { { Skill, Level }, ... }
function SkillTree.GetMissingPrerequisites(skills, skillId)
	local missing = {}
	for _, requirement in Config.Skills[skillId].Prerequisites or {} do
		if SkillTree.GetLevel(skills, requirement.Skill) < requirement.Level then
			table.insert(missing, requirement)
		end
	end
	return missing
end

function SkillTree.ArePrerequisitesMet(skills, skillId)
	return #SkillTree.GetMissingPrerequisites(skills, skillId) == 0
end

-- Le prochain niveau peut-il être acheté ? Retourne (ok, raison du refus, coût)
-- Raisons : "InvalidSkill", "MaxLevel", "ComingSoon", "Locked", "NotEnoughCoins"
function SkillTree.CanUpgrade(skills, coins, skillId)
	local skill = Config.Skills[skillId]
	if not skill then
		return false, "InvalidSkill", nil
	end
	local level = SkillTree.GetLevel(skills, skillId)
	if level >= skill.MaxLevel then
		return false, "MaxLevel", nil
	end
	if skill.ComingSoon then
		return false, "ComingSoon", nil
	end
	if not SkillTree.ArePrerequisitesMet(skills, skillId) then
		return false, "Locked", nil
	end
	local cost = SkillTree.GetSkillCost(skillId, level + 1)
	if coins < cost then
		return false, "NotEnoughCoins", cost
	end
	return true, nil, cost
end

-- État d'affichage d'un nœud : "Locked" | "ComingSoon" | "Available" | "Purchased" | "Maxed"
function SkillTree.GetNodeState(skills, skillId)
	local skill = Config.Skills[skillId]
	local level = SkillTree.GetLevel(skills, skillId)
	if level >= skill.MaxLevel then
		return "Maxed"
	elseif skill.ComingSoon then
		return "ComingSoon"
	elseif not SkillTree.ArePrerequisitesMet(skills, skillId) then
		return "Locked"
	elseif level > 0 then
		return "Purchased"
	end
	return "Available"
end

-- Compétences affichées dans l'arbre (les branches cachées comme Sword sont exclues)
function SkillTree.GetTreeSkillIds()
	local ids = {}
	for skillId, skill in Config.Skills do
		if not Config.Branches[skill.Branch].Hidden then
			table.insert(ids, skillId)
		end
	end
	table.sort(ids)
	return ids
end

---------------------------------------------------------------- effets utilisés par les autres systèmes

-- 🍀 Luck : multiplie le poids des raretés au-dessus de Common (voir RollMath)
function SkillTree.GetLuck(skills)
	return SkillTree.GetSkillBonus("Luck", SkillTree.GetLevel(skills, "Luck"))
end

-- 🍀 Mythic Hunter : bonus supplémentaire pour Legendary et Mythic uniquement
function SkillTree.GetHighRarityBonus(skills)
	return SkillTree.GetSkillBonus("MythicHunter", SkillTree.GetLevel(skills, "MythicHunter"))
end

-- 🎲 Better Rolls : chance (0 à 1) de recevoir un 2e objet
function SkillTree.GetDoubleRollChance(skills)
	return SkillTree.GetSkillBonus("BetterRolls", SkillTree.GetLevel(skills, "BetterRolls"))
end

-- 🎲 Roll Mastery : nombre de rolls avant un Rare+ garanti (nil si pas débloqué)
function SkillTree.GetPityThreshold(skills)
	local level = SkillTree.GetLevel(skills, "RollMastery")
	if level <= 0 then
		return nil
	end
	return Config.Base.PityRolls - SkillTree.GetSkillBonus("RollMastery", level)
end

function SkillTree.HasAutoRoll(skills)
	return SkillTree.GetLevel(skills, "AutoRoll") >= 1
end

-- 🎲 Offline Rolls : heures de rolls stockées hors ligne (système à venir)
function SkillTree.GetOfflineRollHours(skills)
	return SkillTree.GetSkillBonus("OfflineRolls", SkillTree.GetLevel(skills, "OfflineRolls"))
end

-- ⚡ Roll Speed : secondes minimum entre deux rolls (le serveur fait respecter ce délai)
function SkillTree.GetRollCooldown(skills)
	local level = SkillTree.GetLevel(skills, "RollSpeed")
	local reduction = Config.Skills.RollSpeed.Bonus.PerLevel
	return math.max(Config.Base.MinRollCooldown, Config.Base.RollCooldown * (1 - reduction) ^ level)
end

-- ⚡ Quick Reveal : multiplicateur de durée de l'animation de roll (1 = normal)
function SkillTree.GetRevealDurationMultiplier(skills)
	return math.max(0.3, 1 - SkillTree.GetSkillBonus("QuickReveal", SkillTree.GetLevel(skills, "QuickReveal")))
end

-- 🏝️ Core HP : multiplicateur de la vie du Core
function SkillTree.GetCoreHPMultiplier(skills)
	return 1 + SkillTree.GetSkillBonus("CoreHP", SkillTree.GetLevel(skills, "CoreHP"))
end

-- 🏝️ Build Capacity : nombre maximum d'objets posés sur l'île
function SkillTree.GetBuildCapacity(skills)
	return Config.Base.BuildCapacity + SkillTree.GetSkillBonus("BuildCapacity", SkillTree.GetLevel(skills, "BuildCapacity"))
end

-- 🏝️ Build Height : nombre d'étages autorisés
function SkillTree.GetMaxBuildHeight(skills)
	return Config.Base.BuildHeight + SkillTree.GetSkillBonus("BuildHeight", SkillTree.GetLevel(skills, "BuildHeight"))
end

-- 🏝️ Island Size : rangées de cases en plus (système à venir)
function SkillTree.GetIslandSizeBonus(skills)
	return SkillTree.GetSkillBonus("IslandSize", SkillTree.GetLevel(skills, "IslandSize"))
end

-- ⚔️ Sword : dégâts d'un coup d'épée (+X% par niveau, cumulés en multiplication)
function SkillTree.GetSwordDamage(skills)
	local level = SkillTree.GetLevel(skills, "Sword")
	return math.floor(Config.Base.SwordDamage * (1 + Config.Skills.Sword.Bonus.PerLevel) ^ level)
end

---------------------------------------------------------------- texte des bonus (affichage)

-- Ex : DescribeBonus("Luck", 3) -> "+45% Luck"
function SkillTree.DescribeBonus(skillId, level)
	local skill = Config.Skills[skillId]
	if not skill.Bonus then
		return if level >= 1 then "Unlocked" else "Locked"
	end
	local value = SkillTree.GetSkillBonus(skillId, level)
	local format = skill.BonusFormat
	if format == "Percent" then
		return string.format("+%d%%%s", math.floor(value * 100 + 0.5), skill.BonusSuffix or "")
	elseif format == "Cooldown" then
		return string.format("%.2fs between rolls", SkillTree.GetRollCooldown({ [skillId] = level }))
	elseif format == "Pity" then
		if level <= 0 then
			return "No guarantee"
		end
		return string.format("Rare+ guaranteed every %d rolls", SkillTree.GetPityThreshold({ [skillId] = level }))
	elseif format == "Hours" then
		return string.format("%dh of offline rolls", value)
	end
	return string.format("+%d%s", value, skill.BonusSuffix or "")
end

return SkillTree
