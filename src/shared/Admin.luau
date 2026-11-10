-- The one place admin accounts are listed. Every admin command and admin-only
-- server function checks a player through Admin.isAdmin.
local Admin = {}

Admin.UserIds = table.freeze({
	[2541746813] = true, -- hyperlinkhyper
})

function Admin.isAdmin(player: Player?): boolean
	return player ~= nil and Admin.UserIds[player.UserId] == true
end

return table.freeze(Admin)
