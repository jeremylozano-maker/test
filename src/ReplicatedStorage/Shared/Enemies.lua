-- Enemies : types de zombies
-- Tes vrais modèles : ReplicatedStorage > EnemyModels > un Model nommé comme le type (ex : "WaterZombie").
-- Speed en studs/seconde, Damage par coup, AttackCooldown en secondes, Size = échelle du modèle provisoire.
local Enemies = {
	WaterZombie = {
		Name = "Water Zombie",
		HP = 40,
		Speed = 5,
		Damage = 10,
		AttackCooldown = 1,
		Size = 1,
		Color = Color3.fromRGB(90, 170, 90),
	},
	FastZombie = {
		Name = "Fast Zombie",
		HP = 25,
		Speed = 9,
		Damage = 6,
		AttackCooldown = 0.7,
		Size = 0.8,
		Color = Color3.fromRGB(170, 200, 70),
	},
	TankZombie = {
		Name = "Tank Zombie",
		HP = 160,
		Speed = 3,
		Damage = 30,
		AttackCooldown = 1.5,
		Size = 1.5,
		Color = Color3.fromRGB(60, 110, 70),
	},
}

return Enemies
