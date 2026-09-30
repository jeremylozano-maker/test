-- Faux moteur Roblox minimal (instances, signaux, types de données) pour exécuter les scripts d'UI hors de Studio
local function newSignal()
	local signal = { Handlers = {} }
	function signal:Connect(handler)
		table.insert(self.Handlers, handler)
		return { Disconnect = function() end }
	end
	function signal:Fire(...)
		for _, handler in self.Handlers do
			handler(...)
		end
	end
	return signal
end


---------------------------------------------------------------- types de données
local Vector2MT = {}
Vector2MT.__index = function(v, key)
	if key == "Magnitude" then return math.sqrt(v.X * v.X + v.Y * v.Y) end
end
Vector2MT.__add = function(a, b) return Vector2.new(a.X + b.X, a.Y + b.Y) end
Vector2MT.__sub = function(a, b) return Vector2.new(a.X - b.X, a.Y - b.Y) end
Vector2MT.__mul = function(a, b)
	if type(a) == "number" then return Vector2.new(a * b.X, a * b.Y) end
	if type(b) == "number" then return Vector2.new(a.X * b, a.Y * b) end
	return Vector2.new(a.X * b.X, a.Y * b.Y)
end
Vector2 = { new = function(x, y) return setmetatable({ X = x or 0, Y = y or 0 }, Vector2MT) end }
Vector2.zero = Vector2.new(0, 0)

local UDim2MT = {}
UDim2MT.__add = function(a, b)
	return UDim2.new(a.X.Scale + b.X.Scale, a.X.Offset + b.X.Offset, a.Y.Scale + b.Y.Scale, a.Y.Offset + b.Y.Offset)
end
UDim = { new = function(s, o) return { Scale = s or 0, Offset = o or 0 } end }
UDim2 = {
	new = function(xs, xo, ys, yo) return setmetatable({ X = UDim.new(xs, xo), Y = UDim.new(ys, yo) }, UDim2MT) end,
	fromScale = function(x, y) return UDim2.new(x, 0, y, 0) end,
	fromOffset = function(x, y) return UDim2.new(0, x, 0, y) end,
}
local Color3MT = {}
Color3MT.__index = { Lerp = function(a, b, t) return Color3.new(a.R + (b.R - a.R) * t, a.G + (b.G - a.G) * t, a.B + (b.B - a.B) * t) end }
Color3 = {
	new = function(r, g, b) return setmetatable({ R = r or 0, G = g or 0, B = b or 0 }, Color3MT) end,
	fromRGB = function(r, g, b) return Color3.new(r / 255, g / 255, b / 255) end,
	fromHSV = function() return Color3.new(1, 1, 1) end,
}
ColorSequence = { new = function(a, b) return { a, b } end }
TweenInfo = { new = function(...) return { ... } end }
Enum = setmetatable({}, { __index = function(_, category)
	return setmetatable({}, { __index = function(_, item) return category .. "." .. item end })
end })
typeof = type

---------------------------------------------------------------- instances
local EVENTS = { Activated = true, MouseEnter = true, MouseLeave = true, MouseButton1Down = true, MouseButton1Up = true,
	Changed = true, ChildAdded = true, ChildRemoved = true, Event = true, OnClientEvent = true, AttributeChanged = true }
local GUI_CLASSES = { Frame = true, TextLabel = true, TextButton = true, ImageLabel = true, ScrollingFrame = true }

local InstanceMT = {}
local methods = {}

function methods:IsA(className)
	return self.__class == className or (className == "GuiObject" and GUI_CLASSES[self.__class] == true)
		or (className == "BasePart" and self.__class == "Part")
end
function methods:GetChildren()
	return table.clone(self.__children)
end
function methods:GetDescendants()
	local result = {}
	for _, child in self.__children do
		table.insert(result, child)
		for _, descendant in child:GetDescendants() do
			table.insert(result, descendant)
		end
	end
	return result
end
function methods:FindFirstChild(name)
	for _, child in self.__children do
		if child.Name == name then return child end
	end
	return nil
end
function methods:WaitForChild(name)
	local child = self:FindFirstChild(name)
	assert(child, "WaitForChild bloquerait : " .. tostring(name) .. " sous " .. tostring(self.Name))
	return child
