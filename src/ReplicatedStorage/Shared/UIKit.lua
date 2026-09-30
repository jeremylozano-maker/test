-- UIKit : style commun de toute l'interface (look "brique" avec studs, dégradés, contours, animations)
local TweenService = game:GetService("TweenService")

local UIKit = {}

UIKit.WHITE = Color3.new(1, 1, 1)
UIKit.GREY = Color3.fromRGB(120, 125, 140)
UIKit.DARK = Color3.fromRGB(12, 14, 24)
UIKit.PANEL_COLOR = Color3.fromRGB(32, 37, 60)
UIKit.PANEL_DARK = Color3.fromRGB(22, 25, 42)
UIKit.BUTTON_COLOR = Color3.fromRGB(62, 70, 102)
UIKit.GREEN = Color3.fromRGB(70, 195, 90)
UIKit.RED = Color3.fromRGB(225, 65, 70)
UIKit.BLUE = Color3.fromRGB(55, 135, 245)
UIKit.PURPLE = Color3.fromRGB(150, 85, 240)
UIKit.ORANGE = Color3.fromRGB(255, 145, 35)
UIKit.YELLOW = Color3.fromRGB(255, 205, 55)
UIKit.HEADER_COLOR = UIKit.YELLOW
UIKit.TITLE_FONT = Enum.Font.FredokaOne
UIKit.TEXT_FONT = Enum.Font.GothamBold

-- Optionnel : id d'une texture de studs de la Toolbox (ex : "rbxassetid://123456"),
-- posée en motif discret sur toutes les fenêtres. Laisse vide pour ne rien mettre.
UIKit.STUD_TEXTURE = ""

function UIKit.create(className, props, children)
	local instance = Instance.new(className)
	for key, value in props do
		if key ~= "Parent" then
			instance[key] = value
		end
	end
	for _, child in children or {} do
		child.Parent = instance
	end
	instance.Parent = props.Parent
	return instance
end

local create = UIKit.create

function UIKit.lighten(color, amount)
	return color:Lerp(Color3.new(1, 1, 1), amount)
end

function UIKit.darken(color, amount)
	return color:Lerp(Color3.new(0, 0, 0), amount)
end

function UIKit.corner(radius)
	return create("UICorner", { CornerRadius = UDim.new(0, radius or 12) })
end

