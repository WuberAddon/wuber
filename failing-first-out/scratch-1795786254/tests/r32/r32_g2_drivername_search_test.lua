local T = ...
local test, eq, ok = T.test, T.eq, T.ok
local H = T.H

-- Round 32, group G2: HUNT-14. Typing a driver's name in Where to? and pressing Enter listed the driver
-- but also warned "No place called <name>".

local function homeWorld()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, { screenW = 1365, screenH = 768 })
	w:advance(15)
	local t0 = r.env.GetTime()
	r.W.drivers = r.W.drivers or {}
	r.W.drivers["mia runner"] = { name = "Mia Runner", key = "mia runner", dest = "Undercity", price = 5000, state = "open", team = 3,
		service = "Mia's Rides", heard = t0, queue = 0, ver = "2.3.0" }
	r.W.db.fold = { v = 1, pages = {}, narrow = true }
	r.W.UI.Toggle(true)
	w:advance(3)
	r.W.UI.Show("home")
	w:advance(1.5)
	return w, r, r.W.UI.state.screens.home
end

local function toastTexts(r)
	local out = {}
	for _, t in ipairs(r:visibleTexts()) do out[#out + 1] = t end
	return table.concat(out, " | ")
end

test("r32 g2: Enter on a driver's name does not say there is no such place", function()
	local w, r, s = homeWorld()
	local e = s.search.edit
	e:SetText("Mia Runner")
	e:GetScript("OnEnterPressed")(e)
	w:advance(0.5)
	local txt = toastTexts(r)
	ok(not txt:find("No place called", 1, true), "no warning for a driver's name: " .. txt)
end)

test("r32 g2: Enter on a word that is no place and no driver still warns", function()
	local w, r, s = homeWorld()
	local e = s.search.edit
	e:SetText("Zzqxw")
	e:GetScript("OnEnterPressed")(e)
	w:advance(0.5)
	ok(toastTexts(r):find("No place called Zzqxw", 1, true), "still warns: " .. toastTexts(r))
end)
