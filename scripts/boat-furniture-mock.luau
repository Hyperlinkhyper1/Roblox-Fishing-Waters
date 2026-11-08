-- Minimal Roblox mock for building boat furniture without Studio: Vector3, CFrame
-- (full rotations), Color3, Enum, Instance. Used by scripts/check-boat-furniture.mjs,
-- which appends Shared.BoatFurniture, the item builders and a dumper.
local function v3(x, y, z)
	return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, Vector3Meta)
end
Vector3Meta = {}
Vector3Meta.__index = function(self, key)
	if key == "Magnitude" then
		return math.sqrt(self.X * self.X + self.Y * self.Y + self.Z * self.Z)
	elseif key == "Unit" then
		local m = math.sqrt(self.X * self.X + self.Y * self.Y + self.Z * self.Z)
		if m == 0 then return v3(0, 0, 0) end
		return v3(self.X / m, self.Y / m, self.Z / m)
	elseif key == "x" then return self.X
	elseif key == "y" then return self.Y
	elseif key == "z" then return self.Z
	end
	return Vector3Methods[key]
end
Vector3Methods = {}
function Vector3Methods.Dot(a, b) return a.X * b.X + a.Y * b.Y + a.Z * b.Z end
function Vector3Methods.Cross(a, b)
	return v3(a.Y * b.Z - a.Z * b.Y, a.Z * b.X - a.X * b.Z, a.X * b.Y - a.Y * b.X)
end
function Vector3Methods.Lerp(a, b, t) return v3(a.X + (b.X - a.X) * t, a.Y + (b.Y - a.Y) * t, a.Z + (b.Z - a.Z) * t) end
function Vector3Methods.Abs(a) return v3(math.abs(a.X), math.abs(a.Y), math.abs(a.Z)) end
function Vector3Methods.Min(a, b) return v3(math.min(a.X, b.X), math.min(a.Y, b.Y), math.min(a.Z, b.Z)) end
function Vector3Methods.Max(a, b) return v3(math.max(a.X, b.X), math.max(a.Y, b.Y), math.max(a.Z, b.Z)) end
Vector3Meta.__add = function(a, b) return v3(a.X + b.X, a.Y + b.Y, a.Z + b.Z) end
Vector3Meta.__sub = function(a, b) return v3(a.X - b.X, a.Y - b.Y, a.Z - b.Z) end
Vector3Meta.__unm = function(a) return v3(-a.X, -a.Y, -a.Z) end
Vector3Meta.__mul = function(a, b)
	if type(a) == "number" then return v3(b.X * a, b.Y * a, b.Z * a) end
	if type(b) == "number" then return v3(a.X * b, a.Y * b, a.Z * b) end
	return v3(a.X * b.X, a.Y * b.Y, a.Z * b.Z)
end
Vector3Meta.__div = function(a, b)
	if type(b) == "number" then return v3(a.X / b, a.Y / b, a.Z / b) end
	return v3(a.X / b.X, a.Y / b.Y, a.Z / b.Z)
end
Vector3Meta.__eq = function(a, b) return a.X == b.X and a.Y == b.Y and a.Z == b.Z end
Vector3Meta.__tostring = function(a) return string.format("%g, %g, %g", a.X, a.Y, a.Z) end
Vector3 = {
	new = v3,
	zero = v3(0, 0, 0),
	one = v3(1, 1, 1),
	xAxis = v3(1, 0, 0),
	yAxis = v3(0, 1, 0),
	zAxis = v3(0, 0, 1),
}

-- CFrame: position p and rotation columns r (right), u (up), b (back = -look).
CFrameMeta = {}
local function cf(p, r, u, b)
	return setmetatable({ p = p, r = r, u = u, b = b }, CFrameMeta)
end
local function rotate(c, v)
	return v3(
		c.r.X * v.X + c.u.X * v.Y + c.b.X * v.Z,
		c.r.Y * v.X + c.u.Y * v.Y + c.b.Y * v.Z,
		c.r.Z * v.X + c.u.Z * v.Y + c.b.Z * v.Z
	)
end
local function inverse(c)
	-- Transpose of the rotation, then rotate -p.
	local r = v3(c.r.X, c.u.X, c.b.X)
	local u = v3(c.r.Y, c.u.Y, c.b.Y)
	local b = v3(c.r.Z, c.u.Z, c.b.Z)
	local t = cf(v3(), r, u, b)
	return cf(-rotate(t, c.p), r, u, b)
