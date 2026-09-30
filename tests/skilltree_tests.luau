-- Tests du Skill Tree (logique serveur + calculs partagés)
local profiles = {}
local notifyCount = 0
useModule("DataService", {
	Get = function(player) return profiles[player] end,
	Notify = function() notifyCount += 1 end,
	AddItem = function(player, itemId, amount)
		local data = profiles[player]
		data.Inventory[itemId] = (data.Inventory[itemId] or 0) + amount
		data.Index[itemId] = true
	end,
})

local Config = require({ Name = "SkillTreeConfig" })
local SkillTree = require({ Name = "SkillTree" })
local SkillService = require({ Name = "SkillService" })
local RollMath = require({ Name = "RollMath" })
local Rarities = require({ Name = "Rarities" })
local Grid = require({ Name = "Grid" })

local function newPlayer(coins)
	local player = { Name = "Player" .. math.random(1, 1e6) }
	local skills = {}
	for skillId in Config.Skills do
		skills[skillId] = 0
	end
	profiles[player] = { Coins = coins, Skills = skills, Inventory = {}, Index = {}, Stats = { TotalRolls = 0, RollsSinceRare = 0 } }
	return player, profiles[player]
end

------------------------------------------------------------------------
section("Config : cohérence")
for skillId, skill in Config.Skills do
	check(skillId .. " a une branche valide", Config.Branches[skill.Branch] ~= nil)
	check(skillId .. " MaxLevel >= 1", skill.MaxLevel >= 1)
	for _, requirement in skill.Prerequisites or {} do
		local target = Config.Skills[requirement.Skill]
		check(skillId .. " prérequis " .. requirement.Skill .. " existe", target ~= nil)
		check(skillId .. " prérequis niveau atteignable", target and requirement.Level <= target.MaxLevel)
	end
	local previous = 0
	for level = 1, skill.MaxLevel do
		local cost = SkillTree.GetSkillCost(skillId, level)
		check(skillId .. " coût niv." .. level .. " > 0 et croissant", cost ~= nil and cost > 0 and cost >= previous)
		previous = cost or previous
		check(skillId .. " DescribeBonus niv." .. level .. " ok", type(SkillTree.DescribeBonus(skillId, level)) == "string")
	end
	check(skillId .. " pas de coût au-delà du max", SkillTree.GetSkillCost(skillId, skill.MaxLevel + 1) == nil)
	check(skillId .. " pas de coût niveau 0", SkillTree.GetSkillCost(skillId, 0) == nil)
	if not Config.Branches[skill.Branch].Hidden then
		check(skillId .. " a une position dans l'arbre", skill.Position ~= nil)
	end
end
-- pas de boucle de prérequis
local function hasCycle(skillId, visiting)
	if visiting[skillId] then return true end
	visiting[skillId] = true
	for _, requirement in Config.Skills[skillId].Prerequisites or {} do
		if hasCycle(requirement.Skill, visiting) then return true end
	end
	visiting[skillId] = nil
	return false
end
for skillId in Config.Skills do
	check(skillId .. " sans boucle de prérequis", not hasCycle(skillId, {}))
