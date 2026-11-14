-- Micro Harbour, the computer superstore in the city (Map/TechStore, TechStoreService, client
-- TechStore). Components are cosmetic: they show inside and on the office PC (Shared.PcModel),
-- in its boot screen and in the MY PC app. Monitors change how the office PC's screen looks
-- (client RetroUI.applyScreen). Licenses unlock PC apps: the STOCKS app (Harbour Exchange) needs
-- a trading license and the WEB SHOP app (Harbour Direct, Shared.WebShop) a web shop license.
--
-- Buying a part puts it in the company's parts bin; it is fitted at the workbench in a base
-- (PcWorkshopService): pick the PC up off the desk, carry it to the bench, unscrew the case,
-- swap parts and carry it back. Complete PCs credit components already owned and are handed
-- over in the store, ready to carry home.
--
-- Saved on the company profile as `Tech` = { Owned = { [id] = true }, Equipped = { [slot] = id },
-- Licenses = { [id] = true } }. `decode` is forgiving: unknown ids are dropped and anything
-- missing falls back to the starter parts every office PC ships with.
local Catalog = {}

Catalog.STORE_NAME = "MICRO HARBOUR"
Catalog.STORE_TAG = "TechStore"
Catalog.PROMPT_NAME = "BrowseTechPrompt"

Catalog.Slots = { "CPU", "Motherboard", "RAM", "GPU", "Storage", "Cooling", "PSU", "Case", "Monitor" }
Catalog.SlotNames = {
	CPU = "Processor",
	Motherboard = "Motherboard",
	RAM = "Memory",
	GPU = "Graphics card",
	Storage = "Storage",
	Cooling = "Cooling",
	PSU = "Power supply",
	Case = "Case",
	Monitor = "Monitor",
}
-- Departments are the shop window's tabs and the store's three service desks.
Catalog.Departments = { "Components", "Monitors", "Licenses" }

local rgb = Color3.fromRGB

-- Screen looks, from the original green tube to an OLED panel. Colours fill RetroUI.Colors:
-- Screen (background), Panel, Dim (borders), Mid (secondary text), Bright (text), Hot (accent).
-- Bloom is the text stroke transparency (1 = crisp), Scanlines the darkness of every 4th line
-- (nil = none) and Rim the edge vignette (nil = none).
local SCREENS = {
	Mono14 = {
		Screen = rgb(4, 12, 7),
		Panel = rgb(8, 24, 13),
		Dim = rgb(28, 82, 44),
		Mid = rgb(78, 184, 104),
		Bright = rgb(110, 255, 140),
		Hot = rgb(205, 255, 214),
		Title = Enum.Font.Arcade,
		Body = Enum.Font.Code,
		Bloom = 0.88,
		Scanlines = 0.82,
		Rim = 0.55,
	},
	Amber14 = {
		Screen = rgb(14, 8, 2),
		Panel = rgb(30, 17, 4),
		Dim = rgb(96, 56, 14),
		Mid = rgb(206, 128, 36),
		Bright = rgb(255, 176, 64),
		Hot = rgb(255, 226, 170),
		Title = Enum.Font.Arcade,
		Body = Enum.Font.Code,
		Bloom = 0.9,
		Scanlines = 0.86,
		Rim = 0.62,
	},
	Paper15 = {
		Screen = rgb(10, 12, 14),
		Panel = rgb(22, 25, 28),
		Dim = rgb(70, 78, 86),
		Mid = rgb(160, 170, 178),
		Bright = rgb(230, 236, 240),
		Hot = rgb(255, 255, 255),
		Title = Enum.Font.Arcade,
		Body = Enum.Font.RobotoMono,
		Bloom = 0.93,
		Scanlines = 0.92,
		Rim = 0.75,
	},
	Vga17 = {
		Screen = rgb(0, 0, 132),
		Panel = rgb(0, 0, 168),
		Dim = rgb(84, 84, 252),
		Mid = rgb(170, 170, 170),
		Bright = rgb(255, 255, 255),
		Hot = rgb(255, 255, 84),
		Title = Enum.Font.Arcade,
		Body = Enum.Font.RobotoMono,
		Bloom = 0.96,
		Scanlines = 0.94,
		Rim = 0.85,
	},
	Flat24 = {
		Screen = rgb(24, 28, 36),
		Panel = rgb(34, 40, 52),
		Dim = rgb(74, 86, 108),
		Mid = rgb(150, 162, 184),
		Bright = rgb(236, 240, 248),
		Hot = rgb(96, 176, 255),
		Title = Enum.Font.GothamBlack,
		Body = Enum.Font.Gotham,
		Bloom = 1,
	},
	Oled34 = {
		Screen = rgb(0, 0, 0),
		Panel = rgb(16, 14, 24),
		Dim = rgb(64, 52, 96),
		Mid = rgb(170, 160, 210),
		Bright = rgb(255, 255, 255),
		Hot = rgb(255, 84, 160),
		Title = Enum.Font.GothamBlack,
		Body = Enum.Font.GothamMedium,
		Bloom = 1,
	},
}