end
CFrameMeta.__index = function(self, key)
	if key == "Position" then return self.p
	elseif key == "X" then return self.p.X
	elseif key == "Y" then return self.p.Y
	elseif key == "Z" then return self.p.Z
	elseif key == "RightVector" or key == "XVector" then return self.r
	elseif key == "UpVector" or key == "YVector" then return self.u
	elseif key == "LookVector" then return -self.b
	elseif key == "ZVector" then return self.b
	elseif key == "Rotation" then return cf(v3(), self.r, self.u, self.b)
	end
	return CFrameMethods[key]
end
CFrameMeta.__mul = function(a, b)
	if getmetatable(b) == CFrameMeta then
		return cf(a.p + rotate(a, b.p), rotate(a, b.r), rotate(a, b.u), rotate(a, b.b))
	end
	return a.p + rotate(a, b)
end
CFrameMeta.__add = function(a, v) return cf(a.p + v, a.r, a.u, a.b) end
CFrameMeta.__sub = function(a, v) return cf(a.p - v, a.r, a.u, a.b) end
CFrameMethods = {}
function CFrameMethods.Inverse(c) return inverse(c) end
function CFrameMethods.ToObjectSpace(a, b) return inverse(a) * b end
function CFrameMethods.ToWorldSpace(a, b) return a * b end
function CFrameMethods.PointToObjectSpace(a, v) return inverse(a) * v end
function CFrameMethods.PointToWorldSpace(a, v) return a * v end
function CFrameMethods.VectorToWorldSpace(a, v) return rotate(a, v) end
function CFrameMethods.VectorToObjectSpace(a, v) return rotate(inverse(a), v) end
function CFrameMethods.GetComponents(c)
	return c.p.X, c.p.Y, c.p.Z, c.r.X, c.u.X, c.b.X, c.r.Y, c.u.Y, c.b.Y, c.r.Z, c.u.Z, c.b.Z
end
function CFrameMethods.Lerp(a, b, t)
	-- Good enough for builders: lerp position, keep a's rotation until halfway.
	return cf(a.p:Lerp(b.p, t), if t < 0.5 then a.r else b.r, if t < 0.5 then a.u else b.u, if t < 0.5 then a.b else b.b)
end

local IDENTITY_R, IDENTITY_U, IDENTITY_B = v3(1, 0, 0), v3(0, 1, 0), v3(0, 0, 1)
local function rx(a)
	local c, s = math.cos(a), math.sin(a)
	return cf(v3(), v3(1, 0, 0), v3(0, c, s), v3(0, -s, c))
end
local function ry(a)
	local c, s = math.cos(a), math.sin(a)
	return cf(v3(), v3(c, 0, -s), v3(0, 1, 0), v3(s, 0, c))
end
local function rz(a)
	local c, s = math.cos(a), math.sin(a)
	return cf(v3(), v3(c, s, 0), v3(-s, c, 0), v3(0, 0, 1))
end
local function lookAt(at, target, up)
	up = up or v3(0, 1, 0)
	local look = (target - at).Unit
	if look.Magnitude == 0 then
		return cf(at, IDENTITY_R, IDENTITY_U, IDENTITY_B)
	end
	local right = look:Cross(up)
	if right.Magnitude < 1e-6 then
		right = look:Cross(v3(0, 0, 1))
		if right.Magnitude < 1e-6 then right = look:Cross(v3(1, 0, 0)) end
	end
	right = right.Unit
	local upv = right:Cross(look).Unit
	return cf(at, right, upv, -look)
end
CFrame = {
	identity = cf(v3(), IDENTITY_R, IDENTITY_U, IDENTITY_B),
	new = function(x, y, z, ...)
		if type(x) == "table" then
			if y then return lookAt(x, y) end
			return cf(x, IDENTITY_R, IDENTITY_U, IDENTITY_B)
		end
		local extra = { ... }
		if #extra == 9 then
			return cf(v3(x, y, z), v3(extra[1], extra[4], extra[7]), v3(extra[2], extra[5], extra[8]), v3(extra[3], extra[6], extra[9]))
		end
		return cf(v3(x or 0, y or 0, z or 0), IDENTITY_R, IDENTITY_U, IDENTITY_B)
	end,
	Angles = function(x, y, z) return rx(x or 0) * ry(y or 0) * rz(z or 0) end,
	fromEulerAnglesXYZ = function(x, y, z) return rx(x or 0) * ry(y or 0) * rz(z or 0) end,
	fromEulerAnglesYXZ = function(x, y, z) return ry(y or 0) * rx(x or 0) * rz(z or 0) end,
	fromOrientation = function(x, y, z) return ry(y or 0) * rx(x or 0) * rz(z or 0) end,
	lookAt = lookAt,
	fromAxisAngle = function(axis, angle)
		local a = axis.Unit
		local c, s = math.cos(angle), math.sin(angle)
		local t = 1 - c
		local x, y, z = a.X, a.Y, a.Z
		return cf(
			v3(),
			v3(t * x * x + c, t * x * y + s * z, t * x * z - s * y),
			v3(t * x * y - s * z, t * y * y + c, t * y * z + s * x),
			v3(t * x * z + s * y, t * y * z - s * x, t * z * z + c)
		)
	end,
}

