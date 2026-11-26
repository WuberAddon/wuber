-- Tests of FX.Emblem (BRIEF15 agent B): the Pioneers' floating emblem over nameplates. Loaded by
-- tests/run.lua with its helper table T. The shipped lists are empty: every test that needs names
-- sets its own fake lists on its own client (a fresh world each time) and puts the shipped table back.
local T = ...
local test, eq, ok, S = T.test, T.eq, T.ok, T.S
local TESTCHAR, BOB, CAL, ANITA = T.TESTCHAR, T.BOB, T.CAL, T.ANITA

-- riders: Bob, Wuber (me) and Anita (a founder); drivers: Cal
local function fake()
	return { riders = { ["EU-PvE"] = { BOB, TESTCHAR, ANITA } }, drivers = { ["EU-PvE"] = { CAL } } }
end

local function count(c, otype)
	local n = 0
	for _, o in ipairs(c.widgets) do if S[o].otype == otype then n = n + 1 end end
	return n
end

-- the emblem holder on a player's plate (a frame with the orb sprite, a glow and the fallback ring), or nil
local function emblemOn(c, name)
	for _, f in ipairs(c:onPlate(name)) do
		if f.orb and f.halo and f.ring then return f end
	end
	return nil
end

local function world(opts)
	opts = opts or {}
	local w = T.newWorld({ realm = T.H.FOUNDER_REALM })
	local r = T.rider(w, TESTCHAR)
	for _, n in ipairs({ BOB, CAL, ANITA, "Dee Nobody" }) do w:addBot(n, { spot = "Orgrimmar", class = "MAGE" }) end
	T.settle(w)
	local shipped = r.W.PIONEERS
	if opts.fake ~= false then r.W.PIONEERS = fake() end
	return w, r, function() r.W.PIONEERS = shipped end
end

local function showAll(r, w)
	for _, n in ipairs({ BOB, CAL, ANITA, "Dee Nobody" }) do r:showPlate(n, { force = true }) end
	w:advance(2.5)
end

local function said(r, part)
	for _, l in ipairs(r.chatLines or {}) do if tostring(l):find(part, 1, true) then return true end end
	return false
end