-- Case looks (Shared.PcModel): shell plastic or steel, trim, front, and how the shell is built.
-- Form "Desktop" lies flat with the monitor on top and a lift-off lid; "Tower" stands beside the
-- monitor with a screwed side panel; "Showcase" is a wide glass cube. Window is how much of the
-- side panel is glass ("None", "Small", "Full"); Mesh gives a perforated front.
local CASES = {
	CaseBeige = { Form = "Desktop", Body = rgb(204, 192, 160), Trim = rgb(176, 164, 133), Front = rgb(198, 186, 155), Window = "None" },
	CaseGraphite = { Form = "Tower", Body = rgb(52, 54, 58), Trim = rgb(30, 31, 34), Front = rgb(64, 66, 70), Window = "None" },
	CaseMesh = { Form = "Tower", Body = rgb(38, 44, 50), Trim = rgb(20, 22, 26), Front = rgb(28, 30, 34), Window = "Small", Mesh = true },
	CaseArctic = { Form = "Tower", Body = rgb(236, 238, 240), Trim = rgb(196, 200, 204), Front = rgb(246, 247, 248), Window = "Full" },
	CaseGlass = { Form = "Tower", Body = rgb(22, 22, 26), Trim = rgb(12, 12, 14), Front = rgb(40, 40, 46), Window = "Full", GlassFront = true, Glow = true },
	CaseAbyss = { Form = "Showcase", Body = rgb(16, 22, 34), Trim = rgb(8, 10, 16), Front = rgb(24, 30, 44), Window = "Full", GlassFront = true, Glow = true },
}

