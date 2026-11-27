-- Round 8 (Wuber 2.3.0), agent C (rider): the folded rider UI of every new feature, on the
-- Net/Drive stubs (W.Bounty, W.Raincheck, W.Passphrase, W.FounderSummon replaced per test).
-- Test names start "r8 c:". Loaded by run.lua with the module tests' helpers.
--   Two clients (SPEC7 8.2, "r8 c e2e:"): the PvP warning on Confirm from a real beacon, the
--     passphrase on Found matching the driver's, the live tracker from real G messages, a raincheck
--     asked on Sorry / accepted on the card / used on rebooking, a bounty served -> the toast.
--   Unfolded pages: ride, confirm (and Finding), trips, settings (and Help): what
--     moves into the side pane, what stays, folding back exactly, no new frames the second time,
--     PAGE from Settings.
--   Confirm: the dial (and the pill's words under it), the route header, the PvP card per level,
--     the raincheck toggle, all of it inside 544 with the Request pill clear.
--   Found: the live tracker per phase (pips by alpha), the passphrase (2.3.0 drivers only), the
--     founder's gold ring, the PvP line, the arrival share; Done/Sorry: share once, ask a raincheck.
--   Pay: a raincheck the driver took lowers what to type. Home: the bounty empty state, Pin, chip.
--   Moments: the raincheck offer card; the bounty's "now summons" toast. Settings: the new rows.

local T = ...
local SI = "s" -- (design 1 H: money is letters, "23s", no coin icons)
local function G(s) return "|cfff9c53e" .. s .. "|r" end -- (design 1 P) an amount beside a time is gold letters
local H, test, eq, ok, list = T.H, T.test, T.eq, T.ok, T.list
local newWorld, clean = T.newWorld, T.clean

local MIA = "Mia Runner"
local function texts(c) return list(c:visibleTexts(), " | ") end
local function has(c, pattern, plain) return #c:findText(pattern, false, plain) > 0 end
local function R(f) return H.rect(f) end
local function inside(a, b, slack)
	slack = slack or 0.5
	return a.l >= b.l - slack and a.l + a.w <= b.l + b.w + slack and a.b >= b.b - slack and a.b + a.h <= b.b + b.h + slack
end
local function apart(a, b)
	return a.l + a.w <= b.l + 0.5 or b.l + b.w <= a.l + 0.5 or a.b + a.h <= b.b + 0.5 or b.b + b.h <= a.b + 0.5
end

-- media other agents add (G: shield.tga, fx/runes_gold.tga): until they land in this branch, a
-- missing one is forgiven here (only these two names)
local function forgiveArt(w)
	for path in pairs(w.missingFiles) do
		if path:match("shield$") or path:match("runes_gold$") then w.missingFiles[path] = nil end
	end
end

local function riderWorld()
	local w = newWorld()
	local r = T.rider(w, T.TESTCHAR, { screenW = 1365, screenH = 768 })
	w:advance(15)
	local t0 = r.env.GetTime()
	r.W.drivers = r.W.drivers or {}
	r.W.drivers["mia runner"] = { name = MIA, key = "mia runner", dest = "Undercity", price = 5000, state = "open", team = 3,
		service = "Mia's Rides", heard = t0, queue = 0, ver = "2.3.0" }
	r.W.FlightCost = function() return 2300, 1 end
	r.W.TravelSaved = function() return 540 end
	-- the folded layouts (the Fold would open every page on this screen by itself)
	r.W.db.fold = { v = 1, pages = {}, narrow = true }
	return w, r
end

local function withRide(w, r, state, extra)
	local ride = { id = "r8", driver = MIA, driverKey = "mia runner", dest = "Undercity", price = 5000, state = state,
		at = r.env.GetTime(), payee = MIA, payto = "Mia", service = "Mia's Rides" }
	for k, v in pairs(extra or {}) do ride[k] = v end
	r.W.ride = ride
	r.W.Fire("RIDE")
end

local function show(w, r, screen, key)
	r.W.UI.Toggle(true)
	w:advance(3)
	r.W.UI.Show(screen, key)
	w:advance(1.5)
	return r.W.UI.state.screens[screen]
end

---------------------------------------------------------------------------
-- Confirm
---------------------------------------------------------------------------

test("r8 c: confirm - the dial with the pill's words, the route header, all inside the sheet", function()
	local w, r = riderWorld()
	r.W.DestHere = function() return "Orgrimmar", { name = "Orgrimmar", kind = "city" } end
	local s = show(w, r, "confirm", "mia runner")
	ok(H.visible(s.dial), "the dial: " .. texts(r))
	ok(not H.visible(s.saved), "the pill steps aside")
	eq(s.dial.verdict.wuberText, "Summon wins by about 9 min", "the verdict")
	ok(has(r, "faster · Net " .. G("27" .. SI) .. " vs flying", true), "the pill's words under it: " .. texts(r))
	ok(H.visible(s.route) and s.route.from.wuberText == "Orgrimmar" and s.route.to.wuberText == "Undercity", "the route header")
	ok(apart(R(s.route), R(s.back)), "clear of the back button")
	ok(inside(R(s.dial), R(s.card)), "the dial inside the sheet")
	ok(H.visible(r.env.WuberRequestButton), "the secure Request button over its pill")
	-- no flying data: the old look
	r.W.FlightCost = function() return nil end
	r.W.TravelSaved = function() return nil end
	r.W.UI.Refresh(true)
	w:advance(1)
	ok(not H.visible(s.dial), "no dial without data")
	clean(w)
end)

test("r8 c: confirm - PvP card per level, raincheck toggle; dial + PvP + raincheck fit 544", function()
	local w, r = riderWorld()
	local d = r.W.drivers["mia runner"]
	d.danger, d.dangerSecs = 2, 120
	local using, asked = true, nil
	r.W.Raincheck = { ForDriver = function(drv) if type(drv) == "table" and drv.key == "mia runner" then return "v1abcdef", 5000 end end,
		Use = function(on) using = on ~= false asked = { on } end, Using = function() return using end, Mine = function() return {} end }
	local s = show(w, r, "confirm", "mia runner")
	forgiveArt(w)
	ok(H.visible(s.pvp), "the PvP card")
	eq(s.pvp.head.wuberText, "Hot drop", "head")
	eq(s.pvp.body.wuberText, "Mia's crew fought enemy players 2 min ago. You may land in a fight.", "level 2")
	ok(H.visible(s.rc) and has(r, "Use raincheck (covers 50s)", true), "the raincheck toggle: " .. texts(r))
	ok(s.rc.toggle.on, "on by default")
	ok(has(r, "Raincheck covers 50s · nothing to pay", true), "what to pay: " .. texts(r))
	-- every block inside the sheet, above the Request pill, none on another
	local req = R(s.request)
	local blocks = { s.dial, s.card.row, s.pvp, s.rc }
	for i, f in ipairs(blocks) do
		ok(H.visible(f), "block " .. i .. " shown")
		ok(inside(R(f), R(s.card)), "block " .. i .. " inside the sheet")
		ok(R(f).b >= req.b + req.h - 0.5, "block " .. i .. " above Request")
		for j = i + 1, #blocks do ok(apart(R(f), R(blocks[j])), "blocks " .. i .. " and " .. j .. " apart") end
	end
	ok(inside(R(s.card), R(s.frame)), "the sheet inside 544")
	ok(apart(R(s.route), R(s.card)) and apart(R(s.route), R(s.back)), "the route header clear")
	-- the toggle off: normal fare, Net told
	s.rc.toggle:Click()
	w:advance(1)
	eq(asked and asked[1], false, "W.Raincheck.Use(false)")
	eq(using, false, "Net keeps the choice")
	ok(has(r, "Trade 50s after you arrive", true), "normal fare again: " .. texts(r))
	-- level 1
	d.danger, d.dangerSecs = 1, 30
	r.W.UI.Refresh(true)
	w:advance(1)
	eq(s.pvp.body.wuberText, "Enemy players were seen near the summon spot.", "level 1")
	-- the beacon's raw "l:s" form
	d.danger, d.dangerSecs = "2:300", nil
	r.W.UI.Refresh(true)
	w:advance(1)
	eq(s.pvp.body.wuberText, "Mia's crew fought enemy players 5 min ago. You may land in a fight.", "D field 18 form")
	d.danger = 0
	r.W.UI.Refresh(true)
	w:advance(1)
	ok(not H.visible(s.pvp), "level 0: no card")
	forgiveArt(w)
	clean(w)
end)

---------------------------------------------------------------------------
-- Found
---------------------------------------------------------------------------

test("r8 c: found - the live tracker per phase, pips by alpha only", function()
	local w, r = riderWorld()
	withRide(w, r, "ingroup", { ritual = { phase = "t", tapped = 0, need = 2, caster = "Anita Lift" } })
	local s = show(w, r, "found")
	local rv = r.W.UI.Ride()
	ok(H.visible(s.kitchen), "the tracker card: " .. texts(r))
	eq(s.kitchen.text.wuberText, "Anita is getting ready", "t")
	local phases = {
		{ "c", 0, "Opening rift..." }, { "h", 1, "Opening rift... 1/2 clickers tapped" },
		{ "h", 2, "Opening rift... 2/2 clickers tapped" }, { "f", 0, "The rift closed - trying again" },
		{ "s", 2, "Summon sent - accept it!" },
	}
	for _, p in ipairs(phases) do
		r.W.ride.ritual = { phase = p[1], tapped = p[2], need = 2, caster = "Anita Lift" }
		r.W.UI.Refresh(true)
		w:advance(1)
		eq(s.kitchen.text.wuberText, p[3], "phase " .. p[1])
	end
	ok(s.kitchen.pips[1]:GetAlpha() > 0.9 and s.kitchen.pips[2]:GetAlpha() > 0.9, "both pips lit")
	for _, pip in ipairs(s.kitchen.pips) do
		local sc = H.state[pip].scale
		ok(sc == nil or sc == 1, "never scaled")
	end
	-- queued: the place in line
	r.W.ride.state, r.W.ride.position = "accepted", 2
	r.W.ride.ritual = { phase = "q", need = 2 }
	r.W.UI.Refresh(true)
	w:advance(1)
	eq(s.kitchen.text.wuberText, "In the queue · 2nd", "q")
	ok(not H.visible(s.queue), "the tracker takes the queue line's place")
	eq(r.W.UI.RitualText(rv) ~= nil, true, "UI.RitualText")
	clean(w)
end)

test("r8 c: found - the passphrase (2.3.0 drivers only), the gold ring for a genuine founder, the PvP line", function()
	local w, r = riderWorld()
	withRide(w, r, "ingroup")
	r.W.Passphrase = function(id, key) return "Violet Otter" end
	-- round 9: shown only when the driver shows it (the flag cached on the ride, W.ride.showPass)
	r.W.ride.showPass = true
	local s = show(w, r, "found")
	ok(H.visible(s.pass) and has(r, "Violet Otter", true), "the passphrase: " .. texts(r))
	ok(not has(r, "your driver sees", true), "the line is just the words (word rule)")
	do -- the long version is the tooltip
		s.passHit:GetScript("OnEnter")(s.passHit)
		eq(r.env.GameTooltipTextLeft2:GetText(), "Your driver sees the same words.", "its words, in the tooltip")
	end
	-- (round 9, C10) the driver's entry expires (whisper fallback) or goes (closed): the line stays
	local entry = r.W.drivers["mia runner"]
	r.W.drivers["mia runner"] = nil
	r.W.UI.Refresh(true)
	w:advance(1)
	ok(H.visible(s.pass), "the passphrase stays when the driver's entry goes")
	r.W.drivers["mia runner"] = entry
	-- a driver without the flag (an old one, or the setting off): hidden
	r.W.ride.showPass = nil
	r.W.UI.Refresh(true)
	w:advance(1)
	ok(not H.visible(s.pass), "hidden without the driver's flag")
	-- founder: the ring turns gold (W.FounderSummon decides; any doubt is violet)
	r.W.ride.state, r.W.ride.summonUp = "summoning", true
	r.W.FounderSummon = function() return true end
	r.W.UI.Refresh(true)
	w:advance(1)
	forgiveArt(w)
	ok(s.hero.gold == true, "gold ring")
	ok(tostring(s.hero.runes:GetTextureFilePath()):match("runes_gold"), "the gold runes sheet")
	r.W.FounderSummon = function() return false end
	r.W.UI.Refresh(true)
	w:advance(1)
	ok(s.hero.gold == false and not tostring(s.hero.runes:GetTextureFilePath()):match("gold"), "violet otherwise")
	-- PvP before accepting (no map warning)
	r.W.ride.state, r.W.ride.summonUp = "ingroup", nil
	r.W.ride.ritual = { phase = "c", danger = 2, need = 2 }
	r.W.UI.Refresh(true)
	w:advance(1)
	ok(H.visible(s.alert) and s.alert.head.wuberText == "Hot drop", "the PvP line on Found: " .. texts(r))
	forgiveArt(w)
	clean(w)
end)

test("r8 c: found and done - the arrival share once per ride, grouped only; its text", function()
	local w, r = riderWorld()
	withRide(w, r, "arrived", { saved = 540 })
	local s = show(w, r, "found")
	ok(not H.visible(s.share), "not grouped: no share")
	r.W.InGroup = function() return true end
	r.W.UI.Refresh(true)
	w:advance(1)
	ok(H.visible(s.share), "grouped: Share")
	-- (round 9, C7) the tier chip (same corner) stays hidden under the Share pill
	eq(s.tier:GetAlpha(), 0, "the tier chip steps aside for Share")
	eq(s.shareLine, "Summoned to Undercity by Mia with Wuber - about 9 min saved.", "the line")
	r.W.ride.savedHow = "own"
	eq(r.W.UI.FlexText(r.W.UI.Ride()), "Summoned to Undercity by Mia with Wuber - 9 min saved.", "measured: no about")
	-- (round 9, C1) an hour or more ("1 h 5 min") still gives a line; Goldshire is a place, not "gold"
	r.W.ride.saved = 3900
	eq(r.W.UI.FlexText(r.W.UI.Ride()), "Summoned to Undercity by Mia with Wuber - 1 h 5 min saved.", "an hour: still a line")
	r.W.ride.dest = "Goldshire"
	eq(r.W.UI.FlexText(r.W.UI.Ride()), "Summoned to Goldshire by Mia with Wuber - 1 h 5 min saved.", "Goldshire passes")
	r.W.ride.dest = "Undercity"
	r.W.ride.saved = 540
	r.W.ride.saved = nil
	eq(r.W.UI.FlexText(r.W.UI.Ride()), "Summoned to Undercity by Mia with Wuber.", "no time known: no time")
	ok(#s.shareLine <= 240 and not s.shareLine:lower():find("gold") and not s.shareLine:find("%d+[gs]%f[%s%p]"), "no price, no gold")
	-- once per ride
	r.W.UI.state.flexShared = { r8 = true }
	r.W.UI.Refresh(true)
	w:advance(1)
	ok(not H.visible(s.share), "shared: gone")
	-- Done
	r.W.UI.state.flexShared = nil
	r.W.ride.state = "done"
	r.W.ride.saved = 540
	r.W.Fire("RIDE")
	w:advance(1)
	local d = show(w, r, "done")
	ok(H.visible(d.share) and d.shareLine ~= nil, "Done's share: " .. texts(r))
	ok(apart(R(d.share), R(d.done)) and apart(R(d.share), R(d.savedPill)), "clear of Done and the pills")
	clean(w)
end)

test("r8 c: sorry - ask for a raincheck after a paid ride that failed; pay - a raincheck lowers what to type", function()
	local w, r = riderWorld()
	local askedId, canAsk = nil, {}
	-- Net decides who may ask (W.Raincheck.CanAsk(rideId) -> ok, why); the stub says yes for r8 only
	r.W.Raincheck = { Ask = function(id) askedId = id return true end, Mine = function() return {} end,
		CanAsk = function(id) canAsk[#canAsk + 1] = id if id == "r8" then return true end return false, "unpaid" end }
	withRide(w, r, "cancelled", { paid = 5000 })
	local s = show(w, r, "sorry")
	ok(H.visible(s.ask), "Ask for a raincheck: " .. texts(r))
	s.ask:Click()
	w:advance(1)
	eq(askedId, "r8", "W.Raincheck.Ask(rideId)")
	eq(canAsk[1], "r8", "W.Raincheck.CanAsk(rideId)")
	ok(not H.visible(s.ask), "asked once")
	-- unpaid: no button
	withRide(w, r, "cancelled", { id = "r9" })
	r.W.UI.Refresh(true)
	w:advance(1)
	ok(not H.visible(s.ask), "unpaid: nothing to ask")
	-- arrived rides never qualify
	withRide(w, r, "failed", { id = "r10", paid = 5000, arrived = true })
	r.W.UI.Refresh(true)
	w:advance(1)
	ok(not H.visible(s.ask), "arrived: never")
	-- pay: the driver took a raincheck (Net.Rides: W.ride.voucher, .voucherCover, .voucherTaken /
	-- .voucherRefused from the A; .fare = the full fare and .price = what is due)
	local UI = r.W.UI
	r.W.db.tipPct = 0
	local function rv(price, cover, taken)
		return { price = price, raw = { price = price, fare = 5000, voucher = "v1abcdef", voucherCover = cover,
			voucherTaken = taken == true or nil, voucherRefused = taken == false or nil } }
	end
	eq(UI.PayTotal(rv(0, 5000, true)), 0, "covered: nothing")
	eq(UI.PayTotal(rv(1000, 4000, true)), 1000, "the difference")
	eq(UI.PayTotal(rv(5000, 4000, false)), 5000, "not taken: normal fare")
	eq(UI.RaincheckLine(rv(5000, 4000, false)), "Raincheck not taken: normal fare", "says so")
	eq(UI.RaincheckLine(rv(0, 5000, true)), "Raincheck covers 50s · nothing to pay", "covered line")
	eq(UI.RaincheckLine(rv(1000, 4000, true)), "Raincheck covers 40s · type 10s", "part covered")
	eq(UI.RaincheckLine(rv(5000, 4000, nil)), nil, "before the driver answered: nothing yet")
	clean(w)
end)

---------------------------------------------------------------------------
-- Home: bounties; Moments: the raincheck offer, the bounty toast
---------------------------------------------------------------------------

test("r8 c: home - nobody serves a known place: pin a bounty; the chip; x takes it down", function()
	local w, r = riderWorld()
	local pinned, mine, cancelled
	r.W.Bounty = {
		Pin = function(place, copper) pinned = { place, copper } mine = { place = place, copper = copper, at = r.env.time() } return true end,
		Cancel = function() cancelled = true mine = nil return true end,
		Mine = function() return mine end,
		Demand = function() return {} end,
	}
	r.W.ToggleWatch = function() return true end
	local s = show(w, r, "home")
	r.W.UI.SetSearch("Gadgetzan")
	w:advance(1)
	ok(has(r, "Nobody summons to Gadgetzan right now", true), "the empty state: " .. texts(r))
	ok(has(r, "Pin a bounty so drivers see you want it:", true), "the ask")
	ok(has(r, "A bounty is a wish, not a payment. You still pay the driver's fare.", true), "the note")
	for _, label in ipairs({ "50s", "75s", "1g", "Custom" }) do ok(has(r, "^" .. label .. "$"), "pick " .. label) end
	local bb = s.empty.bounty
	bb.picks[2]:Click()
	w:advance(0.5)
	bb.pin:Click()
	w:advance(1)
	eq(pinned and pinned[1], "Gadgetzan", "pinned the place")
	eq(pinned and pinned[2], 7500, "75s")
	ok(has(r, "Your bounty is up", true), "pinned: " .. texts(r))
	-- a served place: no bounty offer
	r.W.UI.SetSearch("Undercity")
	w:advance(1)
	ok(not has(r, "Nobody summons to", true), "Undercity is served")
	-- the chip on the list
	r.W.UI.SetSearch("")
	w:advance(1)
	ok(H.visible(s.bountyChip) and s.bountyChip.text.wuberText == "Your bounty: 75s for Gadgetzan"
		and tostring(s.bountyChip.row.sub.wuberText):match("^%d+ min$"), "the bounty row (design 2: a plain row, Take down as a link): " .. texts(r))
	s.bountyChip.close:Click()
	w:advance(1)
	ok(cancelled and not H.visible(s.bountyChip), "x takes it down")
	clean(w)
end)

-- (2.3.2) Custom keeps its text: picking it again after a chip makes the state agree with the box
test("r8 c: 2.3.2 - bounty Custom: the box and the amount agree after another pick and Custom again", function()
	local w, r = riderWorld()
	local pinned
	r.W.Bounty = { Pin = function(place, copper) pinned = copper return true end, Cancel = function() return true end,
		Mine = function() return nil end, Demand = function() return {} end }
	r.W.ToggleWatch = function() return true end
	local s = show(w, r, "home")
	r.W.UI.SetSearch("Gadgetzan")
	w:advance(1)
	local bb = s.empty.bounty
	bb.picks[4]:Click()
	w:advance(0.3)
	local eb = bb.custom.edit
	eb:GetScript("OnEditFocusGained")(eb)
	eb:SetText("60s")
	eb:GetScript("OnEnterPressed")(eb)
	w:advance(0.3)
	eq(bb.copper, 6000, "60s committed")
	bb.picks[3]:Click()
	eq(bb.copper, 10000, "1g")
	eb:SetText("60s") -- (T.Field keeps an unmanaged box's text; this branch's Forms may still clear it)
	bb.picks[4]:Click()
	w:advance(0.3)
	eq(bb.custom:Text(), "60s", "the box still shows 60s")
	eq(bb.copper, 6000, "and the amount follows it")
	ok(not bb.pin.inactive, "Pin is live")
	bb.pin:Click()
	w:advance(0.5)
	eq(pinned, 6000, "pinned 60s")
	clean(w)
end)

-- (round 9, C8) the bounty chip and the empty state never overlap
test("r8 c: round 9 C8 - a bounty up for a place nobody serves: the chip sits above the empty state", function()
	local w, r = riderWorld()
	local mine = { place = "Gadgetzan", copper = 5000, at = r.env.time() }
	r.W.Bounty = { Mine = function() return mine end, Cancel = function() return true end, Demand = function() return {} end }
	local s = show(w, r, "home")
	r.W.UI.SetSearch("Gadgetzan")
	w:advance(1)
	ok(H.visible(s.bountyChip) and H.visible(s.empty.title), "the chip and the empty state: " .. texts(r))
	ok(apart(R(s.bountyChip), R(s.empty.title)), "the chip clear of the title")
	ok(apart(R(s.bountyChip), R(s.empty.sub)), "the chip clear of the line under it")
	-- no bounty: the empty state back at the top
	mine = nil
	r.W.UI.Refresh(true)
	w:advance(1)
	ok(math.abs(R(s.empty).h + R(s.empty).b - (R(s.clip).h + R(s.clip).b)) < 0.5, "the empty state at the list's top")
	clean(w)
end)

-- (round 9, Y2) nobody online: say so, when drivers are usually around (real times only), the bell
-- and a bounty for the rider's usual place
test("r8 c: round 9 Y2 - the empty Home: usual hours from real times, the bell and a bounty for the usual place", function()
	local w, r = riderWorld()
	local W = r.W
	W.drivers = {}
	W.Bounty = { Mine = function() return nil end, Demand = function() return {} end }
	local watched
	W.ToggleWatch = function(place) watched = place return true end
	-- a new rider: the plain line, no bell or bounty (no place to offer)
	W.db.rides, W.db.seenDrivers = {}, {}
	local s = show(w, r, "home")
	local e = s.empty
	ok(H.visible(e), "the empty state")
	eq(e.title.wuberText, "No drivers online", "plainly: nobody online")
	eq(e.sub.wuberText, "Drivers show up here the moment they go online. Fares from 50s.", "no times made up")
	ok(not H.visible(e.watch) and not H.visible(e.bountyGo), "nothing to offer yet")
	-- rides in the evenings (19:00-21:59 on four days): "7-10pm"
	local stamp = r.env.time()
	for i = 1, 5 do
		local d = r.env.date("*t", stamp - i * 86400)
		d.hour, d.min = 19 + (i % 3), 15
		W.db.rides[i] = { dest = "Undercity", driver = MIA, driverKey = "mia runner", price = 5000, at = os.time(d), saved = 600 }
	end
	W.RebuildTotals()
	W.UI.Refresh(true)
	w:advance(1)
	eq(e.sub.wuberText, "Usually here 7-10pm", "the usual hours")
	eq(e.subTipBody, "You've mostly seen drivers around 7-10pm (local time). They appear here as soon as they open.", "the long words are its tooltip")
	ok(H.visible(e.watch) and e.watch.label:GetText() == "Tell me" and e.watch.place == "Undercity", "the bell for the usual place: " .. texts(r))
	ok(H.visible(e.bountyGo) and e.bountyGo.label:GetText() == "Pin a bounty" and e.bountyGo.place == "Undercity", "a bounty for it")
	ok(H.visible(e.ping) and H.visible(e.why), "ping and why stay")
	for _, f in ipairs({ e.title, e.sub, e.ping, e.watch, e.bountyGo, e.why }) do
		ok(inside(R(f), R(s.clip)), "inside the list (folded)")
	end
	e.watch:Click()
	w:advance(0.5)
	eq(watched, "Undercity", "the bell watches the usual place")
	e.bountyGo:Click()
	w:advance(1)
	eq(W.UI.state.filter and W.UI.state.filter.place, "Undercity", "the bounty pill opens that place")
	ok(H.visible(e.bounty), "its bounty card: " .. texts(r))
	W.UI.SetSearch("")
	w:advance(1)
	-- no pattern (rides spread over the day) but drivers seen: when Wuber last saw one
	for i = 1, 5 do
		local d = r.env.date("*t", stamp - i * 86400)
		d.hour = i * 4
		W.db.rides[i].at = os.time(d)
	end
	W.db.seenDrivers = { ["mia runner"] = { name = MIA, at = stamp - 2 * 86400 - 60 } }
	W.UI.Refresh(true)
	w:advance(1)
	eq(e.sub.wuberText, "Last driver seen 2 days ago. Drivers appear here as soon as they open.", "last seen, from real data")
	-- (2.3.2, B5) five sightings but all on two days: no guess
	for i = 1, 5 do
		local d = r.env.date("*t", stamp - (i % 2 + 1) * 86400)
		d.hour, d.min = 19 + (i % 3), 15
		W.db.rides[i].at = os.time(d)
	end
	W.UI.Refresh(true)
	w:advance(1)
	ok(not e.sub.wuberText:find("mostly seen", 1, true), "two days are not a pattern: " .. e.sub.wuberText)
	-- (2.3.2, B5) three days but only four sightings: no guess either
	W.db.rides[5] = nil
	W.db.seenDrivers = {}
	for i = 1, 4 do
		local d = r.env.date("*t", stamp - i * 86400)
		d.hour, d.min = 19 + (i % 3), 15
		W.db.rides[i].at = os.time(d)
	end
	W.UI.Refresh(true)
	w:advance(1)
	ok(not e.sub.wuberText:find("mostly seen", 1, true), "four sightings are not a pattern")
	clean(w)
end)

-- (2.3.2, B6) the city you stand in is never offered as a bounty
test("r8 c: 2.3.2 B6 - no bounty offer for the place you stand in", function()
	local w, r = riderWorld()
	local W = r.W
	W.drivers = {}
	W.Bounty = { Mine = function() return nil end, Demand = function() return {} end }
	W.db.rides = {}
	for i = 1, 3 do W.db.rides[i] = { dest = "Undercity", driver = MIA, driverKey = "mia runner", price = 5000, at = r.env.time() - i * 86400, saved = 600 } end
	W.RebuildTotals()
	local s = show(w, r, "home")
	local e = s.empty
	ok(H.visible(e.bountyGo), "away from Undercity: the offer is there")
	W.AlreadyAt = function(place) return place == "Undercity" and "Undercity" or nil end
	W.UI.Refresh(true)
	w:advance(1)
	ok(not H.visible(e.bountyGo), "standing in Undercity: no bounty offer")
	clean(w)
end)

-- (2.3.2, B4) open as a driver: Home says so, what riders see, a tap goes to the Drive tab; never bookable
test("r8 c: 2.3.2 B4 - Home while open as a driver: the line, what riders see, a chip with others, a tap to Drive", function()
	local w, r = riderWorld()
	local W = r.W
	local UI = W.UI
	W.drivers = {}
	W.Bounty = { Mine = function() return nil end, Demand = function() return {} end }
	W.db.rides, W.db.seenDrivers = {}, { ["mia runner"] = { name = MIA, at = r.env.time() - 11 * 3600 } }
	W.DriverBeacon = function() return { dest = "Orgrimmar", destShown = "Orgrimmar", price = 5000, state = "open", service = "Anita's Rides", team = 1, seats = 0, queue = 0 } end
	local s = show(w, r, "home")
	local e = s.empty
	ok(H.visible(e), "the empty state")
	eq(e.title.wuberText, "You're open as a driver", "the title")
	ok(H.visible(e.own) and e.own.label:GetText() == "Orgrimmar · 50s · open", "what riders see: " .. tostring(e.own.label:GetText()))
	ok(e.sub.wuberText:find("Riders see you in Orgrimmar for 50s", 1, true), "the line: " .. tostring(e.sub.wuberText))
	ok(not e.sub.wuberText:find("last saw", 1, true) and not e.sub.wuberText:find("Last driver", 1, true), "no 'last saw a driver'")
	ok(not H.visible(e.ping) and not H.visible(e.watch) and not H.visible(e.bountyGo), "no ping, bell or bounty")
	ok(e.own.wuberTip, "a tooltip")
	-- a tap goes to the Drive tab
	local went
	UI.SelectTab = function(name) went = name return true end
	e.own:Click()
	eq(went, "Drive", "tap -> Drive tab")
	-- paused
	W.DriverBeacon = function() return { dest = "Orgrimmar", price = 5000, state = "paused", service = "A", team = 1, seats = 0, queue = 0 } end
	UI.Refresh(true)
	w:advance(1)
	eq(e.title.wuberText, "You're paused as a driver", "paused")
	-- another driver listed too: a chip, the list, never a card for yourself
	W.DriverBeacon = function() return { dest = "Orgrimmar", destShown = "Orgrimmar", price = 5000, state = "open", service = "A", team = 1, seats = 0, queue = 0 } end
	W.drivers["mia runner"] = { name = MIA, key = "mia runner", dest = "Undercity", price = 5000, state = "open", team = 3,
		service = "Mia's Rides", heard = r.env.GetTime(), queue = 0, ver = "2.3.0" }
	UI.Refresh(true)
	w:advance(1)
	ok(not H.visible(e), "not the empty state")
	ok(H.visible(s.ownChip) and s.ownChip.text.wuberText == "You're open as a driver · Orgrimmar · 50s · open", "the chip: " .. tostring(s.ownChip.text.wuberText))
	ok(s.ownChip.wuberTip, "chip tooltip")
	went = nil
	s.ownChip:Click()
	eq(went, "Drive", "the chip -> Drive")
	local n = 0
	for _, c in pairs(UI.state.cards) do if c.key then n = n + 1 end end
	eq(n, 1, "one card: Mia's, never you")
	-- not driving: nothing
	W.DriverBeacon = function() return nil end
	UI.Refresh(true)
	w:advance(1)
	ok(not H.visible(s.ownChip), "no chip when not driving")
	clean(w)
end)

-- (2.3.2, S3) folded Confirm shows "About this driver"; standing in the place: no X > X route
test("r8 c: 2.3.2 S3 - folded Confirm: About this driver; no route to the place you stand in", function()
	local w, r = riderWorld()
	local W = r.W
	local UI = W.UI
	W.db.rides = {}
	local s = show(w, r, "confirm", "mia runner")
	local side = r.W.Mod("UI.Rider.Confirm").side
	ok(not UI.Fold.IsUnfolded(), "folded")
	ok(side.about and H.visible(side.about), "About this driver folded: " .. texts(r))
	eq(side.about.head:GetText(), "About this driver", "its heading")
	ok(inside(R(side.about), R(s.card), 1), "inside the sheet")
	ok(R(side.about).b >= R(s.request).b + R(s.request).h - 0.5, "above Request")
	ok(H.visible(s.route), "the route header is there")
	-- standing in Mia's place: no route
	W.DestHere = function() return "Undercity", { name = "Undercity", kind = "city" } end
	W.AlreadyAt = function(dest) return dest == "Undercity" and "Undercity" or nil end
	UI.Refresh(true)
	w:advance(1)
	ok(not H.visible(s.route), "no Undercity > Undercity header")
	ok(not H.visible(s.map.destPin), "no portal pin on the spot")
	clean(w)
end)

test("r19 c: F3 - folded Confirm with the flight card and a PvP warning: dial, PvP, About, how-you-pay and Request all show, no overlap", function()
	local check = dofile(T.dir .. "/lib/listfade.lua")(H)
	local w, r = riderWorld()
	local W = r.W
	local UI = W.UI
	W.db.rides = {}
	UI.DangerOf = function() return 2, 30 end
	UI.DangerLine = function(_, _, who) return "Hot drop", "Mia's crew fought enemy players 3 min ago. You may land in a fight." end
	local s = show(w, r, "confirm", "mia runner")
	local side = r.W.Mod("UI.Rider.Confirm").side
	ok(not UI.Fold.IsUnfolded(), "folded")
	ok(H.visible(s.dial), "the flight card shows")
	eq(s.dial:GetHeight(), 62, "the flight card in its short form")
	eq(s.pvp:GetHeight(), 50, "the PvP card compact")
	ok(H.visible(s.pvp) and s.pvp.head:GetText() == "Hot drop" and s.pvp.body:GetText():find("fought enemy players"), "PvP words kept")
	ok(side.about and H.visible(side.about), "About this driver visible: " .. texts(r))
	ok(H.visible(s.pay), "the how-you-pay row: " .. texts(r))
	ok(H.visible(s.request), "Request")
	ok(inside(R(side.about), R(s.card), 1), "About inside the sheet")
	ok(R(side.about).b >= R(s.request).b + R(s.request).h - 0.5, "above Request")
	local blocks = { s.dial, s.card.row, s.pvp, s.pay, side.about }
	for i = 1, #blocks do
		for j = i + 1, #blocks do
			local p, q = R(blocks[i]), R(blocks[j])
			ok(p.b >= q.b + q.h - 0.5 or q.b >= p.b + p.h - 0.5, "blocks " .. i .. " and " .. j .. " overlap")
		end
	end
	eq(#check(r, "confirm folded squeezed"), 0, "nothing cut: " .. table.concat(check(r, "confirm folded squeezed"), "; "))
	clean(w)
end)

test("r19 c: F3 - T.AlertCard default is unchanged; SetCompact(true/false) round-trips", function()
	local w, r = riderWorld()
	local T2 = r.W.Theme
	local card = T2.AlertCard(UIParent, 300, 64)
	eq(card:GetHeight(), 64, "default height")
	card:SetCompact(true)
	eq(card:GetHeight(), 50, "compact height")
	card:SetCompact(false)
	eq(card:GetHeight(), 64, "back to full")
	ok(card.ring:IsShown(), "ring back")
	clean(w)
end)

test("r8 c: moments - a raincheck offer card (Accept / No thanks); the bounty's 'now summons' toast", function()
	local w, r = riderWorld()
	local accepted
	local mine = { { id = "v1abcdef", driver = MIA, cover = 5000, expires = r.env.time() + 7 * 86400, state = "offered" } }
	r.W.Raincheck = { Mine = function() return mine end, Accept = function(id) accepted = id mine[1].state = "active" return true end,
		Decline = function() return true end }
	r.W.UI.Toggle(true)
	w:advance(3)
	r.W.Fire("RAINCHECK")
	w:advance(1)
	ok(has(r, "Mia offers a raincheck", true), "the card: " .. texts(r))
	ok(has(r, "One summon at no charge, up to 50s, until", true), "its words")
	r:clickText("Accept")
	w:advance(1)
	eq(accepted, "v1abcdef", "Accept sent")
	ok(not has(r, "Mia offers a raincheck", true), "gone")
	r.W.Fire("RAINCHECK")
	w:advance(1)
	ok(not has(r, "offers a raincheck", true), "never twice")
	-- Trips: Rainchecks (1)
	r.W.UI.SelectTab("Trips")
	w:advance(1)
	ok(has(r, "Rainchecks (1)", true), "the Trips row: " .. texts(r))
	-- bounty toast: Net.Bounty ends the bounty with BOUNTY("mine", nil, "served", driver); Moments
	-- only says so (WATCH_HIT never cancels it)
	local cancelled, mineB = nil, { place = "Undercity", copper = 5000 }
	r.W.Bounty = { Mine = function() return mineB end, Cancel = function() cancelled = true return true end }
	r.W.Fire("BOUNTY", "mine", mineB)
	w:advance(0.5)
	mineB = nil
	r.W.Fire("BOUNTY", "mine", nil, "served", MIA)
	w:advance(0.5)
	ok(has(r, "Mia now summons to Undercity", true), "the toast: " .. texts(r))
	r.W.Fire("WATCH_HIT", r.W.drivers["mia runner"], 1)
	w:advance(0.5)
	ok(not has(r, "A driver to Undercity is online", true),
		"(round 47, AUD-210) one driver, one toast: a WATCH_HIT within 10 s of the bounty ending says nothing more: " .. texts(r))
	w:advance(11)
	r.W.Fire("WATCH_HIT", r.W.drivers["mia runner"], 1)
	w:advance(0.5)
	ok(not has(r, "now summons to Undercity", true) and has(r, "A driver to Undercity is online", true),
		"later, WATCH_HIT is the usual online toast (no second 'now summons'): " .. texts(r))
	ok(not cancelled, "WATCH_HIT never cancels the bounty")
	clean(w)
end)

---------------------------------------------------------------------------
-- Settings
---------------------------------------------------------------------------

test("r8 c: settings - the new rows (flight offers, wide pages, reset; the split rule and casters' part moved to the Crew page, what riders want is typed)", function()
	local w = newWorld()
	local r = T.driver(w, "Anita Lift", {})
	w:advance(15)
	local wide, reset
	r.W.UI.WindowWide = function(on) wide = on r.W.db.fold = { v = 1, pages = {}, narrow = not on } end
	r.W.UI.Fold = r.W.UI.Fold or {}
	local oldReset = r.W.UI.Fold.Reset
	r.W.UI.Fold.Reset = function() reset = true end
	r.W.UI.Toggle(true)
	w:advance(3)
	r.W.UI.OpenSettings()
	w:advance(1)
	local c = r.W.UI.settings.controls
	for _, key in ipairs({ "flightOffers", "foldWide", "foldReset" }) do
		ok(c[key], "control " .. key)
	end
	for _, label in ipairs({ "Flight offers", "Wide pages" }) do
		ok(#r:findText(label, true, true) > 0, label)
	end
	for _, key in ipairs({ "drive.cutRule", "drive.cutCaster", "drive.watchBounty" }) do
		ok(not c[key], key .. ": no longer a Settings row")
	end
	ok(c.flightOffers.on, "the offers are on by default")
	c.flightOffers:Click()
	w:advance(0.5)
	eq(r.W.db.birdTip, false, "off saves the flight master tip")
	eq(r.W.db.flightOffers, false, "off saves the offers")
	c.foldWide.buttons[2]:Click()
	w:advance(0.5)
	eq(wide, false, "Always narrow: UI.WindowWide(false)")
	c.foldWide.buttons[1]:Click()
	w:advance(0.5)
	eq(wide, true, "Auto: UI.WindowWide(true)")
	local DR = r.W.Drive
	c.foldReset:Click()
	w:advance(0.5)
	ok(reset, "UI.Fold.Reset called")
	eq(DR.Opt("watchBounty"), true, "what riders want: on by default (a typed command now)")
	r.W.UI.Fold.Reset = oldReset
	clean(w)
end)

---------------------------------------------------------------------------
-- Unfolded pages (2.9 page tests)
---------------------------------------------------------------------------

-- a rider on a wide screen (1920 x 1080), every page free to unfold; the pages' starting
-- choices can be given ("closed" keeps one folded until the button is clicked)
local function wideWorld(pages)
	local w = newWorld()
	local r = T.rider(w, T.TESTCHAR, {})
	w:advance(15)
	r.W.FlightCost = function() return 2300, 1 end
	r.W.TravelSaved = function() return 540 end
	-- past the first-open tips (the Fold keeps every page folded while they run)
	r.W.db.coach = true
	r.W.db.fold = { v = 1, pages = pages or {}, narrow = false }
	r.W.UI.Toggle(true)
	w:advance(3)
	-- (the window's first open starts the driver list afresh: Mia comes after it)
	r.W.drivers = r.W.drivers or {}
	r.W.drivers["mia runner"] = { name = MIA, key = "mia runner", dest = "Undercity", price = 5000, state = "open", team = 3,
		service = "Mia's Rides", heard = r.env.GetTime(), queue = 0, ver = "2.3.0" }
	r.W.Fire("DRIVERS")
	w:advance(0.5)
	return w, r
end

local function same(a, b, what)
	ok(math.abs(a.l - b.l) < 0.5 and math.abs(a.b - b.b) < 0.5 and math.abs(a.w - b.w) < 0.5 and math.abs(a.h - b.h) < 0.5,
		what .. string.format(": %.1f,%.1f %.1fx%.1f vs %.1f,%.1f %.1fx%.1f", a.l, a.b, a.w, a.h, b.l, b.b, b.w, b.h))
end

-- screen units per window unit (the window's scale), and the side pane's left edge on screen
local function unit(r) return R(r.env.WuberFrame).w / r.env.WuberFrame:GetWidth() end
local function sideLeft(r) return R(r.env.WuberFrame).l + 360 * unit(r) end
local function errs(w, r)
	return " [errors: " .. table.concat(w.errors or {}, " / ") .. ((r and r.W.lastError) and (" / last: " .. r.W.lastError) or "") .. "]"
end

-- the left (primary) pane of the window: x from its left edge to 360
local function inLeft(r, f)
	local win = R(r.env.WuberFrame)
	local a = R(f)
	return a.l >= win.l - 0.5 and a.l + a.w <= sideLeft(r) + 0.5
end

local function toggleTwice(w, UI)
	UI.Fold.Toggle() w:advance(1)
	UI.Fold.Toggle() w:advance(1)
end

test("r8 c: unfolded ride - drivers left from y 16, Home's map in the side pane under Here/World; folds back exactly", function()
	local w, r = wideWorld({ ride = "closed" })
	local UI = r.W.UI
	local s = show(w, r, "home")
	eq(UI.Fold.Page(), "ride", "the ride page")
	ok(not UI.Fold.IsUnfolded(), "folded (its choice)")
	local mapF, sheetF = R(s.map), R(s.sheet)
	local win = R(r.env.WuberFrame)
	UI.Fold.Toggle()
	w:advance(1)
	ok(UI.Fold.IsUnfolded(), "unfolded")
	eq(r.env.WuberFrame:GetWidth(), 720, "720 wide")
	ok(s.holder and s.map:GetParent() == s.holder, "Home's map is in the side pane" .. errs(w, r))
	eq(s.map:GetWidth(), 360, "the map 360 wide")
	eq(s.map:GetHeight(), 500, "the map 500 high (p242 r3 F: from y 44, under the header buttons; was 512 from y 32)")
	ok(R(s.map).l >= sideLeft(r) - 0.5, "on the right")
	local top = ((win.b + win.h) - (R(s.sheet).b + R(s.sheet).h)) / unit(r)
	ok(math.abs(top - 16) < 0.5, "the sheet from y 16 (design 2: from the top of the screen, no top bar): " .. top)
	ok(#r:findText("^Here$") > 0 and #r:findText("^World$") > 0, "the Here/World control: " .. texts(r))
	ok(inLeft(r, s.search or s.sheet), "the search stays left")
	ok(not H.visible(s.grab), "(round 9, S9) no grab handle in two panes")
	-- back: exactly as before
	UI.Fold.Toggle()
	w:advance(1)
	ok(not UI.Fold.IsUnfolded() and s.map:GetParent() == s.frame, "the map is back")
	ok(H.visible(s.grab), "the grab handle folded")
	same(R(s.map), mapF, "map rect")
	same(R(s.sheet), sheetF, "sheet rect")
	-- no new frames the second time (2.9 item 9)
	toggleTwice(w, UI)
	local n = #r.widgets
	toggleTwice(w, UI)
	eq(#r.widgets, n, "no new frames on the second unfold and fold")
	clean(w)
end)

test("r8 c: unfolded confirm - the map and About this driver right, Request left; the big dial with the pill; Finding keeps the map", function()
	local w, r = wideWorld()
	local UI = r.W.UI
	r.W.DestHere = function() return "Orgrimmar", { name = "Orgrimmar", kind = "city" } end
	r.W.db.rides = { { at = 1, driver = MIA, driverKey = "mia runner", dest = "Undercity", price = 5000 } }
	local s = show(w, r, "confirm", "mia runner")
	eq(UI.Fold.Page(), "confirm", "the confirm page")
	ok(UI.Fold.IsUnfolded(), "unfolded by itself")
	local side = r.W.Mod("UI.Rider.Confirm").side
	ok(side.holder and s.map:GetParent() == side.holder, "Confirm's map in the side pane")
	-- (2.3.2, I29) About this driver in the booking column (never over the map); the ride count
	-- in the driver card, so the card leaves it out
	ok(H.visible(side.about), "About this driver" .. errs(w, r))
	ok(inLeft(r, side.about), "About this driver left, not over the map")
	ok(H.visible(s.card.again) and s.card.again.label:GetText() == "2nd ride with Mia", "rides with you, in the driver card")
	eq(side.about.lines[1].wuberText, "Their crew clicks the portal", "no fare line with fewer than 3 drivers")
	ok(not H.visible(side.about.lines[2]), "one line")
	ok(H.visible(r.env.WuberRequestButton) and inLeft(r, r.env.WuberRequestButton) and inLeft(r, s.request), "Request stays left")
	ok(inLeft(r, s.card), "the booking sheet left")
	-- (round 9, S9) the line stays under the verdict as folded (no separate pill); one header row
	-- (back + route); no grab handle in two panes
	eq(s.dial:GetHeight(), 112, "the dial 324 x 112 (the bigger arc, its line under the verdict)")
	ok(not H.visible(s.saved) and has(r, "9 min faster · Net " .. G("27" .. SI) .. " vs flying", true) and has(r, "Summon wins by about 9 min", true), "the line under the verdict: " .. texts(r))
	ok(inside(R(s.dial.line), R(s.dial)), "the line inside the dial")
	ok(apart(R(s.dial.line), R(s.dial.verdict)), "under the verdict, apart")
	local rb, rr = R(s.back), R(s.route)
	ok(math.abs((rb.b + rb.h / 2) - (rr.b + rr.h / 2)) < 0.5 and rr.l >= rb.l + rb.w, "back and route on one row")
	ok(R(s.card).b + R(s.card).h <= rb.b + 0.5, "the sheet right under the header row")
	ok(not H.visible(s.card.grab), "no grab handle unfolded")
	local blocks = { s.dial, s.card.row }
	for i, f in ipairs(blocks) do
		ok(R(f).b >= R(s.request).b + R(s.request).h - 0.5, "block " .. i .. " above Request")
	end
	-- three drivers to Undercity: the fare against the usual
	local t0 = r.env.GetTime()
	r.W.drivers["bea"] = { name = "Bea", key = "bea", dest = "Undercity", price = 7000, state = "open", team = 3, service = "Bea", heard = t0 }
	r.W.drivers["cal"] = { name = "Cal", key = "cal", dest = "Undercity", price = 6000, state = "open", team = 3, service = "Cal", heard = t0 }
	r.W.Fire("DRIVERS")
	UI.Refresh(true)
	w:advance(1)
	eq(side.about.lines[1].wuberText, "10s under the usual 60s to Undercity", "fare vs the usual")
	ok(H.visible(side.about) and inLeft(r, side.about), "still in the booking column")
	ok(R(side.about).b >= R(s.request).b + R(s.request).h - 0.5, "above Request")
	-- Finding: the map stays on the right
	withRide(w, r, "requesting")
	local fnd = show(w, r, "finding")
	eq(UI.Fold.Page(), "confirm", "Finding is the confirm page")
	-- (Orgrimmar to Undercity crosses the sea: World shows; Here is the docked map)
	local wmv = r.W.Mod("UI.Rider.WorldMap").cache.maps[side.holder]
	ok(UI.Fold.IsUnfolded() and s.map:GetParent() == side.holder and (H.visible(s.map) or (wmv and wmv.view and wmv.view:IsVisible())), "the map stays")
	ok(H.visible(fnd.cancel) and inLeft(r, fnd.cancel), "Cancel left")
	-- back to folded: the strip map under the sheet, the dial 88
	r.W.ride = nil
	r.W.Fire("RIDE")
	show(w, r, "confirm", "mia runner")
	UI.Fold.Toggle()
	w:advance(1)
	ok(not UI.Fold.IsUnfolded() and s.map:GetParent() == s.frame, "the map is back on its strip")
	eq(s.dial:GetHeight(), 88, "the folded dial")
	ok(not H.visible(s.saved), "the pill steps aside again")
	ok(H.visible(s.card.grab), "the grab handle folded")
	toggleTwice(w, UI)
	local n = #r.widgets
	toggleTwice(w, UI)
	eq(#r.widgets, n, "no new frames the second time")
	clean(w)
end)

test("r19 c: F3 - About this driver after a tight folded layout, unfolded: back to the normal spacing", function()
	local w, r = wideWorld()
	local UI = r.W.UI
	r.W.db.rides = {}
	UI.DangerOf = function() return 2, 30 end
	UI.DangerLine = function() return "Hot drop", "Mia's crew fought enemy players 3 min ago. You may land in a fight." end
	local s = show(w, r, "confirm", "mia runner")
	local side = r.W.Mod("UI.Rider.Confirm").side
	UI.Fold.Toggle()
	w:advance(1)
	ok(not UI.Fold.IsUnfolded(), "folded")
	ok(H.visible(side.about), "About folded (tight)")
	local tightGap = R(side.about.head).b - R(side.about.lines[1]).b
	UI.DangerOf = function() return 0, nil end
	UI.DangerLine = function() return nil end
	UI.Fold.Toggle()
	w:advance(1)
	UI.Refresh(true)
	w:advance(1)
	ok(UI.Fold.IsUnfolded(), "unfolded")
	ok(H.visible(side.about), "About unfolded")
	local gap = R(side.about.head).b - R(side.about.lines[1]).b
	ok(math.abs(gap) > math.abs(tightGap) or tightGap ~= gap, "the lines moved back: " .. tostring(tightGap) .. " -> " .. tostring(gap))
	ok(math.abs((gap - tightGap) - 4) < 1, "heading to first line is 4 px further than the tight card (18 vs 14): " .. tostring(gap - tightGap))
	clean(w)
end)

-- (2.3.2, I29: a reviewer's shots 8 and 9) "About this driver" covered the south of both continents in the
-- side pane, and folded Confirm never said "10th ride with Mia"
test("r8 c: I29 - '10th ride with Mia' in the driver card folded and unfolded; About this driver in the booking column, never over the map", function()
	local check = dofile(T.dir .. "/lib/listfade.lua")(H)
	local w, r = wideWorld()
	local UI = r.W.UI
	r.W.DestHere = function() return "Orgrimmar", { name = "Orgrimmar", kind = "city" } end
	r.W.db.rides = {}
	for i = 1, 9 do r.W.db.rides[i] = { at = i, driver = MIA, driverKey = "mia runner", dest = "Undercity", price = 5000 } end
	local s = show(w, r, "confirm", "mia runner")
	local side = r.W.Mod("UI.Rider.Confirm").side
	ok(UI.Fold.IsUnfolded(), "unfolded")
	-- unfolded: the chip in the driver card, About under it on the left
	ok(H.visible(s.card.again), "the ride count" .. errs(w, r))
	eq(s.card.again.label:GetText(), "10th ride with Mia", "10th ride")
	ok(inside(R(s.card.again), R(s.card.row)), "inside the driver card")
	ok(H.visible(side.about) and inLeft(r, side.about), "About this driver in the booking column")
	ok(R(side.about).l + R(side.about).w <= sideLeft(r) + 0.5, "nothing of it over the map")
	ok(R(side.about).b + R(side.about).h <= R(s.card.row).b + 0.5, "under the driver card")
	ok(R(side.about).b >= R(s.request).b + R(s.request).h - 0.5, "above Request")
	eq(side.about.lines[1].wuberText, "Their crew clicks the portal", "the card leaves out the ride count (the driver card says it)")
	eq(#check(r, "confirm unfolded"), 0, "nothing cut: " .. table.concat(check(r, "confirm unfolded"), "; "))
	-- three drivers to Undercity: the fare line too; About comes before the bigger dial
	local t0 = r.env.GetTime()
	r.W.drivers["bea"] = { name = "Bea", key = "bea", dest = "Undercity", price = 7000, state = "open", team = 3, service = "Bea", heard = t0 }
	r.W.drivers["cal"] = { name = "Cal", key = "cal", dest = "Undercity", price = 6000, state = "open", team = 3, service = "Cal", heard = t0 }
	r.W.Fire("DRIVERS")
	UI.Refresh(true)
	w:advance(1)
	ok(H.visible(side.about.lines[2]), "two lines: " .. tostring(side.about.lines[1].wuberText))
	eq(s.dial:GetHeight(), 88, "the dial stays 88 so About fits")
	ok(R(side.about).b >= R(s.request).b + R(s.request).h - 0.5, "still above Request")
	eq(#check(r, "confirm unfolded, 3 drivers"), 0, "nothing cut")
	-- folded: the chip in the driver card, no About, nothing over Request
	UI.Fold.Toggle()
	w:advance(1)
	ok(not UI.Fold.IsUnfolded(), "folded")
	ok(H.visible(s.card.again) and s.card.again.label:GetText() == "10th ride with Mia", "folded: the ride count too")
	ok(inside(R(s.card.again), R(s.card.row)), "inside the driver card")
	-- (r19, F3) About this driver now always shows folded (tighter card, how-you-pay steps aside)
	ok(H.visible(side.about), "About folded too")
	ok(R(side.about).b >= R(s.request).b + R(s.request).h - 0.5, "About above Request folded")
	ok(R(s.card.row).b >= R(s.request).b + R(s.request).h - 0.5, "the driver card above Request")
	eq(#check(r, "confirm folded"), 0, "nothing cut: " .. table.concat(check(r, "confirm folded"), "; "))
	ok(s.card.again.wuberTip, "the chip has a tooltip")
	-- a first ride: no chip, the driver card as before
	r.W.db.rides = {}
	UI.Refresh(true)
	w:advance(1)
	ok(not (s.card.again and H.visible(s.card.again)), "a first ride: no chip")
	eq(s.card.row:GetHeight(), 70, "the driver card as before")
	-- unfolded again on a first ride: the card says so
	UI.Fold.Toggle()
	w:advance(1)
	eq(side.about.lines[1].wuberText, "Your first ride with Mia", "the first ride in the card")
	clean(w)
end)

test("r8 c: unfolded trips - the milestones three to a row on the right; folded, four in the one column", function()
	local w, r = wideWorld()
	local UI = r.W.UI
	UI.Toggle(true)
	w:advance(3)
	UI.SelectTab("Trips")
	w:advance(1.5)
	eq(UI.Fold.Page(), "trips", "the trips page")
	ok(UI.Fold.IsUnfolded(), "unfolded")
	local tr = UI.trips
	ok(tr.side and tr.tray:GetParent() == tr.side.content, "the milestones in the side pane")
	local c1, c4 = R(tr.cells[1]), R(tr.cells[4])
	ok(math.abs(c1.l - c4.l) < 0.5 and c4.b < c1.b, "three to a row (the 4th starts row 2)")
	ok(c1.l >= sideLeft(r) - 0.5, "on the right")
	ok(inLeft(r, tr.level) and inLeft(r, tr.hero), "level and time saved stay left" .. errs(w, r))
	ok(#r:findText("Milestones", true, true) > 0, "Milestones")
	UI.Fold.Toggle()
	w:advance(1)
	ok(not UI.Fold.IsUnfolded() and tr.tray:GetParent() == tr.content, "back in the one column")
	c1, c4 = R(tr.cells[1]), R(tr.cells[4])
	ok(math.abs(c1.b - c4.b) < 0.5 and c4.l > c1.l, "four to a row again")
	toggleTwice(w, UI)
	local n = #r.widgets
	toggleTwice(w, UI)
	eq(#r.widgets, n, "no new frames the second time")
	clean(w)
end)

-- (round 9, C3: a reviewer's report was not a real bug - UI.Window builds Settings with the window, so
-- "settings" is registered with UI.Fold before Help can open; this test keeps it that way)
test("r8 c: round 9 C3 - Help opened before Settings while unfolded stays wide, its text inside the window", function()
	local w, r = wideWorld()
	local UI = r.W.UI
	UI.Toggle(true)
	w:advance(3)
	ok(UI.Fold.IsUnfolded(), "unfolded on Home")
	ok(not H.visible(UI.settings.panel), "Settings never opened")
	UI.OpenHelp("status")
	w:advance(1)
	eq(UI.Fold.Page(), "settings", "the settings page")
	ok(UI.Fold.IsUnfolded(), "still unfolded")
	local help = UI.settings.help
	ok(help.wide and not help.nav, "wide Help has no contents list")
	local win, clip = R(r.W.UI.state.win), R(help.clip)
	ok(clip.l + clip.w <= win.l + win.w + 0.5 and clip.l >= win.l - 0.5, "Help's text inside the window: " .. clip.l .. "+" .. clip.w .. " in " .. win.l .. "+" .. win.w)
	UI.CloseHelp(true)
	w:advance(1)
	-- Settings opened later still builds its section list
	UI.OpenSettings()
	w:advance(1)
	ok(UI.settings.nav and H.visible(UI.settings.nav), "the section list on the later Settings open")
	clean(w)
end)

test("r8 c: unfolded settings - sections left, the chosen one right; Help wide; PAGE on open, close and help", function()
	local w, r = wideWorld()
	local UI = r.W.UI
	local pages = 0
	r.W.Listen("PAGE", function() pages = pages + 1 end)
	UI.Toggle(true)
	w:advance(3)
	local before = pages
	UI.OpenSettings()
	w:advance(1)
	ok(pages > before, "Settings fired PAGE on open")
	eq(UI.Fold.Page(), "settings", "the settings page")
	ok(UI.Fold.IsUnfolded(), "unfolded")
	local st = UI.settings
	ok(st.panel.slices and st.panel.slices.mid, "the panel's 3-slice background")
	ok(H.visible(st.nav), "the section list")
	-- (round 9, S11: the list is a narrow column; the rows sit right of it, over the side pane)
	ok(st.clip:GetParent() == st.panel and R(st.clip).l >= R(st.nav.rows[1]).l + R(st.nav.rows[1]).w, "the rows right of the list")
	for _, label in ipairs({ "Riding", "Map", "Sound and effects", "This window", "Help: finding drivers" }) do
		ok(#r:findText("^" .. label .. "$") > 0, "list: " .. label)
	end
	eq(st.sec, "riding", "Riding first")
	-- pick Map: the scroll shows only its range
	for _, b in ipairs(st.nav.rows) do
		if b.key == "map" then b:Click() end
	end
	w:advance(1)
	eq(st.sec, "map", "Map chosen")
	local rng
	for _, x in ipairs(r.W.Mod("UI.Settings.Panel").sectionRanges()) do
		if x.key == "map" then rng = x end
	end
	ok(rng and st.scrollMin == rng.top, "scrolled to Map's top")
	ok(math.abs(st.clip:GetHeight() - math.min(rng.bottom - rng.top, 544 - 54)) < 0.5, "only Map's rows show: " .. st.clip:GetHeight() .. errs(w, r))
	ok(inLeft(r, st.nav.rows[1]), "the list on the left")
	-- Help: no contents list, reads as folded Help inside the window
	before = pages
	UI.OpenHelp("settings")
	w:advance(1)
	ok(pages > before, "PAGE on help")
	local help = st.help
	ok(help.wide and not help.nav, "wide Help has no contents list")
	ok(R(help.clip).l >= R(r.W.UI.state.win).l - 0.5, "Help's text inside the window")
	before = pages
	UI.CloseHelp(true)
	w:advance(1)
	ok(pages > before, "PAGE on closing help")
	-- folding: the long scroll as before
	UI.Fold.Toggle()
	w:advance(1)
	ok(not UI.Fold.IsUnfolded() and st.clip:GetParent() == st.panel, "the rows back in the panel")
	ok(not H.visible(st.nav), "no list folded")
	-- (round 9, G1: folded, the chosen section stays, with its back arrow to the Settings home)
	eq(st.title:GetText(), "Map", "Map's page folded")
	eq(st.scrollMin, rng.top, "only Map's rows")
	toggleTwice(w, UI)
	local n = #r.widgets
	toggleTwice(w, UI)
	eq(#r.widgets, n, "no new frames the second time")
	before = pages
	UI.CloseSettings(true)
	w:advance(1)
	ok(pages > before, "PAGE on close")
	clean(w)
end)

---------------------------------------------------------------------------
-- Two clients over the real wire: what the rider sees
---------------------------------------------------------------------------

local ANITA, TESTCHAR = T.ANITA, T.TESTCHAR

local function online(c)
	if c.netOnly then ok(c.W.SetDriving(true) ~= false, "online") else ok(c.W.Driver.SetOnline(true) ~= false, "online") end
	c.world:advance(3)
end

-- Anita, a Net-only driver on 2.3.0 whose beacon can carry more (a PvP level)
local function netDriver(w, extra)
	local d = T.driver(w, ANITA, { netOnly = true })
	d.W.VERSION = "2.3.0"
	local W, env = d.W, d.env
	W.SetLocalDriver(function()
		if W.Char().drive ~= true then return nil end
		local m = env.C_Map.GetBestMapForUnit("player")
		local pos = m and env.C_Map.GetPlayerMapPosition(m, "player")
		local b = { dest = "Ratchet", mapID = m, x = pos and pos.x, y = pos and pos.y, price = 5000,
			service = W.Me(), state = "open", team = 3, seats = 4,
			showPass = W.PassphraseOn and W.PassphraseOn() or nil } -- round 9: as DR.NetBeacon (D field 19)
		for k, v in pairs(extra or {}) do b[k] = v end
		return b
	end)
	return d
end

-- Wuber on 2.3.0, the window folded and open
local function appRider(w, opts)
	local r = T.rider(w, TESTCHAR, opts or {})
	r.W.VERSION = "2.3.0"
	r.W.db.fold = { v = 1, pages = {}, narrow = true }
	return r
end

local function openApp(w, r)
	r.W.UI.Toggle(true)
	w:advance(3)
end

-- a ride booked with Anita, accepted, in her group: the rider's Found screen
local function bookedRide(w, d, r)
	local ride = r.W.RequestRide("anita lift")
	w:advance(1)
	local inc = d.W.incoming[1]
	ok(inc and ride and inc.id == ride.id, "the driver has the request")
	d.W.AcceptRequest(ride.id, 5)
	w:group({ ANITA, TESTCHAR })
	w:advance(2)
	return ride, inc
end

test("r8 c e2e: a hot drop on the driver's beacon warns on Confirm; Request is still there", function()
	local w = newWorld()
	local d = netDriver(w, { danger = 2, dangerSecs = 120 })
	local r = appRider(w)
	T.settle(w)
	online(d)
	local dr = r.W.drivers["anita lift"]
	ok(dr and dr.danger == 2, "level 2 came over D field 18")
	openApp(w, r)
	r.W.UI.Show("confirm", "anita lift")
	w:advance(1.5)
	local s = r.W.UI.state.screens.confirm
	forgiveArt(w)
	ok(H.visible(s.pvp), "the PvP card: " .. texts(r))
	eq(s.pvp.head.wuberText, "Hot drop", "its head")
	ok(tostring(s.pvp.body.wuberText):match("^Anita's crew fought enemy players %d+ min ago%. You may land in a fight%.$"),
		"its words: " .. tostring(s.pvp.body.wuberText))
	ok(has(r, "Request summon · 50s", true), "a warning, never a block: " .. texts(r))
	forgiveArt(w)
	clean(w)
end)

test("r8 c e2e: the passphrase on the rider's Found screen is the words the driver sees", function()
	local w = newWorld()
	local d = netDriver(w)
	local r = appRider(w)
	T.settle(w)
	online(d)
	openApp(w, r)
	local ride, inc = bookedRide(w, d, r)
	eq(r.W.UI.state.screen, "found", "the Found screen")
	local s = r.W.UI.state.screens.found
	local words = d.W.Passphrase(inc.id, inc.buyerKey)
	ok(words and words:match("^%u%l+ %u%l+$"), "two words: " .. tostring(words))
	-- round 9: off by default; the driver's "Show ride passphrase" setting rides on its beacon (D field 19)
	ok(not H.visible(s.pass), "off by default: no passphrase")
	-- the driver's next beacon after a change refreshes the rider's cached flag (C10)
	local function nextBeacon()
		local heard = r.W.drivers[r.W.ride.driverKey] and r.W.drivers[r.W.ride.driverKey].heard
		for _ = 1, 12 do
			w:advance(10)
			local e = r.W.drivers[r.W.ride.driverKey]
			if e and e.heard ~= heard then break end
		end
		r.W.UI.Refresh(true)
		w:advance(1)
	end
	d.W.Drive.SetOpt("showPass", true)
	nextBeacon()
	eq(r.W.ride.showPass, true, "the driver turned it on: the beacon carries it")
	ok(H.visible(s.pass) and has(r, words, true), "the same words on the rider's screen: " .. texts(r))
	d.W.Drive.SetOpt("showPass", false)
	nextBeacon()
	eq(r.W.ride.showPass, nil, "a beacon without the flag turns it off")
	ok(not H.visible(s.pass), "off again: no passphrase")
	clean(w)
end)

test("r8 c e2e: the live tracker on Found follows the driver's G messages, phase by phase", function()
	local w = newWorld()
	local d = netDriver(w)
	local r = appRider(w)
	T.settle(w)
	online(d)
	openApp(w, r)
	local ride = bookedRide(w, d, r)
	local s = r.W.UI.state.screens.found
	local want = {
		{ "t", 0, "Anita is getting ready" }, { "c", 0, "Opening rift..." }, { "h", 1, "Opening rift... 1/2 clickers tapped" },
		{ "h", 2, "Opening rift... 2/2 clickers tapped" }, { "s", 2, "Summon sent - accept it!" },
	}
	for _, p in ipairs(want) do
		d.W.SendRitual(ride.id, TESTCHAR, p[1], p[2], 2, ANITA, 0)
		w:advance(2)
		ok(H.visible(s.kitchen), "the tracker shows (" .. p[1] .. ")")
		eq(s.kitchen.text.wuberText, p[3], "phase " .. p[1] .. " " .. p[2])
	end
	ok(s.kitchen.pips[1]:GetAlpha() > 0.9 and s.kitchen.pips[2]:GetAlpha() > 0.9, "both pips lit")
	clean(w)
end)

test("r8 c e2e: raincheck: asked on Sorry, accepted on the offer card, used on rebooking: nothing to pay", function()
	local w = newWorld()
	local d = T.driver(w, ANITA, { netOnly = true })
	local r = appRider(w, { money = 100000 })
	T.settle(w)
	online(d)
	-- a stand-in for the driver's book (Drive.Raincheck decides eligibility; tested by F)
	local book = {}
	d.W.Listen("RAINCHECK", function(op, a, key, addr)
		if op == "ask" then
			book.given = { id = "Rc0000C1", rider = key }
			d.W.Raincheck.Give(a, addr, "Rc0000C1", d.env.time() + 7 * 86400, 5000, "Anita Lift")
		elseif op == "accept" and book.given and book.given.id == a and book.given.rider == key then
			book.active = true
		end
	end)
	openApp(w, r)
	local ride = r.W.RequestRide("anita lift")
	w:advance(1)
	d.W.AcceptRequest(ride.id, 5)
	w:group({ ANITA, TESTCHAR })
	w:move(ANITA, "Orgrimmar")
	w:advance(2)
	ok(w:openTrade(w:player(ANITA), w:player(TESTCHAR)), "a trade")
	w:tradeMoney(w:player(TESTCHAR), 5000)
	w:tradeAccept(w:player(ANITA))
	w:tradeAccept(w:player(TESTCHAR))
	w:advance(1)
	ok(r.W.ride.paid, "paid by trade")
	ok(r.W.CancelRide(), "the summon never came: the ride ends")
	w:advance(1)
	eq(r.W.UI.state.screen, "sorry", "Sorry")
	local sorry = r.W.UI.state.screens.sorry
	ok(H.visible(sorry.ask), "Ask for a raincheck: " .. texts(r))
	sorry.ask:Click()
	w:advance(2)
	ok(book.given and book.given.rider ~= nil, "the driver heard the ask")
	ok(has(r, "Anita offers a raincheck", true), "the offer card: " .. texts(r))
	r:clickText("Accept")
	w:advance(2)
	ok(book.active, "the driver's book has Wuber's accept")
	-- rebook: Anita back at Ratchet, Wuber out of her group
	w:move(ANITA, "Ratchet")
	w:leave(TESTCHAR)
	r.W.ClearRide()
	w:advance(65)
	r.W.UI.Show("confirm", "anita lift")
	w:advance(1.5)
	local s = r.W.UI.state.screens.confirm
	ok(H.visible(s.rc) and has(r, "Use raincheck (covers 50s)", true), "Confirm offers the raincheck: " .. texts(r))
	ok(s.rc.toggle.on, "on by default")
	ok(has(r, "Raincheck covers 50s · nothing to pay", true), "what to pay: " .. texts(r))
	local ride2, why = r.W.RequestRide("anita lift")
	ok(ride2, "booked again: " .. tostring(why))
	w:advance(1)
	local inc = d.W.incoming[1]
	eq(inc and inc.voucher, "Rc0000C1", "the request names the raincheck")
	d.W.AcceptRequest(ride2.id, 5, nil, nil, book.active and inc.voucher == book.given.id and inc.buyerKey == book.given.rider)
	w:advance(1)
	local rv = { price = r.W.ride.price, raw = r.W.ride }
	eq(r.W.UI.RaincheckLine(rv), "Raincheck covers 50s · nothing to pay", "the driver took it")
	eq(r.W.UI.PayTotal(rv), 0, "nothing to type")
	clean(w)
end)

test("r8 c e2e: a bounty pinned on Home is served: the rider's toast names the driver and the chip goes", function()
	local w = newWorld()
	local d = T.driver(w, ANITA, { spot = "Gadgetzan" })
	local r = appRider(w)
	T.settle(w)
	local toasts = {}
	local realToast = r.W.UI.Toast
	r.W.UI.Toast = function(text, ...)
		toasts[#toasts + 1] = tostring(text)
		return realToast(text, ...)
	end
	openApp(w, r)
	local home = r.W.UI.state.screens.home
	r.W.UI.SetSearch("Gadgetzan")
	w:advance(1)
	ok(has(r, "Nobody summons to Gadgetzan right now", true), "the empty state: " .. texts(r))
	home.empty.bounty.picks[2]:Click()
	w:advance(0.5)
	home.empty.bounty.pin:Click()
	w:advance(2)
	local mine = r.W.Bounty.Mine()
	ok(mine and mine.place == "Gadgetzan" and mine.copper == 7500, "pinned 75s for Gadgetzan")
	eq(#d.W.Bounty.Demand(), 1, "Anita sees what Wuber wants")
	r.W.UI.SetSearch("")
	w:advance(1)
	ok(H.visible(home.bountyChip), "the chip on the list")
	w:advance(60)
	online(d)
	w:advance(5)
	eq(r.W.Bounty.Mine(), nil, "the bounty is over")
	local said
	for _, t in ipairs(toasts) do
		if t:find("Anita now summons to Gadgetzan", 1, true) then said = true end
	end
	ok(said, "the toast: " .. table.concat(toasts, " / "))
	ok(not H.visible(home.bountyChip), "the chip is gone")
	clean(w)
end)

test("r8 c: unfolded Wrapped - the slide on the left, the month as a list on the right; a row shows its slide", function()
	local w, r = wideWorld()
	local W = r.W
	local env = r.env
	local realDate = env.date
	env.date = function(fmt, t)
		if fmt == "*t" and t == nil then return { year = 2026, month = 11, day = 3, hour = 12, min = 0, sec = 0, wday = 3 } end
		return realDate(fmt, t)
	end
	W.db.rides = {}
	for i = 1, 4 do
		W.db.rides[i] = { at = os.time({ year = 2026, month = 10, day = i, hour = 12, min = 0, sec = 0 }), dest = "Undercity",
			driver = MIA, driverKey = "mia runner", price = 5000, saved = 600 }
	end
	W.RebuildTotals()
	W.UI.SelectTab("Trips")
	w:advance(1.5)
	ok(W.UI.Fold.IsUnfolded(), "trips unfolded")
	local WR = W.Mod("UI.Rider.Wrapped")
	ok(H.visible(W.UI.trips.wrapCard), "the Wrapped card (in the side pane)")
	ok(R(W.UI.trips.wrapCard).l >= sideLeft(r) - 0.5, "on the right")
	ok(WR.Open(2026, 10), "the story opens")
	w:advance(0.5)
	local st, sum = WR.Story(), WR.Summary()
	ok(H.visible(st) and inLeft(r, st), "the slide on the left")
	ok(sum and H.visible(sum), "the month list on the right")
	ok(R(sum).l >= sideLeft(r) - 0.5, "in the side pane")
	eq(sum.rows[1].big.wuberText, "4 summons", "row 1")
	ok(#r:findText("in short", false, true) > 0, "its head: " .. texts(r))
	sum.rows[3]:Click()
	w:advance(0.5)
	eq(st.index, 3, "a row shows its slide")
	WR.Close()
	w:advance(0.5)
	ok(not H.visible(sum), "closing the story hides the list")
	-- folded: no list
	WR.Open(2026, 10)
	W.UI.Fold.Toggle()
	w:advance(1)
	ok(not W.UI.Fold.IsUnfolded() and not H.visible(sum), "folded: the slide only")
	WR.Close()
	clean(w)
end)

---------------------------------------------------------------------------
-- The app opens on the pay screen (the author's test 18 Nov #1: "Wuber didn't open for the passenger
-- when he got there"): arrived with a fare due, once per ride; not when paid or free; not in
-- combat (after it); an open window is left alone; the driver's trade opens it too.
---------------------------------------------------------------------------

local function shown(r) return r.W.UI.IsShown() == true end

test("r8 c: pay open - arrived with a fare due opens the app on the pay screen, once per ride", function()
	local w, r = riderWorld()
	ok(not shown(r), "closed to begin with")
	withRide(w, r, "arrived")
	w:advance(1.5)
	ok(shown(r), "arrival opened the app")
	eq(r.W.UI.state.screen, "found", "on the ride's pay screen")
	eq(r.W.UI.state.tab, "Ride", "the Ride tab")
	ok(has(r, "Type in trade window", true), "what to do: " .. texts(r))
	-- closed by the player: not again for this ride
	r.W.UI.Toggle(false)
	w:advance(1.5)
	eq(r.W.UI.OpenForPay("arrived"), false, "once per ride")
	r.W.Fire("RIDE")
	w:advance(1)
	ok(not shown(r), "stays closed")
	-- a new ride arriving opens it again
	withRide(w, r, "arrived", { id = "r8b" })
	w:advance(1.5)
	ok(shown(r), "the next ride's arrival opens it")
	eq(#w.errors, 0, "no errors")
	clean(w)
end)

test("r8 c: pay open - not when paid or free; in combat it waits for combat to end", function()
	local w, r = riderWorld()
	withRide(w, r, "arrived", { price = 0 })
	w:advance(1.5)
	ok(not shown(r), "nothing due: closed")
	withRide(w, r, "arrived", { id = "r8p", paid = true })
	w:advance(1.5)
	ok(not shown(r), "paid: closed")
	-- combat
	w:enterCombat(r)
	withRide(w, r, "arrived", { id = "r8c" })
	w:advance(2)
	ok(not shown(r), "not in combat")
	w:leaveCombat(r)
	w:advance(1.5)
	ok(shown(r), "after combat it opens")
	eq(r.W.UI.state.screen, "found", "on the pay screen")
	eq(#w.errors, 0, "no errors")
	clean(w)
end)

test("r8 c: pay open - an open window is left alone; the driver's trade opens it, a stranger's doesn't", function()
	local w, r = riderWorld()
	r.W.UI.Toggle(true)
	w:advance(3)
	r.W.UI.SelectTab("Trips")
	w:advance(1)
	withRide(w, r, "arrived")
	w:advance(1.5)
	eq(r.W.UI.state.tab, "Trips", "the player's tab stays")
	-- closed, then the driver opens a trade
	r.W.UI.Toggle(false)
	w:advance(1.5)
	local stranger = w:addClient("Sam Stranger", { spot = "Orgrimmar", class = "MAGE" })
	local mia = w:addClient(MIA, { spot = "Orgrimmar", class = "WARLOCK" })
	w:advance(1)
	r.W.ride.state = "arrived"
	r.env.TradeFrame:Show()
	ok(w:openTrade(stranger, r), "a stranger's trade")
	w:advance(1)
	ok(not shown(r), "a stranger's trade doesn't open the app")
	w:tradeCancel(r)
	r.env.TradeFrame:Show()
	w:advance(0.5)
	ok(w:openTrade(mia, r), "the driver's trade")
	w:advance(1)
	ok(shown(r), "the driver's trade opens the app")
	eq(r.W.UI.state.tab, "Ride", "on the Ride tab")
	ok(r.W.UI.state.screen == "found", "the pay screen")
	clean(w)
end)

test("r8 c: unfolded maps keep their layers above the canvas (rider dot, place pill, pins); folded again too", function()
	local w, r = wideWorld()
	local W = r.W
	ok(W.UI.Fold.IsUnfolded(), "ride unfolded")
	local m = W.UI.state.screens.home.map
	local function above(mm, what)
		local c = mm.canvas:GetFrameLevel()
		ok(mm.dots:GetFrameLevel() > c and mm.shade:GetFrameLevel() > c, what .. ": dots " .. mm.dots:GetFrameLevel() .. ", shade " .. mm.shade:GetFrameLevel() .. ", canvas " .. c)
		ok(mm.dots:GetFrameLevel() > mm.shade:GetFrameLevel(), what .. ": the dots over the shade")
	end
	above(m, "ride unfolded")
	W.UI.Show("confirm", "mia runner")
	w:advance(1.5)
	local cm = W.UI.state.screens.confirm.map
	above(cm, "confirm unfolded")
	W.UI.Fold.Toggle()
	w:advance(1.5)
	ok(not W.UI.Fold.IsUnfolded(), "folded")
	above(cm, "confirm folded")
	W.UI.Show("home")
	w:advance(1.5)
	above(m, "ride folded")
	eq(#w.errors, 0, "no errors")
	clean(w)
end)

test("r8 c: Via - a route across continents is a crossing before any price is known; the side map shows World and the route", function()
	local w, r = wideWorld()
	local W = r.W
	local Booking = W.Mod("UI.Rider.Booking")
	-- no learned price (FlightCost says nothing of a boat); the route's ends: Orgrimmar (Kalimdor) -> Undercity
	W.FlightCost = function() return nil end
	W.FlightRoute = function(_, to) if to == "Undercity" then return { 23, 11 } end return { 23, 25 } end
	W.TravelSaved = function() return 540 end
	eq(Booking.Via("Undercity"), "zeppelin", "two continents, Horde flight masters: zeppelin")
	eq(Booking.Via("Crossroads"), nil, "one continent: no crossing")
	-- (round 26, item 4) the route decides the word, so the boat case is a route over a boat (Ratchet - Booty Bay)
	local zepRoute = W.FlightRoute
	W.FlightRoute = function() return { 80, 18 } end
	W.TravelSaved = function() return 540, "by boat" end
	eq(Booking.Via("Undercity"), "boat", "the travel estimate says boat")
	W.FlightRoute = zepRoute
	W.TravelSaved = function() return 540 end
	-- no route known: no crossing
	local route = W.FlightRoute
	W.FlightRoute = function() return nil end
	local pair = W.FLY and W.FLY.Pair
	if W.FLY then W.FLY.Pair = function() return nil end end
	eq(Booking.Via("Undercity"), nil, "no route: nil")
	W.FlightRoute = route
	if W.FLY then W.FLY.Pair = pair end
	-- the unfolded Confirm opens World with the route to Undercity
	W.UI.Show("confirm", "mia runner")
	w:advance(1.5)
	ok(W.UI.Fold.IsUnfolded(), "confirm unfolded")
	local CM = W.Mod("UI.Rider.Confirm")
	local wm = W.Mod("UI.Rider.WorldMap").cache.maps[CM.side.holder]
	ok(wm, "the side pane's world map")
	eq(wm.mode, "world", "World across the sea")
	eq(wm.route and wm.route.to, "Undercity", "the route to Undercity")
	eq(#w.errors, 0, "no errors")
	clean(w)
end)