function UIKit.stroke(thickness, color)
	return create("UIStroke", {
		Thickness = thickness or 3,
		Color = color or UIKit.DARK,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

-- Dégradé vertical : haut clair, bas plus sombre (effet plastique brillant)
function UIKit.shine(bottom)
	return create("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new(Color3.new(1, 1, 1), bottom or Color3.fromRGB(180, 180, 190)),
	})
end

function UIKit.padding(pixels)
	local value = UDim.new(0, pixels)
	return create("UIPadding", { PaddingTop = value, PaddingBottom = value, PaddingLeft = value, PaddingRight = value })
end

-- Studs sur le dessus de l'élément, comme une brique (suivent sa couleur)
function UIKit.addStuds(target, count)
	local studs = {}
	for index = 1, count do
		table.insert(studs, create("Frame", {
			Parent = target,
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(index / (count + 1), 0, 0, 3),
			Size = UDim2.fromOffset(18, 8),
			BorderSizePixel = 0,
		}, { UIKit.corner(4), UIKit.stroke(2), UIKit.shine() }))
	end
	local function recolor()
		for _, stud in studs do
			stud.BackgroundColor3 = UIKit.lighten(target.BackgroundColor3, 0.15)
		end
	end
	recolor()
	target:GetPropertyChangedSignal("BackgroundColor3"):Connect(recolor)
end

-- Grossit au survol, s'enfonce au clic
function UIKit.addPressEffect(button)
	local scale = create("UIScale", { Parent = button })
	local function tweenTo(value)
		TweenService:Create(scale, TweenInfo.new(0.1, Enum.EasingStyle.Quad), { Scale = value }):Play()
	end
	button.MouseEnter:Connect(function()
		tweenTo(1.05)
	end)
	button.MouseLeave:Connect(function()
		tweenTo(1)
	end)
	button.MouseButton1Down:Connect(function()
		tweenTo(0.93)
	end)
	button.MouseButton1Up:Connect(function()
		tweenTo(1.05)
	end)
end

-- Texte avec contour sombre (lisible sur tous les fonds)
function UIKit.label(props)
	props.BackgroundTransparency = props.BackgroundTransparency or 1
	props.TextColor3 = props.TextColor3 or UIKit.WHITE
	props.Font = props.Font or UIKit.TITLE_FONT
	props.TextScaled = true
	props.TextStrokeTransparency = props.TextStrokeTransparency or 0.4
	return create("TextLabel", props)
end

-- Bouton brique : props.Studs = nombre de studs sur le dessus (0 par défaut)
function UIKit.makeButton(props)
	local studs = props.Studs or 0
	props.Studs = nil
	props.BackgroundColor3 = props.BackgroundColor3 or UIKit.BUTTON_COLOR
	props.TextColor3 = props.TextColor3 or UIKit.WHITE
	props.Font = props.Font or UIKit.TITLE_FONT
	props.TextScaled = true
	props.TextStrokeTransparency = 0.3
	props.AutoButtonColor = false
	props.BorderSizePixel = 0
	local button = create("TextButton", props, {
		UIKit.corner(12),
		UIKit.stroke(3),
		UIKit.shine(),
		UIKit.padding(7),
	})
	UIKit.addPressEffect(button)
	if studs > 0 then
		UIKit.addStuds(button, studs)
	end
	return button
end

-- Bouton-icône (grosse icône + nom dessous), pour la barre du bas
-- props : comme makeButton, plus Icon et Label. Retourne (bouton, texte de l'icône, texte du nom)
function UIKit.makeIconButton(props)
	local icon, labelText = props.Icon, props.Label
	props.Icon, props.Label = nil, nil
	props.Text = ""
	local button = UIKit.makeButton(props)
	local iconLabel = UIKit.label({
		Parent = button,
		Position = UDim2.fromScale(0, 0),
		Size = UDim2.fromScale(1, 0.64),
		Text = icon,
	})
	local nameLabel = UIKit.label({
		Parent = button,
		Position = UDim2.fromScale(0, 0.64),
		Size = UDim2.fromScale(1, 0.36),
		Text = labelText,
		TextStrokeTransparency = 0,
	})
	return button, iconLabel, nameLabel
end

-- Pastille ronde avec un nombre (ex : améliorations disponibles), en haut à droite d'un bouton
function UIKit.makeCountBadge(parent)
	local badge = create("TextLabel", {
		Parent = parent,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -4, 0, 4),
		Size = UDim2.fromOffset(30, 30),
		BackgroundColor3 = UIKit.RED,
		BorderSizePixel = 0,
		Text = "",
		TextColor3 = UIKit.WHITE,
		Font = UIKit.TITLE_FONT,
		TextScaled = true,
		Visible = false,
		ZIndex = 3,
	}, { create("UICorner", { CornerRadius = UDim.new(0.5, 0) }), UIKit.stroke(2, UIKit.WHITE), UIKit.padding(4) })
	return badge
end

-- Barre de progression ; retourne (fond, remplissage)
function UIKit.makeBar(props, fillColor)
	props.BackgroundColor3 = UIKit.DARK
	props.BorderSizePixel = 0
	local back = create("Frame", props, { UIKit.corner(8), UIKit.stroke(2) })
	local fill = create("Frame", {
		Parent = back,
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = fillColor,
		BorderSizePixel = 0,
	}, { UIKit.corner(8), UIKit.shine() })
	return back, fill
end

-- Fenêtre : bandeau titre coloré, studs sur le dessus, bouton fermer
-- options : Parent, Title, Name, Accent, AnchorPoint, Position, Size, MinSize, MaxSize, ZIndex, Close (false = pas de X)
-- Retourne (fenêtre, zone de contenu, texte du titre, bandeau, bouton fermer)
function UIKit.makePanel(options)
	local panel = create("Frame", {
		Parent = options.Parent,
		Name = options.Name or options.Title,
		Visible = false,
		AnchorPoint = options.AnchorPoint or Vector2.new(0.5, 0.5),
		Position = options.Position,
		Size = options.Size,
		ZIndex = options.ZIndex or 1,
		BackgroundColor3 = UIKit.PANEL_COLOR,
		BorderSizePixel = 0,
	}, {
		UIKit.corner(18),
		UIKit.stroke(4),
		UIKit.shine(Color3.fromRGB(165, 165, 185)),
	})
	if options.MinSize then
		create("UISizeConstraint", { Parent = panel, MinSize = options.MinSize, MaxSize = options.MaxSize })
	end
	if UIKit.STUD_TEXTURE ~= "" then
		create("ImageLabel", {
			Parent = panel,
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Image = UIKit.STUD_TEXTURE,
			ScaleType = Enum.ScaleType.Tile,
			TileSize = UDim2.fromOffset(32, 32),
			ImageTransparency = 0.85,
		}, { UIKit.corner(18) })
	end
	UIKit.addStuds(panel, 5)

	local header = create("Frame", {
		Parent = panel,
		Position = UDim2.new(0, 8, 0, 8),
		Size = UDim2.new(1, -16, 0, 44),
		BackgroundColor3 = options.Accent or UIKit.BLUE,
		BorderSizePixel = 0,
	}, { UIKit.corner(12), UIKit.stroke(3), UIKit.shine() })

	local hasClose = options.Close ~= false
	local title = UIKit.label({
		Parent = header,
		Position = UDim2.new(0, 12, 0, 5),
		Size = UDim2.new(1, if hasClose then -62 else -24, 1, -10),
		Text = options.Title,
		TextXAlignment = Enum.TextXAlignment.Left,
	})

	local closeButton
	if hasClose then
		closeButton = UIKit.makeButton({
			Parent = header,
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -6, 0.5, 0),
			Size = UDim2.fromOffset(34, 34),
			BackgroundColor3 = UIKit.RED,
			Text = "✕",
		})
		closeButton.Activated:Connect(function()
			panel.Visible = false
		end)
	end

	local body = create("Frame", {
		Parent = panel,
		Position = UDim2.new(0, 12, 0, 62),
		Size = UDim2.new(1, -24, 1, -74),
		BackgroundTransparency = 1,
	})
	return panel, body, title, header, closeButton