-- id -> item. Every slot has one free starter item (Price 0), owned by everyone. Watts is the
-- part's power draw (PSU parts give Capacity instead); Tier (1-6) sizes it inside the case.
Catalog.Items = {
	-- Processors: the badge and clock readout on the case front, and the chip under the cooler.
	Cpu386 = { Slot = "CPU", Name = "Harbour 386DX", Spec = "33 MHz, 1 core", Price = 0, Badge = "PC 386", Clock = "33", Watts = 5, Tier = 1, Lid = rgb(70, 72, 78) },
	Cpu486 = { Slot = "CPU", Name = "Harbour 486DX2", Spec = "66 MHz, 1 core", Price = 600, Badge = "PC 486", Clock = "66", Watts = 8, Tier = 2, Lid = rgb(160, 162, 166) },
	CpuTide = { Slot = "CPU", Name = "Tidewater P5", Spec = "200 MHz, 1 core", Price = 1800, Badge = "TIDE P5", Clock = "200", Watts = 15, Tier = 3, Lid = rgb(178, 180, 186) },
	CpuSurge = { Slot = "CPU", Name = "Surge Q4", Spec = "3.2 GHz, 4 cores", Price = 3200, Badge = "SURGE Q4", Clock = "3.2", Watts = 65, Tier = 4, Lid = rgb(196, 198, 204) },
	CpuRiptide = { Slot = "CPU", Name = "Riptide X8", Spec = "4.2 GHz, 8 cores", Price = 5000, Badge = "RIPTIDE", Clock = "4.2", Watts = 120, Tier = 5, Lid = rgb(206, 208, 214) },
	CpuKraken = { Slot = "CPU", Name = "Kraken 32", Spec = "5.6 GHz, 32 cores", Price = 14000, Badge = "KRAKEN", Clock = "5.6", Watts = 250, Tier = 6, Lid = rgb(214, 182, 96) },
	-- Motherboards: the board everything plugs into.
	MbAt = { Slot = "Motherboard", Name = "Harbour AT board", Spec = "Baby-AT, ISA slots", Price = 0, Watts = 10, Tier = 1, Pcb = rgb(34, 96, 52), Heatsink = rgb(150, 150, 150) },
	MbAtx = { Slot = "Motherboard", Name = "Lagoon ATX", Spec = "ATX, PCI and AGP", Price = 450, Watts = 20, Tier = 2, Pcb = rgb(30, 92, 86), Heatsink = rgb(170, 172, 176) },
	MbReef = { Slot = "Motherboard", Name = "Reef B650", Spec = "ATX, PCIe 4.0", Price = 1400, Watts = 35, Tier = 3, Pcb = rgb(24, 26, 30), Heatsink = rgb(70, 140, 200) },
	MbRiptide = { Slot = "Motherboard", Name = "Riptide X870", Spec = "ATX, PCIe 5.0, Wi-Fi", Price = 3800, Watts = 50, Tier = 4, Pcb = rgb(20, 20, 24), Heatsink = rgb(196, 200, 206), Rgb = rgb(255, 80, 155) },
	MbKraken = { Slot = "Motherboard", Name = "Kraken Extreme", Spec = "E-ATX, armoured, RGB", Price = 9000, Watts = 70, Tier = 5, Pcb = rgb(14, 14, 18), Heatsink = rgb(214, 182, 96), Rgb = rgb(180, 110, 255), Armour = true },
	-- Memory: the boot screen's memory test counts it.
	Ram640 = { Slot = "RAM", Name = "640K base memory", Spec = "640 KB", Price = 0, Kilobytes = 640, Watts = 1, Sticks = 1, Spreader = rgb(30, 92, 50) },
	Ram4M = { Slot = "RAM", Name = "Driftwood 4 MB", Spec = "4 MB SIMM", Price = 300, Kilobytes = 4096, Watts = 2, Sticks = 2, Spreader = rgb(28, 96, 54) },
	Ram64M = { Slot = "RAM", Name = "Driftwood 64 MB", Spec = "64 MB DIMM", Price = 1200, Kilobytes = 65536, Watts = 4, Sticks = 2, Spreader = rgb(30, 100, 62) },
	Ram16G = { Slot = "RAM", Name = "Current 16 GB", Spec = "16 GB DDR5", Price = 3500, Kilobytes = 16777216, Watts = 8, Sticks = 2, Spreader = rgb(40, 44, 52), Tall = true },
	Ram32G = { Slot = "RAM", Name = "Current 32 GB", Spec = "32 GB DDR5, heat spreaders", Price = 5500, Kilobytes = 33554432, Watts = 10, Sticks = 4, Spreader = rgb(150, 156, 166), Tall = true },
	Ram128G = { Slot = "RAM", Name = "Current RGB 128 GB", Spec = "128 GB DDR5, RGB", Price = 9000, Kilobytes = 134217728, Watts = 20, Sticks = 4, Spreader = rgb(24, 24, 28), Tall = true, Rgb = true },
	-- Graphics cards, from a bare text adapter to a triple-fan flagship.
	GpuMono = { Slot = "GPU", Name = "Mono text adapter", Spec = "720 x 348, 2 colours", Price = 0, Watts = 3, Tier = 1, Shroud = rgb(30, 92, 52) },
	GpuVga = { Slot = "GPU", Name = "Lagoon VGA", Spec = "640 x 480, 256 colours", Price = 500, Watts = 6, Tier = 2, Shroud = rgb(28, 88, 60) },
	GpuReef = { Slot = "GPU", Name = "Reef 3D accelerator", Spec = "16 MB, hardware 3D", Price = 2000, Watts = 20, Tier = 3, Shroud = rgb(196, 120, 40), Fans = 1 },
	GpuCurrent = { Slot = "GPU", Name = "Current GT 4", Spec = "4 GB, shader model 5", Price = 3500, Watts = 75, Tier = 4, Shroud = rgb(46, 50, 58), Fans = 1 },
	GpuSwell = { Slot = "GPU", Name = "Swell RX 8", Spec = "8 GB, ray tracing", Price = 6000, Watts = 220, Tier = 5, Shroud = rgb(36, 38, 44), Fans = 2, Glow = rgb(80, 170, 255) },
	GpuTsunami = { Slot = "GPU", Name = "Tsunami 24", Spec = "24 GB, flagship", Price = 15000, Watts = 450, Tier = 6, Shroud = rgb(186, 190, 198), Fans = 3, Glow = rgb(255, 80, 155) },
	-- Storage: drive C: in the boot screen. Form is how the drive is built and mounted.
	Hdd20 = { Slot = "Storage", Name = "20 MB fixed disk", Spec = "20 MB, 3600 RPM", Price = 0, Drive = "20MB", Watts = 10, Form = "Bay525" },
	Hdd540 = { Slot = "Storage", Name = "Quayside 540", Spec = "540 MB hard disk", Price = 400, Drive = "540MB", Watts = 8, Form = "Hdd" },
	Hdd80G = { Slot = "Storage", Name = "Quayside 80G", Spec = "80 GB hard disk", Price = 1500, Drive = "80GB", Watts = 8, Form = "Hdd" },
	SsdSata = { Slot = "Storage", Name = "Seafloor 512", Spec = "512 GB SATA SSD", Price = 2500, Drive = "512GB SSD", Watts = 3, Form = "Ssd" },
	Ssd2T = { Slot = "Storage", Name = "Seafloor 2 TB", Spec = "2 TB NVMe stick", Price = 4000, Drive = "2TB SSD", Watts = 6, Form = "M2" },
	Ssd16T = { Slot = "Storage", Name = "Abyss 16 TB", Spec = "16 TB NVMe SSD, heatsink", Price = 10000, Drive = "16TB NVME", Watts = 9, Form = "M2", Heatsink = true },
	-- Cooling: the CPU cooler, and the case's power light (and the glow inside a glass case).
	FanStock = { Slot = "Cooling", Name = "Stock fan", Spec = "Whirs politely", Price = 0, Light = rgb(90, 230, 110), Watts = 2, Form = "Stock" },
	FanTower = { Slot = "Cooling", Name = "Gale tower cooler", Spec = "Single-fan air tower", Price = 400, Light = rgb(80, 170, 255), Watts = 4, Form = "Tower" },
	FanTwin = { Slot = "Cooling", Name = "Gale twin tower", Spec = "Dual-tower, two fans", Price = 1100, Light = rgb(120, 200, 255), Watts = 6, Form = "Twin" },
	LiquidAio = { Slot = "Cooling", Name = "Undertow 240 liquid", Spec = "240 mm liquid loop", Price = 2000, Light = rgb(40, 230, 230), Watts = 12, Form = "Aio" },
	RgbLoop = { Slot = "Cooling", Name = "Aurora custom loop", Spec = "Hard-line loop, RGB", Price = 7000, Light = rgb(255, 70, 190), Watts = 25, Form = "Loop" },
	CoolChiller = { Slot = "Cooling", Name = "Abyss sub-zero chiller", Spec = "Phase-change, frosty", Price = 12000, Light = rgb(150, 230, 255), Watts = 180, Form = "Chiller" },
	-- Power supplies: Capacity is what the build may draw.
	Psu200 = { Slot = "PSU", Name = "200 W AT supply", Spec = "200 W, beige box", Price = 0, Capacity = 200, Body = rgb(170, 166, 150) },
	Psu450 = { Slot = "PSU", Name = "Harbour 450", Spec = "450 W, 80+ bronze", Price = 350, Capacity = 450, Body = rgb(60, 62, 66) },
	Psu750 = { Slot = "PSU", Name = "Tidal 750 Gold", Spec = "750 W, modular", Price = 1300, Capacity = 750, Body = rgb(34, 36, 40), Accent = rgb(217, 174, 75) },
	Psu1000 = { Slot = "PSU", Name = "Surge 1000 Platinum", Spec = "1000 W, fully modular", Price = 3000, Capacity = 1000, Body = rgb(26, 26, 30), Accent = rgb(200, 206, 214) },
	Psu1600 = { Slot = "PSU", Name = "Leviathan 1600", Spec = "1600 W titanium, RGB", Price = 7500, Capacity = 1600, Body = rgb(20, 20, 24), Accent = rgb(180, 110, 255), Rgb = true },
	-- Cases: the shape and colour of the PC on the desk.
	CaseBeige = { Slot = "Case", Name = "Beige desktop", Spec = "Yellowing nicely", Price = 0, Watts = 0 },
	CaseGraphite = { Slot = "Case", Name = "Graphite mini tower", Spec = "Matte black steel tower", Price = 800, Watts = 0 },
	CaseMesh = { Slot = "Case", Name = "Reefline mesh tower", Spec = "Mesh front, small window", Price = 1500, Watts = 4 },
	CaseArctic = { Slot = "Case", Name = "Arctic tower", Spec = "Clean white steel, side window", Price = 2500, Watts = 4 },
	CaseGlass = { Slot = "Case", Name = "Prism glass case", Spec = "Tempered glass, RGB fans", Price = 6000, Watts = 10 },
	CaseAbyss = { Slot = "Case", Name = "Abyss showcase", Spec = "Dual-glass aquarium cube, RGB", Price = 12000, Watts = 15 },
	-- Monitors: each changes the office PC's screen.
	Mono14 = { Slot = "Monitor", Name = "Monochrome 14", Spec = "Green phosphor CRT", Price = 0, Plate = "MONOCHROME 14", Bezel = rgb(214, 204, 175), Inches = 14 },
	Amber14 = { Slot = "Monitor", Name = "Amber 14", Spec = "Amber phosphor CRT, sharper", Price = 750, Plate = "AMBER 14", Bezel = rgb(206, 198, 176), Inches = 14 },
	Paper15 = { Slot = "Monitor", Name = "Paperwhite 15", Spec = "White phosphor CRT, crisp", Price = 2000, Plate = "PAPERWHITE 15", Bezel = rgb(228, 228, 224), Inches = 15 },
	Vga17 = { Slot = "Monitor", Name = "Colour VGA 17", Spec = "Full-colour CRT", Price = 5000, Plate = "COLOUR VGA 17", Bezel = rgb(196, 198, 196), Inches = 17 },
	Flat24 = { Slot = "Monitor", Name = "Flatline 24 LCD", Spec = "Flat panel, no scanlines", Price = 10000, Plate = "FLATLINE 24", Bezel = rgb(38, 38, 42), Flat = true, Inches = 24 },
	Oled34 = { Slot = "Monitor", Name = "Abyss 34 OLED", Spec = "Ultrawide OLED, true blacks", Price = 20000, Plate = "ABYSS OLED", Bezel = rgb(18, 18, 20), Flat = true, Inches = 34, Ultrawide = true },
}

