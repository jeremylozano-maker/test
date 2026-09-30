-- SkillTree : branches, coûts en Coins et effets des compétences
local SkillTree = {}

SkillTree.BaseRollCooldown = 2
SkillTree.MinRollCooldown = 0.5

SkillTree.Branches = {
	{ Id = "Roll", Name = "🎲 ROLL", Skills = { "AutoRoll" } },
	{ Id = "Luck", Name = "🍀 LUCK", Skills = { "Luck" } },
	{ Id = "RollSpeed", Name = "⚡ ROLL SPEED", Skills = { "RollSpeed" } },
	{ Id = "Island", Name = "🏝️ ISLAND", Skills = { "CoreHP" } },
}

-- Coût du niveau N -> N+1 = BaseCost * CostGrowth ^ N
SkillTree.Skills = {
	AutoRoll = { Name = "Auto Roll", Description = "Les rolls se lancent tout seuls.", MaxLevel = 1, BaseCost = 300, CostGrowth = 1 },
	Luck = { Name = "Luck", Description = "+0.15 Luck par niveau.", MaxLevel = 10, BaseCost = 100, CostGrowth = 1.6, PerLevel = 0.15 },
	RollSpeed = { Name = "Roll Speed", Description = "-8% de temps entre les rolls par niveau.", MaxLevel = 10, BaseCost = 80, CostGrowth = 1.5, PerLevel = 0.08 },
	CoreHP = { Name = "Core HP", Description = "+20% de vie du Core par niveau.", MaxLevel = 10, BaseCost = 120, CostGrowth = 1.55, PerLevel = 0.2 },
}

function SkillTree.GetCost(skillId, currentLevel)
	local skill = SkillTree.Skills[skillId]
	if not skill or currentLevel >= skill.MaxLevel then
		return nil
	end
	return math.floor(skill.BaseCost * skill.CostGrowth ^ currentLevel)
end

function SkillTree.GetLuck(skills)
	return (skills.Luck or 0) * SkillTree.Skills.Luck.PerLevel
end

function SkillTree.GetRollCooldown(skills)
	local level = skills.RollSpeed or 0
	local cooldown = SkillTree.BaseRollCooldown * (1 - SkillTree.Skills.RollSpeed.PerLevel) ^ level
	return math.max(SkillTree.MinRollCooldown, cooldown)
end

function SkillTree.GetCoreHPMultiplier(skills)
	return 1 + (skills.CoreHP or 0) * SkillTree.Skills.CoreHP.PerLevel
end

function SkillTree.HasAutoRoll(skills)
	return (skills.AutoRoll or 0) >= 1
end

return SkillTree
