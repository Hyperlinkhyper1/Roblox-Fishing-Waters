-- One permanent hire per role; prices are charged by the server once.
return {
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
