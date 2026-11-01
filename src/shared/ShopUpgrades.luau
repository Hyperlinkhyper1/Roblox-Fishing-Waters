-- Shared shop upgrade prices and customer arrival settings.
local Upgrades = {}

Upgrades.SocialMediaAdvertisement = {
	Name = "Social Media Advertisement",
	Description = "You now spawn 2 customers at a time.",
	Price = 1000,
}

Upgrades.Baskets = {
	Name = "Baskets",
	Description = "Customers can buy up to 3 items at a time.",
	Price = 2000,
}

function Upgrades.hasBaskets(data)
	return (data.Upgrades.Baskets or 0) >= 1
end

function Upgrades.hasAdvertisement(data)
	return (data.Upgrades.SocialMediaAdvertisement or 0) >= 1
end

return Upgrades
