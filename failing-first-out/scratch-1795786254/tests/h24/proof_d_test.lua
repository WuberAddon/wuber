-- H24 group D: flight-map price tags and Wuber's window (E3b-07). Loaded by tests/run.lua with its helper table T.
local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H

-- r50 (job 2609): these bugs are fixed in 2.4.1; their proofs now run as normal tests
local FIXED = { ["H24-01"] = true, ["H24-02"] = true, ["H24-03"] = true, ["H24-04"] = true, ["H24-05"] = true, ["H24-08"] = true, ["H24-15"] = true }
local function proof(id, name, fn)
	if os.getenv("WUBER_H24_PROOF") or FIXED[id] then
		test(id .. ": " .. name, fn)
	else
		test(id .. " (expected fail until fixed): " .. name, function()
			local okp = pcall(fn)
			assert(not okp, id .. " now passes: the bug looks fixed; make this a normal test")
		end)
	end
end

local function addDriver(r, key, opts)
	r.W.drivers = r.W.drivers or {}
	r.W.drivers[key] = { name = opts.name or key, key = key, dest = opts.dest, price = opts.price or 5000, state = "open",
		team = 3, heard = r.env.GetTime() }
end

local function overlaps(a, b)
	return not (a.l + a.w <= b.l + 0.5 or b.l + b.w <= a.l + 0.5 or a.b + a.h <= b.b + 0.5 or b.b + b.h <= a.b + 0.5)
end

-- the map open with one tag, Wuber open; returns world, rider, the pins module, the window, the phone and the tag's first rect
local function setup()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, { spot = "Thunder Bluff", screenW = 1365, screenH = 768 })
	T.settle(w)
	addDriver(r, "anita lift", { name = "Anita Lift", dest = "Orgrimmar", price = 5000 })
	local Mod = r.W.Mod("UI.FlightPins")
	w:openTaxiMap(r, H.realTaxi("Kalimdor", "Thunder Bluff", { known = { "Orgrimmar" } }))
	w:advance(0.5)
	local tr = H.rect(Mod.Pins()[1].tag)
	r.W.UI.Toggle(true)
	w:advance(0.5)
	local win = r.W.UI.state.win
	return w, r, Mod, win, r.W.UI.state.phone or win, tr
end

-- drops the window with its left edge 2 px inside the tag's first place (screen px -> UIParent units by the window's own ratio)
local function dropOverTag(r, win, tr)
	local before = H.rect(win)
	win:ClearAllPoints()
	win:SetPoint("LEFT", r.env.UIParent, "BOTTOMLEFT", before.l, before.b + before.h / 2)
	local k = H.rect(win).l / before.l
	win:ClearAllPoints()
	win:SetPoint("LEFT", r.env.UIParent, "BOTTOMLEFT", (tr.l + 2) / k, (tr.b + tr.h / 2) / k)
end

local function tagUnderWindow(Mod, ph)
	local t = Mod.Pins()[1].tag
	return t and H.visible(t) and overlaps(H.rect(t), H.rect(ph))
end

proof("H24-04", "dragging Wuber by the phone's status bar or pill over a price tag leaves the tag under the window until the next 1 s check", function()
	local w, r, Mod, win, ph, tr = setup()
	local grip = r.W.UI.state.phone.island
	assert(grip and grip:GetScript("OnDragStart"), "the pill is a drag handle")
	grip:GetScript("OnDragStart")(grip)
	dropOverTag(r, win, tr)
	grip:GetScript("OnDragStop")(grip)
	w:advance(0.1)
	assert(not tagUnderWindow(Mod, ph), "a price tag is drawn under Wuber's window after a drop by the pill")
	T.clean(w)
end)

local function source(path)
	local f = assert(io.open(path, "rb"), "cannot open " .. path)
	local s = f:read("*a")
	f:close()
	return s
end

-- a file's header block: the leading comment lines
local function header(path)
	local out = {}
	for line in (source(path) .. "\n"):gmatch("(.-)\r?\n") do
		if not line:match("^%-%-") then break end
		out[#out + 1] = line
	end
	return table.concat(out, "\n")
end

proof("H24-08", "Bird.lua's header still names the Settings row 'Flight master tip', which is now 'Flight offers'", function()
	local h = header("Wuber/UI/Bird.lua")
	assert(not h:find('"Flight master tip"', 1, true), "the header sends the reader to a Settings row that no longer exists")
end)

proof("H24-08", "Commands.lua's header still names the Settings row 'Login tips', which is now 'Tips'", function()
	local h = header("Wuber/UI/Commands.lua")
	assert(not h:find("Riding > Login tips", 1, true), "the header names a Settings row that no longer exists")
end)

proof("H24-08", "FlightPins.lua's header lists no Listen FOLD / Listen PAGE and none of the new window helpers", function()
	local h = header("Wuber/UI/FlightPins.lua")
	assert(h:find("Listen FOLD", 1, true) and h:find("Listen PAGE", 1, true), "the Events line omits the two new listeners")
	assert(h:find("windowRect", 1, true) and h:find("hookWin", 1, true), "the Internals line omits the new helpers")
end)
