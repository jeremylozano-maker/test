-- HexUI : dessine des hexagones et des lignes en GUI (utilisé par l'écran du Skill Tree).
-- Astuce : 3 rectangles (largeur = 1/2, hauteur = 0.866 du carré) tournés de 0°, 60° et 120°
-- se superposent en un hexagone parfait (pointes à gauche et à droite).
local TweenService = game:GetService("TweenService")

local HexUI = {}

local RECT_ROTATIONS = { 0, 60, 120 }
local HEX_HEIGHT_RATIO = 0.866 -- hauteur d'un hexagone / largeur

-- Couche hexagonale qui remplit `parent` (un carré) à `scale` de sa taille.
-- shine = dégradé vertical (plus clair en haut), qui reste vertical malgré la rotation des rectangles.
function HexUI.makeLayer(parent, scale, color, transparency, zIndex, shine)
	local layer = Instance.new("Frame")
	layer.Name = "HexLayer"
	layer.AnchorPoint = Vector2.new(0.5, 0.5)
	layer.Position = UDim2.fromScale(0.5, 0.5)
	layer.Size = UDim2.fromScale(scale, scale)
	layer.BackgroundTransparency = 1
	layer.ZIndex = zIndex
	for _, rotation in RECT_ROTATIONS do
		local rect = Instance.new("Frame")
		rect.AnchorPoint = Vector2.new(0.5, 0.5)
		rect.Position = UDim2.fromScale(0.5, 0.5)
		rect.Size = UDim2.fromScale(0.5, HEX_HEIGHT_RATIO)
		rect.Rotation = rotation
		rect.BackgroundColor3 = color
		rect.BackgroundTransparency = transparency
		rect.BorderSizePixel = 0
		rect.ZIndex = zIndex
		if shine then
			local gradient = Instance.new("UIGradient")
			gradient.Rotation = 90 - rotation
			gradient.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(170, 170, 185))
			gradient.Parent = rect
		end
		rect.Parent = layer
	end
	layer.Parent = parent
	return layer
end

function HexUI.setColor(layer, color)
	for _, rect in layer:GetChildren() do
		if rect:IsA("Frame") then
			rect.BackgroundColor3 = color
		end
	end
end

function HexUI.setTransparency(layer, transparency)
	for _, rect in layer:GetChildren() do
		if rect:IsA("Frame") then
			rect.BackgroundTransparency = transparency
		end
	end
end

function HexUI.tweenColor(layer, color, duration)
	for _, rect in layer:GetChildren() do
		if rect:IsA("Frame") then
			TweenService:Create(rect, TweenInfo.new(duration), { BackgroundColor3 = color }):Play()
		end
	end
end

-- Ligne épaisse entre deux points (en pixels, dans le repère de `parent`)
function HexUI.makeLine(parent, from, to, thickness, color, zIndex)
	local delta = to - from
	local line = Instance.new("Frame")
	line.AnchorPoint = Vector2.new(0.5, 0.5)
	line.Position = UDim2.fromOffset((from.X + to.X) / 2, (from.Y + to.Y) / 2)
	line.Size = UDim2.fromOffset(delta.Magnitude, thickness)
	line.Rotation = math.deg(math.atan2(delta.Y, delta.X))
	line.BackgroundColor3 = color
	line.BorderSizePixel = 0
	line.ZIndex = zIndex
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = line
	line.Parent = parent
	return line
end

return HexUI
