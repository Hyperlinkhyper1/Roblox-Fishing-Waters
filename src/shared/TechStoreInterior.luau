-- Merchandise only: parts, complete PC setups, price tags and boxed stock. Bare racks and
-- store furniture live in TechStoreFixtures and remain visible when this content unloads.
local Catalog = require(script.Parent.TechCatalog)
local Layout = require(script.Parent.TechStoreLayout)
local PcModel = require(script.Parent.PcModel)
local Interior = {}
local rgb, M = Color3.fromRGB, Enum.Material
local WHITE, RED, NAVY = rgb(234, 237, 240), rgb(204, 22, 34), rgb(20, 36, 82)
local DARK, STEEL, GOLD = rgb(28, 31, 38), rgb(156, 166, 178), rgb(217, 174, 75)
local ACCENTS = { CPU = rgb(54, 127, 235), GPU = rgb(106, 210, 80), RAM = rgb(206, 92, 231),
	Storage = rgb(250, 162, 55), Cooling = rgb(53, 210, 224), Case = rgb(239, 77, 110), Monitor = rgb(94, 161, 255),
	Motherboard = rgb(70, 190, 150), PSU = rgb(240, 206, 70) }
-- Sample sizes on the shelves: real Shared.PcModel parts, scaled up so they read from the aisle.
local DISPLAY_SCALE = { CPU = 5, Motherboard = 1.9, RAM = 3.6, GPU = 2.3, Storage = 3.4, Cooling = 3, PSU = 2.6, Case = 1.45, Monitor = 2 }

