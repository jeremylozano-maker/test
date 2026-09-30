-- RollMath : tirage de la rareté puis de l'objet, en tenant compte de la Luck
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Items = require(Shared:WaitForChild("Items"))
local Rarities = require(Shared:WaitForChild("Rarities"))

local RollMath = {}

local function pickWeighted(entries, rng)
	local total = 0
	for _, entry in entries do
		total += entry.Weight
	end
	local roll = rng:NextNumber() * total
	for _, entry in entries do
		-- un poids de 0 ne doit jamais être tiré (raretés exclues par une garantie)
		if entry.Weight > 0 then
			roll -= entry.Weight
			if roll <= 0 then
				return entry.Value
			end
		end
	end
	return entries[#entries].Value
end

local HIGH_RARITY_RANK = 5 -- Legendary et Mythic

-- Chances finales en % pour chaque rareté
-- luck : bonus Luck ; highRarityBonus : bonus en plus pour Legendary/Mythic ; minRank : rareté minimum (garantie)
function RollMath.GetRarityChances(luck, highRarityBonus, minRank)
	local weights, total = {}, 0
	for _, name in Rarities.Order do
		local info = Rarities.Info[name]
		local weight = info.Chance * (1 + luck * info.LuckFactor)
		if info.Rank >= HIGH_RARITY_RANK then
			weight *= 1 + (highRarityBonus or 0)
		end
		if info.Rank < (minRank or 1) then
			weight = 0
		end
		weights[name] = weight
		total += weight
	end
	local chances = {}
	for name, weight in weights do
		chances[name] = weight / total * 100
	end
	return chances
end

function RollMath.RollRarity(luck, rng, highRarityBonus, minRank)
	local chances = RollMath.GetRarityChances(luck, highRarityBonus, minRank)
	local entries = {}
	for _, name in Rarities.Order do
		table.insert(entries, { Value = name, Weight = chances[name] })
	end
	return pickWeighted(entries, rng)
end

function RollMath.RollItem(luck, rng, highRarityBonus, minRank)
	local rarity = RollMath.RollRarity(luck, rng, highRarityBonus, minRank)
	local entries = {}
	for _, item in Items.ByRarity[rarity] do
		table.insert(entries, { Value = item, Weight = Items.CategoryInfo[item.Category].RollWeight })
	end
	return pickWeighted(entries, rng)
end

return RollMath
