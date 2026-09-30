-- SkillTreeConfig : TOUTES les valeurs du Skill Tree (noms, coûts, bonus, prérequis, positions, sons).
-- Modifie ce fichier pour équilibrer le jeu : aucun script n'a de valeur de compétence écrite en dur.
--
-- Coût d'un niveau (le niveau acheté = niveau actuel + 1) :
--   Cost = { Base = 100, Growth = 1.6 }        -> Base * Growth^(niveau - 1)
--   Cost = { 100, 250, 500, 900 }              -> liste exacte, une valeur par niveau
-- Bonus total au niveau N :
--   Bonus = { PerLevel = 0.15 }                -> N * PerLevel
--   Bonus = { 0.05, 0.10, 0.20 }               -> liste exacte, une valeur par niveau
-- Prerequisites = { { Skill = "Luck", Level = 5 } } -> il faut Luck niveau 5 pour débloquer
-- ComingSoon = true : visible dans l'arbre mais pas encore achetable (système pas encore codé)
-- Position = { X, Y } en "cases" autour du centre de l'arbre (X vers la droite, Y vers le bas)
local SkillTreeConfig = {}

SkillTreeConfig.Branches = {
	Roll = { Name = "ROLL", Icon = "🎲", Color = Color3.fromRGB(255, 150, 40), LabelPosition = { -1.9, -1.2 } },
	Luck = { Name = "LUCK", Icon = "🍀", Color = Color3.fromRGB(80, 210, 100), LabelPosition = { 1.1, -2.6 } },
	RollSpeed = { Name = "ROLL SPEED", Icon = "⚡", Color = Color3.fromRGB(60, 190, 255), LabelPosition = { 1.9, -1.2 } },
	Island = { Name = "ISLAND", Icon = "🏝️", Color = Color3.fromRGB(175, 110, 255), LabelPosition = { 1.3, 1.4 } },
	-- branche hors de l'arbre : l'épée s'améliore avec son propre bouton
	Sword = { Name = "SWORD", Icon = "⚔️", Color = Color3.fromRGB(200, 200, 210), Hidden = true },
}

SkillTreeConfig.BranchOrder = { "Roll", "Luck", "RollSpeed", "Island" }

-- Valeurs de base des systèmes (sans aucune compétence)
SkillTreeConfig.Base = {
	RollCooldown = 2, -- secondes entre deux rolls
	MinRollCooldown = 0.5,
	BuildCapacity = 60, -- objets posés au maximum sur l'île
	BuildHeight = 3, -- étages
	PityRolls = 60, -- Roll Mastery : un Rare+ garanti tous les N rolls
	SwordDamage = 15,
}