for id, screen in SCREENS do
	Catalog.Items[id].Screen = screen
end
for id, look in CASES do
	Catalog.Items[id].Look = look
end

-- Shop order within each slot (cheapest first). Each rack showcase holds at most six.
Catalog.Order = {
	CPU = { "Cpu386", "Cpu486", "CpuTide", "CpuSurge", "CpuRiptide", "CpuKraken" },
	Motherboard = { "MbAt", "MbAtx", "MbReef", "MbRiptide", "MbKraken" },
	RAM = { "Ram640", "Ram4M", "Ram64M", "Ram16G", "Ram32G", "Ram128G" },
	GPU = { "GpuMono", "GpuVga", "GpuReef", "GpuCurrent", "GpuSwell", "GpuTsunami" },
	Storage = { "Hdd20", "Hdd540", "Hdd80G", "SsdSata", "Ssd2T", "Ssd16T" },
	Cooling = { "FanStock", "FanTower", "FanTwin", "LiquidAio", "RgbLoop", "CoolChiller" },
	PSU = { "Psu200", "Psu450", "Psu750", "Psu1000", "Psu1600" },
	Case = { "CaseBeige", "CaseGraphite", "CaseMesh", "CaseArctic", "CaseGlass", "CaseAbyss" },
	Monitor = { "Mono14", "Amber14", "Paper15", "Vga17", "Flat24", "Oled34" },
}

