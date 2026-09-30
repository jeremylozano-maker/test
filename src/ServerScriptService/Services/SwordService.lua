-- SwordService : l'épée du joueur ; le coup est validé par le serveur (portée, cooldown, dégâts)
-- Ton vrai modèle : ReplicatedStorage > un Tool nommé "SwordModel" (avec une part "Handle").
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SkillTree = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("SkillTree"))
local DataService = require(script.Parent:WaitForChild("DataService"))
local EnemyService = require(script.Parent:WaitForChild("EnemyService"))

local SwordService = {}

local SWING_COOLDOWN = 0.5
local REACH = 8 -- studs
local ARC_DOT = 0.2 -- 1 = pile devant, 0 = sur les côtés
local SLASH_SOUND_ID = "rbxasset://sounds/swordslash.wav"

-- Couleur de la lame selon le niveau : bois, fer, or, diamant, légendaire
local BLADE_LOOKS = {
	{ MinLevel = 0, Color = Color3.fromRGB(150, 110, 70), Material = Enum.Material.Wood },
	{ MinLevel = 5, Color = Color3.fromRGB(190, 195, 205), Material = Enum.Material.Metal },
	{ MinLevel = 10, Color = Color3.fromRGB(255, 200, 60), Material = Enum.Material.Metal },
	{ MinLevel = 15, Color = Color3.fromRGB(120, 230, 255), Material = Enum.Material.Glass },
	{ MinLevel = 20, Color = Color3.fromRGB(255, 60, 100), Material = Enum.Material.Neon },
}

local lastSwing = {} -- [player] = os.clock()

local function swordLevel(player)
	local data = DataService.Get(player)
	return data and data.Skills.Sword or 0
end

local function applyLook(tool, level)
	local handle = tool:FindFirstChild("Handle")
	if not handle or ReplicatedStorage:FindFirstChild("SwordModel") then
		return
	end
	local look = BLADE_LOOKS[1]
	for _, candidate in BLADE_LOOKS do
		if level >= candidate.MinLevel then
			look = candidate
		end
	end
	handle.Color = look.Color
	handle.Material = look.Material
end

local function swing(player, tool)
	local now = os.clock()
	if lastSwing[player] and now - lastSwing[player] < SWING_COOLDOWN then
		return
	end
	lastSwing[player] = now

	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local data = DataService.Get(player)
	if not root or not humanoid or humanoid.Health <= 0 or not data then
		return
	end

	-- animation de coup de l'Animate par défaut de Roblox
	local animation = Instance.new("StringValue")
	animation.Name = "toolanim"
	animation.Value = "Slash"
	animation.Parent = tool
	Debris:AddItem(animation, 1)
	local sound = tool.Handle:FindFirstChild("Slash")
	if sound then
		sound:Play()
	end

	local damage = SkillTree.GetSwordDamage(data.Skills)
	local look = (root.CFrame.LookVector * Vector3.new(1, 0, 1)).Unit
	for _, enemy in EnemyService.GetEnemies() do
		if not enemy.Dead then
			local offset = enemy.Position - root.Position
			local flat = Vector3.new(offset.X, 0, offset.Z)
			local distance = flat.Magnitude
			local inFront = distance < 2 or flat.Unit:Dot(look) > ARC_DOT
			if distance <= REACH + enemy.Radius and math.abs(offset.Y) < 8 and inFront then
				EnemyService.Damage(enemy, damage)
			end
		end
	end
end

local function makeSword()
	local template = ReplicatedStorage:FindFirstChild("SwordModel")
	if template then
		return template:Clone()
	end
	local tool = Instance.new("Tool")
	tool.CanBeDropped = false
	-- prise en main classique d'épée Roblox : la lame pointe vers l'avant
	tool.GripPos = Vector3.new(0, 0, -1.5)
	tool.GripForward = Vector3.new(-1, 0, 0)
	tool.GripRight = Vector3.new(0, 1, 0)
	tool.GripUp = Vector3.new(0, 0, 1)
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.3, 0.8, 4.5)
	handle.CanCollide = false
	handle.Massless = true
	handle.Parent = tool
	return tool
end

local function giveSword(player)
	local backpack = player:WaitForChild("Backpack")
	local tool = makeSword()
	tool.Name = "Sword"
	tool.ToolTip = "Click to hit zombies"
	local handle = tool:WaitForChild("Handle")
	local sound = Instance.new("Sound")
	sound.Name = "Slash"
	sound.SoundId = SLASH_SOUND_ID
	sound.Volume = 0.6
	sound.Parent = handle
	applyLook(tool, swordLevel(player))
	tool.Activated:Connect(function()
		swing(player, tool)
	end)
	tool.Parent = backpack
end

-- Change la couleur de l'épée après une amélioration
local function refreshLook(player)
	local level = swordLevel(player)
	for _, container in { player:FindFirstChild("Backpack"), player.Character } do
		local tool = container and container:FindFirstChild("Sword")
		if tool then
			applyLook(tool, level)
		end
	end
end

function SwordService.Init()
	local function onPlayerAdded(player)
		player.CharacterAdded:Connect(function()
			giveSword(player)
		end)
		if player.Character then
			giveSword(player)
		end
	end
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
	Players.PlayerRemoving:Connect(function(player)
		lastSwing[player] = nil
	end)
	DataService.Changed.Event:Connect(refreshLook)
end

return SwordService
