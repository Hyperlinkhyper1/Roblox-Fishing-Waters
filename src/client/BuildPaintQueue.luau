-- Paint stays responsive while the network saves. One writer batches/coalesces
-- clicks, and later commands can wait for a complete paint stroke to commit.
local Queue = {}
function Queue.new(options)
	local self = { Outstanding = {}, Waiting = {}, Order = {}, Running = false, Serial = 0, Listeners = {} }
	local lastSend = -math.huge
	local function report()
		if options.Changed then options.Changed(self.Outstanding) end
	end
	local function run()
		if self.Running then return end
		self.Running = true
		task.spawn(function()
			while #self.Order > 0 do
				local pause = (options.Interval or 0.1) - (os.clock() - lastSend)
				if pause > 0 then task.wait(pause) end
				local batch, serials = {}, {}
				while #self.Order > 0 and #batch < 64 do
					local id = table.remove(self.Order, 1)
					local record = self.Waiting[id]
					self.Waiting[id] = nil
					if record then
						table.insert(batch, record.Patch)
						serials[id] = record.Serial
					end
				end
				if #batch > 0 then
					local ok, result
					for attempt = 1, 6 do
						lastSend = os.clock()
						ok, result = pcall(options.Send, batch)
						local delay = ok and type(result) == "table" and result.RetryAfter
						if ok and type(result) == "table" and result.Ok == false and type(delay) == "number" and delay == delay and delay >= 0.05 and delay <= 1 and attempt < 6 then
							task.wait(delay)
						else break end
					end
					if not ok then result = { Ok = false, Message = "Painting could not be saved. Please try again." } end
					for id, serial in serials do
						local latest = self.Outstanding[id]
						if latest and latest.Serial == serial then self.Outstanding[id] = nil end
					end
					if options.Result then options.Result(result, self.Outstanding) end
					report()
				end
			end
			self.Running = false
			local listeners = self.Listeners
			self.Listeners = {}
			for _, callback in listeners do callback() end
		end)
	end
	function self:paint(patch)
		self.Serial += 1
		local record = { Patch = { Id = patch.Id, Material = patch.Material, Color = table.clone(patch.Color) }, Serial = self.Serial }
		if not self.Waiting[patch.Id] then table.insert(self.Order, patch.Id) end
		self.Waiting[patch.Id], self.Outstanding[patch.Id] = record, record
		report()
		run()
	end
	function self:drain(callback)
		if not self.Running and #self.Order == 0 then callback()
		else table.insert(self.Listeners, callback); run() end
	end
	function self:busy()
		return self.Running or #self.Order > 0
	end
	return self
end
return Queue
