-- Shared presentation rules keep included/installed displays discoverable with an E prompt.
local Catalog = require(script.Parent.TechCatalog)
local Prompts = {}

function Prompts.update(prompt, entry, state, pending, money)
	local item = Catalog.product(entry.Kind, entry.Id)
	local owned = state and (if entry.Kind == "License" then state.Licenses[entry.Id]
		elseif entry.Kind == "Prebuilt" then Catalog.prebuiltPrice(state, entry.Id) == 0
		else Catalog.owns(state, entry.Id))
	local installed = state and (if entry.Kind == "Prebuilt" then Catalog.prebuiltInstalled(state, entry.Id)
		else item.Slot and state.Equipped[item.Slot] == entry.Id)
	local price = if state and entry.Kind == "Prebuilt" then Catalog.prebuiltPrice(state, entry.Id) else item.Price
	-- A disabled installed prompt made included starter products look broken. Keep the
	-- normal keyboard/touch/controller affordance; only an in-flight request disables it.
	prompt.Enabled = not pending
	prompt.ActionText = if entry.Kind == "Prebuilt" then (if owned then "Take home (parts owned)" else "Buy " .. money(price) .. " & carry")
		elseif installed and item.Price == 0 then "Installed / included"
		elseif installed then "Already installed"
		elseif owned and entry.Kind == "License" then "Already licensed"
		elseif owned then "Owned / fit at workbench"
		else "Buy " .. money(price)
end

return Prompts
