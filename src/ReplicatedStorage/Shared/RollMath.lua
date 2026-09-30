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
		roll -= entry.Weight
		if roll <= 0 then
			return entry.Value
		end
	end
	return entries[#entries].Value
end

-- Chances finales en % pour chaque rareté (utile aussi pour l'affichage)
function RollMath.GetRarityChances(luck)
	local weights, total = {}, 0
	for _, name in Rarities.Order do
		local info = Rarities.Info[name]
		local weight = info.Chance * (1 + luck * info.LuckFactor)
		weights[name] = weight
		total += weight
	end
	local chances = {}
	for name, weight in weights do
		chances[name] = weight / total * 100
	end
	return chances
end

function RollMath.RollRarity(luck, rng)
	local chances = RollMath.GetRarityChances(luck)
	local entries = {}
	for _, name in Rarities.Order do
		table.insert(entries, { Value = name, Weight = chances[name] })
	end
	return pickWeighted(entries, rng)
end

function RollMath.RollItem(luck, rng)
	local rarity = RollMath.RollRarity(luck, rng)
	local entries = {}
	for _, item in Items.ByRarity[rarity] do
		table.insert(entries, { Value = item, Weight = Items.CategoryInfo[item.Category].RollWeight })
	end
	return pickWeighted(entries, rng)
end

return RollMath