Catalog.Defaults = {}
for slot, ids in Catalog.Order do
	Catalog.Defaults[slot] = ids[1]
end

Catalog.Licenses = {
	StockExchange = {
		Name = "Harbour Exchange trading license",
		Spec = "Unlocks the STOCKS app on your office PC",
		Price = 5000,
		App = "Stocks",
	},
	WebShop = {
		Name = "Harbour Direct web shop license",
		Spec = "Unlocks the WEB SHOP app: order cages and nets to your tools racks",
		Price = 3500,
		App = "WebShop",
	},
}
Catalog.LicenseOrder = { "StockExchange", "WebShop" }

-- Complete PCs use the existing company parts save. Buying a build charges only for its
-- missing parts and hands the assembled PC over to carry home; no second ownership system.
Catalog.PrebuiltOrder = { "HarbourHome", "HarbourOffice", "ReefCreator", "RiptideGaming", "ArcticStudio", "KrakenUltra" }
Catalog.Prebuilts = {
	HarbourHome = { Name = "Harbour Home", Spec = "Classic home PC / warm amber CRT", Accent = rgb(255, 176, 64),
		Parts = { CPU = "Cpu486", Motherboard = "MbAtx", RAM = "Ram4M", GPU = "GpuVga", Storage = "Hdd540", Cooling = "FanStock", PSU = "Psu200", Case = "CaseBeige", Monitor = "Amber14" } },
	HarbourOffice = { Name = "Harbour Office", Spec = "Everyday office tower / crisp paperwhite CRT", Accent = rgb(115, 205, 170),
		Parts = { CPU = "CpuTide", Motherboard = "MbAtx", RAM = "Ram64M", GPU = "GpuReef", Storage = "Hdd80G", Cooling = "FanTower", PSU = "Psu450", Case = "CaseGraphite", Monitor = "Paper15" } },
	ReefCreator = { Name = "Reef Creator", Spec = "Creative workstation / 32 GB / 2 TB SSD", Accent = rgb(80, 185, 255),
		Parts = { CPU = "CpuRiptide", Motherboard = "MbReef", RAM = "Ram32G", GPU = "GpuSwell", Storage = "Ssd2T", Cooling = "LiquidAio", PSU = "Psu750", Case = "CaseMesh", Monitor = "Flat24" } },
	RiptideGaming = { Name = "Riptide Gaming", Spec = "RGB gaming PC / glass case / ultrawide OLED", Accent = rgb(255, 80, 155),
		Parts = { CPU = "CpuRiptide", Motherboard = "MbRiptide", RAM = "Ram16G", GPU = "GpuSwell", Storage = "Ssd2T", Cooling = "RgbLoop", PSU = "Psu1000", Case = "CaseGlass", Monitor = "Oled34" } },
	ArcticStudio = { Name = "Arctic Studio", Spec = "White studio build / 128 GB / liquid cooled", Accent = rgb(100, 235, 230),
		Parts = { CPU = "CpuKraken", Motherboard = "MbRiptide", RAM = "Ram128G", GPU = "GpuSwell", Storage = "Ssd2T", Cooling = "LiquidAio", PSU = "Psu1000", Case = "CaseArctic", Monitor = "Flat24" } },
	KrakenUltra = { Name = "Kraken Ultra", Spec = "Flagship / sub-zero / 24 GB graphics / 16 TB", Accent = rgb(180, 110, 255),
		Parts = { CPU = "CpuKraken", Motherboard = "MbKraken", RAM = "Ram128G", GPU = "GpuTsunami", Storage = "Ssd16T", Cooling = "CoolChiller", PSU = "Psu1600", Case = "CaseAbyss", Monitor = "Oled34" } },
}
for _, build in Catalog.Prebuilts do
	build.Price = 0
	for _, id in build.Parts do build.Price += Catalog.Items[id].Price end
