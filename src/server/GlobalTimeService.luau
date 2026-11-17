-- A durable, monotonically increasing offset keeps every server on the same calendar.
-- Messaging makes changes prompt; periodic reads repair missed messages and new servers.
local DataStoreService = game:GetService("DataStoreService")
local MessagingService = game:GetService("MessagingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local DayNight = require(ReplicatedStorage.Shared.DayNight)

local Service = {}
local started = false
local store
local subscription
local offset = 0
local topic = "FishingWatersGlobalTime_v1"
local key = "CalendarOffset"

local function valid(value)
	return type(value) == "number" and value == value and value >= 0 and value < math.huge
end

local function observe(value)
	if valid(value) and value > offset then
		-- A local /set date preview may have shifted the hour. Round its offset up
		-- to a whole day so this jump still moves forward and reaches the global hour.
		local localOffset = workspace:GetAttribute("CalendarOffset")
		if type(localOffset) == "number" and localOffset == localOffset and math.abs(localOffset) < math.huge then
			local day = 24 * DayNight.SECONDS_PER_HOUR
			workspace:SetAttribute("CalendarOffset", math.ceil(localOffset / day) * day)
		end
		offset = value
		workspace:SetAttribute("GlobalCalendarOffset", offset)
	end
end

local function getStore()
	store = store or DataStoreService:GetDataStore("FishingWatersGlobalTime_v1")
	return store
end

local function nextOffset(current, targetHour)
	local now = workspace:GetServerTimeNow()
	local day = 24 * DayNight.SECONDS_PER_HOUR
	local elapsed = now - DayNight.EPOCH + current
	local jump = (targetHour * DayNight.SECONDS_PER_HOUR - elapsed % day) % day
	if jump == 0 then
		jump = day
	end
	return current + jump
end

function Service.advance(target)
	if target ~= "day" and target ~= "night" then
		return false, "invalid time"
	end
	local hour = if target == "day" then 12 else 0
	if RunService:IsStudio() then
		observe(nextOffset(offset, hour))
		return true, "studio"
	end
	-- UpdateAsync serializes concurrent commands across servers. Compute the jump inside
	-- its callback so a retry always advances from the latest committed offset.
	local ok, result = pcall(function()
		return getStore():UpdateAsync(key, function(old)
			return nextOffset(if valid(old) then old else 0, hour)
		end)
	end)
	if not ok then
		return false, result
	end
	observe(result)
	local sent, problem = pcall(MessagingService.PublishAsync, MessagingService, topic, result)
	if not sent then
		warn("[GlobalTime] Broadcast failed; servers will catch up on their next sync: " .. tostring(problem))
	end
	return true, sent
end

function Service.start()
	if started then return end
	started = true
	if RunService:IsStudio() then return end
	-- Read once before clock-dependent services start. A failed read is retried below.
	local loaded, initial = pcall(function() return getStore():GetAsync(key) end)
	if loaded then
		observe(initial)
	else
		warn("[GlobalTime] Initial sync will retry: " .. tostring(initial))
	end
	task.spawn(function()
		while true do
			if not subscription then
				local ok, result = pcall(MessagingService.SubscribeAsync, MessagingService, topic, function(message)
					observe(message.Data)
				end)
				if ok then
					subscription = result
				else
					warn("[GlobalTime] Subscription will retry: " .. tostring(result))
				end
			end
			local ok, result = pcall(function() return getStore():GetAsync(key) end)
			if ok then
				observe(result)
			else
				warn("[GlobalTime] Sync will retry: " .. tostring(result))
			end
			task.wait(30)
		end
	end)
end

return Service
