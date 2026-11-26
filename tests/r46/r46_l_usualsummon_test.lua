-- Round 46 group L: FEAT-01 (b), the rider's side of the average summon time says it. A driver who is open with
-- nobody waiting and whose advert carries their average (D field 21, d.avgSummon) gets "usually about 45 sec" at the
-- end of the booking card's grey driver line and "Usually about 45 sec" on the small right-hand line of their card in
-- the rider's list. Every other driver: nothing new (unknown numbers are hidden).
local T = ...
local test, eq, ok = T.test, T.eq, T.ok

local function find(f, text)
	for _, rg in ipairs({ f:GetRegions() }) do
		if rg.GetText and rg:GetText() == text and (not rg.IsVisible or rg:IsVisible()) then return rg end
	end
	for _, ch in ipairs({ f:GetChildren() }) do
		local got = find(ch, text)
		if got then return got end
	end
end

-- (design 2) a driver is a row now: the state words end the row's second line ("To Ratchet · No helpers · Usually about 45 sec")
local function inRow(f, tail)
	for _, rg in ipairs({ f:GetRegions() }) do
		local t = rg.GetText and rg:GetText()
		if type(t) == "string" and t:find("^To Ratchet") and t:sub(-#tail) == tail and (not rg.IsVisible or rg:IsVisible()) then return rg end
	end
	for _, ch in ipairs({ f:GetChildren() }) do
		local got = inRow(ch, tail)
		if got then return got end
	end
end

-- any shown text with "sually about" in it (either place, either case)
local function anyUsual(f, out)
	out = out or {}
	for _, rg in ipairs({ f:GetRegions() }) do
		local t = rg.GetText and rg:GetText()
		if type(t) == "string" and t:find("sually about", 1, true) and (not rg.IsVisible or rg:IsVisible()) then out[#out + 1] = t end
	end
	for _, ch in ipairs({ f:GetChildren() }) do anyUsual(ch, out) end
	return out
end

local function world(fields)
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, { screenW = 1365, screenH = 768 })
	w:advance(15)
	local W = r.W
	W.drivers = W.drivers or {}
	local d = { name = "Mia Runner", key = "mia runner", dest = "Ratchet", price = 5000, state = "open",
		team = 3, service = "Mia's Rides", heard = r.env.GetTime(), queue = 0 }
	for k, v in pairs(fields or {}) do if v == false then d[k] = nil else d[k] = v end end
	W.drivers["mia runner"] = d
	return w, r, W
end

local function confirm(fields)
	local w, r, W = world(fields)
	W.UI.Show("confirm", "mia runner")
	w:advance(2)
	return w, r, W
end

local function home(fields)
	local w, r, W = world(fields)
	W.UI.Show("home")
	if W.UI.RefreshNow then W.UI.RefreshNow() end
	w:advance(2)
	return w, r, W
end

test("r46 l: FEAT-01 b: the booking card's grey line ends with the driver's usual summon in seconds", function()
	local w, r = confirm({ avgSummon = 45 })
	ok(find(r.env.UIParent, "Ratchet · Crew ready · Open · usually about 45 sec"), "the grey line ends usually about 45 sec")
	T.clean(w)
end)

test("r46 l: FEAT-01 b: a minute or more is said in minutes, the Fly or summon card's rounding", function()
	local w, r = confirm({ avgSummon = 120 })
	ok(find(r.env.UIParent, "Ratchet · Crew ready · Open · usually about 2 min"), "120 s: usually about 2 min")
	T.clean(w)
	w, r = confirm({ avgSummon = 59 })
	ok(find(r.env.UIParent, "Ratchet · Crew ready · Open · usually about 59 sec"), "59 s: in seconds")
	T.clean(w)
	w, r = confirm({ avgSummon = 900 })
	ok(find(r.env.UIParent, "Ratchet · Crew ready · Open · usually about 15 min"), "900 s: 15 min")
	T.clean(w)
end)

test("r46 l: FEAT-01 b: no average, someone waiting, busy or paused: the booking card's line is as before", function()
	for _, case in ipairs({
		{ {}, "Ratchet · Crew ready · Open", "no average (an older driver, or under 3 rides)" },
		{ { avgSummon = 45, queue = 2 }, "Ratchet · Crew ready · Open", "open but 2 waiting" },
		{ { avgSummon = 45, queue = false }, "Ratchet · Crew ready · Open", "open, queue not sent" },
		{ { avgSummon = 45, state = "busy", queue = 1 }, "Ratchet · Crew ready · Busy · 1 waiting", "busy" },
		{ { avgSummon = 5 }, "Ratchet · Crew ready · Open", "an average out of range is not a number to show" },
	}) do
		local w, r = confirm(case[1])
		ok(find(r.env.UIParent, case[2]), case[3] .. ": the old line")
		eq(#anyUsual(r.env.UIParent), 0, case[3] .. ": nothing says usually")
		T.clean(w)
	end
end)

test("r46 l: FEAT-01 b: the longest place, two friends to bring and the usual time: the line wraps, whole, and the card grows", function()
	local w, r = confirm({ avgSummon = 59, dest = "Feathermoon Stronghold", team = 1 })
	local fs = find(r.env.UIParent, "Feathermoon Stronghold · Bring 2 friends · Open · usually about 59 sec")
	ok(fs, "the whole line is there")
	ok(fs and fs.wuberWrapped, "it wraps to a second line")
	ok(fs and not (fs.IsTruncated and fs:IsTruncated()), "never cut")
	eq(fs and fs:GetParent():GetHeight(), 83, "the driver card is a line taller")
	T.clean(w)
end)

test("r46 l: FEAT-01 b: an open driver's card in the list says Usually about 45 sec on its small right-hand line", function()
	local w, r = home({ avgSummon = 45 })
	ok(inRow(r.env.UIParent, " · Usually about 45 sec"), "the row's second line ends with it")
	T.clean(w)
	w, r = home({ avgSummon = 120 })
	ok(inRow(r.env.UIParent, " · Usually about 2 min"), "a minute or more: Usually about 2 min")
	T.clean(w)
end)

test("r46 l: FEAT-01 b: the list card shows nothing new without an average, with someone waiting, busy, paused or full", function()
	for _, case in ipairs({
		{ {}, "no average" },
		{ { avgSummon = 45, queue = 1 }, "one waiting" },
		{ { avgSummon = 45, queue = false }, "queue not sent" },
		{ { avgSummon = 45, state = "busy", queue = 0 }, "busy" },
		{ { avgSummon = 45, state = "paused" }, "paused" },
		{ { avgSummon = 45, seats = 0 }, "group full" },
	}) do
		local w, r = home(case[1])
		ok(find(r.env.UIParent, "Mia's Rides"), case[2] .. ": control, the card is listed")
		eq(#anyUsual(r.env.UIParent), 0, case[2] .. ": nothing says usually")
		T.clean(w)
	end
	local w, r = home({ avgSummon = 45, seats = 0 })
	ok(inRow(r.env.UIParent, " · Group full"), "group full: the old words stay, and no 'Usually' beside them")
	T.clean(w)
end)
