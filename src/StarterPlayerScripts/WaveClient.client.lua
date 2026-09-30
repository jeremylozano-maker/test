-- WaveClient : bouton START, vitesse, vie du Core, vague en cours, écran de mort
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local Shared = ReplicatedStorage:WaitForChild("Shared")
local UIKit = require(Shared:WaitForChild("UIKit"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local waveInfo = ReplicatedStorage:WaitForChild("WaveInfo")
local gridInfo = ReplicatedStorage:WaitForChild("GridInfo")

local create, corner, stroke, makeButton = UIKit.create, UIKit.corner, UIKit.stroke, UIKit.makeButton

local gui = create("ScreenGui", {
	Name = "WaveUI",
	ResetOnSpawn = false,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	Parent = player:WaitForChild("PlayerGui"),
})

---------------------------------------------------------------- vague + vie du Core (en haut)

local wavePanel = create("Frame", {
	Parent = gui,
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 62),
	Size = UDim2.new(0, 300, 0, 60),
	BackgroundColor3 = UIKit.PANEL_COLOR,
}, { corner(12), stroke(3) })

local waveLabel = create("TextLabel", {
	Parent = wavePanel,
	Position = UDim2.new(0, 10, 0, 4),
	Size = UDim2.new(1, -20, 0, 26),
	BackgroundTransparency = 1,
	Text = "🌊 WAVE 1",
	TextColor3 = UIKit.WHITE,
	Font = UIKit.TITLE_FONT,
	TextScaled = true,
})

local coreBack = create("Frame", {
	Parent = wavePanel,
	Position = UDim2.new(0, 10, 0, 34),
	Size = UDim2.new(1, -20, 0, 20),
	BackgroundColor3 = UIKit.DARK,
	BorderSizePixel = 0,
}, { corner(6) })

local coreFill = create("Frame", {
	Parent = coreBack,
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = Color3.fromRGB(230, 60, 80),
	BorderSizePixel = 0,
}, { corner(6) })

local coreLabel = create("TextLabel", {
	Parent = coreBack,
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
	Text = "❤️ Core",
	TextColor3 = UIKit.WHITE,
	Font = UIKit.TITLE_FONT,
	TextScaled = true,
	ZIndex = 2,
})

---------------------------------------------------------------- boutons (à droite, sous Inventory / Index)

local startButton = makeButton({
	Parent = gui,
	AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.new(1, -12, 0.5, 102),
	Size = UDim2.new(0, 145, 0, 56),
	BackgroundColor3 = Color3.fromRGB(230, 120, 40),
	Text = "▶️ START",
})

local speedButton = makeButton({
	Parent = gui,
	AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.new(1, -12, 0.5, 170),
	Size = UDim2.new(0, 145, 0, 56),
	Text = "⏩ x1",
})

---------------------------------------------------------------- message "vague terminée"

local toast = create("TextLabel", {
	Parent = gui,
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.28),
	Size = UDim2.new(0, 420, 0, 60),
	BackgroundColor3 = UIKit.PANEL_COLOR,
	Text = "",
	TextColor3 = UIKit.HEADER_COLOR,
	Font = UIKit.TITLE_FONT,
	TextScaled = true,
	Visible = false,
}, { corner(14), stroke(3, UIKit.GREEN) })

---------------------------------------------------------------- écran de mort

local deathPanel = create("Frame", {
	Parent = gui,
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromScale(0.5, 0.6),
	BackgroundColor3 = UIKit.PANEL_COLOR,
	Visible = false,
	ZIndex = 5,
}, {
	corner(18),
	stroke(4, UIKit.RED),
	create("UISizeConstraint", { MinSize = Vector2.new(300, 300), MaxSize = Vector2.new(480, 420) }),
})

local function deathText(y, height, text, color)
	return create("TextLabel", {
		Parent = deathPanel,
		Position = UDim2.new(0.06, 0, y, 0),
		Size = UDim2.new(0.88, 0, height, 0),
		BackgroundTransparency = 1,
		Text = text,
		TextColor3 = color,
		Font = UIKit.TITLE_FONT,
		TextScaled = true,
		ZIndex = 6,
	})
end

deathText(0.04, 0.14, "💀 TON CORE EST DÉTRUIT", UIKit.RED)
local killsLabel = deathText(0.24, 0.1, "", UIKit.WHITE)
local coinsLabel = deathText(0.35, 0.1, "", UIKit.HEADER_COLOR)
local wavesLabel = deathText(0.46, 0.1, "", UIKit.WHITE)
local checkpointLabel = deathText(0.58, 0.08, "", UIKit.GREY)