function Interior.build(parent: Instance, base: CFrame, onProduct, checkpoint)
	local function part(name, size, frame, color, material, shape)
		local p = Instance.new("Part")
		p.Name, p.Size, p.CFrame = name, size, base * frame
		p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery = true, false, false, false
		p.CastShadow = false
		p.Color, p.Material = color, material or M.SmoothPlastic
		p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		if shape then p.Shape = shape end
		p.Parent = parent
		if checkpoint then checkpoint() end
		return p
	end
	-- Part factory for Shared.PcModel: the same inert, shadowless detail as `part`, already in world space.
	local function storeMake(folder, name, size, cframe, color, material, shape)
		local p = Instance.new("Part")
		p.Name, p.Size, p.CFrame = name, size, cframe
		p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery = true, false, false, false
		p.CastShadow = false
		p.Color, p.Material = color, material or M.SmoothPlastic
		p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		if shape then p.Shape = shape end
		p.Parent = folder
		if checkpoint then checkpoint() end
		return p
	end
	local function sign(board, text, face, tint)
		local gui = Instance.new("SurfaceGui")
		gui.Name, gui.Face = "ProductSign", face or Enum.NormalId.Back
		gui.SizingMode, gui.PixelsPerStud = Enum.SurfaceGuiSizingMode.PixelsPerStud, 55
		gui.MaxDistance, gui.LightInfluence = if board.Size.X >= 30 then 300 else 75, 0.1
		local label = Instance.new("TextLabel")
		label.Size, label.BackgroundTransparency = UDim2.fromScale(1, 1), 1
		label.Text, label.TextScaled, label.TextWrapped = text, true, true
		label.Font, label.TextColor3 = Enum.Font.GothamBold, tint or WHITE
		local padding = Instance.new("UIPadding")
		padding.PaddingLeft, padding.PaddingRight = UDim.new(0.04, 0), UDim.new(0.04, 0)
		padding.PaddingTop, padding.PaddingBottom = UDim.new(0.06, 0), UDim.new(0.06, 0)
		padding.Parent, label.Parent, gui.Parent = label, gui, board
	end
	local function badge(text, frame, w, h, color)
		local board = part("DepartmentSign", Vector3.new(w, h, 0.12), frame, color or NAVY)
		sign(board, text)
		return board
	end
	local function localPart(frame, name, x, y, z, sx, sy, sz, color, material, shape, rotation)
		return part(name, Vector3.new(sx, sy, sz), frame * CFrame.new(x, y, z) * (rotation or CFrame.identity), color, material, shape)
	end


	for _, entry in Layout.Displays do
		local item = Catalog.product(entry.Kind, entry.Id)
		local frame, slot = entry.Frame, item.Slot
		local accent = item.Accent or ACCENTS[slot] or GOLD
		local function p(name, x, y, z, sx, sy, sz, color, material, shape, rotation)
			return localPart(frame, name, x, y, z, sx, sy, sz, color, material, shape, rotation)
		end
		if entry.Kind == "Prebuilt" then
			local parts = item.Parts
			local look = Catalog.Items[parts.Case].Look
			-- The real build, scaled up: glass cases show the board, card, memory and loop inside.
			local desktop = look.Form == "Desktop"
			local pcFrame = if desktop then CFrame.new(1.4, 0, -0.9) else CFrame.new(-3.4, 0, -0.3)
			PcModel.build(parent, base * frame * pcFrame, parts, { Name = "PrebuiltPC", Scale = 1.6, Make = storeMake })
			local monitorFrame = if desktop
				then pcFrame * CFrame.new(0, PcModel.size(parts.Case).Y * 1.6, 0.8 * 1.6)
				else CFrame.new(1.4, 0, 0.5)
			PcModel.buildMonitor(parent, base * frame * monitorFrame, parts.Monitor, { Name = "PrebuiltMonitor", Scale = if desktop then 1.6 else 1.9, Make = storeMake })
			p("PrebuiltDeskMat", 1.5, 0.08, 2.1, 6, 0.07, 2.4, accent:Lerp(DARK, 0.75), M.Rubber)
			p("PrebuiltKeyboard", 1, 0.2, 2.1, 3.7, 0.18, 1.2, DARK)
			for row = 0, 3 do
				for column = 0, 7 do p("PrebuiltKey", -0.5 + column * 0.4, 0.31, 1.67 + row * 0.27, 0.3, 0.05, 0.2, WHITE) end
			end
			p("PrebuiltMouse", 4.1, 0.25, 2.1, 0.7, 0.3, 1.1, look.Body)
			badge("COMPLETE PC / " .. item.Spec, frame * CFrame.new(0, 0.45, 3.2), 12, 0.7, NAVY)
		elseif entry.Kind == "Item" then
			-- Monitors stand on a deeper deck: bring the tube forward so it stays on it.
			local offset = if slot == "Monitor" then CFrame.new(0, 0, 1.1) else CFrame.identity
			PcModel.component(parent, base * frame * offset, entry.Id, { Name = "Sample", Scale = DISPLAY_SCALE[slot], Make = storeMake })
		else
			p("SoftwareBox", 0, 1.3, 0, 3.2, 2.6, 0.65, NAVY)
			p("LicenseGoldStripe", -1.2, 1.3, 0.34, 0.25, 2.5, 0.03, GOLD, M.Metal)
			badge("HARBOUR\n" .. string.upper(item.App) .. "\nLICENSE", frame * CFrame.new(0.2, 1.35, 0.35), 2.2, 2, NAVY)
		end
		-- Sample plinth, spec card and barcode/price strip are tied to the actual catalog id.
		p("SamplePlinth", 0, 0.015, 0, if entry.Kind == "Prebuilt" then 12 elseif slot == "Monitor" then 7 else 4, 0.06, 2.9, DARK)
		local price = if item.Price == 0 then "STARTER / INCLUDED" else "$" .. tostring(item.Price)
		local tag = part("PriceTag", Vector3.new(12, 1.15, 0.09), entry.PromptFrame, NAVY)
		sign(tag, item.Name .. "\n" .. item.Spec .. "\n" .. price .. "  /  HOLD E" .. (if entry.Kind == "Prebuilt" then " / OWNED PARTS CREDITED" else ""))
		-- A single local prompt at the shelf edge, rather than one on every decorative part.
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name, prompt.KeyboardKeyCode, prompt.GamepadKeyCode = Layout.PromptName, Enum.KeyCode.E, Enum.KeyCode.ButtonX
		prompt.HoldDuration, prompt.MaxActivationDistance = Layout.HoldDuration, Layout.BuyDistance
		prompt.RequiresLineOfSight = false
		prompt.Style = Enum.ProximityPromptStyle.Default
		prompt.UIOffset = Vector2.new(0, -70)
		prompt.Enabled = true
		prompt.Exclusivity = Enum.ProximityPromptExclusivity.OnePerButton
		prompt.ObjectText, prompt.ActionText = item.Name, "Buy " .. price
		prompt:SetAttribute("ProductKind", entry.Kind)
		prompt:SetAttribute("ProductId", entry.Id)
		prompt.Parent = tag
		if onProduct then onProduct(prompt, entry) end
	end

	-- Stock detail comes last so the actual shopping displays become usable sooner.
	for _, rack in Layout.Racks do
		local accent=ACCENTS[rack.Slot]
		for _, side in {-1,1} do
			local turn=CFrame.Angles(0,if side==1 then 0 else math.pi,0)
			local boxes = math.floor((rack.Width / 2 - 3) / 9)
			for k=-boxes,boxes do
				local f=rack.Frame*CFrame.new(k*9,7.32,side*1.7)*turn
				localPart(f,"StockBox",0,0.9,0,5.6,1.8,1.6,NAVY)
				localPart(f,"PackageStripe",-1.9,0.9,0.81,0.22,1.7,0.025,accent)
				badge(string.upper(rack.Slot).."\nMICRO HARBOUR",f*CFrame.new(0.4,0.9,0.82),3.5,1.2)
			end
			local cartons = math.floor((rack.Width / 2 - 4) / 12)
			for k=-cartons,cartons do
				local f=rack.Frame*CFrame.new(k*12,11.32,side*1.7)*turn
				localPart(f,"BulkStockCarton",0,0.9,0,8,1.8,2,rgb(156,133,100),M.SmoothPlastic)
				localPart(f,"CartonTape",0,0.9,1.01,0.3,1.7,0.03,WHITE)
			end
		end
	end

end

return Interior