end

function Catalog.product(kind: string, id: string)
	return if kind == "Prebuilt" then Catalog.Prebuilts[id]
		elseif kind == "License" then Catalog.Licenses[id] else Catalog.Items[id]
end

-- Player attributes TechStoreService mirrors from the profile, for the office PC.
function Catalog.slotAttribute(slot: string): string
	return "Tech" .. slot
end
function Catalog.licenseAttribute(id: string): string
	return "License" .. id
end

export type Tech = {
	Owned: { [string]: boolean },
	Equipped: { [string]: string },
	Licenses: { [string]: boolean },
}

function Catalog.decode(raw: any): Tech
	local tech: Tech = { Owned = {}, Equipped = {}, Licenses = {} }
	local source = if type(raw) == "table" then raw else {}
	if type(source.Owned) == "table" then
		for id, owned in source.Owned do
			if owned == true and type(id) == "string" and Catalog.Items[id] and Catalog.Items[id].Price > 0 then
				tech.Owned[id] = true
			end
		end
	end
	if type(source.Licenses) == "table" then
		for id, owned in source.Licenses do
			if owned == true and type(id) == "string" and Catalog.Licenses[id] then
				tech.Licenses[id] = true
			end
		end
	end
	for _, slot in Catalog.Slots do
		local id = if type(source.Equipped) == "table" then source.Equipped[slot] else nil
		local item = type(id) == "string" and Catalog.Items[id]
		tech.Equipped[slot] = if item and item.Slot == slot and Catalog.owns(tech, id) then id else Catalog.Defaults[slot]
	end
	return tech