local function clamp01(x) return math.max(0, math.min(1, x)) end
Color3Meta = {}
Color3Meta.__index = function(self, key)
	if key == "Lerp" then
		return function(a, b, t) return Color3.new(a.R + (b.R - a.R) * t, a.G + (b.G - a.G) * t, a.B + (b.B - a.B) * t) end
	elseif key == "ToHex" then
		return function(c) return string.format("%02x%02x%02x", math.round(clamp01(c.R) * 255), math.round(clamp01(c.G) * 255), math.round(clamp01(c.B) * 255)) end
	end
	return nil
end
Color3 = {
	new = function(r, g, b) return setmetatable({ R = r or 0, G = g or 0, B = b or 0 }, Color3Meta) end,
	fromRGB = function(r, g, b) return Color3.new((r or 0) / 255, (g or 0) / 255, (b or 0) / 255) end,
	fromHSV = function(h, s, v)
		local i = math.floor(h * 6)
		local f = h * 6 - i
		local p, q, t = v * (1 - s), v * (1 - f * s), v * (1 - (1 - f) * s)
		local m = i % 6
		if m == 0 then return Color3.new(v, t, p) elseif m == 1 then return Color3.new(q, v, p)
		elseif m == 2 then return Color3.new(p, v, t) elseif m == 3 then return Color3.new(p, q, v)
		elseif m == 4 then return Color3.new(t, p, v) end
		return Color3.new(v, p, q)
	end,
}

local function enumGroup(groupName)
	return setmetatable({}, {
		__index = function(self, key)
			local item = { Name = key, EnumType = groupName }
			rawset(self, key, item)
			return item
		end,
	})
end
Enum = setmetatable({}, {
	__index = function(self, key)
		local group = enumGroup(key)
		rawset(self, key, group)
		return group
	end,
})

local InstanceMeta = {}
local instanceMethods = {}
InstanceMeta.__index = function(self, key)
	local method = instanceMethods[key]
	if method then return method end
	return rawget(self, "_props")[key]
end
InstanceMeta.__newindex = function(self, key, value)
	if key == "Parent" then
		local old = rawget(self, "_props").Parent
		if old then
			local list = rawget(old, "_children")
			for i = #list, 1, -1 do
				if list[i] == self then table.remove(list, i) end
			end
		end
		if value then table.insert(rawget(value, "_children"), self) end
	end
	rawget(self, "_props")[key] = value
end
function instanceMethods.GetChildren(self) return table.clone(rawget(self, "_children")) end
function instanceMethods.GetDescendants(self)
	local out = {}
	local function walk(node)
		for _, child in rawget(node, "_children") do
			table.insert(out, child)
			walk(child)
		end
	end
	walk(self)
	return out
end
function instanceMethods.FindFirstChild(self, name)
	for _, child in rawget(self, "_children") do
		if child.Name == name then return child end
	end
	return nil
end
function instanceMethods.IsA(self, class)
	local own = rawget(self, "_props").ClassName
	if class == "BasePart" then return own == "Part" or own == "WedgePart" end
	return own == class
end
function instanceMethods.SetAttribute(self, key, value) rawget(self, "_attributes")[key] = value end
function instanceMethods.GetAttribute(self, key) return rawget(self, "_attributes")[key] end
function instanceMethods.Destroy(self) self.Parent = nil end
function instanceMethods.ClearAllChildren(self)
	for _, child in self:GetChildren() do child.Parent = nil end
end
Instance = {
	new = function(className)
		local props = { ClassName = className, Name = className, Transparency = 0 }
		if className == "Part" or className == "WedgePart" then
			props.Size = v3(4, 1, 2)
			props.CFrame = CFrame.identity
			props.Color = Color3.fromRGB(163, 162, 165)
			props.Shape = Enum.PartType.Block
		end
		return setmetatable({ _props = props, _children = {}, _attributes = {} }, InstanceMeta)
	end,
}
script = nil
warn = function(...) print("WARN", ...) end
