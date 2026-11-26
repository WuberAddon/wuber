-- Round 33 group p2: shrink first, wrap only when the text would still be cut (HUNT-118, HUNT-100, HUNT-98 follow-up).
local T = ...
local H, test, eq, ok = T.H, T.test, T.eq, T.ok

local function find(f, text)
	for _, rg in ipairs({ f:GetRegions() }) do
		if rg.GetText and rg:GetText() == text then return rg end
	end
	for _, ch in ipairs({ f:GetChildren() }) do
		local got = find(ch, text)
		if got then return got end
	end
end

local function visibleText(r, text)
	for _, t in ipairs(r:visibleTexts()) do
		if t == text then return true end
	end
	return false
end

test("r33 p2: folded Confirm: an ordinary grey line wraps to two lines (caption is the floor), the row grows and the About block stays", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, { screenW = 1365, screenH = 768 })
	w:advance(15)
	local W = r.W
	W.drivers = W.drivers or {}
	W.drivers["mia runner"] = { name = "Mia Runner", key = "mia runner", dest = "Thunder Bluff", price = 5000, state = "open",
		team = 1, service = "Mia's Rides", heard = r.env.GetTime() }
	W.UI.Show("confirm", "mia runner")
	w:advance(2)
	local fs
	for _, t in ipairs(r:visibleTexts()) do
		if t:find("Thunder Bluff", 1, true) and t:find("Bring", 1, true) then fs = find(r.env.UIParent, t) end
	end
	ok(fs, "the grey line is there")
	-- (design 3) this line is already the smallest size (caption 11): there is nothing to shrink to, so a line wider than
	-- the room wraps to a second line, every word kept, and the row grows by that line (it used to shrink to 9 and stay 70)
	local H0 = fs:GetParent():GetHeight()
	ok(fs.wuberWrapped, "two lines, nothing cut: " .. tostring(fs.wuberText) .. " at " .. tostring(fs.wuberPx))
	ok(H0 > 70 and H0 <= 70 + 16, "the row grew by the second line: " .. tostring(H0))
	ok(visibleText(r, "Bring friends to click the portal"), "the About block is kept: " .. table.concat(r:visibleTexts(), "; "))
	T.clean(w)
end)

test("r33 p2: the dial at the folded width keeps (net 27s) on the summon side", function()
	local w = T.newWorld()
	local r = T.rider(w)
	local W = r.W
	local Mod = W.Mod("UI.Rider.Booking")
	local d = { dest = "Undercity", price = 5000, queue = 3 }
	W.TravelSaved = function() return 540 end
	W.FlightCost = function() return 2300, 1 end
	local dial = Mod.Dial(r.env.UIParent, 324, 88)
	dial:SetPoint("CENTER", r.env.UIParent, "CENTER")
	dial:Set(Mod.DialInfo(d, 5000))
	-- (design 1) the amounts are gold inside the sentence: the words are the same with the colour codes taken off
	local plain = dial.summonText.wuberText:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
	ok(plain:find("(net 27s)", 1, true), "the net stays: " .. tostring(dial.summonText.wuberText))
	ok(not dial.summonText.wuberWrapped, "one line")
	ok(not dial.flyText.wuberWrapped, "the fly side shrinks to one line: " .. tostring(dial.flyText.wuberText) .. " at " .. tostring(dial.flyText.wuberPx))
	eq(dial:GetHeight(), 88, "the dial keeps its height")
	T.clean(w)
end)

test("r33 p2: Home's own chip with an ordinary place and price wraps to two lines and grows", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, { screenW = 1365, screenH = 768 })
	w:advance(15)
	local W = r.W
	W.drivers = { ["mia runner"] = { name = "Mia Runner", key = "mia runner", dest = "Undercity", price = 5000, state = "open", team = 3,
		service = "Mia's Rides", heard = r.env.GetTime(), queue = 0, ver = "2.3.0" } }
	W.db.fold = { v = 1, pages = {}, narrow = true }
	W.Bounty = { Mine = function() return nil end, Demand = function() return {} end }
	W.db.rides = {}
	W.DriverBeacon = function() return { dest = "Orgrimmar", destShown = "Orgrimmar", price = 5000, state = "open",
		service = "A", team = 1, seats = 0, queue = 0 } end
	W.UI.Toggle(true)
	w:advance(3)
	W.UI.Show("home")
	w:advance(1.5)
	local chip = W.UI.state.screens.home.ownChip
	ok(H.visible(chip), "the chip is up")
	-- (design 3) at the smallest size the line is still wider than the chip: it wraps to two lines and the chip grows
	-- (it used to shrink to 10 and stay 28)
	ok(chip.text.wuberWrapped, "two lines: " .. tostring(chip.text.wuberText))
	eq(chip:GetHeight(), 44, "the chip grew: " .. tostring(chip:GetHeight()))
	T.clean(w)
end)
