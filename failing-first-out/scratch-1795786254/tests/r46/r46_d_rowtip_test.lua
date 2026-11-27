local T = ...
local test, eq, ok = T.test, T.eq, T.ok
local function key(n) return (n:lower():gsub("[%s%-]+", " ")) end

test("r46 AUD-124: a queue row tooltip says Click: options. where a click opens the menu", function()
	local w = T.newWorld()
	local a = T.driver(w, T.ANITA, { spot = "Ratchet" })
	local DAN, EVE = "Dan Miller", "Eve Stone"
	w:addBot(DAN, { spot = "Crossroads", acceptsInvites = true })
	w:addBot(EVE, { spot = "Ratchet", acceptsInvites = true })
	w:advance(15)
	local orig0 = a.env.UnitIsVisible
	a.env.UnitIsVisible = function(u) if a.env.UnitName(u) == "Dan" then return false end return orig0(u) end
	local W = a.W
	local DR = W.Drive
	DR.Shards = function() return 10 end
	ok(DR.SetOpen(true), "open")
	w:advance(3)
	w:botWhisper(DAN, a, "summon pls")
	w:advance(8)
	local dan = DR.customers[key(DAN)]
	ok(dan and (dan.state == "joined" or dan.state == "waiting" or dan.state == "invited"), "control: Dan is a rider waiting: " .. tostring(dan and dan.state))
	-- his friend Eve is in the group too (the driver invites her by hand)
	w:invite(a, EVE)
	w:advance(8)
	local D = W.Driver
	local eve = DR.customers[key(EVE)]
	ok(eve, "Eve has a row")
	eq(eve.helperOf, DAN, "control: Eve is the 'came with' row of Dan")
	local tip = D.RowTip(eve)
	ok(tip:find("Click", 1, true), "control: the tip has a Click line")
	-- what a click does: it opens the options menu, it never invites
	local invites = 0
	local orig = DR.Invite
	DR.Invite = function(...) invites = invites + 1 return orig(...) end
	D.RowClick(eve, "LeftButton")
	eq(invites, 0, "control: a left click does not invite her")
	ok(tip:find("Click: options.", 1, true), "helper row tip reads Click: options.")
	ok(not tip:find("Click: invite them.", 1, true), "no invite line for the helper row")
	-- a row in no actionable state: a click opens the menu too
	local tip2 = D.RowTip({ name = "Zed", key = "zed", state = "done" })
	ok(tip2:find("Click: options.", 1, true), "idle row tip reads Click: options.")
	ok(not tip2:find("nothing to do yet", 1, true), "no 'nothing to do yet'")
	T.clean(w)
end)

test("r46 HUNT-47: the PvP chip tip no longer mentions the zone being hostile or at war", function()
	local f = io.open("Wuber/UI/Driver/Draw.lua", "rb")
	local s = f:read("*a"); f:close()
	ok(not s:find("hostile or at war", 1, true), "old words gone")
	ok(s:find("showed near your summon spot. Riders booking you see a warning.", 1, true) or s:find("showed near your summon spot.\"", 1, true), "sentence reads on")
end)
