-- WaveClient : boutons START / STOP, vitesse, vie du Core, vague en cours, résumé de session
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

local CORE_COLOR = Color3.fromRGB(235, 60, 85)

local gui = create("ScreenGui", {
	Name = "WaveUI",
	ResetOnSpawn = false,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	Parent = player:WaitForChild("PlayerGui"),
})

---------------------------------------------------------------- vague, zombies restants, vie du Core (en bas au milieu, au-dessus du ROLL)

local wavePanel = create("Frame", {
	Parent = gui,
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -114),
	Size = UDim2.new(0, 310, 0, 64),
	BackgroundColor3 = UIKit.PANEL_COLOR,
	BorderSizePixel = 0,
}, { corner(14), stroke(3), UIKit.shine(Color3.fromRGB(165, 165, 185)) })
UIKit.addStuds(wavePanel, 4)

local waveLabel = UIKit.label({
	Parent = wavePanel,
	Position = UDim2.new(0, 12, 0, 6),
	Size = UDim2.new(1, -24, 0, 26),
	Text = "🌊 WAVE 1",
})

local coreBack, coreFill = UIKit.makeBar({
	Parent = wavePanel,
	Position = UDim2.new(0, 12, 0, 36),
	Size = UDim2.new(1, -24, 0, 20),
}, CORE_COLOR)

local coreLabel = UIKit.label({
	Parent = coreBack,
	Position = UDim2.new(0, 0, 0, 2),
	Size = UDim2.new(1, 0, 1, -4),
	Text = "❤️ Core",
	TextStrokeTransparency = 0,
})

---------------------------------------------------------------- boutons (à droite, sous Inventory / Index)

local startButton = makeButton({
	Parent = gui,
	AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.new(1, -14, 0.5, 102),
	Size = UDim2.new(0, 150, 0, 56),
	BackgroundColor3 = UIKit.ORANGE,
	Text = "▶️ START",
	Studs = 3,
})

local stopButton = makeButton({
	Parent = gui,
	AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.new(1, -14, 0.5, 102),
	Size = UDim2.new(0, 150, 0, 56),
	BackgroundColor3 = UIKit.RED,
	Text = "⏹️ STOP",
	Visible = false,
	Studs = 3,
})

local speedButton = makeButton({
	Parent = gui,
	AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.new(1, -14, 0.5, 170),
	Size = UDim2.new(0, 150, 0, 56),
	Text = "⏩ x1",
	Studs = 3,
})

---------------------------------------------------------------- message "vague terminée"

local toast = create("Frame", {
	Parent = gui,
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.3),
	Size = UDim2.new(0, 440, 0, 64),
	BackgroundColor3 = UIKit.darken(UIKit.GREEN, 0.2),
	BorderSizePixel = 0,
	Visible = false,
}, { corner(16), stroke(4), UIKit.shine() })
UIKit.addStuds(toast, 5)
local toastScale = create("UIScale", { Parent = toast })

local toastLabel = UIKit.label({
	Parent = toast,
	Position = UDim2.new(0, 14, 0, 8),
	Size = UDim2.new(1, -28, 1, -16),
	Text = "",
	TextColor3 = UIKit.WHITE,
	TextStrokeTransparency = 0,
})

---------------------------------------------------------------- résumé de session (mort ou STOP)

local summaryPanel, summaryBody, summaryTitle, summaryHeader = UIKit.makePanel({
	Parent = gui,
	Title = "",
	Accent = UIKit.RED,
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromScale(0.5, 0.62),
	MinSize = Vector2.new(320, 340),
	MaxSize = Vector2.new(500, 440),
	ZIndex = 5,
	Close = false,
})

