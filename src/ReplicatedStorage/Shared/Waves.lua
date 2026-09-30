-- Waves : composition des vagues, vie du Core, récompenses et checkpoints
local Waves = {}

Waves.CoreBaseHP = 500
Waves.SpawnInterval = 0.8 -- secondes entre deux apparitions
Waves.SpawnDistance = 35 -- studs entre le bord de l'île et l'apparition des zombies
Waves.CheckpointEvery = 10
Waves.Intermission = 4 -- secondes de pause entre deux vagues enchaînées

-- Coins gagnés en survivant à la vague (x3 sur les vagues de checkpoint)
function Waves.GetReward(wave)
	local reward = 10 + 5 * wave
	if wave % Waves.CheckpointEvery == 0 then
		reward *= 3
	end
	return reward
end

-- Vague de reprise après une mort (ex : mort à la 17 -> reprise à la 11)
function Waves.GetCheckpoint(wave)
	return math.floor((wave - 1) / Waves.CheckpointEvery) * Waves.CheckpointEvery + 1
end

-- Liste des zombies à faire apparaître, dans l'ordre
function Waves.Build(wave)
	local hpMultiplier = 1.12 ^ (wave - 1)
	local count = 4 + 2 * wave
	local spawns = {}
	for index = 1, count do
		local enemyType = "WaterZombie"
		if wave >= 5 and index % 6 == 0 then
			enemyType = "TankZombie"
		elseif wave >= 3 and index % 4 == 0 then
			enemyType = "FastZombie"
		end
		table.insert(spawns, { Type = enemyType, HPMultiplier = hpMultiplier })
	end
	-- Vague de checkpoint : des Tanks en plus (le Kraken viendra ici)
	if wave % Waves.CheckpointEvery == 0 then
		for _ = 1, wave // 5 do
			table.insert(spawns, { Type = "TankZombie", HPMultiplier = hpMultiplier * 1.5 })
		end
	end
	return spawns
end

return Waves
