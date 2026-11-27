-- Group F (prep-242): AU24-25 driver-name search under a place filter; AU24-16 "Do nothing" tooltip.
local T = ...
local test = T.test
local ok = T.ok

local function world()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, { screenW = 1365, screenH = 768 })
	w:advance(15)
	local t0 = r.env.GetTime()
	r.W.drivers = r.W.drivers or {}
	r.W.drivers["gadget runner"] = { name = "Gadget Runner", key = "gadget runner", dest = "Undercity", price = 5000, state = "open", team = 3,
		service = "Gadget's Rides", heard = t0, queue = 0, ver = "2.3.0" }
	r.W.drivers["gz driver"] = { name = "Zed Pilot", key = "zed pilot", dest = "Gadgetzan", price = 4000, state = "open", team = 3,
		service = "Zed's Rides", heard = t0, queue = 0, ver = "2.3.0" }
	r.W.db.fold = { v = 1, pages = {}, narrow = true }
	r.W.UI.Toggle(true)
	w:advance(3)
	r.W.UI.Show("home")
	w:advance(1.5)
	return w, r
end

local function type_(w, r, text)
	local e = r.W.UI.state.screens.home.search.edit
	e:SetText(text)
	e:GetScript("OnEnterPressed")(e)
	w:advance(1)
	return T.list(r:visibleTexts())
end

test("p242 F AU24-25: a typed driver name that starts a place name lists that driver and the place's drivers", function()
	local w, r = world()
	local seen = type_(w, r, "Gadget")
	ok(seen:find("Gadget's Rides", 1, true), "the typed driver is listed. Visible: " .. seen:sub(1, 400))
	ok(seen:find("Zed's Rides", 1, true), "the drivers to the place still list. Visible: " .. seen:sub(1, 400))
	T.clean(w)
end)

-- guard: the place filter alone (text matching no name) still hides drivers to other places
test("p242 F AU24-25 guard: a place search still hides drivers to other places", function()
	local w, r = world()
	local seen = type_(w, r, "Gadgetzan")
	ok(seen:find("Zed's Rides", 1, true), "place driver listed. Visible: " .. seen:sub(1, 400))
	ok(not seen:find("Gadget's Rides", 1, true), "an unrelated driver to Undercity stays hidden. Visible: " .. seen:sub(1, 400))
	T.clean(w)
end)

local function leaversTip()
	local w = T.newWorld()
	local d = T.driver(w, T.BOB)
	T.settle(w)
	d.W.db.coach = true
	d.W.UI.Toggle(true)
	w:advance(3)
	d.W.UI.OpenSettings("driving")
	w:advance(1)
	local seg = d.W.UI.settings.controls["drive.leavers"]
	local out = {}
	for i = 1, 3 do
		local text = seg.buttons[i].wuberTip.text
		if type(text) == "function" then text = text(seg.buttons[i]) end
		if type(text) == "table" then text = table.concat(text, " ") end
		out[i] = text
	end
	T.clean(w)
	return out
end

test("p242 F AU24-16: 'Do nothing' says nothing happens, not that the rider is blocked", function()
	local tips = leaversTip()
	ok(tips[3] == "Nothing happens: the rider stays unblocked and you only get a toast.", "text: " .. tostring(tips[3]))
end)

-- guard: the two blocking choices keep their own words
test("p242 F AU24-16 guard: 'Block and tell them' and 'Block quietly' keep their tips", function()
	local tips = leaversTip()
	ok(tips[1]:find("gets one whisper", 1, true) and tips[1]:find("is blocked", 1, true), tips[1])
	ok(tips[2]:find("is blocked", 1, true) and not tips[2]:find("whisper", 1, true), tips[2])
end)
