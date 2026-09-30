---------------------------------------------------------------- mise en place : modules, serveur, remotes
local cache = {}
function require(moduleScript)
	local name = moduleScript.Name
	if cache[name] == nil then
		cache[name] = assert(Modules[name], "module inconnu " .. name)(moduleScript)
	end
	return cache[name]
end
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local shared = Instance.new("Folder"); shared.Name = "Shared"; shared.Parent = ReplicatedStorage
for _, name in { "Items", "Rarities", "SkillTreeConfig", "SkillTree", "UIKit", "HexUI" } do
	local module = Instance.new("ModuleScript"); module.Name = name; module.Parent = shared
end
local services = Instance.new("Folder"); services.Name = "Services"
for _, name in { "SkillService", "DataService" } do
	local module = Instance.new("ModuleScript"); module.Name = name; module.Parent = services
end

-- faux DataService côté serveur
local SkillTreeConfig = require(shared.SkillTreeConfig)
local profile = { Coins = 1000, Skills = {}, Inventory = {}, Index = {}, Stats = {} }
for skillId in SkillTreeConfig.Skills do profile.Skills[skillId] = 0 end
local serverPlayer = { Name = "Tester" }
cache.DataService = { Get = function(p) return if p == serverPlayer then profile else nil end, Notify = function() end }
local SkillService = require(services.SkillService)

local remotes = Instance.new("Folder"); remotes.Name = "Remotes"; remotes.Parent = ReplicatedStorage
local dataSync = Instance.new("RemoteEvent"); dataSync.Name = "DataSync"; dataSync.Parent = remotes
local function snapshot() return { Coins = profile.Coins, Skills = table.clone(profile.Skills), Inventory = {}, Index = {} } end
local getSnapshot = Instance.new("RemoteFunction"); getSnapshot.Name = "GetSnapshot"; getSnapshot.Parent = remotes
getSnapshot.InvokeServer = function() return snapshot() end
local purchase = Instance.new("RemoteFunction"); purchase.Name = "PurchaseSkill"; purchase.Parent = remotes
local purchaseCalls = 0
purchase.InvokeServer = function(_, skillId)
	purchaseCalls += 1
	local result = SkillService.Purchase(serverPlayer, skillId)
	dataSync.OnClientEvent:Fire(snapshot())
	return result
end

---------------------------------------------------------------- tests
local passed, failed = 0, 0
local function check(label, condition)
	if condition then passed += 1 else failed += 1; print("❌ ÉCHEC : " .. label) end
end
local playerGui = game:GetService("Players").LocalPlayer.PlayerGui

local ok, err = pcall(Modules.SkillTreeClient, Instance.new("LocalScript"))
check("SkillTreeClient s'exécute sans erreur : " .. tostring(err), ok)

local treeGui = playerGui:FindFirstChild("SkillTreeUI")
local hudGui = playerGui:FindFirstChild("SkillsButtonUI")
check("écran SkillTreeUI créé", treeGui ~= nil)
check("bouton 🌳 SKILLS créé", hudGui ~= nil)

local function findText(root, predicate)
	for _, object in root:GetDescendants() do
		if (object:IsA("TextLabel") or object:IsA("TextButton")) and object.Text and predicate(object.Text) then return object end
	end
	return nil
end
local function findNode(skillId)
	for _, object in treeGui:GetDescendants() do
		if object.Name == skillId and object:IsA("TextButton") then return object end
	end
end

local nodeCount = 0
for _, skillId in require(shared.SkillTree).GetTreeSkillIds() do
	if findNode(skillId) then nodeCount += 1 end
end
check("12 hexagones créés", nodeCount == 12)
check("fermé au départ", treeGui.Enabled == false)

local openButton = findText(hudGui, function(text) return text == "🌳 SKILLS" end)
openButton.Activated:Fire()
check("ouvert après clic sur SKILLS", treeGui.Enabled == true)
check("Coins affichés 1,000", findText(treeGui, function(text) return text == "🪙 1,000" end) ~= nil)

