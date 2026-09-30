-- Tests de la mise en page du HUD : Roll, Vagues, Construction, Épée, dans un faux Roblox
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
for _, name in { "Items", "Rarities", "RollMath", "SkillTreeConfig", "SkillTree", "UIKit", "HudState", "Grid", "ItemVisuals" } do
	local module = Instance.new("ModuleScript"); module.Name = name; module.Parent = shared
end

-- état envoyé par le "serveur"
local skills = {}
for skillId in require(shared.SkillTreeConfig).Skills do skills[skillId] = 0 end
local snapshot = { Coins = 500, Skills = skills, Inventory = { WoodCube = 5, BasicCannon = 2, WoodenSpikeTrap = 3 }, Index = { WoodCube = true }, RollCooldown = 2 }

local remotes = Instance.new("Folder"); remotes.Name = "Remotes"; remotes.Parent = ReplicatedStorage
local function remote(className, name)
	local r = Instance.new(className); r.Name = name; r.Parent = remotes; return r
end
local dataSync = remote("RemoteEvent", "DataSync")
remote("RemoteFunction", "GetSnapshot").InvokeServer = function() return snapshot end
local rollCalls = 0
remote("RemoteFunction", "Roll").InvokeServer = function() rollCalls += 1; return { Ok = true, ItemId = "WoodCube", IsNew = false } end
local calls = {}
for _, name in { "StartWave", "StopWaves", "SetWaveSpeed", "ResolveDeath", "PurchaseSkill", "PlaceItem", "DeleteItem", "ClearIsland" } do
	remote("RemoteFunction", name).InvokeServer = function(_, ...) calls[name] = (calls[name] or 0) + 1 end
end

local waveInfo = Instance.new("Folder"); waveInfo.Name = "WaveInfo"; waveInfo.Parent = ReplicatedStorage
waveInfo:SetAttribute("Phase", "Build"); waveInfo:SetAttribute("Wave", 1); waveInfo:SetAttribute("Speed", 1)
local gridInfo = Instance.new("Folder"); gridInfo.Name = "GridInfo"; gridInfo.Parent = ReplicatedStorage
_G_JSON = { grid = { Xs = { 0, 5, 10 }, Zs = { 0, 5, 10 }, TopY = 0, CellSize = 5, LevelHeight = 5, CoreX = 2, CoreZ = 2, CoreLevels = 2 } }
gridInfo:SetAttribute("Data", "grid")
gridInfo:SetAttribute("OwnerUserId", 1)
rawget(game:GetService("Players").LocalPlayer, "__props").UserId = 1
local placed = Instance.new("Folder"); placed.Name = "PlacedObjects"; placed.Parent = workspace

local passed, failed = 0, 0
local function check(label, condition)
	if condition then passed += 1 else failed += 1; print("❌ ÉCHEC : " .. label) end
end

for _, scriptName in { "RollClient", "WaveClient", "BuildClient", "SwordClient" } do
	local ok, err = pcall(Modules[scriptName], Instance.new("LocalScript"))
	check(scriptName .. " s'exécute sans erreur : " .. tostring(err), ok)
end
dataSync.OnClientEvent:Fire(snapshot)

local playerGui = game:GetService("Players").LocalPlayer.PlayerGui
local function find(predicate)
	for _, object in playerGui:GetDescendants() do
		if object.Text ~= nil and predicate(object.Text) then return object end
	end
end
-- un élément est vraiment visible si lui et tous ses parents le sont
local function shown(object)
	while object and object ~= playerGui do
		if object.Visible == false or object.Enabled == false then return false end
		object = object.Parent
	end
	return true
end
local function button(label) return find(function(t) return t == label end).Parent end
local HudState = require(shared.HudState)

-- écran normal
local roll, build = button("ROLL"), button("Build")
local startWave = find(function(t) return t == "▶️ Start Wave" end)
check("normal : ROLL visible", shown(roll))
check("normal : Build visible", shown(build))
check("normal : Start Wave visible", shown(startWave))
check("normal : Coins visibles", shown(find(function(t) return t == "🪙 500" end)))
check("normal : Index visible", shown(find(function(t) return t == "📖 Index" end)))
check("normal : Auto caché", not shown(button("🔒 Auto")))
check("normal : Close caché", not shown(button("Close")))
check("normal : Exit caché", not shown(button("Exit")))