end

function Catalog.owns(tech: Tech, id: string): boolean
	local item = Catalog.Items[id]
	return item ~= nil and (item.Price == 0 or tech.Owned[id] == true)
end

function Catalog.prebuiltPrice(tech: Tech, id: string): number
	local price = 0
	for _, partId in Catalog.Prebuilts[id].Parts do
		if not Catalog.owns(tech, partId) then price += Catalog.Items[partId].Price end
	end
	return price
end

function Catalog.prebuiltInstalled(tech: Tech, id: string): boolean
	for slot, partId in Catalog.Prebuilts[id].Parts do
		if tech.Equipped[slot] ~= partId then return false end
	end
	return true
end

function Catalog.hasLicense(profile: any, id: string): boolean
	return Catalog.decode(profile and profile.Tech).Licenses[id] == true
end

-- What a purchase would do, or why it can't happen. Prebuilts credit already-owned parts.
function Catalog.problem(tech: Tech, cash: number, kind: string, id: any): string?
	if kind == "Prebuilt" then
		if type(id) ~= "string" or not Catalog.Prebuilts[id] then return "Choose a PC from the prebuilt showroom." end
		local price = Catalog.prebuiltPrice(tech, id)
		if cash < price then return "You need $" .. price .. " for the parts you don't own yet." end
		return nil
	end
	if kind == "License" then
		local license = type(id) == "string" and Catalog.Licenses[id]
		if not license then
			return "Choose a license from the counter."
		end
		if tech.Licenses[id] then
			return "You already own this license."
		end
		if cash < license.Price then
			return "You need $" .. license.Price .. " for this license."
		end
		return nil
	end
	local item = type(id) == "string" and Catalog.Items[id]
	if not item then
		return "Choose something from the shelves."
	end
	if Catalog.owns(tech, id) then
		return "You already own this. Fit it at your workbench."
	end
	if cash < item.Price then
		return "You need $" .. item.Price .. " for this."
	end
	return nil
end

-- Applies a purchase to a decoded Tech table and returns the price. Parts go into the parts bin
-- (owned, not fitted); a complete PC's parts are all owned afterwards, ready to hand over.
function Catalog.buy(tech: Tech, kind: string, id: string): number
	if kind == "Prebuilt" then
		local price = Catalog.prebuiltPrice(tech, id)
		for _, partId in Catalog.Prebuilts[id].Parts do
			if Catalog.Items[partId].Price > 0 then tech.Owned[partId] = true end
		end
		return price
	end
	if kind == "License" then
		tech.Licenses[id] = true
		return Catalog.Licenses[id].Price
	end
	local item = Catalog.Items[id]
	tech.Owned[id] = true
	return item.Price
