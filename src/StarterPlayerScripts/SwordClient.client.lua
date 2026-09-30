-- SwordClient : bouton d'amélioration de l'épée (l'achat est validé par le serveur)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local Shared = ReplicatedStorage:WaitForChild("Shared")
local SkillTree = require(Shared:WaitForChild("SkillTree"))
local UIKit = require(Shared:WaitForChild("UIKit"))
local HudState = require(Shared:WaitForChild("HudState"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local UPGRADE_COLOR = UIKit.BLUE

local gui = UIKit.create("ScreenGui", {
	Name = "SwordUI",
	ResetOnSpawn = false,
	Parent = player:WaitForChild("PlayerGui"),
})

-- colonne de gauche, sous Coins / Index / Inventory
local upgradeButton = UIKit.makeButton({
	Parent = gui,
	AnchorPoint = Vector2.new(0, 0.5),
	Position = UDim2.new(0, 16, 0.5, 100),
	Size = UDim2.new(0, 150, 0, 66),
	BackgroundColor3 = UPGRADE_COLOR,
	Text = "⚔️ SWORD",
	Studs = 3,
})

local snapshot = nil

local function render()
	if not snapshot then
		return
	end
	local level = snapshot.Skills.Sword or 0
	local damage = SkillTree.GetSwordDamage(snapshot.Skills)
	local cost = SkillTree.GetCost("Sword", level)
	if cost then
		upgradeButton.Text = string.format("⚔️ Lvl %d • %d dmg\n⬆️ %d 🪙", level, damage, cost)
		upgradeButton.BackgroundColor3 = if snapshot.Coins >= cost then UPGRADE_COLOR else UIKit.BUTTON_COLOR
	else
		upgradeButton.Text = string.format("⚔️ Lvl %d • %d dmg\nMAX", level, damage)
		upgradeButton.BackgroundColor3 = UIKit.BUTTON_COLOR
	end
end

-- caché en mode construction (la fenêtre des objets occupe la gauche)
local function applyHudMode(hudMode)
	upgradeButton.Visible = hudMode ~= "Build"
end
HudState.Changed:Connect(applyHudMode)
applyHudMode(HudState.Mode)

upgradeButton.Activated:Connect(function()
	Remotes.PurchaseSkill:InvokeServer("Sword")
end)

Remotes.DataSync.OnClientEvent:Connect(function(newSnapshot)
	snapshot = newSnapshot
	render()
end)

task.spawn(function()
	local initial = Remotes.GetSnapshot:InvokeServer()
	if initial and not snapshot then
		snapshot = initial
		render()
	end
end)
