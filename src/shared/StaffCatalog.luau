-- One permanent hire per role; prices are charged by the server once.
local Staff = {
	Order = { "Seller", "Porter" },
	Roles = {
		Seller = {
			Name = "Seller",
			Price = 250,
			Description = "Serves customers at your register and collects payment automatically.",
		},
		Porter = {
			Name = "Porter",
			Price = 400,
			Description = "Carries fish from your boat to the freezer, one at a time. Park at your home dock to unload.",
		},
	},
}

-- Keep the shop NPC and its hiring preview identical. Staff currently use the
-- default R15 appearance; future uniforms belong here, rather than in either UI.
function Staff.description(role: string): HumanoidDescription
	assert(Staff.Roles[role], "Unknown staff role")
	return Instance.new("HumanoidDescription")
end

return Staff
