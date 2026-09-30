-- Faux environnement Roblox minimal pour tester la logique pure
Modules = {}
local cache = {}
local function token(name)
	local t = { Name = name }
	t.WaitForChild = function(self, child) return token(child) end
	t.Parent = setmetatable({ Name = "Folder" }, { __index = function(_, key) if key == "WaitForChild" then return function(self, child) return token(child) end end end })
	return t
end
function require(t)
	local name = t.Name
	if cache[name] == nil then
		assert(Modules[name], "module inconnu : " .. tostring(name))
		cache[name] = Modules[name](token(name))
	end
	return cache[name]
end
function useModule(name, value) cache[name] = value end
Color3 = { fromRGB = function(r, g, b) return { R = r, G = g, B = b } end, new = function(r, g, b) return { R = r, G = g, B = b } end }
Vector3 = { new = function(x, y, z) return { X = x, Y = y, Z = z } end }
typeof = type
local fakeServices = { Players = { PlayerRemoving = { Connect = function() end } } }
game = { GetService = function(self, name) return fakeServices[name] or token(name) end }
Random = { new = function() return { NextNumber = function() return math.random() end } end }

-- mini framework de tests
passed, failed = 0, 0
function check(label, condition)
	if condition then passed += 1 else failed += 1; print("❌ ÉCHEC : " .. label) end
end
function section(name) print("\n== " .. name) end