local reviveButton = makeButton({
	Parent = deathPanel,
	Position = UDim2.new(0.06, 0, 0.72, 0),
	Size = UDim2.new(0.42, 0, 0.2, 0),
	BackgroundColor3 = Color3.fromRGB(150, 70, 230),
	Text = if RunService:IsStudio() then "💎 REVIVE (test)" else "💎 REVIVE (bientôt)",
	ZIndex = 6,
})

local acceptButton = makeButton({
	Parent = deathPanel,
	Position = UDim2.new(0.52, 0, 0.72, 0),
	Size = UDim2.new(0.42, 0, 0.2, 0),
	BackgroundColor3 = UIKit.GREEN,
	Text = "✔ ACCEPTER",
	ZIndex = 6,
})

---------------------------------------------------------------- mise à jour

local function update()
	local phase = waveInfo:GetAttribute("Phase")
	local wave = waveInfo:GetAttribute("Wave") or 1
	local coreHP = waveInfo:GetAttribute("CoreHP") or 0
	local coreMaxHP = waveInfo:GetAttribute("CoreMaxHP") or 0
	local isOwner = gridInfo:GetAttribute("OwnerUserId") == player.UserId

	if phase == "Wave" then
		waveLabel.Text = string.format("🌊 WAVE %d   🧟 %d", wave, waveInfo:GetAttribute("EnemiesLeft") or 0)
	else
		waveLabel.Text = string.format("🌊 WAVE %d", wave)
	end

	coreBack.Visible = phase ~= "Build"
	wavePanel.Size = UDim2.new(0, 300, 0, if phase == "Build" then 34 else 60)
	coreFill.Size = UDim2.fromScale(if coreMaxHP > 0 then math.clamp(coreHP / coreMaxHP, 0, 1) else 0, 1)
	coreLabel.Text = string.format("❤️ %d / %d", coreHP, coreMaxHP)

	startButton.Visible = phase == "Build" and isOwner
	speedButton.Visible = phase == "Wave" and isOwner
	speedButton.Text = "⏩ x" .. (waveInfo:GetAttribute("Speed") or 1)

	deathPanel.Visible = phase == "Dead" and isOwner
	if phase == "Dead" then
		killsLabel.Text = "🧟 Zombies tués : " .. (waveInfo:GetAttribute("RunKills") or 0)
		coinsLabel.Text = "🪙 Coins gagnés : " .. (waveInfo:GetAttribute("RunCoins") or 0)
		wavesLabel.Text = "🌊 Vagues survécues : " .. (waveInfo:GetAttribute("RunWaves") or 0)
		checkpointLabel.Text = "Tu reprendras à la vague " .. (waveInfo:GetAttribute("CheckpointWave") or 1)
	end
end

local toastToken = 0
local function showToast()
	toastToken += 1
	local token = toastToken
	toast.Text = string.format("✅ WAVE %d CLEARED   +%d 🪙", waveInfo:GetAttribute("LastClearedWave") or 0, waveInfo:GetAttribute("LastReward") or 0)
	toast.Visible = true
	toast.Size = UDim2.new(0, 480, 0, 70)
	TweenService:Create(toast, TweenInfo.new(0.3, Enum.EasingStyle.Back), { Size = UDim2.new(0, 420, 0, 60) }):Play()
	task.delay(2.5, function()
		if toastToken == token then
			toast.Visible = false
		end
	end)
end

waveInfo.AttributeChanged:Connect(function(name)
	if name == "ClearedCount" then
		showToast()
	end
	update()
end)

gridInfo:GetAttributeChangedSignal("OwnerUserId"):Connect(update)

startButton.Activated:Connect(function()
	Remotes.StartWave:InvokeServer()
end)

speedButton.Activated:Connect(function()
	local nextSpeed = if waveInfo:GetAttribute("Speed") == 2 then 1 else 2
	Remotes.SetWaveSpeed:InvokeServer(nextSpeed)
end)

acceptButton.Activated:Connect(function()
	Remotes.ResolveDeath:InvokeServer("Accept")
end)

reviveButton.Activated:Connect(function()
	Remotes.ResolveDeath:InvokeServer("Revive")
end)

update()