end

-- Liste qui défile, remplie de haut en bas
function UIKit.makeList(props)
	props.BackgroundTransparency = 1
	props.BorderSizePixel = 0
	props.ScrollBarThickness = 6
	props.ScrollBarImageColor3 = UIKit.GREY
	props.CanvasSize = UDim2.new()
	props.AutomaticCanvasSize = Enum.AutomaticSize.Y
	return create("ScrollingFrame", props, {
		create("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
		create("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 4) }),
	})
end

function UIKit.clearList(list)
	for _, child in list:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

function UIKit.sectionHeader(parent, order, text)
	return UIKit.label({
		Parent = parent,
		LayoutOrder = order,
		Size = UDim2.new(1, -10, 0, 26),
		Text = text,
		TextColor3 = UIKit.YELLOW,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
end

-- Ligne d'objet : bande de couleur à gauche, texte, badge à droite
-- options : Parent, LayoutOrder, Text, Color, Badge, Selected, Clickable, Height
-- Retourne (ligne, texte du badge)
function UIKit.itemRow(options)
	local row = create("TextButton", {
		Parent = options.Parent,
		LayoutOrder = options.LayoutOrder,
		Size = UDim2.new(1, -10, 0, options.Height or 40),
		BackgroundColor3 = if options.Selected then UIKit.darken(UIKit.GREEN, 0.35) else UIKit.PANEL_DARK,
		AutoButtonColor = false,
		Active = options.Clickable == true,
		Text = "",
		BorderSizePixel = 0,
	}, {
		UIKit.corner(10),
		UIKit.stroke(2, if options.Selected then UIKit.GREEN else UIKit.DARK),
	})
	create("Frame", {
		Parent = row,
		Position = UDim2.new(0, 6, 0, 6),
		Size = UDim2.new(0, 6, 1, -12),
		BackgroundColor3 = options.Color,
		BorderSizePixel = 0,
	}, { UIKit.corner(3) })
	UIKit.label({
		Parent = row,
		Position = UDim2.new(0, 20, 0, 7),
		Size = UDim2.new(1, if options.Badge then -96 else -28, 1, -14),
		Text = options.Text,
		TextColor3 = options.Color,
		Font = UIKit.TEXT_FONT,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	local badge
	if options.Badge then
		badge = create("TextLabel", {
			Parent = row,
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -8, 0.5, 0),
			Size = UDim2.new(0, 68, 0, 26),
			BackgroundColor3 = UIKit.DARK,
			BorderSizePixel = 0,
			Text = options.Badge,
			TextColor3 = UIKit.WHITE,
			Font = UIKit.TITLE_FONT,
			TextScaled = true,
		}, { UIKit.corner(8), UIKit.padding(4) })
	end
	if options.Clickable then
		UIKit.addPressEffect(row)
	end
	return row, badge
end

return UIKit