end
check("4 branches visibles exactement", #Config.BranchOrder == 4)
check("Sword absent de l'arbre", table.find(SkillTree.GetTreeSkillIds(), "Sword") == nil)
check("12 compétences dans l'arbre", #SkillTree.GetTreeSkillIds() == 12)

------------------------------------------------------------------------
section("Coûts (formules et listes)")
check("Luck niv.1 = 100", SkillTree.GetSkillCost("Luck", 1) == 100)
check("Luck niv.2 = 160", SkillTree.GetSkillCost("Luck", 2) == 160)
check("QuickReveal liste niv.3 = 900", SkillTree.GetSkillCost("QuickReveal", 3) == 900)
check("GetCost(ancienne API) Sword depuis niv.0 = 50", SkillTree.GetCost("Sword", 0) == 50)
check("GetCost Sword au max = nil", SkillTree.GetCost("Sword", 20) == nil)

------------------------------------------------------------------------
section("Compatibilité avec l'ancien équilibrage")
check("Luck niv.4 = 0.6 (0.15/niveau)", math.abs(SkillTree.GetLuck({ Luck = 4 }) - 0.6) < 1e-9)
check("Cooldown niv.0 = 2 s", SkillTree.GetRollCooldown({}) == 2)
check("Cooldown niv.10 = 2*0.92^10", math.abs(SkillTree.GetRollCooldown({ RollSpeed = 10 }) - 2 * 0.92 ^ 10) < 1e-9)
check("Core HP niv.3 = x1.6", math.abs(SkillTree.GetCoreHPMultiplier({ CoreHP = 3 }) - 1.6) < 1e-9)
check("Sword dmg niv.0 = 15", SkillTree.GetSwordDamage({}) == 15)
check("Sword dmg niv.10 = 139", SkillTree.GetSwordDamage({ Sword = 10 }) == 139)
check("AutoRoll absent = false", SkillTree.HasAutoRoll({}) == false)
check("AutoRoll niv.1 = true", SkillTree.HasAutoRoll({ AutoRoll = 1 }) == true)

------------------------------------------------------------------------
section("Effets Island")
check("Build Capacity base = 40", SkillTree.GetBuildCapacity({}) == 40)
check("Build Capacity niv.1 = 50", SkillTree.GetBuildCapacity({ BuildCapacity = 1 }) == 50)
check("Build Capacity niv.20 = 240", SkillTree.GetBuildCapacity({ BuildCapacity = 20 }) == 240)
check("Build Capacity sans prérequis", SkillTree.GetNodeState({}, "BuildCapacity") == "Available")
check("Build Height base = 3", SkillTree.GetMaxBuildHeight({}) == 3)
check("Build Height niv.2 = 5", SkillTree.GetMaxBuildHeight({ BuildHeight = 2 }) == 5)

local grid = Grid.FromData({ Xs = { 0, 5, 10 }, Zs = { 0, 5, 10 }, TopY = 0, CellSize = 5, LevelHeight = 5, CoreX = 2, CoreZ = 2, CoreLevels = 2 })
local three = { "WoodCube", "WoodCube", "WoodCube" }
check("4e bloc refusé avec hauteur 3", grid:GetPlacement("WoodCube", 1, 1, three, 3) == false)
check("4e bloc refusé par défaut (ancien comportement)", grid:GetPlacement("WoodCube", 1, 1, three) == false)
local ok4, h4 = grid:GetPlacement("WoodCube", 1, 1, three, 5)
check("4e bloc accepté avec hauteur 5", ok4 == true and h4 == 4)
check("arme sur arme toujours refusée", grid:GetPlacement("BasicCannon", 1, 1, { "BasicCannon" }, 5) == false)
check("piège en hauteur toujours refusé", grid:GetPlacement("WoodenSpikeTrap", 1, 1, { "WoodCube" }, 5) == false)

------------------------------------------------------------------------
section("Achat serveur : cas normaux")
local poor = newPlayer(0)
local result = SkillService.Purchase(poor, "Luck")
check("0 Coins -> refusé NotEnoughCoins", result.Ok == false and result.Reason == "NotEnoughCoins")
check("0 Coins -> niveau inchangé", profiles[poor].Skills.Luck == 0)

local rich, richData = newPlayer(1000)
result = SkillService.Purchase(rich, "Luck")
check("achat niv.1 accepté", result.Ok == true and result.Level == 1 and result.Cost == 100)
check("100 Coins retirés", richData.Coins == 900)
check("niveau sauvegardé dans data.Skills", richData.Skills.Luck == 1)
check("état renvoyé au client (Notify)", notifyCount >= 1)
result = SkillService.Purchase(rich, "Luck")
check("achat niv.2 accepté (160)", result.Ok and richData.Skills.Luck == 2 and richData.Coins == 740)
check("GetSkillLevel = 2", SkillService.GetSkillLevel(rich, "Luck") == 2)
check("HasSkill Luck", SkillService.HasSkill(rich, "Luck") == true)
check("GetSkillBonus Luck = 0.3", math.abs(SkillService.GetSkillBonus(rich, "Luck") - 0.3) < 1e-9)
check("GetSkillCost Luck niv.3 = 256", SkillService.GetSkillCost("Luck", 3) == 256)

------------------------------------------------------------------------
section("Achat serveur : prérequis, max, bientôt")
local p, data = newPlayer(100000)
result = SkillService.Purchase(p, "AutoRoll")
check("Auto Roll sans Better Rolls 2 -> Locked", result.Ok == false and result.Reason == "Locked")
SkillService.Purchase(p, "BetterRolls")
check("Better Rolls 1 ne suffit pas", SkillService.Purchase(p, "AutoRoll").Reason == "Locked")
SkillService.Purchase(p, "BetterRolls")
result = SkillService.Purchase(p, "AutoRoll")
check("Auto Roll débloqué après Better Rolls 2", result.Ok == true and data.Skills.AutoRoll == 1)
check("Auto Roll activé pour le Roll", SkillTree.HasAutoRoll(data.Skills))
result = SkillService.Purchase(p, "AutoRoll")
check("Auto Roll au max -> MaxLevel", result.Ok == false and result.Reason == "MaxLevel")
check("Offline Rolls -> ComingSoon (non achetable)", SkillService.Purchase(p, "OfflineRolls").Reason == "ComingSoon")
check("Island Size -> ComingSoon", SkillService.Purchase(p, "IslandSize").Reason == "Locked"
	or SkillService.Purchase(p, "IslandSize").Reason == "ComingSoon")
for _ = 1, 10 do SkillService.Purchase(p, "CoreHP") end
check("Core HP monte jusqu'au max 10", data.Skills.CoreHP == 10)
check("Core HP 11e achat refusé", SkillService.Purchase(p, "CoreHP").Reason == "MaxLevel")
check("Core HP x3 au max", math.abs(SkillTree.GetCoreHPMultiplier(data.Skills) - 3) < 1e-9)
check("Build Height verrouillé sans Build Capacity 3", SkillService.Purchase(p, "BuildHeight").Reason == "Locked")
for _ = 1, 3 do SkillService.Purchase(p, "BuildCapacity") end
check("Build Height débloqué", SkillService.Purchase(p, "BuildHeight").Ok == true)
check("Sword achetable via le même service", SkillService.Purchase(p, "Sword").Ok == true)

------------------------------------------------------------------------
section("Sécurité : requêtes invalides et exploits simulés")
local hacker, hackerData = newPlayer(500)
for _, bad in { nil, 42, true, {}, "Hack", "", "luck", "__index" } do
	local r = SkillService.Purchase(hacker, bad)
	check("id invalide refusé : " .. tostring(bad), r.Ok == false)
end
check("id nil refusé", SkillService.Purchase(hacker, nil).Ok == false)
check("aucun Coin perdu avec des ids invalides", hackerData.Coins == 500)
check("joueur sans données refusé", SkillService.Purchase({ Name = "Ghost" }, "Luck").Reason == "NoData")
-- le client ne peut rien envoyer d'autre que l'id : coût / niveau / Coins viennent du serveur
local r = SkillService.Purchase(hacker, "Luck", 999, -100000)
check("arguments en trop ignorés (coût réel payé)", r.Ok and hackerData.Coins == 400 and hackerData.Skills.Luck == 1)

------------------------------------------------------------------------
section("Spam : 200 clics rapides")
local spammer, spamData = newPlayer(1000)
local successes = 0
for _ = 1, 200 do
	if SkillService.Purchase(spammer, "RollSpeed").Ok then successes += 1 end
end
local expectedSpent = 0
for level = 1, spamData.Skills.RollSpeed do expectedSpent += SkillTree.GetSkillCost("RollSpeed", level) end
check("Coins jamais négatifs", spamData.Coins >= 0)
check("niveaux = achats réussis", spamData.Skills.RollSpeed == successes)
check("Coins dépensés = somme exacte des coûts", 1000 - spamData.Coins == expectedSpent)
check("le niveau suivant était vraiment trop cher", spamData.Skills.RollSpeed == 10
	or spamData.Coins < SkillTree.GetSkillCost("RollSpeed", spamData.Skills.RollSpeed + 1))
print(string.format("   spam : %d achats réussis, %d Coins restants", successes, spamData.Coins))

------------------------------------------------------------------------
section("Luck appliquée aux vraies probabilités (RollMath)")
local base = RollMath.GetRarityChances(0)
local lucky = RollMath.GetRarityChances(SkillTree.GetLuck({ Luck = 10 }))
local hunter = RollMath.GetRarityChances(SkillTree.GetLuck({ Luck = 10 }), SkillTree.GetHighRarityBonus({ MythicHunter = 5 }))
check("chances de base = 60/25/10/4/0.9/0.1", math.abs(base.Common - 60) < 1e-9 and math.abs(base.Mythic - 0.1) < 1e-9)
check("Luck 10 augmente Mythic", lucky.Mythic > base.Mythic * 3)
check("Luck 10 baisse Common", lucky.Common < base.Common)
check("Mythic Hunter augmente encore Mythic", hunter.Mythic > lucky.Mythic)
check("Mythic Hunter ne touche pas Epic en valeur relative", hunter.Epic < lucky.Epic + 1e-9)
print(string.format("   Mythic : base %.2f%% -> Luck 10 : %.2f%% -> + Mythic Hunter 5 : %.2f%%", base.Mythic, lucky.Mythic, hunter.Mythic))

local rng = Random.new()
local counts, total = {}, 200000
local luck = SkillTree.GetLuck({ Luck = 10 })
for _ = 1, total do
	local rarity = RollMath.RollRarity(luck, rng)
	counts[rarity] = (counts[rarity] or 0) + 1
end
for _, name in Rarities.Order do
	local measured = (counts[name] or 0) / total * 100
	check(string.format("tirage réel %s ≈ %.2f%% (mesuré %.2f%%)", name, lucky[name], measured), math.abs(measured - lucky[name]) < 0.5)
end

local low = 0
for _ = 1, 50000 do
	if Rarities.Info[RollMath.RollRarity(0, rng, 0, 3)].Rank < 3 then low += 1 end
end
check("garantie Rare+ : jamais de Common/Uncommon (50 000 tirages)", low == 0)

------------------------------------------------------------------------
section("RollService : Roll Speed, Roll Mastery, Better Rolls")
local RollService = require({ Name = "RollService" })
local roller, rollData = newPlayer(0)
local first = RollService.Roll(roller)
local second = RollService.Roll(roller)
check("1er roll accepté", first.Ok == true)
check("2e roll immédiat refusé (cooldown serveur)", second.Ok == false and second.Reason == "Cooldown")
rollData.Skills.RollSpeed = 10
check("Roll Speed 10 : cooldown serveur ~0.87 s", math.abs(SkillTree.GetRollCooldown(rollData.Skills) - 0.8687) < 0.001)

-- pour tester vite : cooldown à 0 (uniquement dans ce test)
Config.Base.RollCooldown, Config.Base.MinRollCooldown = 0, 0
local mastery, masteryData = newPlayer(0)
masteryData.Skills.RollMastery = 5
local threshold = SkillTree.GetPityThreshold(masteryData.Skills)
local streak, worst = 0, 0
for _ = 1, 5000 do
	local res = RollService.Roll(mastery)
	local rank = Rarities.Info[require({ Name = "Items" }).ById[res.ItemId].Rarity].Rank
	if rank >= 3 then streak = 0 else streak += 1 end
	worst = math.max(worst, streak)
end
check("Roll Mastery 5 : seuil = 35 rolls", threshold == 35)
check(string.format("jamais plus de %d rolls sans Rare+ (pire série %d)", threshold - 1, worst), worst <= threshold - 1)

local bettor, bettorData = newPlayer(0)
bettorData.Skills.BetterRolls = 10
local bonusCount, rolls = 0, 20000
for _ = 1, rolls do
	if RollService.Roll(bettor).BonusItemId then bonusCount += 1 end
end
local rate = bonusCount / rolls
check(string.format("Better Rolls 10 : ~30%% de double roll (mesuré %.1f%%)", rate * 100), math.abs(rate - 0.3) < 0.02)
local noBonus = 0
for _ = 1, 2000 do
	if RollService.Roll(roller).BonusItemId then noBonus += 1 end
end
check("sans Better Rolls : aucun objet bonus", noBonus == 0)

------------------------------------------------------------------------
print(string.format("\nRÉSULTAT : %d réussis, %d échoués", passed, failed))
