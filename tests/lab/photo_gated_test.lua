-- Lab job 2858/2880: the photo tour's gated shots (OpenMap's two shots, "Skip the bird", the bird_card_text stand-in) and
-- the full tour with the flight map open or closed. Skipped with one passing note when the Lab isn't there.
local T = ...
local H, test, eq, ok = T.H, T.test, T.eq, T.ok
local LAB_DIR = os.getenv("WUBER_LAB_DIR") or (H.root .. "/lab/WuberLab")
if not H.exists(LAB_DIR .. "/PhotoShots.lua") then
	test("lab photo gated: PhotoShots.lua not found (skipped)", function() end)
	return
end
H.ADDONS.WuberLab = LAB_DIR

-- WuberDB as text, keys sorted
local function serialize(v, out)
	local t = type(v)
	if t == "string" then out[#out + 1] = string.format("%q", v)
	elseif t == "number" or t == "boolean" or t == "nil" then out[#out + 1] = tostring(v)
	elseif t == "table" then
		local keys = {}
		for k in pairs(v) do keys[#keys + 1] = k end
		table.sort(keys, function(a, b)
			if type(a) == type(b) and (type(a) == "number" or type(a) == "string") then return a < b end
			return type(a) < type(b)
		end)
		out[#out + 1] = "{"
		for _, k in ipairs(keys) do
			out[#out + 1] = "["
			serialize(k, out)
			out[#out + 1] = "]="
			serialize(v[k], out)
			out[#out + 1] = ","
		end
		out[#out + 1] = "}"
	else out[#out + 1] = "<" .. t .. ">" end
end
local function dbText(c)
	local out = {}
	serialize(c.env.WuberDB, out)
	return table.concat(out)
end

local SW, SH = 1500, 1180 -- a nearly square screen, as the maintainer's (2662 x 2089)

local function labOf(c) return c.ns.WuberLab end

local function client(w, opts)
	opts = opts or {}
	local c = w:addClient(opts.name or "Anita Lift", { spot = opts.spot or "Orgrimmar", class = opts.class or "WARLOCK", money = 100000,
		addons = { "Wuber", "WuberLab" }, screenW = SW, screenH = SH, openMap = opts.openMap,
		rewrite = function(_, _, text) return text end }) -- (no change to the source: it only takes this test's OpenMap fake out of the taint guard, which judges Wuber's own writes)
	w:advance(15)
	return c
end

-- the lab's log lines since n (text after "kind|")
local function logSince(c, n)
	local lines = c.env.WuberLabDB.chars["Anita Lift"].lines
	local out = {}
	for i = n + 1, #lines do out[#out + 1] = lines[i] end
	return out, #lines
end
local function logCount(c) return #c.env.WuberLabDB.chars["Anita Lift"].lines end
local function has(lines, text)
	for _, l in ipairs(lines) do if l:find(text, 1, true) then return l end end
	return nil
end

local function runTour(c, w, cmd)
	local L = labOf(c)
	c:slash(cmd)
	for _ = 1, 300 do
		if not L.Touring() then break end
		w:advance(0.5)
	end
	ok(not L.Touring(), "the tour ended")
	return L.lastTour
end

-- a frame's rect in screen pixels
local function px(f)
	local e = f:GetEffectiveScale()
	return { l = f:GetLeft() * e, r = f:GetRight() * e, t = f:GetTop() * e, b = f:GetBottom() * e }
end

-- the maintainer's OpenMap: the window wider than the screen, its left part off it, the quest list open beside the
-- map; a flat view (u, v across the canvas) that ShowWorld moves at once unless frozen
local function maintainerOpenMap(c, frozen)
	local env = c.env
	local wm, UIParent = env.WorldMapFrame, env.UIParent
	local saved = { window = { "TOPLEFT", "TOPLEFT", -700, -120 }, windowSize = { 2200, 1000 }, windowScale = 1 }
	env.OpenMapDB = { worldmap = { window = saved.window, windowSize = saved.windowSize, windowScale = 1, maxZoom = 8 } }
	wm:ClearAllPoints()
	wm:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -700, -120)
	wm:SetSize(2200, 1000)
	local sc = wm.ScrollContainer
	sc:ClearAllPoints()
	sc:SetPoint("TOPLEFT", wm, "TOPLEFT", 0, -30)
	sc:SetPoint("BOTTOMRIGHT", wm, "BOTTOMRIGHT", 0, 0)
	local log = env.CreateFrame("Frame", nil, wm)
	log:SetPoint("TOPRIGHT", wm, "TOPRIGHT", 0, -30)
	log:SetPoint("BOTTOMRIGHT", wm, "BOTTOMRIGHT", 0, 0)
	log:SetWidth(700)
	local o = { toggles = 0, saved = saved, log = log }
	rawset(wm, "QuestLog", log)
	rawset(wm, "IsSidePanelShown", function() return log:IsShown() end)
	rawset(wm, "HandleUserActionToggleSidePanel", function()
		o.toggles = o.toggles + 1
		log:SetShown(not log:IsShown())
	end)
	local view = { u = 0.3, v = 0.4, z = 1.2 }
	o.view = view
	local child = sc.Child
	local function apply()
		local sw, sh = sc:GetWidth(), sc:GetHeight()
		child:SetSize(sw * view.z, sh * view.z)
		child:ClearAllPoints()
		child:SetPoint("TOPLEFT", sc, "TOPLEFT", sw / 2 - view.u * sw * view.z, -(sh / 2 - view.v * sh * view.z))
	end
	o.apply = apply
	local api = env.OpenMapAPI
	rawset(api, "MapFromWorld", function(id, u, v) if type(u) == "number" and type(v) == "number" then return u, v end end)
	rawset(api, "GetView", function() return view.u, view.v, view.z end)
	rawset(api, "ShowWorld", function(u, v, z)
		if type(u) ~= "number" or type(v) ~= "number" then return false end
		if not frozen then
			view.u, view.v, view.z = u, v, z or view.z
			apply()
		end
		return true
	end)
	if H.taint and H.taint.snap then H.taint.snap(c) end -- (the test's own fake OpenMap functions are not the addon's writes)
	wm:HookScript("OnSizeChanged", apply)
	apply()
	o.points = { wm:GetPoint(1) }
	return o
end

-- notes what is on screen at each Screenshot(); the game says it saved it 0.2 s later
local function cameraOn(c, measure)
	local shots = {}
	c.env.Screenshot = function()
		c.env.C_Timer.After(0.2, function() c:fire("SCREENSHOT_SUCCEEDED") end)
		shots[#shots + 1] = measure and measure() or {}
	end
	return shots
end

---------------------------------------------------------------------------

test("lab gated: /lab tour openmap fits OpenMap's window on the screen, collapses the quest list, hides the chat, frames every pin and both route ends, and puts it all back", function()
	local w = H.NewWorld()
	local c = client(w, { openMap = {} })
	local L, env = labOf(c), c.env
	local o = maintainerOpenMap(c)
	local wm, chat = env.WorldMapFrame, env.ChatFrame1
	chat:Show()
	chat:SetAlpha(1)
	local before = dbText(c)
	local n0 = logCount(c)
	local shots = cameraOn(c, function()
		return { win = px(wm), screen = px(env.UIParent), log = o.log:IsShown(), chat = chat:GetAlpha(), shown = wm:IsShown() }
	end)
	local res = runTour(c, w, "/lab tour openmap")
	local lines = logSince(c, n0)
	eq(#shots, 2, "two shots (skipped: " .. table.concat(res.skipped, ", ") .. ")")
	for i, s in ipairs(shots) do
		ok(s.shown, i .. ": the map open")
		ok(s.win.l >= s.screen.l and s.win.r <= s.screen.r and s.win.b >= s.screen.b and s.win.t <= s.screen.t,
			("%d: the whole window on the screen (%d..%d x %d..%d)"):format(i, s.win.l, s.win.r, s.win.b, s.win.t))
		ok(s.win.l >= 24 and s.screen.r - s.win.r >= 24, i .. ": with a margin")
		eq(s.log, false, i .. ": the quest list collapsed")
		eq(s.chat, 0, i .. ": the chat out of the shot")
	end
	ok(has(lines, "openmap_pins folded: check: 4 pins inside the visible map"), "pins checked: " .. table.concat(lines, "\n"))
	ok(has(lines, "openmap_route folded: check: both route ends inside the visible map"), "route checked: " .. table.concat(lines, "\n"))
	ok(has(lines, "quest list collapsed"), "the fit logged")
	-- put back exactly
	local db = env.OpenMapDB.worldmap
	ok(db.window == o.saved.window and db.windowSize == o.saved.windowSize, "OpenMap's saved place and size: the same tables")
	eq(db.window[3], -700, "saved x")
	eq(db.windowSize[1], 2200, "saved width")
	local p = { wm:GetPoint(1) }
	eq(p[1], "TOPLEFT", "point")
	eq(p[4], -700, "x")
	eq(p[5], -120, "y")
	eq(math.floor(wm:GetWidth() + 0.5), 2200, "width")
	eq(math.floor(wm:GetHeight() + 0.5), 1000, "height")
	eq(o.log:IsShown(), true, "the quest list open again")
	eq(o.toggles, 4, "collapsed and opened once per shot")
	eq(wm:IsShown(), false, "the map closed again (the tour opened it)")
	eq(chat:GetAlpha(), 1, "the chat back")
	eq(dbText(c), before, "WuberDB unchanged")
end)

test("lab gated: the chat is back straight after the shot is saved (and after 1.5 s if the game never says)", function()
	local w = H.NewWorld()
	local c = client(w, { openMap = {} })
	local L, env = labOf(c), c.env
	maintainerOpenMap(c)
	local chat, tab = env.ChatFrame1, env.ChatFrame2
	chat:Show(); chat:SetAlpha(1)
	tab:Show(); tab:SetAlpha(0.6)
	local alphas = {}
	env.Screenshot = function()
		alphas[#alphas + 1] = { chat:GetAlpha(), tab:GetAlpha() }
		-- the game never says it saved this one
	end
	local t0
	c:slash("/lab tour openmap_pins")
	for _ = 1, 100 do
		w:advance(0.1)
		if #alphas == 1 and not t0 then t0 = w.time end
		if t0 and w.time - t0 >= 1 then break end
	end
	eq(#alphas, 1, "one shot")
	eq(alphas[1][1], 0, "chat hidden at the shot")
	eq(alphas[1][2], 0, "the second chat frame too")
	eq(chat:GetAlpha(), 0, "still hidden 1 s on (no save event)")
	w:advance(0.6)
	eq(chat:GetAlpha(), 1, "back after 1.5 s")
	eq(tab:GetAlpha(), 0.6, "its own alpha back")
	for _ = 1, 40 do if not labOf(c).Touring() then break end w:advance(0.5) end
end)

test("lab gated: OpenMap's view doesn't go where it is sent: the shot is still taken and the check says what is outside", function()
	local w = H.NewWorld()
	local c = client(w, { openMap = {} })
	local env = c.env
	local o = maintainerOpenMap(c, true)
	o.view.u, o.view.v, o.view.z = 0.9, 0.9, 6
	o.apply()
	local n0 = logCount(c)
	local shots = cameraOn(c)
	runTour(c, w, "/lab tour openmap_pins")
	eq(#shots, 1, "the shot taken")
	local lines = logSince(c, n0)
	ok(has(lines, "openmap_pins folded: check: NOT inside the visible map"), "says what is outside: " .. table.concat(lines, "\n"))
	eq(env.WorldMapFrame:GetWidth(), 2200, "window put back")
end)

test("lab gated (L1): openmap_pins is framed wide (zoom within the bound, pins well apart) and an over-zoomed view fails the check", function()
	local w = H.NewWorld()
	local c = client(w, { openMap = {} })
	local o = maintainerOpenMap(c)
	local zs = {}
	local shots = cameraOn(c, function() zs[#zs + 1] = o.view.z; return {} end)
	local n0 = logCount(c)
	runTour(c, w, "/lab tour openmap_pins")
	eq(#shots, 1, "the shot taken")
	ok(zs[1] <= 3.05, "zoom within the bound: " .. tostring(zs[1]))
	local lines = logSince(c, n0)
	ok(has(lines, "openmap_pins folded: check: 4 pins inside"), "framed: " .. table.concat(lines, "\n"))
	-- an over-zoomed view that OpenMap will not leave: the check says so even when every pin is on screen
	local w2 = H.NewWorld()
	local c2 = client(w2, { openMap = {} })
	local o2 = maintainerOpenMap(c2, true)
	o2.view.z = 7
	o2.apply()
	local m0 = logCount(c2)
	cameraOn(c2)
	runTour(c2, w2, "/lab tour openmap_pins")
	local l2 = logSince(c2, m0)
	ok(has(l2, "NOT framed: zoomed in too far") or has(l2, "NOT inside the visible map") or has(l2, "NOT framed: too close"),
		"over-zoom fails the check: " .. table.concat(l2, "\n"))
end)

test("lab gated (L1): openmap_route keeps its old framing (zoom 2 or more, no spread or zoom-bound check)", function()
	local w = H.NewWorld()
	local c = client(w, { openMap = {} })
	local o = maintainerOpenMap(c)
	local zs = {}
	cameraOn(c, function() zs[#zs + 1] = o.view.z; return {} end)
	local n0 = logCount(c)
	runTour(c, w, "/lab tour openmap_route")
	ok(zs[1] and zs[1] >= 2 - 0.05, "route zoom is not held to the pins bound: " .. tostring(zs[1]))
	local lines = logSince(c, n0)
	ok(not has(lines, "NOT framed"), "no pins-only check on the route: " .. table.concat(lines, "\n"))
	-- a view OpenMap will not leave, over-zoomed past the pins bound: the route is not failed for it
	local w2 = H.NewWorld()
	local c2 = client(w2, { openMap = {} })
	local o2 = maintainerOpenMap(c2, true)
	o2.view.z = 5
	o2.apply()
	local m0 = logCount(c2)
	cameraOn(c2)
	runTour(c2, w2, "/lab tour openmap_route")
	ok(not has(logSince(c2, m0), "NOT framed"), "route not failed for zoom or spread")
end)

test("lab gated (L1): pins too close on screen fail the check (NOT framed); a well-spread set passes", function()
	local out = {}
	for _, z in ipairs({ 0.2, 3 }) do
		local w = H.NewWorld()
		local c = client(w, { openMap = {} })
		local o = maintainerOpenMap(c, true) -- the view will not move
		o.view.u, o.view.v, o.view.z = 0.5, 0.5, z
		o.apply()
		local n0 = logCount(c)
		cameraOn(c)
		runTour(c, w, "/lab tour openmap_pins")
		out[z] = logSince(c, n0)
	end
	ok(has(out[0.2], "check: NOT framed: too close together on screen"), "tiny view fails: " .. table.concat(out[0.2], "\n"))
	ok(not has(out[3], "too close together"), "wide view is not too close: " .. table.concat(out[3], "\n"))
end)

test("lab gated: no OpenMapDB (another OpenMap): the window is fitted directly and put back", function()
	local w = H.NewWorld()
	local c = client(w, { openMap = {} })
	local env = c.env
	local o = maintainerOpenMap(c)
	env.OpenMapDB = nil
	local shots = cameraOn(c, function() return { win = px(env.WorldMapFrame), screen = px(env.UIParent) } end)
	runTour(c, w, "/lab tour openmap")
	eq(#shots, 2, "two shots")
	ok(shots[1].win.l >= 0 and shots[1].win.r <= shots[1].screen.r, "on the screen")
	local p = { env.WorldMapFrame:GetPoint(1) }
	eq(p[4], -700, "put back")
	eq(o.log:IsShown(), true, "quest list back")
end)

-- a flight master's map at Orgrimmar
local ORG = { { name = "Orgrimmar, Durotar", type = "CURRENT", cost = 0, x = 0.6, y = 0.3 },
	{ name = "Crossroads, The Barrens", type = "REACHABLE", cost = 300, x = 0.5, y = 0.5 },
	{ name = "Thunder Bluff, Mulgore", type = "REACHABLE", cost = 500, x = 0.4, y = 0.6 } }

local function birdClient(w)
	local c = client(w, { spot = "Orgrimmar" })
	local W = c.W
	-- (the harness can't time flights: Wuber's own lookups, answered for the test like tests/ui/bird_test.lua)
	W.FlightCost = function(_, to) if to == "Thunder Bluff" then return 4700, 1 elseif to == "Crossroads" then return 300, 1 end end
	W.FlightTime = function(_, to) if to == "Thunder Bluff" then return 420, "est" elseif to == "Crossroads" then return 150, "est" end end
	return c
end

test("lab gated: /lab tour bird with FlightMapFrame open: Mia summons to the longest flight a summon beats, the card is in the shot", function()
	local w = H.NewWorld()
	local c = birdClient(w)
	local env, W = c.env, c.W
	w:openTaxiMap(c, ORG, { frame = "FlightMapFrame" })
	w:advance(1)
	local Bd = W.Mod("UI.Bird")
	local n0 = logCount(c)
	local before = dbText(c)
	local shots = cameraOn(c, function()
		local card = Bd.Card()
		return { card = card and H.visible(card) and card.text.wuberText or nil, map = env.FlightMapFrame:IsShown() }
	end)
	local res = runTour(c, w, "/lab tour bird")
	local lines = logSince(c, n0)
	eq(#shots, 1, "one shot (skipped: " .. table.concat(res.skipped, ", ") .. "; " .. table.concat(lines, " / ") .. ")")
	ok(shots[1].card and shots[1].card:find("Summon", 1, true) and shots[1].card:find("Fly about 7 min", 1, true), "the card: " .. tostring(shots[1].card))
	ok(has(lines, "bird: the flight map is FlightMapFrame; from Orgrimmar"), "which frame, logged: " .. table.concat(lines, "\n"))
	eq(env.FlightMapFrame:IsShown(), true, "the map stays open (nothing follows the shot)")
	eq(dbText(c), before, "WuberDB unchanged")
end)

test("lab gated: the bird with TaxiFrame; a flight master whose flights are all short says so", function()
	local w = H.NewWorld()
	local c = birdClient(w)
	local W = c.W
	w:openTaxiMap(c, ORG, { frame = "TaxiFrame" })
	w:advance(1)
	local shots = cameraOn(c)
	runTour(c, w, "/lab tour bird")
	eq(#shots, 1, "shot with TaxiFrame")
	W.FlightTime = function() return 100, "est" end
	local n0 = logCount(c)
	local res = runTour(c, w, "/lab tour bird")
	eq(#shots, 1, "no second shot")
	ok(has(logSince(c, n0), "no flight from here is long enough for a summon to beat it"), "says why: " .. table.concat(res.skipped, ","))
end)

test("lab gated: no flight map: the bird is left out and the log names both frames", function()
	local w = H.NewWorld()
	local c = birdClient(w)
	local n0 = logCount(c)
	cameraOn(c)
	c:slash("/lab tour bird")
	w:advance(1)
	local l = has(logSince(c, n0), "left out bird: the flight map isn't open")
	ok(l and l:find("TaxiFrame not loaded, FlightMapFrame not loaded", 1, true), "frames named: " .. tostring(l))
	-- the map opened then closed
	w:openTaxiMap(c, ORG, { frame = "FlightMapFrame" })
	w:closeTaxiMap(c)
	n0 = logCount(c)
	-- (job 2858) no real flight map: the bird itself is left out; its stand-in card (bird_card_text) may be taken
	-- instead, and the game's FlightMapFrame is exactly what it was after the tour
	c:slash("/lab tour bird")
	w:advance(3)
	ok(c.env.FlightMapFrame ~= c.env.WuberLabTaxiStand, "FlightMapFrame is not the stand-in any more after the tour")
	ok(c.env.FlightMapFrame == nil or c.env.FlightMapFrame:IsShown() == false, "FlightMapFrame is the game's own (or none), not shown")
end)

test("lab gated: the flight master's events say open but no known frame shows: the shot is tried and its skip names the frames", function()
	local w = H.NewWorld()
	local c = birdClient(w)
	w:openTaxiMap(c, ORG, { frame = false })
	w:advance(1)
	local n0 = logCount(c)
	local shots = cameraOn(c)
	local res = runTour(c, w, "/lab tour bird")
	eq(#shots, 0, "no shot")
	local lines = logSince(c, n0)
	ok(has(lines, "bird: the flight master's map is open (TAXIMAP_OPENED) but not in"), "logged: " .. table.concat(lines, "\n"))
	ok(has(lines, "the flight map isn't in a frame Wuber's card can stand beside"), "skip says why: " .. table.concat(res.skipped, ","))
end)

test("lab gated: the full video tour at a flight master: the bird first, the flight map closed after it, every other shot taken", function()
	local w = H.NewWorld()
	local c = birdClient(w)
	local env = c.env
	w:openTaxiMap(c, ORG, { frame = "FlightMapFrame" })
	w:advance(1)
	local n0 = logCount(c)
	local before = dbText(c)
	local shots = cameraOn(c, function() return { map = env.FlightMapFrame:IsShown() } end)
	local res = runTour(c, w, "/lab tour video")
	local lines = logSince(c, n0)
	ok(#shots >= 8, "shots taken: " .. #shots .. " (skipped: " .. table.concat(res.skipped, ", ") .. ")")
	eq(res.shot[1], "bird", "the bird first")
	eq(shots[1].map, true, "the flight map open at the bird's shot")
	for i = 2, #shots do eq(shots[i].map, false, "the flight map closed at shot " .. i) end
	ok(has(lines, "bird: the flight map closed for the rest of the tour"), "logged")
	eq(dbText(c), before, "WuberDB unchanged")
end)

test("lab gated: /lab tour openmap without OpenMap says nothing to shoot; the openmap group resolves both shots", function()
	local w = H.NewWorld()
	local c = client(w)
	local L = labOf(c)
	local ids = L.TourResolve({ "openmap" })
	eq(table.concat(ids, ","), "openmap_pins,openmap_route", "the group")
	eq(table.concat((L.TourResolve({ "bird" })), ","), "bird,bird_card_text", "the bird by id (and its stand-in card, job 2858)")
	cameraOn(c)
	c:slash("/lab tour openmap")
	w:advance(1)
	ok(not L.Touring(), "nothing started")
	local said = table.concat(c.chatLines or {}, " / ")
	ok(said:find("nothing to shoot", 1, true), "said: " .. said)
end)


-- (job 2880) the Lab's "Photo tour" button always runs the FULL tour: the bird first when the flight map is open
-- (run 3 took a 1-shot partial "bird" tour), left out with a note when it is not
local function fullTour(c, w)
	local L = labOf(c)
	L.TourFull()
	for _ = 1, 2400 do
		if not L.Touring() then break end
		w:advance(0.5)
	end
	ok(not L.Touring(), "the tour ended")
	return L.lastTour
end

test("lab gated: the Photo tour button with the flight map open runs the full tour, the bird in it", function()
	local w = H.NewWorld()
	local c = birdClient(w)
	local env = c.env
	w:openTaxiMap(c, ORG, { frame = "FlightMapFrame" })
	w:advance(1)
	local n0 = logCount(c)
	local before = dbText(c)
	local shots = cameraOn(c, function() return { map = env.FlightMapFrame:IsShown() } end)
	local res = fullTour(c, w)
	local pt = env.WuberLabDB.photoTour
	eq(pt.subset, nil, "not a partial tour")
	ok(#shots >= 60, "the full tour: " .. #shots .. " shots (skipped: " .. table.concat(res.skipped, ", ") .. ")")
	eq(res.shot[1], "bird", "the bird first")
	eq(shots[1].map, true, "the flight map open at the bird's shot")
	ok(not has(logSince(c, n0), "partial tour"), "no partial tour in the log")
	eq(dbText(c), before, "WuberDB unchanged")
end)

test("lab gated: the Photo tour button without a flight map runs the full tour and says the bird was left out", function()
	local w = H.NewWorld()
	local c = birdClient(w)
	local n0 = logCount(c)
	local shots = cameraOn(c)
	fullTour(c, w)
	ok(#shots >= 60, "the full tour: " .. #shots .. " shots")
	eq(c.env.WuberLabDB.photoTour.subset, nil, "not a partial tour")
	ok(has(logSince(c, n0), "left out bird: the flight map isn't open"), "the bird's note is in the log")
	local said = table.concat(c.chatLines or {}, " / ")
	ok(said:find("full tour; left out here", 1, true), "said: " .. said)
end)