end

-- A clean parts list ({ [slot] = id }) for every slot: unknown, wrong-slot or unowned parts
-- fall back to the starter part. `tech` may be nil to only check ids and slots.
function Catalog.sanitize(parts: any, tech: Tech?): { [string]: string }
	local result = {}
	for _, slot in Catalog.Slots do
		local id = type(parts) == "table" and parts[slot]
		local item = type(id) == "string" and Catalog.Items[id]
		result[slot] = if item and item.Slot == slot and (tech == nil or Catalog.owns(tech, id)) then id else Catalog.Defaults[slot]
	end
	return result
end

-- Fits a whole PC (a parts list from the workbench or a complete PC) into the office desk.
function Catalog.fit(tech: Tech, parts: { [string]: string })
	tech.Equipped = Catalog.sanitize(parts, tech)
end

-- Plain table to save: only purchases and non-default parts.
function Catalog.encode(tech: Tech): any
	local saved = { Owned = {}, Equipped = {}, Licenses = {} }
	for id in tech.Owned do
		saved.Owned[id] = true
	end
	for id in tech.Licenses do
		saved.Licenses[id] = true
	end
	for slot, id in tech.Equipped do
		if id ~= Catalog.Defaults[slot] then
			saved.Equipped[slot] = id
		end
	end
	return saved
end

-- The installed item in `slot`, from a decoded Tech or a player's mirrored attributes.
function Catalog.installed(slot: string, id: any): any
	local item = type(id) == "string" and Catalog.Items[id]
	return if item and item.Slot == slot then item else Catalog.Items[Catalog.Defaults[slot]]
end

-- Power the parts draw against the power supply's capacity (monitors have their own plug).
function Catalog.power(parts: { [string]: string }): (number, number)
	local draw = 0
	for _, slot in Catalog.Slots do
		local item = Catalog.installed(slot, parts[slot])
		if slot ~= "Monitor" and slot ~= "PSU" then
			draw += item.Watts or 0
		end
	end
	return draw, Catalog.installed("PSU", parts.PSU).Capacity
end

-- A rough benchmark: each slot's position in its range, summed and scaled to 0-1000.
function Catalog.score(parts: { [string]: string }): number
	local total, most = 0, 0
	for _, slot in Catalog.Slots do
		local order = Catalog.Order[slot]
		local index = table.find(order, Catalog.installed(slot, parts[slot]).Id or "") or 1
		total += (index - 1) / math.max(#order - 1, 1)
		most += 1
	end
	return math.floor(total / most * 1000 + 0.5)
end

-- What the office PC on the desk looks like (Map/OfficeDesk.dress) with these parts installed.
-- Parts is the full clean parts list Shared.PcModel builds from.
function Catalog.deskLook(equipped: { [string]: string })
	local parts = Catalog.sanitize(equipped)
	local cpu = Catalog.Items[parts.CPU]
	local cooler = Catalog.Items[parts.Cooling]
	local case = Catalog.Items[parts.Case]
	local monitor = Catalog.Items[parts.Monitor]
	local keys = {}
	for _, slot in Catalog.Slots do
		table.insert(keys, parts[slot])
	end
	return {
		Key = table.concat(keys, ","),
		Parts = parts,
		Body = case.Look.Body,
		Trim = case.Look.Trim,
		Front = case.Look.Front,
		Form = case.Look.Form,
		Glow = case.Look.Glow == true,
		Badge = cpu.Badge,
		Clock = cpu.Clock,
		Light = cooler.Light,
		Bezel = monitor.Bezel,
		Plate = monitor.Plate,
		Phosphor = monitor.Screen.Bright,
		Flat = monitor.Flat == true,
	}
end

-- Memory as the boot screen counts it.
function Catalog.memoryText(kilobytes: number): string
	if kilobytes >= 1048576 then
		return string.format("%d GB", kilobytes // 1048576)
	elseif kilobytes >= 1024 then
		return string.format("%d MB", kilobytes // 1024)
	end
	return string.format("%dK", kilobytes)
end

for id, item in Catalog.Items do
	item.Id = id
end

return Catalog
