-- The weather radar: a round radar table on a pedestal, bought at the furniture
-- shop and placed in the yard behind a base house. The server only builds the
-- table; each client draws the live picture onto the tagged screen itself
-- (src/client/WeatherRadar.luau), from the same deterministic forecast that
-- drives its own sky, so nothing about the weather is replicated.
local CollectionService = game:GetService("CollectionService")

local Props = require(script.Parent.Props)

local WeatherRadar = {}
local rgb = Color3.fromRGB
local M = Enum.Material
local IRON = rgb(46, 52, 56)
local PAINT = rgb(222, 226, 222)
local BEZEL = rgb(32, 36, 40)
local GLASS = rgb(12, 22, 30)

WeatherRadar.SCREEN_TAG = "WeatherRadarScreen"
WeatherRadar.DIAMETER = 3.6
-- The console leans toward the reader standing at the item's +Z side.
WeatherRadar.TILT = math.rad(22)
WeatherRadar.HEIGHT = 4.4

local function decorative(piece: BasePart): BasePart
	piece.CanCollide, piece.CanQuery = false, false
	return piece
end

local function disc(parent: Instance, frame: CFrame, thickness: number, diameter: number, color: Color3, material): Part
	-- Cylinders run along their X axis; turn it upright in the console's frame.
	local piece = Props.part(
		parent,
		Vector3.new(thickness, diameter, diameter),
		frame * CFrame.Angles(0, 0, math.pi / 2),
		color,
		material
	)
	piece.Shape = Enum.PartType.Cylinder
	return piece
end

function WeatherRadar.build(parent: Instance, frame: CFrame): Model
	local model = Instance.new("Model")
	model.Name = "WeatherRadar"
	model.Parent = parent
	disc(model, frame * CFrame.new(0, 0.15, 0), 0.3, 2.6, IRON, M.Metal)
	local column = disc(model, frame * CFrame.new(0, 1.45, 0), 2.3, 0.9, PAINT, M.Metal)
	column.Name = "RadarColumn"
	local console = frame * CFrame.new(0, 2.85, 0) * CFrame.Angles(WeatherRadar.TILT, 0, 0)
	local bezel = disc(model, console, 0.4, WeatherRadar.DIAMETER + 0.5, BEZEL, M.Metal)
	bezel.Name = "RadarBezel"
	decorative(disc(model, console * CFrame.new(0, 0.2, 0), 0.04, WeatherRadar.DIAMETER, GLASS, M.Glass))
	-- An invisible square over the glass carries the client's SurfaceGui on its
	-- top face; the client only paints the round area inside the bezel.
	local screen = decorative(
		Props.part(
			model,
			Vector3.new(WeatherRadar.DIAMETER, 0.02, WeatherRadar.DIAMETER),
			console * CFrame.new(0, 0.23, 0),
			GLASS,
			M.SmoothPlastic
		)
	)
	screen.Name = "RadarScreen"
	screen.Transparency = 1
	screen.CastShadow = false
	screen:SetAttribute("Diameter", WeatherRadar.DIAMETER)
	CollectionService:AddTag(screen, WeatherRadar.SCREEN_TAG)
	-- A small dish on a mast behind the table, with a red beacon on top.
	decorative(Props.part(model, Vector3.new(0.18, 2.4, 0.18), frame * CFrame.new(0, 3.2, -1.75), IRON, M.Metal))
	decorative(
		disc(
			model,
			frame * CFrame.new(0, 4.15, -1.62) * CFrame.Angles(math.rad(-35), 0, 0),
			0.12,
			1.3,
			PAINT,
			M.SmoothPlastic
		)
	)
	decorative(
		Props.part(model, Vector3.new(0.22, 0.22, 0.22), frame * CFrame.new(0, 4.5, -1.75), rgb(220, 50, 40), M.Neon)
	)
	return model
end

return WeatherRadar
