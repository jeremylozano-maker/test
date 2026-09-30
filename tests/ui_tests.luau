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

-- survol de Luck -> encart d'infos (sans bouton)
findNode("Luck").MouseEnter:Fire()
check("encart : titre LUCK 0/10", findText(treeGui, function(text) return text:find("🍀 LUCK", 1, true) and text:find("0/10", 1, true) end) ~= nil)
check("encart : coût 100", findText(treeGui, function(text) return text == "Coût : 🪙 100" end) ~= nil)
check("encart : bonus +15%", findText(treeGui, function(text) return text:find("+15%% Luck") ~= nil end) ~= nil)
check("aucun bouton UPGRADE (achat direct)", findText(treeGui, function(text) return text:find("UPGRADE") ~= nil end) == nil)
check("le survol n'achète rien", profile.Skills.Luck == 0 and purchaseCalls == 0)

-- un clic = un achat
findNode("Luck").Activated:Fire()
check("clic : 1 seule requête serveur", purchaseCalls == 1)
check("serveur : Luck niveau 1", profile.Skills.Luck == 1)
check("serveur : 100 Coins payés", profile.Coins == 900)
check("UI : niveau 1/10 sur l'hexagone", findText(findNode("Luck"), function(text) return text == "1/10" end) ~= nil)
check("UI : encart mis à jour LUCK I", findText(treeGui, function(text) return text:find("LUCK I   ", 1, true) ~= nil end) ~= nil)
check("UI : Coins 900", findText(treeGui, function(text) return text == "🪙 900" end) ~= nil)
findNode("Luck").Activated:Fire()
check("2e clic : Luck niveau 2 (160 payés)", profile.Skills.Luck == 2 and profile.Coins == 740)

-- nœud verrouillé : Auto Roll (il faut Better Rolls 2)
local callsBefore = purchaseCalls
findNode("AutoRoll").Activated:Fire()
check("verrouillé : aucune requête serveur", purchaseCalls == callsBefore)
check("verrouillé : Auto Roll toujours 0", profile.Skills.AutoRoll == 0)
check("verrouillé : prérequis affiché", findText(treeGui, function(text) return text:find("Requiert : Better Rolls niv. 2", 1, true) ~= nil end) ~= nil)
check("verrouillé : message flottant", findText(treeGui, function(text) return text:find("Prérequis manquant", 1, true) ~= nil end) ~= nil)

-- débloquer Auto Roll en cliquant 2 fois sur Better Rolls
findNode("BetterRolls").Activated:Fire()
findNode("BetterRolls").Activated:Fire()
check("serveur : Better Rolls 2", profile.Skills.BetterRolls == 2)
findNode("AutoRoll").Activated:Fire()
check("Auto Roll acheté au clic", profile.Skills.AutoRoll == 1)

-- pas assez de Coins
profile.Coins = 10
dataSync.OnClientEvent:Fire(snapshot())
callsBefore = purchaseCalls
findNode("CoreHP").Activated:Fire()
check("pas assez de Coins : aucune requête", purchaseCalls == callsBefore)
check("message 'Pas assez de Coins'", findText(treeGui, function(text) return text:find("Pas assez de Coins", 1, true) ~= nil end) ~= nil)

-- bientôt disponible
profile.Coins = 100000
dataSync.OnClientEvent:Fire(snapshot())
callsBefore = purchaseCalls
findNode("OfflineRolls").Activated:Fire()
check("Offline Rolls : aucune requête", purchaseCalls == callsBefore)
check("Offline Rolls : 'Bientôt disponible'", findText(treeGui, function(text) return text:find("Bientôt disponible", 1, true) ~= nil end) ~= nil)
check("hexagone Offline Rolls marqué BIENTÔT", findText(findNode("OfflineRolls"), function(text) return text == "BIENTÔT" end) ~= nil)

-- niveau max
profile.Skills.RollSpeed = 3
profile.Skills.QuickReveal = 2
dataSync.OnClientEvent:Fire(snapshot())
findNode("QuickReveal").Activated:Fire()
check("dernier niveau acheté au clic", profile.Skills.QuickReveal == 3)
callsBefore = purchaseCalls
findNode("QuickReveal").Activated:Fire()
check("au max : aucune requête", purchaseCalls == callsBefore)
check("au max : MAX LEVEL affiché", findText(treeGui, function(text) return text == "⭐ MAX LEVEL" end) ~= nil)
check("au max : badge MAX sur l'hexagone", (function()
	for _, object in findNode("QuickReveal"):GetDescendants() do
		if object.Text == "MAX" and object.Visible then return true end
	end
	return false
end)())

-- sortie du survol : l'encart disparaît
findNode("QuickReveal").MouseLeave:Fire()
check("encart caché après la sortie du survol", findText(treeGui, function(text) return text == "⭐ MAX LEVEL" end).Parent.Visible == false)

-- fermeture
findText(treeGui, function(text) return text == "✕" end).Activated:Fire()
check("fermé après ✕", treeGui.Enabled == false)

print(string.format("\nRÉSULTAT UI : %d réussis, %d échoués", passed, failed))