-- ROLL : ouvre la fenêtre des dés et lance un roll
roll.Activated:Fire()
check("ROLL : mode Roll", HudState.Mode == "Roll")
check("ROLL : 1 roll demandé au serveur", rollCalls == 1)
check("Roll : Auto visible", shown(button("🔒 Auto")))
check("Roll : Close visible", shown(button("Close")))
check("Roll : Build caché", not shown(build))
check("Roll : chances '1 in N' affichées", find(function(t) return t:match("^1 in %d+$") ~= nil end) ~= nil)
button("🔒 Auto").Activated:Fire()
check("Auto verrouillé : renvoie vers les Skills", find(function(t) return t == "🌳 Skills!" end) ~= nil)
runTasks(200) -- fin de l'animation du roll (10 s simulées)
-- Auto Roll débloqué : il continue après la fermeture de la fenêtre
snapshot.Skills.AutoRoll = 1
dataSync.OnClientEvent:Fire(snapshot)
button("Auto: OFF").Activated:Fire()
check("Auto Roll activé", find(function(t) return t == "Auto: ON" end) ~= nil)
button("Close").Activated:Fire()
check("Close : retour à l'écran normal", HudState.Mode == "Main" and shown(build))
check("Close : Auto Roll toujours actif", find(function(t) return t == "Auto: ON" end) ~= nil)
check("Close : le bouton ROLL indique AUTO", find(function(t) return t == "AUTO" end) ~= nil)
roll = button("AUTO")
runTasks(30) -- l'Auto Roll tourne en fond (1.5 s simulées)
local topName = find(function(t) return t == "Wood Cube" and true end)
check("Auto Roll en fond : de nouveaux rolls partent", rollCalls >= 2)
check("Auto Roll en fond : objet affiché", topName ~= nil and shown(topName))
check("Auto Roll en fond : affiché tout en haut", topName and topName.Parent.AnchorPoint.Y == 0 and topName.Parent.Position.Y.Scale == 0)
check("Auto Roll en fond : en petit", topName and topName.Parent:FindFirstChildWhichIsA("UIScale").Scale < 1)

-- Build
build.Activated:Fire()
check("Build : mode Build", HudState.Mode == "Build")
check("Build : fenêtre Build Mode visible", shown(find(function(t) return t == "🔨 Build Mode" end)))
check("Build : Exit visible", shown(button("Exit")))
check("Build : Delete visible", shown(button("Delete")))
check("Build : ROLL caché", not shown(roll))
check("Build : Coins cachés (fenêtre à gauche)", not shown(find(function(t) return t == "🪙 500" end)))
check("Build : compteur 0 / 40", shown(find(function(t) return t == "0 / 40" end)))
check("Build : case Wood Cube ×5", find(function(t) return t == "×5" end) ~= nil)
check("Build : onglet Blocks n'affiche pas le canon", find(function(t) return t == "Basic Cannon" end) == nil)
find(function(t) return t == "⚔️ Weapons" end).Activated:Fire()
check("onglet Weapons : affiche le canon", find(function(t) return t == "Basic Cannon" end) ~= nil)
local function inBuildUI(label)
	for _, object in playerGui.BuildUI:GetDescendants() do
		if object.Text == label then return true end
	end
	return false
end
check("onglet Weapons : n'affiche plus le cube", not inBuildUI("Wood Cube"))
find(function(t) return t == "🔺 Traps" end).Activated:Fire()
check("onglet Traps : affiche le piège", find(function(t) return t == "Wooden Spike Trap" end) ~= nil)
find(function(t) return t == "🧱 Blocks" end).Activated:Fire()
check("onglet Blocks : retour au cube", inBuildUI("Wood Cube") and not inBuildUI("Basic Cannon"))
check("Build : bouton Clear plot", shown(find(function(t) return t == "🧹 Clear plot" end)))
local sortButton = find(function(t) return t:find("Rarity", 1, true) ~= nil end)
check("Build : bouton de tri", sortButton ~= nil)
sortButton.Activated:Fire()
check("Tri suivant : HP", find(function(t) return t == "↕️ ❤️ HP" end) ~= nil)
button("Delete").Activated:Fire()
check("Delete : fenêtre toujours visible", shown(find(function(t) return t == "🔨 Build Mode" end)))
button("Exit").Activated:Fire()
check("Exit : retour à l'écran normal", HudState.Mode == "Main" and shown(roll) and shown(build))

-- Vagues : START devient END, zombies restants et numéro de vague
waveInfo:SetAttribute("WaveTotal", 10)
waveInfo:SetAttribute("EnemiesLeft", 4)
waveInfo:SetAttribute("CoreHP", 300); waveInfo:SetAttribute("CoreMaxHP", 500)
waveInfo:SetAttribute("Wave", 3)
waveInfo:SetAttribute("Phase", "Wave")
check("vague : START caché", not shown(startWave))
check("vague : End Waves visible", shown(find(function(t) return t == "⏹️ End Waves" end)))
check("vague : '🧟 4 left'", shown(find(function(t) return t == "🧟 4 left" end)))
check("vague : 'Wave 3'", shown(find(function(t) return t == "Wave 3" end)))
check("vague : teaser boss vague 10", find(function(t) return t == "🐙 ??? at wave 10" end) ~= nil)
check("vague : vie du Core", shown(find(function(t) return t == "❤️ 300 / 500" end)))

print(string.format("\nRÉSULTAT HUD : %d réussis, %d échoués", passed, failed))
