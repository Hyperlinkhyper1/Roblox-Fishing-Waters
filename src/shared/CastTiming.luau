-- Shared timing keeps the displayed power and the server's luck award in sync.
local CastTiming = {}

CastTiming.ChargeSeconds = 1
CastTiming.PerfectThreshold = 0.94
CastTiming.PerfectLuck = 0.15
CastTiming.MaxChargeSeconds = 30
CastTiming.NetworkTolerance = 0.2

function CastTiming.strength(elapsed: number): number
	local cycle = math.max(0, elapsed) / CastTiming.ChargeSeconds % 2
	return 1 - math.abs(1 - cycle)
end

function CastTiming.isPerfect(elapsed: number): boolean
	return CastTiming.strength(elapsed) + 1e-6 >= CastTiming.PerfectThreshold
end

-- The client supplies its release duration, never a trusted perfect/luck flag.
-- Compare it with the charge observed by the server, allowing network jitter.
function CastTiming.validRelease(elapsed: any, observed: number): boolean
	return type(elapsed) == "number"
		and elapsed == elapsed
		and elapsed >= 0
		and elapsed <= CastTiming.MaxChargeSeconds
		and observed >= 0
		and observed <= CastTiming.MaxChargeSeconds
		and math.abs(elapsed - observed) <= CastTiming.NetworkTolerance
end

return CastTiming
