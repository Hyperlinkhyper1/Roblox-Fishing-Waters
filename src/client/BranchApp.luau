-- BRANCHES: the office PC app (opened by OfficeComputer) for buying the company
-- branch you don't have yet. A fishing company can open a café in the city and
-- a café company can start fishing at the harbour (Shared.Branches). Purchases
-- go to BranchService, which only accepts them while you sit at your own PC.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RetroUI = require(script.Parent.RetroUI)
local Stocks = require(ReplicatedStorage.Shared.Stocks)

local BranchApp = {}
BranchApp.TITLE = "COMPANY BRANCHES"
BranchApp.SUBTITLE = "EXPAND YOUR BUSINESS"
BranchApp.READY = "BUY A BRANCH TO RUN BOTH A FISHING BUSINESS AND A CAFE."

local C = RetroUI.Colors
local px = UDim2.fromOffset
local CENTER = Enum.TextXAlignment.Center

export type App = { destroy: () -> () }

function BranchApp.mount(content: Frame, onStatus: (string) -> ()): App
	local alive = true
	local app = {}
	function app.destroy()
		alive = false
	end

	local folder = ReplicatedStorage:WaitForChild("Branches", 10)
	local remote = folder and folder:WaitForChild("Request", 10)
	if not alive then
		return app
	end
	if not remote or not remote:IsA("RemoteFunction") then
		RetroUI.text(content, "Offline", "BRANCH OFFICE IS OFFLINE.\nTRY AGAIN IN A MOMENT.", px(0, 0), UDim2.fromScale(1, 1), {
			AlignX = CENTER,
			Wrap = true,
			Size = 22,
		})
		return app
	end

	local busy = false
	local page: Frame? = nil

	local function call(action: string, value: any?)
		local ok, result = pcall(remote.InvokeServer, remote, action, value)
		if not ok or type(result) ~= "table" then
			return { Ok = false, Message = "THE BRANCH OFFICE DIDN'T ANSWER. TRY AGAIN." }
		end
		return result
	end

	local render: (any) -> ()
	render = function(result)
		if not alive then
			return
		end
		if page then
			page:Destroy()
		end
		local frame = RetroUI.frame(content, "Page", px(0, 0), UDim2.fromScale(1, 1))
		page = frame
		if result.Ok ~= true or type(result.Branches) ~= "table" then
			RetroUI.text(frame, "Error", string.upper(tostring(result.Message or "Could not load branches.")), px(24, 24), px(720, 80), {
				Wrap = true,
				Size = 20,
			})
			return
		end
		RetroUI.text(frame, "Heading", "YOUR COMPANY'S BRANCHES", px(24, 14), px(500, 30), {
			Font = RetroUI.Fonts.Title,
			Size = 16,
		})
		RetroUI.text(frame, "Cash", "CASH " .. Stocks.money(result.Cash or 0), px(470, 14), px(274, 30), {
			Size = 20,
			Color = C.Mid,
			AlignX = Enum.TextXAlignment.Right,
		})
		RetroUI.rule(frame, "HeadingRule", px(24, 48), UDim.new(0, 720), C.Mid)
		for index, branch in result.Branches do
			local y = 64 + (index - 1) * 200
			local card = RetroUI.frame(frame, "Branch" .. tostring(branch.Id), px(24, y), px(720, 184), {
				BackgroundTransparency = 0,
				BackgroundColor3 = C.Panel,
			})
			RetroUI.border(card, if branch.Owned then C.Mid else C.Bright, 2)
			RetroUI.text(card, "Title", string.upper(tostring(branch.Title)), px(18, 12), px(460, 30), {
				Font = RetroUI.Fonts.Title,
				Size = 16,
				Color = C.Hot,
			})
			RetroUI.text(card, "Blurb", string.upper(tostring(branch.Blurb)), px(18, 50), px(684, 64), {
				Wrap = true,
				Size = 18,
				Color = C.Mid,
				AlignY = Enum.TextYAlignment.Top,
			})
			if branch.Owned then
				RetroUI.text(card, "Owned", "[ OWNED ]", px(470, 12), px(232, 30), {
					Font = RetroUI.Fonts.Title,
					Size = 14,
					AlignX = Enum.TextXAlignment.Right,
				})
			else
				RetroUI.text(card, "Price", "PRICE " .. Stocks.money(branch.Price or 0), px(18, 128), px(320, 40), { Size = 22 })
				local affordable = (result.Cash or 0) >= (branch.Price or math.huge)
				local buy = RetroUI.button(card, "Buy", "BUY BRANCH", px(482, 128), px(220, 40), function()
					if busy then
						return
					end
					busy = true
					onStatus("OPENING THE " .. string.upper(tostring(branch.Title)) .. "...")
					local response = call("Buy", branch.Id)
					busy = false
					if not alive then
						return
					end
					onStatus(string.upper(tostring(response.Message or (if response.Ok then "DONE." else "THAT DIDN'T WORK."))))
					if response.Ok then
						render(response)
					end
				end, { Font = RetroUI.Fonts.Title, Size = 14 })
				buy:setEnabled(affordable)
				if not affordable then
					RetroUI.text(card, "Short", "NOT ENOUGH CASH YET", px(340, 128), px(140, 40), {
						Size = 14,
						Color = C.Dim,
						Wrap = true,
					})
				end
			end
		end
	end

	render(call("State"))
	return app
end

return BranchApp