end
function methods:FindFirstChildWhichIsA(className)
	for _, child in self.__children do
		if child:IsA(className) then return child end
	end
	return nil
end
methods.FindFirstChildOfClass = methods.FindFirstChildWhichIsA
function methods:Destroy()
	self.Parent = nil
end
function methods:ClearAllChildren()
	for _, child in self:GetChildren() do child:Destroy() end
end
function methods:GetPropertyChangedSignal(property)
	return self.__signals["prop:" .. property] or (function()
		self.__signals["prop:" .. property] = newSignal()
		return self.__signals["prop:" .. property]
	end)()
end
function methods:GetAttribute(name) return self.__attributes[name] end
function methods:SetAttribute(name, value)
	self.__attributes[name] = value
	self:GetAttributeChangedSignal(name):Fire()
	self.AttributeChanged:Fire(name)
end
function methods:GetAttributeChangedSignal(name) return self:GetPropertyChangedSignal("attr:" .. name) end

InstanceMT.__index = function(self, key)
	if methods[key] then return methods[key] end
	local value = rawget(self, "__props")[key]
	if value ~= nil then return value end
	if EVENTS[key] then
		local signals = rawget(self, "__signals")
		signals[key] = signals[key] or newSignal()
		return signals[key]
	end
	for _, child in rawget(self, "__children") do
		if rawget(child, "__props").Name == key then return child end
	end
	if key == "AbsoluteSize" then return Vector2.new(1280, 600) end
	if key == "AbsolutePosition" then return Vector2.new(0, 118) end
	return nil
end
InstanceMT.__newindex = function(self, key, value)
	local props = rawget(self, "__props")
	if key == "Parent" then
		local old = props.Parent
		if old then
			local siblings = rawget(old, "__children")
			local index = table.find(siblings, self)
			if index then table.remove(siblings, index) end
			old.ChildRemoved:Fire(self)
		end
		if value then
			table.insert(rawget(value, "__children"), self)
			value.ChildAdded:Fire(self)
		end
	end
	props[key] = value
	local signal = rawget(self, "__signals")["prop:" .. key]
	if signal then signal:Fire() end
	if key == "Value" then self.Changed:Fire(value) end
end
InstanceMT.__tostring = function(self) return self.__class .. ":" .. tostring(self.Name) end

Instance = {
	new = function(className)
		local object = setmetatable({ __class = className, __props = {}, __children = {}, __signals = {}, __attributes = {} }, InstanceMT)
		object.Name = className
		return object
	end,
}

---------------------------------------------------------------- services
local services = {}
local function service(name)
	services[name] = services[name] or Instance.new(name)
	return services[name]
end
game = { GetService = function(_, name) return service(name) end }

local TweenService = service("TweenService")
rawget(TweenService, "__props").Create = function(_, object, _, goals)
	return { Play = function() for key, value in goals do object[key] = value end end }
end
rawget(service("SoundService"), "__props").PlayLocalSound = function() end
rawget(service("Debris"), "__props").AddItem = function() end
rawget(service("GuiService"), "__props").GetGuiInset = function() return Vector2.new(0, 58) end
local RunService = service("RunService")
rawget(RunService, "__props").IsStudio = function() return true end
rawget(RunService, "__props").RenderStepped = newSignal()
local UIS = service("UserInputService")
for _, name in { "InputBegan", "InputChanged", "InputEnded", "TouchPinch" } do
	rawget(UIS, "__props")[name] = newSignal()
end
rawget(UIS, "__props").TouchEnabled = false
rawget(UIS, "__props").MouseEnabled = true

local Players = service("Players")
local localPlayer = Instance.new("Player")
localPlayer.Name = "Tester"
local playerGui = Instance.new("PlayerGui")
playerGui.Name = "PlayerGui"
playerGui.Parent = localPlayer
rawget(Players, "__props").LocalPlayer = localPlayer

---------------------------------------------------------------- tâches (exécution immédiate)
task = {
	spawn = function(fn, ...) coroutine.wrap(fn)(...) end,
	defer = function(fn, ...) coroutine.wrap(fn)(...) end,
	delay = function(_, fn, ...) coroutine.wrap(fn)(...) end,
	wait = function() return 0 end,
}
