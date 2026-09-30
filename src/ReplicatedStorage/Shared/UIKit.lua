-- UIKit : petites fonctions pour créer l'interface par code
local UIKit = {}

UIKit.WHITE = Color3.new(1, 1, 1)
UIKit.GREY = Color3.fromRGB(110, 110, 120)
UIKit.HEADER_COLOR = Color3.fromRGB(255, 220, 120)
UIKit.PANEL_COLOR = Color3.fromRGB(28, 32, 46)
UIKit.BUTTON_COLOR = Color3.fromRGB(45, 50, 70)
UIKit.GREEN = Color3.fromRGB(60, 170, 90)
UIKit.RED = Color3.fromRGB(200, 60, 60)
UIKit.DARK = Color3.fromRGB(15, 15, 25)
UIKit.TITLE_FONT = Enum.Font.FredokaOne
UIKit.TEXT_FONT = Enum.Font.GothamBold

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

function UIKit.corner(radius)
	return UIKit.create("UICorner", { CornerRadius = UDim.new(0, radius or 12) })
end

function UIKit.stroke(thickness, color)
	return UIKit.create("UIStroke", {
		Thickness = thickness or 3,
		Color = color or UIKit.DARK,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

function UIKit.makeButton(props)
	props.BackgroundColor3 = props.BackgroundColor3 or UIKit.BUTTON_COLOR
	props.TextColor3 = props.TextColor3 or UIKit.WHITE
	props.Font = UIKit.TITLE_FONT
	props.TextScaled = true
	props.AutoButtonColor = true
	return UIKit.create("TextButton", props, {
		UIKit.corner(14),
		UIKit.stroke(3),
		UIKit.create("UIPadding", {
			PaddingTop = UDim.new(0, 6),
			PaddingBottom = UDim.new(0, 6),
			PaddingLeft = UDim.new(0, 8),
			PaddingRight = UDim.new(0, 8),
		}),
	})
end

return UIKit