test("fx.emblem: contract (registered, deps, header, public names)", function()
	local W, w = T.contract("FX.Emblem", "tests/fx/emblem_test.lua", {
		["W.Emblem"] = "table", ["W.EmblemHeard"] = "function", ["W.EmblemFlag"] = "function",
		["W.Emblem.Kind"] = "function", ["W.Emblem.Sweep"] = "function", ["W.Emblem.Preview"] = "function",
		["W.Emblem.Command"] = "function", ["W.Emblem.Status"] = "function", ["W.Emblem.LOOKS"] = "table",
		["W.Emblem.ATLAS"] = "table", ["W.Emblem.FrameCoords"] = "function",
		["W.Emblem.Active"] = "function", ["W.Emblem.Mine"] = "function",
	})
	eq(#W.Emblem.LOOKS, 3, "three looks to pick from")
	eq(W.Emblem.Look(), 2, "look 2 (the Orb, the author's pick) is the default")
	eq(W.Emblem.MODELS, nil, "no game models any more: Wuber's own art (BRIEF16)")
	eq(W.Mod("FX.Nameplates").emblem, W.Emblem, "FX.Nameplates' hook slot is filled")
	T.clean(w)
end)

test("fx.emblem: with the shipped (empty) lists nothing is made, nothing is flagged, nothing is sent", function()
	local w, r, restore = world({ fake = false })
	local W = r.W
	W.db.myEmblem = false
	showAll(r, w)
	w:advance(5)
	eq(W.Emblem.Count(), 0, "no emblems")
	eq(count(r, "PlayerModel"), 0, "no model frame made")
	eq(W.EmblemFlag(), nil, "no hide flag: nobody is a Pioneer")
	eq(W.Emblem.Active(), false, "the lists are empty")
	eq(W.Emblem.Kind(W.Key(BOB)), nil, "nobody gets one")
	W.EmblemHeard(BOB, "0")
	W.db.myEmblem = nil
	W.SlashCommand("emblem mine off")
	eq(W.db.myEmblem, nil, "not a Pioneer: nothing to hide, nothing saved")
	ok(said(r, "aren't on the Pioneer list"), "says so")
	ok(not (W.Emblem.SelfHolder() and W.Emblem.SelfHolder():IsShown()), "nothing over my head")
	restore()
	T.clean(w)
end)

test("fx.emblem: a listed rider and driver get one on their plate (different colours); the founder keeps the crown; others nothing", function()
	local w, r, restore = world()
	local W = r.W
	showAll(r, w)
	local b, c = emblemOn(r, BOB), emblemOn(r, CAL)
	ok(b, "Bob (a Pioneer rider) has an emblem")
	ok(c, "Cal (a Pioneer Driver) has an emblem")
	eq(b and b.kind, "rider")
	eq(c and c.kind, "driver")
	local rb, cb = S[b.halo].vertex, S[c.halo].vertex
	-- one colour per kind, from the Pioneer badge's theme token (T.PIONEER[kind].colour)
	local Th = W.Theme
	for kind, got in pairs({ rider = rb, driver = cb }) do
		local r_, g_, b_ = Th.RGB(Th.PIONEER[kind].colour)
		eq(got and string.format("%.3f %.3f %.3f", got[1], got[2], got[3]), string.format("%.3f %.3f %.3f", r_, g_, b_),
			kind .. "'s glow is the badge's colour (" .. Th.PIONEER[kind].colour .. ")")
	end
	eq(Th.PIONEER.rider.colour, "glow", "riders: the bright violet token")
	eq(Th.PIONEER.driver.colour, "teal", "Pioneer Drivers: the teal token")
	ok(rb[1] ~= cb[1], "rider and driver colours differ")
	eq(emblemOn(r, ANITA), nil, "a founder on the list: no emblem (the crown wins)")
	eq(emblemOn(r, "Dee Nobody"), nil, "not listed: nothing")
	eq(W.Emblem.Count(), 2, "two emblems")
	eq(count(r, "PlayerModel"), 0, "no model frames: the orb is Wuber's own sprite")
	eq(S[b.orb].texture, W.Emblem.ATLAS.rider, "riders: the violet atlas")
	eq(S[c.orb].texture, W.Emblem.ATLAS.driver, "Pioneer Drivers: the teal atlas")
	ok(b.orb:IsShown() and not b.ring:IsShown() and not b.flat, "the orb, not the fallback ring")
	ok(W.Emblem.SelfHolder() and W.Emblem.SelfHolder():IsShown(), "a listed Pioneer sees their own over their head")
	-- it spins: the frames step
	local t1 = table.concat(S[b.orb].texCoord, ",")
	w:advance(1)
	ok(table.concat(S[b.orb].texCoord, ",") ~= t1, "it turns")
	-- pooled: the plate goes and comes back; no new frame
	local frames = count(r, "Frame")
	r:hidePlate(BOB)
	w:advance(0.5)
	eq(emblemOn(r, BOB), nil, "gone with the plate")
	eq(W.Emblem.Count(), 1)
	r:showPlate(BOB, { force = true })
	w:advance(0.5)
	ok(emblemOn(r, BOB), "back with the plate")
	eq(count(r, "Frame"), frames, "the holder was reused")
	restore()
	T.clean(w)
end)

test("fx.emblem: hidden in instances, by its own setting, and never on a forbidden plate", function()
	local w, r, restore = world()
	local W = r.W
	showAll(r, w)
	eq(W.Emblem.Count(), 2)
	r.env.IsInInstance = function() return true, "party" end
	w:advance(2.5)
	eq(W.Emblem.Count(), 0, "inside an instance: none")
	ok(not W.Emblem.SelfHolder():IsShown(), "not over my head either")
	r.env.IsInInstance = function() return false, "none" end
	w:advance(2.5)
	eq(W.Emblem.Count(), 2, "back in the open world")
	W.SlashCommand("emblem off")
	eq(W.db.emblems, false, "saved off")
	w:advance(2.5)
	eq(W.Emblem.Count(), 0, "turned off: none")
	W.SlashCommand("emblem on")
	eq(W.db.emblems, nil, "on is the default: nothing saved")
	w:advance(2.5)
	eq(W.Emblem.Count(), 2, "on again")
	-- the crowns-and-badges setting is separate
	W.db.plates = false
	w:advance(2.5)
	eq(W.Emblem.Count(), 2, "badges off: emblems stay")
	W.db.plates = nil
	r:hidePlate(BOB)
	w:advance(0.5)
	r:showPlate(BOB, { force = true, forbidden = true })
	w:advance(2.5)
	eq(emblemOn(r, BOB), nil, "a forbidden plate is never touched")
	restore()
	T.clean(w)
end)

-- a D beacon from name with field 20 = flag (nil: 19 fields, as today)
local function beacon(w, name, flag)
	local f = { "D", "1", "Ratchet", "1413", "500", "500", "5000", "", "open", "1", "0", "", "2.3.2-dev", "", "", "1", "", "1", "", "", "" }
	if flag then f[#f + 1] = flag end
	w:inject(name, table.concat(f, "~"), "CHANNEL")
	w:advance(0.5)
end

test("fx.emblem: unforgeable: no message gives one; a listed Pioneer's hide flag only hides, and its absence shows again", function()
	local w, r, restore = world()
	local W = r.W
	showAll(r, w)
	ok(emblemOn(r, CAL), "Cal has one")
	-- a beacon claiming anything (pioneer words, the flag) from an unlisted player gives nothing
	beacon(w, "Dee Nobody", "1")
	beacon(w, "Dee Nobody", "pioneer")
	w:advance(2.5)
	eq(emblemOn(r, "Dee Nobody"), nil, "unlisted: still nothing")
	eq(W.PioneerKind("Dee Nobody"), nil)
	-- Cal hides his: field 20 "0"
	beacon(w, CAL, "0")
	w:advance(2.5)
	eq(emblemOn(r, CAL), nil, "Cal's flag hid it")
	ok(emblemOn(r, BOB), "Bob's stays")
	-- his next beacon without the flag: shown again
	beacon(w, CAL, nil)
	w:advance(2.5)
	ok(emblemOn(r, CAL), "shown again")
	-- a rider's Q ping with field 2 "0" (channel)
	w:inject(BOB, "Q~1~~0", "CHANNEL")
	w:advance(2.5)
	eq(emblemOn(r, BOB), nil, "Bob's ping hid his")
	w:inject(BOB, "Q~1", "CHANNEL")
	w:advance(2.5)
	ok(emblemOn(r, BOB), "a ping without it shows it again")
	restore()
	T.clean(w)
end)

test("fx.emblem: a Pioneer who hides theirs flags it on their beacon (field 20) and pings (field 2); others' messages are unchanged", function()
	local w = T.newWorld()
	local d = T.driver(w, CAL)
	local r = T.rider(w, TESTCHAR)
	T.settle(w)
	local shippedD, shippedR = d.W.PIONEERS, r.W.PIONEERS
	d.W.PIONEERS, r.W.PIONEERS = fake(), fake()
	T.goOnline(d)
	w:advance(5)
	local before = T.msgs(w, "D", CAL)
	local allD = T.msgs(w, "D")
	ok(#before > 0, "Cal beacons: D total " .. #allD .. " from " .. tostring(allD[1] and allD[1].from))
	eq(T.fields(before[#before])[22], nil, "no field 20 while his emblem shows")
	eq(d.W.EmblemFlag(), nil)
	d.W.SlashCommand("emblem mine off")
	eq(d.W.db.myEmblem, false, "saved")
	eq(d.W.EmblemFlag(), "0")
	d.W.SendBeacon(true)
	w:advance(2)
	local after = T.msgs(w, "D", CAL)
	ok(#after > #before, "a new beacon")
	eq(T.fields(after[#after])[22], "0", "field 20 (after kind and protocol) is 0")
	ok(#after[#after].text <= 250, "still under 250 bytes")
	-- Wuber (a listed rider) hides his: his channel ping carries it
	r.W.db.myEmblem = false
	w:advance(120) -- past the ping gaps
	local q0 = #T.msgs(w, "Q", TESTCHAR)
	r.W.Ping()
	w:advance(1)
	local qs = T.msgs(w, "Q", TESTCHAR)
	ok(#qs > q0, "Wuber pinged")
	local q = qs[#qs]
	eq(T.fields(q)[4], "0", "Q field 2 is 0: " .. q.text)
	d.W.SlashCommand("emblem mine on")
	eq(d.W.db.myEmblem, nil, "back to the default: nothing saved")
	d.W.PIONEERS, r.W.PIONEERS = shippedD, shippedR
	T.clean(w)
end)

test("fx.emblem: the preview shows it over my own head and my target's plate, sends nothing, saves nothing and ends by itself", function()
	local w, r, restore = world({ fake = false })
	local W = r.W
	showAll(r, w)
	local sent = #T.msgs(w, nil, TESTCHAR)
	W.SlashCommand("emblem preview")
	w:advance(0.5)
	local h = W.Emblem.SelfHolder()
	ok(h and h:IsShown(), "over my head")
	eq(h.kind, "rider", "rider colour by default")
	ok(said(r, "Only you see it"), "says it is local")
	ok(said(r, "Preview on: custom portal"), "and that it is the custom portal")
	eq(W.Emblem.Status().model, "custom portal")
	eq(h:GetWidth(), W.Emblem.LOOKS[2].size, "look 2's size by default")
	eq(W.Emblem.Count(), 0, "nobody else gets one: the lists are empty")
	r.player.target = w:player(BOB)
	w:advance(2.5)
	ok(emblemOn(r, BOB), "my target's plate shows it too")
	r.player.target = w:player(ANITA)
	w:advance(2.5)
	eq(emblemOn(r, BOB), nil, "it moves with the target")
	local a = emblemOn(r, ANITA)
	ok(a, "even over a founder (only on my screen)")
	local _, _, _, _, y = a:GetPoint(1)
	ok(y >= 50, "above the founder's crown: " .. tostring(y))
	r.player.target = w:player(BOB)
	w:advance(2.5)
	W.SlashCommand("emblem preview driver")
	w:advance(0.5)
	eq(W.Emblem.SelfHolder().kind, "driver", "driver colour")
	eq(S[W.Emblem.SelfHolder().orb].texture, W.Emblem.ATLAS.driver, "the teal atlas")
	W.SlashCommand("emblem 3")
	eq(W.db.emblemLook, 3, "look 3 saved")
	w:advance(2.5)
	eq(W.Emblem.SelfHolder():GetWidth(), W.Emblem.LOOKS[3].size, "look 3's size")
	ok(emblemOn(r, BOB) and emblemOn(r, BOB):GetWidth() == W.Emblem.LOOKS[3].size, "on the plate too")
	W.SlashCommand("emblem 9")
	eq(W.db.emblemLook, 3, "an unknown look changes nothing")
	W.SlashCommand("emblem 2")
	eq(W.db.emblemLook, nil, "look 2 is the default: nothing saved")
	eq(#T.msgs(w, nil, TESTCHAR), sent, "nothing was sent")
	w:advance(121)
	ok(not W.Emblem.SelfHolder():IsShown(), "the preview ends by itself")
	eq(W.Emblem.Count(), 0, "and leaves the target's plate")
	eq(W.db.emblems, nil)
	eq(W.db.myEmblem, nil)
	restore()
	T.clean(w)
end)

-- the atlas file on disk: width, height, bits per pixel of a 32-bit true-colour TGA (or nil)
local function tgaSize(path)
	local f = io.open(path, "rb")
	if not f then return nil end
	local head = f:read(18)
	local size = f:seek("end")
	f:close()
	if not head or #head < 18 then return nil end
	local w = head:byte(13) + head:byte(14) * 256
	local h = head:byte(15) + head:byte(16) * 256
	return w, h, head:byte(17), head:byte(3), size
end

test("fx.emblem: the atlas: both colours are on disk in the crown's format, and the frame grid is right", function()
	local W, w = T.contract("FX.Emblem", "tests/fx/emblem_test.lua", {})
	local A = W.Emblem.ATLAS
	eq(A.rider, "Interface\\AddOns\\Wuber\\Media\\fx\\emblem", "riders' (violet) atlas path")
	eq(A.driver, "Interface\\AddOns\\Wuber\\Media\\fx\\emblem_teal", "Pioneer Drivers' (teal) atlas path")
	for _, name in ipairs({ "emblem", "emblem_teal" }) do
		local wd, ht, bpp, kind, size = tgaSize(T.H.ADDONS.Wuber .. "/Media/fx/" .. name .. ".tga")
		eq(wd, A.w, name .. ".tga width")
		eq(ht, A.h, name .. ".tga height")
		eq(bpp, 32, name .. ".tga: 32 bits (alpha)")
		eq(kind, 2, name .. ".tga: uncompressed true colour")
		eq(size, 18 + A.w * A.h * 4, name .. ".tga: whole")
	end
	eq(A.w / A.cell, A.cols, "columns")
	eq((A.w / A.cell) * (A.h / A.cell), A.frames, "the grid holds exactly the frames")
	local function coords(i) return string.format("%.4f %.4f %.4f %.4f", W.Emblem.FrameCoords(i)) end
	eq(coords(0), "0.0000 0.1250 0.0000 0.2500", "frame 0: top left")
	eq(coords(7), "0.8750 1.0000 0.0000 0.2500", "frame 7: end of the first row")
	eq(coords(9), "0.1250 0.2500 0.2500 0.5000", "frame 9: second row, second cell")
	eq(coords(31), "0.8750 1.0000 0.7500 1.0000", "frame 31: bottom right")
	eq(coords(32), coords(0), "frame 32 wraps to 0 (a seamless loop)")
	eq(coords(12.7), coords(12), "part frames round down")
	T.clean(w)
end)

test("fx.emblem: the frames step at the look's spin, each emblem from its own frame; still when effects are off", function()
	local w, r, restore = world()
	local W = r.W
	-- only Bob is listed (nothing over my head): one holder to watch
	W.PIONEERS = { riders = { ["EU-PvE"] = { BOB } }, drivers = {} }
	r:showPlate(BOB, { force = true })
	w:advance(0.5)
	local b = emblemOn(r, BOB)
	ok(b, "Bob's emblem")
	local A, L = W.Emblem.ATLAS, W.Emblem.LOOKS[2]
	local fps = A.frames * L.spin / A.turn
	ok(fps > 15 and fps < 22, "look 2: about 18 frames a second (" .. fps .. ")")
	local p0 = b.pos
	local sets = S[b.orb].texCoordSets or 0
	w:advance(1)
	local moved = (b.pos - p0) % A.frames
	ok(math.abs(moved - fps) < 1.5, "one second moves about " .. fps .. " frames: " .. moved)
	ok((S[b.orb].texCoordSets or 0) - sets >= 8, "the texture coords step on every game frame (" .. ((S[b.orb].texCoordSets or 0) - sets) .. ")")
	local i = math.floor(b.pos) % A.frames
	eq(table.concat(S[b.orb].texCoord, ","), table.concat({ W.Emblem.FrameCoords(i) }, ","), "showing the frame it is on")
	-- its start frame comes from the name (emblems side by side don't turn in step)
	r:hidePlate(BOB)
	w:advance(0.5)
	r:showPlate(BOB, { force = true })
	local b2 = emblemOn(r, BOB)
	eq(b2 and b2.pos, W.FX.Hash(W.Key(BOB)) % A.frames, "starts at its name's frame")
	-- effects off: it holds still, as the crown
	W.db.fx = "off"
	local held = b2.pos
	w:advance(1)
	eq(b2.pos, held, "effects off: still")
	W.db.fx = nil
	w:advance(1)
	ok(b2.pos ~= held, "turns again")
	restore()
	T.clean(w)
end)

test("fx.emblem: if the orb art won't load, Wuber's flat ring turns instead and Status says so", function()
	local w, r, restore = world()
	local W = r.W
	local A = W.Emblem.ATLAS
	local rider = A.rider
	A.rider = "Interface\\AddOns\\Wuber\\Media\\fx\\no_such_emblem"
	showAll(r, w)
	local b = emblemOn(r, BOB)
	ok(b and b.flat, "the flat ring")
	ok(b.ring:IsShown() and not b.orb:IsShown(), "ring shown, orb hidden")
	local a1 = b.angle
	w:advance(1)
	ok(b.angle ~= a1, "the ring turns")
	local c = emblemOn(r, CAL)
	ok(c and not c.flat and c.orb:IsShown(), "the teal atlas loads: Cal's is the orb")
	W.Emblem.Preview(true, "rider")
	ok(W.Emblem.Status().flat, "Status says so")
	eq(W.Emblem.Status().model, "flat ring (the portal art didn't load)")
	W.Emblem.Preview(false)
	A.rider = rider
	w.missingFiles["Interface\\AddOns\\Wuber\\Media\\fx\\no_such_emblem"] = nil
	restore()
	T.clean(w)
end)

test("fx.emblem: my own character gets my emblem only from my ruleset's list (Core.Base's rule)", function()
	local w, r, restore = world()
	local W = r.W
	-- Wuber is listed only on another ruleset's list: somebody else's name there
	W.PIONEERS = { riders = { ["US-PvE"] = { TESTCHAR } }, drivers = {} }
	W.db.myEmblem = false
	w:advance(2.5)
	eq(W.Emblem.Mine(), nil, "not my list: I am not a Pioneer here")
	eq(W.EmblemFlag(), nil, "so no hide flag on my messages")
	ok(not (W.Emblem.SelfHolder() and W.Emblem.SelfHolder():IsShown()), "nothing over my head")
	W.db.myEmblem = nil
	restore()
	T.clean(w)
end)

test("fx.emblem: Settings shows its rows only once the lists name someone (a Pioneer also gets 'Show my Pioneer emblem'); each has a tooltip", function()
	local w, r, restore = world({ fake = false })
	r.W.UI.Toggle(true)
	w:advance(2)
	r.W.UI.OpenSettings()
	w:advance(1)
	local st = r.W.UI.settings
	eq(st.controls.myEmblem, nil, "empty lists: no emblem row")
	r.W.UI.OpenSettings("sound")
	w:advance(1)
	ok(#r:findText("Pioneer") == 0, "and no Pioneer word on the Badges over heads row")
	restore()
	T.clean(w)
	local w2, r2, restore2 = world()
	-- the window (and Settings) is built at login, before this test's fake lists: build Settings
	-- again, as a client with names on its shipped lists would have built it
	r2.W.UI.settings.panel = nil
	r2.W.UI.BuildSettings(r2.W.UI.state.win)
	r2.W.UI.Toggle(true)
	w2:advance(2)
	r2.W.UI.OpenSettings()
	w2:advance(1)
	local st2 = r2.W.UI.settings
	-- (Settings diet) the emblems switch is part of "Badges over heads" (plates), which then names Pioneers
	ok(st2.controls.plates, "the Badges over heads row (built " .. tostring(st2.panel) .. ", active " .. tostring(r2.W.Emblem.Active()) .. ")")
	r2.W.UI.OpenSettings("sound")
	w2:advance(1)
	ok(#r2:findText("Pioneer emblems") > 0, "with names on the lists it says Pioneer emblems")
	ok(st2.controls.myEmblem, "Wuber is listed: his own row (Map, Advanced)")
	ok(st2.controls.plates.wuberTip and st2.controls.plates.wuberTip.text and st2.controls.plates.wuberTip.text:find("emblem", 1, true), "the merged row's toggle has a tooltip naming the emblems")
	ok(st2.controls.myEmblem.wuberTip and st2.controls.myEmblem.wuberTip.text, "and the Pioneer's own")
	st2.controls.myEmblem:Click()
	w2:advance(0.5)
	eq(r2.W.db.myEmblem, false, "the toggle hides mine")
	eq(r2.W.EmblemFlag(), "0")
	ok(not r2.W.Emblem.SelfHolder():IsShown(), "and over my head")
	restore2()
	T.clean(w2)
end)