local statsList = create("Frame", {
	Parent = summaryBody,
	Size = UDim2.new(1, 0, 1, -76),
	BackgroundTransparency = 1,
}, {
	create("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
})

-- Retourne le badge où s'affiche la valeur
local function statRow(order, text, color)
	local _, badge = UIKit.itemRow({ Parent = statsList, LayoutOrder = order, Text = text, Color = color, Badge = "0", Height = 42 })
	return badge
end

local killsBadge = statRow(1, "🧟 Zombies tués", Color3.fromRGB(120, 220, 120))
local coinsBadge = statRow(2, "🪙 Coins gagnés", UIKit.YELLOW)
local wavesBadge = statRow(3, "🌊 Vagues survécues", Color3.fromRGB(110, 190, 255))

local checkpointLabel = UIKit.label({
	Parent = statsList,
	LayoutOrder = 4,
	Size = UDim2.new(1, -10, 0, 24),
	Text = "",
	TextColor3 = UIKit.GREY,
	Font = UIKit.TEXT_FONT,
})

local buttonRow = create("Frame", {
	Parent = summaryBody,
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.new(0, 0, 1, -4),
	Size = UDim2.new(1, 0, 0, 60),
	BackgroundTransparency = 1,
})

local reviveButton = makeButton({
	Parent = buttonRow,
	Size = UDim2.new(0.48, 0, 1, 0),
	BackgroundColor3 = UIKit.PURPLE,
	Text = if RunService:IsStudio() then "💎 REVIVE (test)" else "💎 REVIVE (bientôt)",
	Studs = 3,
})

local acceptButton = makeButton({
	Parent = buttonRow,
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.fromScale(1, 0),
	Size = UDim2.new(0.48, 0, 1, 0),
	BackgroundColor3 = UIKit.GREEN,
	Text = "✔ ACCEPTER",
	Studs = 3,
})

local okButton = makeButton({
	Parent = buttonRow,
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.fromScale(0.5, 0),
	Size = UDim2.new(0.55, 0, 1, 0),
	BackgroundColor3 = UIKit.GREEN,
	Text = "✔ OK",
	Studs = 3,
})

---------------------------------------------------------------- mise à jour

local showStopSummary = false -- résumé après STOP, fermé avec OK

local function update()
	local phase = waveInfo:GetAttribute("Phase")
	local wave = waveInfo:GetAttribute("Wave") or 1
	local coreHP = waveInfo:GetAttribute("CoreHP") or 0
	local coreMaxHP = waveInfo:GetAttribute("CoreMaxHP") or 0
	local isOwner = gridInfo:GetAttribute("OwnerUserId") == player.UserId

	local nextWaveIn = waveInfo:GetAttribute("NextWaveIn") or 0
	if phase == "Wave" and nextWaveIn > 0 then
		waveLabel.Text = string.format("⏳ WAVE %d dans %d...", wave, nextWaveIn)
	elseif phase == "Wave" then
		waveLabel.Text = string.format("🌊 WAVE %d   🧟 %d", wave, waveInfo:GetAttribute("EnemiesLeft") or 0)
	else
		waveLabel.Text = string.format("🌊 WAVE %d", wave)
	end

	coreBack.Visible = phase ~= "Build"
	wavePanel.Size = UDim2.new(0, 310, 0, if phase == "Build" then 38 else 64)
	coreFill.Size = UDim2.fromScale(if coreMaxHP > 0 then math.clamp(coreHP / coreMaxHP, 0, 1) else 0, 1)
	coreLabel.Text = string.format("❤️ %d / %d", coreHP, coreMaxHP)

	startButton.Visible = phase == "Build" and isOwner
	stopButton.Visible = phase == "Wave" and isOwner
	speedButton.Visible = phase == "Wave" and isOwner
	speedButton.Text = "⏩ x" .. (waveInfo:GetAttribute("Speed") or 1)
	speedButton.BackgroundColor3 = if waveInfo:GetAttribute("Speed") == 2 then UIKit.BLUE else UIKit.BUTTON_COLOR

	local isDead = phase == "Dead"
	if phase == "Wave" then
		showStopSummary = false
	end
	summaryPanel.Visible = isOwner and (isDead or showStopSummary)
	if summaryPanel.Visible then
		summaryTitle.Text = if isDead then "💀 TON CORE EST DÉTRUIT" else "⏹️ SESSION TERMINÉE"
		summaryHeader.BackgroundColor3 = if isDead then UIKit.RED else UIKit.ORANGE
		killsBadge.Text = tostring(waveInfo:GetAttribute("RunKills") or 0)
		coinsBadge.Text = tostring(waveInfo:GetAttribute("RunCoins") or 0)
		wavesBadge.Text = tostring(waveInfo:GetAttribute("RunWaves") or 0)
		checkpointLabel.Text = if isDead
			then "Tu reprendras à la vague " .. (waveInfo:GetAttribute("CheckpointWave") or 1)
			else "Prochaine vague : " .. wave
		reviveButton.Visible = isDead
		acceptButton.Visible = isDead
		okButton.Visible = not isDead
	end
end

local toastToken = 0
local function showToast()
	toastToken += 1
	local token = toastToken
	toastLabel.Text = string.format("✅ WAVE %d CLEARED   +%d 🪙",
		waveInfo:GetAttribute("LastClearedWave") or 0, waveInfo:GetAttribute("LastReward") or 0)
	toast.Visible = true
	toastScale.Scale = 1.25
	TweenService:Create(toastScale, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	task.delay(2.5, function()
		if toastToken == token then
			toast.Visible = false
		end
	end)
end

waveInfo.AttributeChanged:Connect(function(name)
	if name == "ClearedCount" then
		showToast()
	elseif name == "StopCount" then
		showStopSummary = true
	end
	update()
end)

gridInfo:GetAttributeChangedSignal("OwnerUserId"):Connect(update)

startButton.Activated:Connect(function()
	Remotes.StartWave:InvokeServer()
end)

stopButton.Activated:Connect(function()
	Remotes.StopWaves:InvokeServer()
end)

speedButton.Activated:Connect(function()
	local nextSpeed = if waveInfo:GetAttribute("Speed") == 2 then 1 else 2
	Remotes.SetWaveSpeed:InvokeServer(nextSpeed)
end)

okButton.Activated:Connect(function()
	showStopSummary = false
	update()
end)

acceptButton.Activated:Connect(function()
	Remotes.ResolveDeath:InvokeServer("Accept")
end)

reviveButton.Activated:Connect(function()
	Remotes.ResolveDeath:InvokeServer("Revive")
end)

update()
