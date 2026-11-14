-- Company branches. A save starts as one type of company (chosen when it is
-- created) and can buy the other branch later on the office PC's BRANCHES app.
-- Profiles saved before branches existed have no Branches field: they are
-- fishing companies, so every existing player stays on the fishing branch.
local Branches = {}

Branches.ORDER = { "Fishing", "Cafe" }
Branches.DEFAULT = "Fishing"

Branches.Info = {
	Fishing = {
		Name = "Fishing",
		Title = "Fishing branch",
		-- Paid by a café company that wants to fish as well.
		Price = 5000,
		Blurb = "A dock and fish shop at Gullhaven harbour. Catch fish and sell them.",
	},
	Cafe = {
		Name = "Café",
		Title = "Café branch",
		-- Paid by a fishing company that wants to open a café as well.
		Price = 7500,
		Blurb = "A one-floor café in the city. Brew coffee for customers for cash and XP.",
	},
}

function Branches.valid(id: any): boolean
	return type(id) == "string" and Branches.Info[id] ~= nil
end

-- Validates a saved Branches table. nil means a legacy fishing company.
function Branches.normalize(raw: any): { [string]: boolean }
	if raw == nil then
		return { Fishing = true }
	end
	assert(type(raw) == "table", "Invalid company branches")
	local result, any = {}, false
	for id, owned in raw do
		assert(type(id) == "string" and type(owned) == "boolean", "Invalid company branch")
		-- Branches removed from the game are dropped rather than failing the save.
		if owned and Branches.Info[id] then
			result[id] = true
			any = true
		end
	end
	if not any then
		result.Fishing = true
	end
	return result
end

function Branches.starting(kind: any): { [string]: boolean }
	assert(kind == nil or Branches.valid(kind), "Choose a fishing company or a café.")
	return { [kind or Branches.DEFAULT] = true }
end

function Branches.has(profile: any, id: string): boolean
	local raw = if type(profile) == "table" then profile.Branches else nil
	local ok, branches = pcall(Branches.normalize, raw)
	return ok and branches[id] == true
end

-- "Fishing", "Café" or "Fishing + Café", in ORDER.
function Branches.label(raw: any): string
	local ok, branches = pcall(Branches.normalize, raw)
	if not ok then
		branches = { Fishing = true }
	end
	local names = {}
	for _, id in Branches.ORDER do
		if branches[id] then
			table.insert(names, Branches.Info[id].Name)
		end
	end
	return table.concat(names, " + ")
end

-- Pure purchase rule, run inside the profile transaction.
function Branches.buy(profile: any, id: any)
	assert(Branches.valid(id), "Unknown branch.")
	local branches = Branches.normalize(profile.Branches)
	assert(not branches[id], "Your company already has the " .. Branches.Info[id].Title .. ".")
	local price = Branches.Info[id].Price
	assert(profile.Cash >= price, "You need " .. tostring(price) .. " cash for the " .. Branches.Info[id].Title .. ".")
	profile.Cash -= price
	branches[id] = true
	profile.Branches = branches
	return profile
end

return Branches
