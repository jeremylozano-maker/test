-- ItemVisuals : crée le modèle 3D d'un objet
-- Tes vrais modèles : ReplicatedStorage > ItemModels > un Model nommé comme l'Id (ex : "WoodCube").
-- Tant qu'un modèle n'existe pas, un modèle provisoire est généré.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Items = require(Shared:WaitForChild("Items"))
local Rarities = require(Shared:WaitForChild("Rarities"))

local ItemVisuals = {}

local TIER_LOOK = {
	{ Material = Enum.Material.Wood, Color = Color3.fromRGB(160, 110, 60) },
	{ Material = Enum.Material.Slate, Color = Color3.fromRGB(130, 130, 135) },
	{ Material = Enum.Material.Metal, Color = Color3.fromRGB(205, 115, 55) },
	{ Material = Enum.Material.DiamondPlate, Color = Color3.fromRGB(165, 170, 180) },
	{ Material = Enum.Material.DiamondPlate, Color = Color3.fromRGB(70, 80, 105) },
}

local FAMILY_COLOR = {
	Cannon = Color3.fromRGB(55, 55, 60),
	Tesla = Color3.fromRGB(60, 120, 230),
	Catapult = Color3.fromRGB(125, 85, 45),
	Mortar = Color3.fromRGB(90, 105, 60),
	Turret = Color3.fromRGB(120, 125, 135),
	Frost = Color3.fromRGB(140, 215, 255),
}

local SPIKE_OFFSETS = { { -0.25, -0.25 }, { 0.25, -0.25 }, { -0.25, 0.25 }, { 0.25, 0.25 }, { 0, 0 } }

local function addPart(model, size, cframe, color, material, props)
	local part = Instance.new("Part")
	part.Anchored = true
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props or {} do
		part[key] = value
	end
	part.Parent = model
	return part
end

local function addIcon(model, adornee, item, height)
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(36, 36)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, height, 0)
	billboard.MaxDistance = 120
	billboard.Adornee = adornee
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = item.Icon
	label.TextScaled = true
	label.Parent = billboard
	billboard.Parent = model
end

-- Modèle provisoire, construit autour de (0,0,0) = bas-centre de la case
local function buildPlaceholder(item, c)
	local model = Instance.new("Model")
	local look = TIER_LOOK[item.Tier]
	local rarityColor = Rarities.Info[item.Rarity].Color

	if item.Category == "Block" then
		addPart(model, Vector3.one * c * 0.98, CFrame.new(0, c * 0.49, 0), look.Color, look.Material)
	elseif item.Category == "Trap" then
		addPart(model, Vector3.new(c * 0.95, c * 0.12, c * 0.95), CFrame.new(0, c * 0.06, 0), look.Color, look.Material)
		for _, offset in SPIKE_OFFSETS do
			local spikeCFrame = CFrame.new(offset[1] * c, c * 0.295, offset[2] * c) * CFrame.Angles(0, math.rad(45), 0)
			addPart(model, Vector3.new(c * 0.12, c * 0.35, c * 0.12), spikeCFrame, Color3.fromRGB(200, 200, 210), Enum.Material.Metal, {
				CanCollide = false,
			})
		end
	else
		local isFancy = Rarities.Info[item.Rarity].Rank >= 4
		local bodyColor = if item.Id == "GoldenCannon" then Color3.fromRGB(255, 200, 60) else FAMILY_COLOR[item.Family]
		addPart(model, Vector3.new(c * 0.85, c * 0.2, c * 0.85), CFrame.new(0, c * 0.1, 0), look.Color, look.Material)
		local body = addPart(model, Vector3.new(c * 0.55, c * 0.4, c * 0.55), CFrame.new(0, c * 0.4, 0), bodyColor, Enum.Material.Metal)
		addPart(model, Vector3.new(c * 0.55, c * 0.18, c * 0.18), CFrame.new(c * 0.3, c * 0.45, 0), rarityColor,
			if isFancy then Enum.Material.Neon else Enum.Material.Metal, { Shape = Enum.PartType.Cylinder })
		addIcon(model, body, item, c * 0.6)
	end

	model.WorldPivot = CFrame.new()
	return model
end

-- Vrai modèle : mis à l'échelle de la case, pivot en bas-centre
local function buildFromTemplate(template, item, c)
	local model = template
	if template:IsA("BasePart") then
		model = Instance.new("Model")
		template.Parent = model
	end
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
		end
	end
	local _, size = model:GetBoundingBox()
	local fit = c * 0.95 / math.max(size.X, size.Z)
	if item.Category == "Block" then
		fit = math.min(fit, c * 0.98 / size.Y)
	end
	model:ScaleTo(model:GetScale() * fit)
	local boxCFrame, boxSize = model:GetBoundingBox()
	model.WorldPivot = boxCFrame * CFrame.new(0, -boxSize.Y / 2, 0)
	return model
end

function ItemVisuals.Create(itemId, cellSize)
	local item = Items.ById[itemId]
	local folder = ReplicatedStorage:FindFirstChild("ItemModels")
	local template = folder and folder:FindFirstChild(itemId)
	local model = if template then buildFromTemplate(template:Clone(), item, cellSize) else buildPlaceholder(item, cellSize)
	model.Name = itemId
	return model
end

-- Transforme un modèle en fantôme (transparent, sans collision)
function ItemVisuals.MakeGhost(model)
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Transparency = math.max(descendant.Transparency, 0.45)
			descendant.CanCollide = false
			descendant.CanQuery = false
			descendant.CanTouch = false
			descendant.CastShadow = false
		elseif descendant:IsA("BillboardGui") then
			descendant:Destroy()
		end
	end
end

return ItemVisuals
