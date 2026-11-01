-- Server-side catch context from the validated location and catch owner.
local Calendar = require(script.Parent.Calendar)
local Halloween = require(script.Parent.Halloween)
local Seasons = require(script.Parent.Seasons)
local CatchConditions = require(script.Parent.CatchConditions)
local Weather = require(script.Parent.Weather)
local MutationContext = {}
function MutationContext.at(position: Vector3, player: Player)
 local context = Weather.mutationContext(position) or {}
 local date = Calendar.now()
 context.season = Seasons.current()
 context.halloween = Halloween.partyActive(date)
 context.volcanic = CatchConditions.area(position) == "volcanic"
 context.supercell = Weather.supercellCover(position, Weather.supercell()) >= Weather.SupercellThreshold
 context.level = player:GetAttribute("Level") or 0
 return context
end
return MutationContext
