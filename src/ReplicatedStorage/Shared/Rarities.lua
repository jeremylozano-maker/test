-- Rarities : chances de base, couleurs, effet de la Luck et durée de l'animation
local Rarities = {}

Rarities.Order = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic" }

-- Chance      : chance de base en %
-- LuckFactor  : poids final = Chance * (1 + Luck * LuckFactor)
-- RevealTicks / RevealMaxDelay : longueur et ralentissement de l'animation de roll
Rarities.Info = {
	Common = { Chance = 60, Color = Color3.fromRGB(200, 200, 200), LuckFactor = 0, RevealTicks = 8, RevealMaxDelay = 0.06 },
	Uncommon = { Chance = 25, Color = Color3.fromRGB(90, 210, 90), LuckFactor = 0.5, RevealTicks = 11, RevealMaxDelay = 0.1 },
	Rare = { Chance = 10, Color = Color3.fromRGB(60, 150, 255), LuckFactor = 1, RevealTicks = 14, RevealMaxDelay = 0.15 },
	Epic = { Chance = 4, Color = Color3.fromRGB(175, 85, 255), LuckFactor = 1.5, RevealTicks = 18, RevealMaxDelay = 0.2 },
	Legendary = { Chance = 0.9, Color = Color3.fromRGB(255, 190, 40), LuckFactor = 2, RevealTicks = 24, RevealMaxDelay = 0.32 },
	Mythic = { Chance = 0.1, Color = Color3.fromRGB(255, 60, 100), LuckFactor = 2.5, RevealTicks = 28, RevealMaxDelay = 0.45 },
}

for rank, name in Rarities.Order do
	Rarities.Info[name].Name = name
	Rarities.Info[name].Rank = rank
end

return Rarities