-- clic sur Luck -> fenêtre d'amélioration
findNode("Luck").Activated:Fire()
check("fenêtre ouverte avec titre LUCK", findText(treeGui, function(text) return text == "🍀 LUCK" end) ~= nil)
check("coût affiché 100", findText(treeGui, function(text) return text == "Coût : 🪙 100" end) ~= nil)
check("bonus affiché +0% -> +15%", findText(treeGui, function(text) return text:find("+15%% Luck") ~= nil end) ~= nil)

local upgrade = findText(treeGui, function(text) return text == "⬆️ UPGRADE" end)
check("bouton UPGRADE actif", upgrade ~= nil)
upgrade.Activated:Fire()
check("serveur : Luck niveau 1", profile.Skills.Luck == 1)
check("serveur : 100 Coins payés", profile.Coins == 900)
check("UI : titre LUCK I", findText(treeGui, function(text) return text == "🍀 LUCK I" end) ~= nil)
check("UI : niveau 1/10 sur l'hexagone", findText(findNode("Luck"), function(text) return text == "1/10" end) ~= nil)
check("UI : Coins 900", findText(treeGui, function(text) return text == "🪙 900" end) ~= nil)

-- nœud verrouillé : Auto Roll (il faut Better Rolls 2)
local callsBefore = purchaseCalls
findNode("AutoRoll").Activated:Fire()
check("Auto Roll affiche le prérequis", findText(treeGui, function(text) return text:find("Requiert : Better Rolls niv. 2") ~= nil end) ~= nil)
findText(treeGui, function(text) return text == "🔒 UPGRADE" end).Activated:Fire()
check("clic UPGRADE verrouillé : aucune requête serveur", purchaseCalls == callsBefore)
check("serveur : Auto Roll toujours 0", profile.Skills.AutoRoll == 0)

-- débloquer Auto Roll en achetant Better Rolls 2 fois
findNode("BetterRolls").Activated:Fire()
findText(treeGui, function(text) return text == "⬆️ UPGRADE" end).Activated:Fire()
findText(treeGui, function(text) return text == "⬆️ UPGRADE" end).Activated:Fire()
check("serveur : Better Rolls 2", profile.Skills.BetterRolls == 2)
findNode("AutoRoll").Activated:Fire()
check("Auto Roll maintenant achetable", findText(treeGui, function(text) return text == "⬆️ UPGRADE" end) ~= nil)

-- pas assez de Coins
profile.Coins = 10
dataSync.OnClientEvent:Fire(snapshot())
findNode("CoreHP").Activated:Fire()
callsBefore = purchaseCalls
findText(treeGui, function(text) return text == "🔒 UPGRADE" end).Activated:Fire()
check("pas assez de Coins : aucune requête", purchaseCalls == callsBefore)
check("message 'Pas assez de Coins'", findText(treeGui, function(text) return text:find("Pas assez de Coins") ~= nil end) ~= nil)

-- bientôt disponible
profile.Coins = 100000
profile.Skills.AutoRoll = 1
dataSync.OnClientEvent:Fire(snapshot())
findNode("OfflineRolls").Activated:Fire()
check("Offline Rolls : 'Bientôt disponible'", findText(treeGui, function(text) return text:find("Bientôt disponible") ~= nil end) ~= nil)
check("hexagone Offline Rolls marqué BIENTÔT", findText(findNode("OfflineRolls"), function(text) return text == "BIENTÔT" end) ~= nil)

-- niveau max
findNode("QuickReveal").Activated:Fire()
check("Quick Reveal verrouillé sans Roll Speed 3", findText(treeGui, function(text) return text:find("Roll Speed niv. 3") ~= nil end) ~= nil)
profile.Skills.RollSpeed = 3
profile.Skills.QuickReveal = 3
dataSync.OnClientEvent:Fire(snapshot())
findNode("QuickReveal").Activated:Fire()
check("niveau max : MAX LEVEL affiché", findText(treeGui, function(text) return text == "⭐ MAX LEVEL" end) ~= nil)
check("niveau max : badge MAX sur l'hexagone", (function()
	for _, object in findNode("QuickReveal"):GetDescendants() do
		if object.Text == "MAX" and object.Visible then return true end
	end
	return false
end)())

-- fermeture
findText(treeGui, function(text) return text == "✕" end).Activated:Fire()
check("fermé après ✕", treeGui.Enabled == false)

print(string.format("\nRÉSULTAT UI : %d réussis, %d échoués", passed, failed))