SkillTreeConfig.Skills = {
	---------------------------------------------------------------- 🎲 ROLL
	BetterRolls = {
		Branch = "Roll",
		Name = "Better Rolls",
		Icon = "🎁",
		Description = "Chance d'obtenir un 2e objet gratuit à chaque roll.",
		MaxLevel = 10,
		Cost = { Base = 60, Growth = 1.45 },
		Bonus = { PerLevel = 0.03 }, -- +3% de chance de double roll par niveau
		BonusFormat = "Percent", -- affiché "+30%"
		BonusSuffix = " double roll",
		Position = { -1.3, 0 },
	},
	AutoRoll = {
		Branch = "Roll",
		Name = "Auto Roll",
		Icon = "🔁",
		Description = "Débloque le bouton AUTO : les rolls se lancent tout seuls.",
		MaxLevel = 1,
		Cost = { 300 },
		Prerequisites = { { Skill = "BetterRolls", Level = 2 } },
		Position = { -2.45, -0.65 },
	},
	RollMastery = {
		Branch = "Roll",
		Name = "Roll Mastery",
		Icon = "🎯",
		Description = "Un objet Rare ou mieux est garanti après un certain nombre de rolls.",
		MaxLevel = 5,
		Cost = { Base = 250, Growth = 1.7 },
		Bonus = { PerLevel = 5 }, -- chaque niveau retire 5 rolls au compteur (niv.1 = 55 rolls)
		BonusFormat = "Pity",
		Prerequisites = { { Skill = "BetterRolls", Level = 3 } },
		Position = { -2.45, 0.65 },
	},
	OfflineRolls = {
		Branch = "Roll",
		Name = "Offline Rolls",
		Icon = "🌙",
		Description = "Accumule des rolls pendant que tu es déconnecté.",
		MaxLevel = 5,
		Cost = { Base = 800, Growth = 1.8 },
		Bonus = { PerLevel = 1 }, -- heures de rolls stockées
		BonusFormat = "Hours",
		Prerequisites = { { Skill = "AutoRoll", Level = 1 } },
		ComingSoon = true, -- le système hors ligne n'existe pas encore
		Position = { -3.6, -0.65 },
	},

	---------------------------------------------------------------- 🍀 LUCK
	Luck = {
		Branch = "Luck",
		Name = "Luck",
		Icon = "🍀",
		Description = "Augmente les chances de toutes les raretés au-dessus de Common.",
		MaxLevel = 10,
		Cost = { Base = 100, Growth = 1.6 },
		Bonus = { PerLevel = 0.15 },
		BonusFormat = "Percent",
		BonusSuffix = " Luck",
		Position = { 0, -1.2 },
	},
	MythicHunter = {
		Branch = "Luck",
		Name = "Mythic Hunter",
		Icon = "🌟",
		Description = "Bonus de chance uniquement pour les objets Legendary et Mythic.",
		MaxLevel = 5,
		Cost = { Base = 600, Growth = 1.75 },
		Bonus = { PerLevel = 0.2 },
		BonusFormat = "Percent",
		BonusSuffix = " Legendary / Mythic",
		Prerequisites = { { Skill = "Luck", Level = 5 } },
		Position = { 0, -2.4 },
	},

	---------------------------------------------------------------- ⚡ ROLL SPEED
	RollSpeed = {
		Branch = "RollSpeed",
		Name = "Roll Speed",
		Icon = "⚡",
		Description = "Réduit le temps d'attente entre deux rolls.",
		MaxLevel = 10,
		Cost = { Base = 80, Growth = 1.5 },
		Bonus = { PerLevel = 0.08 }, -- -8% de cooldown par niveau (cumulés en multiplication)
		BonusFormat = "Cooldown",
		Position = { 1.3, 0 },
	},
	QuickReveal = {
		Branch = "RollSpeed",
		Name = "Quick Reveal",
		Icon = "⏩",
		Description = "L'animation de révélation des rolls est plus rapide.",
		MaxLevel = 3,
		Cost = { 150, 400, 900 },
		Bonus = { PerLevel = 0.2 }, -- -20% de durée d'animation par niveau
		BonusFormat = "Percent",
		BonusSuffix = " plus rapide",
		Prerequisites = { { Skill = "RollSpeed", Level = 3 } },
		Position = { 2.45, 0 },
	},

	---------------------------------------------------------------- 🏝️ ISLAND
	CoreHP = {
		Branch = "Island",
		Name = "Core HP",
		Icon = "❤️",
		Description = "Augmente la vie maximum du Core.",
		MaxLevel = 10,
		Cost = { Base = 120, Growth = 1.55 },
		Bonus = { PerLevel = 0.2 },
		BonusFormat = "Percent",
		BonusSuffix = " HP du Core",
		Position = { 0, 1.2 },
	},
	BuildCapacity = {
		Branch = "Island",
		Name = "Build Capacity",
		Icon = "📦",
		Description = "Augmente le nombre maximum d'objets posés sur l'île.",
		MaxLevel = 10,
		Cost = { Base = 100, Growth = 1.5 },
		Bonus = { PerLevel = 10 }, -- +10 objets par niveau
		BonusFormat = "Flat",
		BonusSuffix = " objets",
		Prerequisites = { { Skill = "CoreHP", Level = 1 } },
		Position = { -1.1, 2.2 },
	},
	BuildHeight = {
		Branch = "Island",
		Name = "Build Height",
		Icon = "🏗️",
		Description = "Permet d'empiler plus haut sur l'île.",
		MaxLevel = 2,
		Cost = { 1500, 5000 },
		Bonus = { PerLevel = 1 }, -- +1 étage par niveau
		BonusFormat = "Flat",
		BonusSuffix = " étage(s)",
		Prerequisites = { { Skill = "BuildCapacity", Level = 3 } },
		Position = { -1.1, 3.4 },
	},
	IslandSize = {
		Branch = "Island",
		Name = "Island Size",
		Icon = "🗺️",
		Description = "Agrandit la zone constructible de l'île.",
		MaxLevel = 3,
		Cost = { 2000, 6000, 15000 },
		Bonus = { PerLevel = 1 }, -- +1 rangée de cases autour de l'île
		BonusFormat = "Flat",
		BonusSuffix = " rangée(s)",
		Prerequisites = { { Skill = "CoreHP", Level = 5 } },
		ComingSoon = true, -- demande d'agrandir le Damier : pas encore géré
		Position = { 1.1, 2.2 },
	},

	---------------------------------------------------------------- ⚔️ SWORD (bouton à part, pas dans l'arbre)
	Sword = {
		Branch = "Sword",
		Name = "Sword",
		Icon = "⚔️",
		Description = "+25% de dégâts de l'épée par niveau.",
		MaxLevel = 20,
		Cost = { Base = 50, Growth = 1.35 },
		Bonus = { PerLevel = 0.25 },
		BonusFormat = "Percent",
		BonusSuffix = " dégâts",
	},
}

-- Sons du Skill Tree (laisser "" = pas de son). Remplace par des ids de la Toolbox si tu veux.
SkillTreeConfig.Sounds = {
	Open = "rbxasset://sounds/clickfast.wav",
	Hover = "",
	Click = "rbxasset://sounds/clickfast.wav",
	Purchase = "rbxasset://sounds/electronicpingshort.wav",
	Error = "",
	Unlock = "rbxasset://sounds/electronicpingshort.wav",
	Max = "rbxasset://sounds/electronicpingshort.wav",
}

-- Mise en page de l'arbre
SkillTreeConfig.Layout = {
	CellSize = 150, -- pixels entre deux positions (1 "case")
	NodeSize = 116, -- largeur d'un hexagone
	HubSize = 170, -- hexagone central
	MinZoom = 0.45,
	MaxZoom = 1.6,
}

return SkillTreeConfig
