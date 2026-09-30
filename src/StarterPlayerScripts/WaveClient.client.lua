-- WaveClient : colonne de droite (START / END, vitesse, zombies restants, vague, Core) et résumé de session
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

---------------------------------------------------------------- colonne de droite : START / END, vitesse, zombies restants, vague, Core

local rightColumn = create("Frame", {
	Parent = gui,
	AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.new(1, -16, 0.5, 0),
	Size = UDim2.new(0, 230, 0, 1),
	BackgroundTransparency = 1,
})

local startButton = makeButton({
	Parent = rightColumn,
	AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.new(1, 0, 0, -80),
	Size = UDim2.new(0, 220, 0, 62),
	BackgroundColor3 = UIKit.GREEN,
	Text = "▶️ Start Wave",
	Studs = 4,
})

-- pendant les vagues, START devient END
local stopButton = makeButton({
	Parent = rightColumn,
	AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.new(1, 0, 0, -80),
	Size = UDim2.new(0, 220, 0, 62),
	BackgroundColor3 = UIKit.RED,
	Text = "⏹️ End Waves",
	Visible = false,
	Studs = 4,
})

local speedButton = makeButton({
	Parent = rightColumn,
	AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.new(1, 0, 0, -12),
	Size = UDim2.new(0, 220, 0, 46),
	Text = "⏩ x1",
	Studs = 3,
})

-- zombies restants
local enemiesBack, enemiesFill = UIKit.makeBar({
	Parent = rightColumn,
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, 0, 0, 22),
	Size = UDim2.new(0, 220, 0, 28),
}, Color3.fromRGB(90, 200, 90))

local enemiesLabel = UIKit.label({
	Parent = enemiesBack,
	Position = UDim2.new(0, 0, 0, 3),
	Size = UDim2.new(1, 0, 1, -6),
	Text = "🧟 0 left",
	TextStrokeTransparency = 0,
})

-- numéro de la vague + teaser du prochain boss
local waveLabel = UIKit.label({
	Parent = rightColumn,
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, 0, 0, 56),
	Size = UDim2.new(0, 220, 0, 40),
	Text = "Wave 1",
	TextStrokeTransparency = 0,
})

local bossLabel = UIKit.label({
	Parent = rightColumn,
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, 0, 0, 96),
	Size = UDim2.new(0, 220, 0, 22),
	Text = "",
	TextColor3 = Color3.fromRGB(255, 80, 80),
	TextStrokeTransparency = 0,
})

-- vie du Core (pendant les vagues)
local coreBack, coreFill = UIKit.makeBar({
	Parent = rightColumn,
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, 0, 0, 126),
	Size = UDim2.new(0, 220, 0, 24),
}, CORE_COLOR)

local coreLabel = UIKit.label({
	Parent = coreBack,
	Position = UDim2.new(0, 0, 0, 2),
	Size = UDim2.new(1, 0, 1, -4),
	Text = "❤️ Core",
	TextStrokeTransparency = 0,
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

local killsBadge = statRow(1, "🧟 Zombies killed", Color3.fromRGB(120, 220, 120))
local coinsBadge = statRow(2, "🪙 Coins earned", UIKit.YELLOW)
local wavesBadge = statRow(3, "🌊 Waves survived", Color3.fromRGB(110, 190, 255))

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
	Text = if RunService:IsStudio() then "💎 REVIVE (test)" else "💎 REVIVE (soon)",
	Studs = 3,
})

local acceptButton = makeButton({
	Parent = buttonRow,
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.fromScale(1, 0),
	Size = UDim2.new(0.48, 0, 1, 0),
	BackgroundColor3 = UIKit.GREEN,
	Text = "✔ ACCEPT",
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
	local enemiesLeft = waveInfo:GetAttribute("EnemiesLeft") or 0
	local waveTotal = math.max(1, waveInfo:GetAttribute("WaveTotal") or 1)
	local inWaves = phase == "Wave"

	waveLabel.Text = if inWaves and nextWaveIn > 0 then string.format("Wave %d in %d...", wave, nextWaveIn) else "Wave " .. wave
	local bossWave = math.ceil(wave / 10) * 10
	bossLabel.Text = if bossWave == wave then "🐙 ??? THIS WAVE!" else string.format("🐙 ??? at wave %d", bossWave)

	enemiesBack.Visible = inWaves and nextWaveIn <= 0
	enemiesLabel.Text = string.format("🧟 %d left", enemiesLeft)
	enemiesFill.Size = UDim2.fromScale(math.clamp(enemiesLeft / waveTotal, 0, 1), 1)

	coreBack.Visible = phase ~= "Build"
	coreFill.Size = UDim2.fromScale(if coreMaxHP > 0 then math.clamp(coreHP / coreMaxHP, 0, 1) else 0, 1)
	coreLabel.Text = string.format("❤️ %d / %d", coreHP, coreMaxHP)

	startButton.Visible = phase == "Build" and isOwner
	stopButton.Visible = inWaves and isOwner
	speedButton.Visible = inWaves and isOwner
	speedButton.Text = "⏩ x" .. (waveInfo:GetAttribute("Speed") or 1)
	speedButton.BackgroundColor3 = if waveInfo:GetAttribute("Speed") == 2 then UIKit.BLUE else UIKit.BUTTON_COLOR

	local isDead = phase == "Dead"
	if phase == "Wave" then
		showStopSummary = false
	end
	summaryPanel.Visible = isOwner and (isDead or showStopSummary)
	if summaryPanel.Visible then
		summaryTitle.Text = if isDead then "💀 YOUR CORE WAS DESTROYED" else "⏹️ SESSION OVER"
		summaryHeader.BackgroundColor3 = if isDead then UIKit.RED else UIKit.ORANGE
		killsBadge.Text = tostring(waveInfo:GetAttribute("RunKills") or 0)
		coinsBadge.Text = tostring(waveInfo:GetAttribute("RunCoins") or 0)
		wavesBadge.Text = tostring(waveInfo:GetAttribute("RunWaves") or 0)
		checkpointLabel.Text = if isDead
			then "You will restart at wave " .. (waveInfo:GetAttribute("CheckpointWave") or 1)
			else "Next wave: " .. wave
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
