-- Shared shop upgrade prices and customer arrival settings.
local Upgrades = {}

Upgrades.SocialMediaAdvertisement = {
	Name = "Social Media Advertisement",
	Description = "You now spawn 2 customers at a time.",
	Price = 1000,
}

function Upgrades.hasAdvertisement(data)
	return (data.Upgrades.SocialMediaAdvertisement or 0) >= 1
end

return Upgrades
