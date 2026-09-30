-- Items : les 40 objets du jeu (blocs, pièges, armes) et leurs stats
local Items = {}

Items.Categories = { "Block", "Trap", "Weapon" }

-- RollWeight : poids d'un objet à l'intérieur de sa rareté (les blocs sortent plus souvent)
-- Règles de placement (grille 9x13x3) :
--   Block  : empilable, peut supporter un bloc ou une arme au-dessus
--   Weapon : au sol ou sur un bloc, rien ne peut être posé dessus
--   Trap   : au sol uniquement, rien dessus, les zombies ne le ciblent pas
Items.CategoryInfo = {
	Block = { Label = "BLOCKS", RollWeight = 6, CanSupport = true, GroundOnly = false, Targetable = true },
	Trap = { Label = "TRAPS", RollWeight = 3, CanSupport = false, GroundOnly = true, Targetable = false },
	Weapon = { Label = "WEAPONS", RollWeight = 1, CanSupport = false, GroundOnly = false, Targetable = true },
}

-- Stats de base par famille (tier 1). Range / MinRange / Splash sont en cases.
Items.Families = {
	Block = { Category = "Block", Icon = "🧱", HP = 100 },
	Spike = { Category = "Trap", Icon = "🔺", Damage = 10, Cooldown = 1 },
	Cannon = { Category = "Weapon", Icon = "💣", HP = 150, Damage = 25, Range = 5, Cooldown = 1.5 },
	Tesla = { Category = "Weapon", Icon = "⚡", HP = 120, Damage = 12, Range = 3, Cooldown = 1, Chain = 3 },
	Catapult = { Category = "Weapon", Icon = "🏹", HP = 150, Damage = 40, Range = 7, Cooldown = 3, Splash = 1.5 },
	Mortar = { Category = "Weapon", Icon = "💥", HP = 130, Damage = 35, Range = 8, MinRange = 2, Cooldown = 2.5, Splash = 2 },
	Turret = { Category = "Weapon", Icon = "🎯", HP = 140, Damage = 8, Range = 4, Cooldown = 0.3 },
	Frost = { Category = "Weapon", Icon = "❄️", HP = 120, Damage = 6, Range = 4, Cooldown = 1.2, Slow = 0.3 },
}

local TIER_RARITY = { "Common", "Uncommon", "Rare", "Epic", "Legendary" }
local MYTHICS = { ThunderTesla = true, WarMortar = true, AbsoluteZero = true }
local MYTHIC_BONUS = 1.3

-- { Id, Nom, Famille, Tier, Icône (optionnelle, sinon celle de la famille) }
local DEFINITIONS = {
	{ "WoodCube", "Wood Cube", "Block", 1, "🧱" },
	{ "StoneCube", "Stone Cube", "Block", 2, "🪨" },
	{ "CopperCube", "Copper Cube", "Block", 3, "🟠" },
	{ "MetalCube", "Metal Cube", "Block", 4, "⚙️" },
	{ "ReinforcedMetalCube", "Reinforced Metal Cube", "Block", 5, "🛡️" },

	{ "WoodenSpikeTrap", "Wooden Spike Trap", "Spike", 1 },
	{ "StoneSpikeTrap", "Stone Spike Trap", "Spike", 2 },
	{ "CopperSpikeTrap", "Copper Spike Trap", "Spike", 3 },
	{ "MetalSpikeTrap", "Metal Spike Trap", "Spike", 4 },
	{ "ReinforcedSpikeTrap", "Reinforced Spike Trap", "Spike", 5 },

	{ "BasicCannon", "Basic Cannon", "Cannon", 1 },
	{ "HeavyCannon", "Heavy Cannon", "Cannon", 2 },
	{ "CopperCannon", "Copper Cannon", "Cannon", 3 },
	{ "SteelCannon", "Steel Cannon", "Cannon", 4 },
	{ "GoldenCannon", "Golden Cannon", "Cannon", 5 },

	{ "TeslaCoil", "Tesla Coil", "Tesla", 1 },
	{ "ChargedTesla", "Charged Tesla", "Tesla", 2 },
	{ "AdvancedTesla", "Advanced Tesla", "Tesla", 3 },
	{ "OverchargedTesla", "Overcharged Tesla", "Tesla", 4 },
	{ "ThunderTesla", "Thunder Tesla", "Tesla", 5 },

	{ "WoodenCatapult", "Wooden Catapult", "Catapult", 1 },
	{ "StoneCatapult", "Stone Catapult", "Catapult", 2 },
	{ "CopperCatapult", "Copper Catapult", "Catapult", 3 },
	{ "HeavyCatapult", "Heavy Catapult", "Catapult", 4 },
	{ "WarCatapult", "War Catapult", "Catapult", 5 },

	{ "BasicMortar", "Basic Mortar", "Mortar", 1 },
	{ "HeavyMortar", "Heavy Mortar", "Mortar", 2 },
	{ "CopperMortar", "Copper Mortar", "Mortar", 3 },
	{ "AdvancedMortar", "Advanced Mortar", "Mortar", 4 },
	{ "WarMortar", "War Mortar", "Mortar", 5 },

	{ "BasicTurret", "Basic Turret", "Turret", 1 },
	{ "RapidTurret", "Rapid Turret", "Turret", 2 },
	{ "HeavyTurret", "Heavy Turret", "Turret", 3 },
	{ "AdvancedTurret", "Advanced Turret", "Turret", 4 },
	{ "EliteTurret", "Elite Turret", "Turret", 5 },

	{ "FrostLauncher", "Frost Launcher", "Frost", 1 },
	{ "IceLauncher", "Ice Launcher", "Frost", 2 },
	{ "FrozenCannon", "Frozen Cannon", "Frost", 3 },
	{ "GlacierLauncher", "Glacier Launcher", "Frost", 4 },
	{ "AbsoluteZero", "Absolute Zero", "Frost", 5 },
}

local function computeStats(family, tier, isMythic)
	local t = tier - 1
	local bonus = if isMythic then MYTHIC_BONUS else 1
	local stats = {}
	for key, value in family do
		if type(value) == "number" then
			stats[key] = value
		end
	end
	if stats.HP then stats.HP = math.floor(stats.HP * 1.5 ^ t * bonus) end
	if stats.Damage then stats.Damage = math.floor(stats.Damage * 1.6 ^ t * bonus) end
	if stats.Range then stats.Range += 0.5 * t end
	if stats.Chain then stats.Chain += t end
	if stats.Splash then stats.Splash += 0.25 * t end
	if stats.Slow then stats.Slow = math.min(0.7, stats.Slow + 0.08 * t) end
	return stats
end

Items.List = {}
Items.ById = {}
Items.ByRarity = {}
Items.ByCategory = {}

for order, def in DEFINITIONS do
	local id, name, familyId, tier, icon = def[1], def[2], def[3], def[4], def[5]
	local family = Items.Families[familyId]
	local isMythic = MYTHICS[id] == true
	local item = {
		Id = id,
		Name = name,
		Family = familyId,
		Tier = tier,
		Order = order,
		Category = family.Category,
		Icon = icon or family.Icon,
		Rarity = if isMythic then "Mythic" else TIER_RARITY[tier],
		Stats = computeStats(family, tier, isMythic),
	}
	table.insert(Items.List, item)
	Items.ById[id] = item
	Items.ByRarity[item.Rarity] = Items.ByRarity[item.Rarity] or {}
	table.insert(Items.ByRarity[item.Rarity], item)
	Items.ByCategory[item.Category] = Items.ByCategory[item.Category] or {}
	table.insert(Items.ByCategory[item.Category], item)
end

return Items
