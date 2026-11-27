-- Tests of UI.Rider.Ride (Wuber/UI/Rider/Ride.lua). Loaded by tests/run.lua with its helper table T.
-- Final home: tests/ui/rider/ride_test.lua; add it to the per-module list in tests/run.lua.
-- Pins: UI.RitualText (the live tracker's line per phase, clamps, nil for a missing or unknown phase);
-- Pins: UI.FlexText (the arrival share line: "about" for a worked-out time, no time under a minute, none when spammy);
-- Pins: Mod.verAtLeast (dotted version compare, numeric not textual);
-- Pins: UI.DoAction (combat lockdown, a refused game call says why, a good one stays quiet);
-- Pins: the Driver-found screen per ride state (titles, button label, pay card amount, tip keys, queue line, passphrase,
-- Pins:   live tracker only in Advanced, Leave your group first, back chevron keeps the ride).
-- Why it matters to a player: this is the screen a rider stares at from "driver accepted" to "paid". If it broke, the rider
-- would see the wrong next step (or none), type the wrong fare, press Accept summon in combat, or lose the ride by tapping Back.
local T = ...
local test, eq, ok = T.test, T.eq, T.ok

local MIA = "Mia Runner"

-- a ride in W.ride, the phone open on it; returns world, rider and the Found screen
local function found(f, opts)
	opts = opts or {}
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, {})
	w:advance(15)
	if opts.advanced ~= nil then r.W.SetAdvanced(opts.advanced) end
	local ride = { id = "r6", driver = MIA, driverKey = "mia runner", dest = "Undercity", price = 5000, state = "accepted", at = r.env.GetTime() }
	for k, v in pairs(f or {}) do ride[k] = v end
	r.W.ride = ride
	r.W.Fire("RIDE")
	r.W.UI.Toggle(true)
	w:advance(3)
	return w, r, r.W.UI.state.screens.found
end

-- every UI.Toast of the rider while fn runs: { text, kind }
local function toasts(r, fn)
	local UI, seen = r.W.UI, {}
	local orig = UI.Toast
	UI.Toast = function(msg, kind, ...) seen[#seen + 1] = { tostring(msg), kind } return orig(msg, kind, ...) end
	fn()
	UI.Toast = orig
	return seen
end

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.rider.ride: contract (registered, deps, header, public names)", function()
	local W, w, r, Mod = T.contract("UI.Rider.Ride", "tests/ui/rider/ride_test.lua", {
		["UI.DoAction"] = "function", ["UI.FlexText"] = "function", ["UI.RitualText"] = "function",
		["Mod.buildFound"] = "function", ["Mod.invitePending"] = "function", ["Mod.verAtLeast"] = "function", ["Mod.fitHeader"] = "function",
	})
	ok(Mod, "W.Mod(\"UI.Rider.Ride\")")
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.rider.ride: verAtLeast compares dotted versions by number, equal passes, junk fails", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, {})
	local v = r.W.Mod("UI.Rider.Ride").verAtLeast
	eq(v("2.3.0", "2.2.1"), true, "newer minor") -- Ride.lua:158-170
	eq(v("2.2.1", "2.2.1"), true, "equal")
	eq(v("2.2.0", "2.2.1"), false, "older patch")
	eq(v("2.10.0", "2.9.9"), true, "10 is more than 9 (numbers, not text)")
	eq(v("2.4", "2.4.0"), true, "a missing part counts as 0")
	eq(v(nil, "2.2.1"), false, "no version")
	eq(v("junk", "2.2.1"), false, "no digits")
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.rider.ride: RitualText says each phase of the summon in plain words", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, {})
	local UI = r.W.UI
	local function rv(g, extra)
		local x = { short = "Mia", raw = { ritual = g } }
		for k, v in pairs(extra or {}) do x[k] = v end
		return x
	end
	local t, tapped, need = UI.RitualText(rv({ phase = "q" }, { position = 2 }))
	eq(t, "In the queue \194\183 2nd", "queue with place") -- Ride.lua:183
	eq(tapped, 0)
	eq(need, 2, "need defaults to 2")
	eq((UI.RitualText(rv({ phase = "q" }, { position = 0 }))), "In the queue", "no place under 1")
	eq((UI.RitualText(rv({ phase = "t" }))), "Mia is getting ready", "no caster named: the driver")
	eq((UI.RitualText(rv({ phase = "c" }))), "Opening rift...")
	t, tapped, need = UI.RitualText(rv({ phase = "h", tapped = 1, need = 2 }))
	eq(t, "Opening rift... 1/2 clickers tapped")
	eq(tapped, 1)
	eq(need, 2)
	t, tapped, need = UI.RitualText(rv({ phase = "s", tapped = 0, need = 3 }))
	eq(t, "Summon sent - accept it!")
	eq(tapped, 3, "all pips lit when sent")
	eq(need, 3)
	t, tapped = UI.RitualText(rv({ phase = "f", tapped = 2, need = 2 }))
	eq(t, "The rift closed - trying again")
	eq(tapped, 0, "pips go dark after a failed try")
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.rider.ride: RitualText clamps counts to 0-9 and gives nothing for a missing, unknown or malformed ritual", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, {})
	local UI = r.W.UI
	local t, tapped, need = UI.RitualText({ short = "Mia", raw = { ritual = { phase = "h", tapped = 99, need = 99 } } })
	eq(tapped, 9, "tapped clamped") -- Ride.lua:179
	eq(need, 9, "need clamped")
	eq(t, "Opening rift... 9/9 clickers tapped")
	t, tapped, need = UI.RitualText({ short = "Mia", raw = { ritual = { phase = "h", tapped = -4, need = -1 } } })
	eq(tapped, 0, "negative tapped")
	eq(need, 0, "negative need")
	eq(UI.RitualText(nil), nil, "no ride")
	eq(UI.RitualText({ short = "Mia" }), nil, "no raw ride")
	eq(UI.RitualText({ short = "Mia", raw = {} }), nil, "no ritual")
	eq(UI.RitualText({ short = "Mia", raw = { ritual = "q" } }), nil, "ritual not a table")
	eq(UI.RitualText({ short = "Mia", raw = { ritual = { phase = "zzz" } } }), nil, "unknown phase")
	eq(UI.RitualText({ short = "Mia", raw = { ritual = { phase = 5 } } }), nil, "phase not text")
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.rider.ride: FlexText is the share line, 'about' only for a worked-out time, no time under a minute", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, {})
	local UI = r.W.UI
	local function has(line, part) return line ~= nil and line:find(part, 1, true) ~= nil end
	local line = UI.FlexText({ dest = "Undercity", short = "Anita", saved = 540, raw = {} })
	ok(has(line, "Summoned to Undercity by Anita with Wuber"), "the start: " .. tostring(line)) -- Ride.lua:279-293
	ok(has(line, "about 9 min saved"), "a worked-out time says about: " .. tostring(line))
	line = UI.FlexText({ dest = "Undercity", short = "Anita", saved = 540, raw = { savedHow = "own" } })
	ok(has(line, "9 min saved") and not has(line, "about"), "a timed trip is exact: " .. tostring(line))
	line = UI.FlexText({ dest = "Undercity", short = "Anita", saved = 540, raw = { savedHow = "shared" } })
	ok(has(line, "9 min saved") and not has(line, "about"), "a shared time is exact: " .. tostring(line))
	line = UI.FlexText({ dest = "Undercity", short = "Anita", saved = 59, raw = {} })
	ok(line and not has(line, "saved"), "under a minute says no time: " .. tostring(line))
	line = UI.FlexText({ dest = "Undercity", short = "Anita", summoner = "Mia", saved = 540, raw = {} })
	ok(has(line, "by Mia with Wuber"), "the summoner, not the driver, is named: " .. tostring(line))
	ok(not has(line, "gold") and not has(line, "|H"), "no price, no link")
	eq(UI.FlexText({ short = "Anita", raw = {} }), nil, "no destination, no line")
	eq(UI.FlexText(nil), nil, "no ride, no line")
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.rider.ride: FlexText offers nothing when the line would read as spam", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, {})
	local UI = r.W.UI
	local asked
	r.W.SentenceSpam = function(line) asked = line return "repeat" end
	eq(UI.FlexText({ dest = "Undercity", short = "Anita", saved = 540, raw = {} }), nil, "spammy: nothing to share") -- Ride.lua:290
	ok(asked and asked:find("Summoned to Undercity", 1, true), "the line was checked")
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.rider.ride: DoAction refuses summon and pay in combat and says why", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, {})
	w:advance(15)
	local called = 0
	r.W.AcceptSummon = function() called = called + 1 return true end
	r.W.PayFare = function() called = called + 1 return true, "x" end
	w:enterCombat(r)
	local seen = toasts(r, function()
		r.W.UI.DoAction("summon")
		r.W.UI.DoAction("pay")
	end)
	w:leaveCombat(r)
	eq(called, 0, "no game call in combat") -- Ride.lua:1238, 1269
	eq(#seen, 2, "two toasts")
	eq(seen[1][1], "Leave combat first")
	eq(seen[1][2], "warn")
	eq(seen[2][1], "Leave combat first")
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.rider.ride: DoAction toasts the game's refusal, stays quiet when the call worked, ignores an unknown action", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, {})
	w:advance(15)
	local W = r.W
	local seen = toasts(r, function()
		W.AcceptSummon = function() return false, "No summon waiting" end
		W.UI.DoAction("summon")
		W.AcceptInvite = function() return false end
		W.UI.DoAction("invite")
		W.AcceptSummon = function() return true end
		W.AcceptInvite = function() return true end
		W.UI.DoAction("summon")
		W.UI.DoAction("invite")
		W.UI.DoAction("nonsense")
		W.UI.DoAction(nil)
	end)
	eq(#seen, 2, "only the two refusals toast: " .. #seen)
	eq(seen[1][1], "No summon waiting") -- Ride.lua:1273-1274
	eq(seen[1][2], "warn")
	eq(seen[2][1], "Click Accept on the invite window", "no reason given: the fallback") -- Ride.lua:1256
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.rider.ride: Found screen, driver accepted: title, wait line, and the button waits for the invite", function()
	local w, r, s = found({ state = "accepted", eta = 45 })
	eq(s.title:GetText(), "Mia accepted") -- Ride.lua:130
	eq(s.sub:GetText(), "A group invite is on its way in about 45 s.")
	eq(s.tip.head:GetText(), "Keep this window handy")
	eq(s.action.label:GetText(), "Waiting for the invite") -- Ride.lua:912
	eq(s.action.what, nil, "nothing to click yet")
	ok(s.cancel:IsShown(), "the rider can still cancel before the summon")
	ok(not s.endRide:IsShown(), "End ride is for after arriving")
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.rider.ride: Found screen, no ETA says 'shortly'; in the group and summoning say what comes next", function()
	local w, r, s = found({ state = "accepted" })
	eq(s.sub:GetText(), "A group invite is on its way shortly.")
	T.clean(w)
	w, r, s = found({ state = "ingroup" })
	eq(s.title:GetText(), "You're in the group")
	eq(s.tip.head:GetText(), "Stay put")
	eq(s.action.label:GetText(), "Waiting for the portal")
	T.clean(w)
	w, r, s = found({ state = "summoning" })
	eq(s.title:GetText(), "Your summon is under way")
	eq(s.sub:GetText(), "Your portal to Undercity is coming.")
	eq(s.action.label:GetText(), "Summon on its way")
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.rider.ride: Found screen, portal up: Accept summon is the button and clicking it accepts", function()
	local w, r, s = found({ state = "portal" })
	eq(s.title:GetText(), "The portal is up")
	eq(s.sub:GetText(), "Ready to teleport to Undercity")
	eq(s.action.label:GetText(), "Accept summon")
	eq(s.action.what, "summon")
	local called = 0
	r.W.AcceptSummon = function() called = called + 1 return true end
	s.action:GetScript("OnClick")(s.action)
	eq(called, 1, "one accept")
	T.clean(w)
	-- the game's summon window hid the name: the line says who is summoning
	w, r, s = found({ state = "portal", summonNoName = true, summoner = "Bea Jones" })
	eq(s.sub:GetText(), "Bea is summoning you to Undercity") -- Ride.lua:124
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.rider.ride: Found screen, rider grouped with somebody else: the button says Leave your group first", function()
	local w = T.newWorld()
	local d = T.driver(w, T.ANITA, { spot = "Ratchet" })
	local r = T.rider(w, T.TESTCHAR, {})
	w:advance(15)
	w:group({ T.TESTCHAR, T.ANITA })
	w:advance(1)
	r.W.ride = { id = "r6", driver = MIA, driverKey = "mia runner", dest = "Undercity", price = 5000, state = "accepted", at = r.env.GetTime() }
	r.W.Fire("RIDE")
	r.W.UI.Toggle(true)
	w:advance(3)
	local s = r.W.UI.state.screens.found
	eq(s.action.label:GetText(), "Leave your group first") -- Ride.lua:883-887
	eq(s.action.what, "leave")
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.rider.ride: Found screen, arrived: the pay card shows the fare, a 20% tip raises what to type, End ride shows", function()
	local w, r, s = found({ state = "arrived", payee = MIA, payto = "Mia", summoner = MIA })
	local W = r.W
	W.UI.SetTipPct(0)
	w:advance(1)
	eq(s.title:GetText(), "You've arrived")
	ok(s.pay:IsShown(), "the pay card")
	eq(s.pay.big:GetText(), W.Money(5000), "no tip: the fare") -- Ride.lua:856
	eq(s.action.label:GetText(), "Waiting for Mia to trade")
	ok(s.endRide:IsShown(), "End ride")
	ok(not s.cancel:IsShown(), "no Cancel after arriving (summon done)")
	-- the 20% key
	local k = s.tipKeys[3]
	eq(k.pct, 20)
	k:GetScript("OnClick")(k)
	w:advance(1)
	eq(W.db.tipPct, 20, "remembered")
	eq(s.pay.big:GetText(), W.Money(6000), "5000 + 20% rounded up to whole silver") -- Pay.lua:60
	k = s.tipKeys[1]
	k:GetScript("OnClick")(k)
	w:advance(1)
	eq(s.pay.big:GetText(), W.Money(5000), "No tip puts it back")
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.rider.ride: Found screen, a ride that costs nothing says Nothing to pay and offers no tip keys", function()
	local w, r, s = found({ state = "arrived", price = 0, payee = MIA, payto = "Mia", summoner = MIA })
	eq(s.pay.big:GetText(), "Nothing to pay") -- Ride.lua:856 (33-words F30, r52 H)
	for i, b in ipairs(s.tipKeys) do ok(not b:IsShown(), "tip key " .. i .. " hidden") end
	ok(s.endRide:IsShown(), "the rider can still end the ride")
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.rider.ride: Found screen, the back chevron shows Home and leaves the ride running", function()
	local w, r, s = found({ state = "ingroup" })
	local ui = r.W.Mod("UI.Kit").ui
	eq(ui.screen, "found", "control: on the Found screen")
	s.back:GetScript("OnClick")(s.back) -- (a click through the harness lands on whatever frame is over it; the script is what the button runs)
	w:advance(1)
	eq(ui.screen, "home", "Back shows Home") -- Ride.lua:485, Window.lua:577 wantedScreen and 1084 UI.Show("home") set ui.peek
	eq(r.W.ride.state, "ingroup", "the ride carries on")
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.rider.ride: Found screen, your place in line: 'You're next' and '2nd in line' with a countdown", function()
	local w, r, s = found({ state = "accepted", position = 1, eta = 120 })
	ok(s.queue:IsShown(), "queue line")
	ok(s.queue.text:GetText():find("You're next", 1, true), "first: " .. s.queue.text:GetText()) -- Ride.lua:1189
	ok(s.queue.clock:GetText():find("^%d+:%d%d$"), "clock m:ss: " .. tostring(s.queue.clock:GetText()))
	T.clean(w)
	w, r, s = found({ state = "accepted", position = 2, eta = 120 })
	ok(s.queue.text:GetText():find("You're 2nd in line \194\183 about 2 min", 1, true), "second: " .. s.queue.text:GetText())
	T.clean(w)
	w, r, s = found({ state = "accepted", position = 0 })
	ok(not s.queue:IsShown(), "no place, no queue line")
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.rider.ride: Found screen, the passphrase shows only when the driver shows it and only before arriving", function()
	local function words(f)
		local w = T.newWorld()
		local r = T.rider(w, T.TESTCHAR, {})
		w:advance(15)
		r.W.Passphrase = function() return "Violet Otter" end
		local ride = { id = "r6", driver = MIA, driverKey = "mia runner", dest = "Undercity", price = 5000, state = "ingroup", at = r.env.GetTime() }
		for k, v in pairs(f) do ride[k] = v end
		r.W.ride = ride
		r.W.Fire("RIDE")
		r.W.UI.Toggle(true)
		w:advance(3)
		local s = r.W.UI.state.screens.found
		local shown, text = s.pass:IsShown(), s.pass:GetText()
		T.clean(w)
		return shown, text
	end
	local shown, text = words({ showPass = true })
	ok(shown, "shown when the driver turns it on")
	ok(text:find("Violet Otter", 1, true) and text:find("^Passphrase: "), "the words: " .. tostring(text)) -- Ride.lua:259
	shown = words({})
	ok(not shown, "off by default")
	shown = words({ showPass = true, state = "accepted" })
	ok(not shown, "not before the group is joined (rank < ingroup)")
	shown = words({ showPass = true, state = "arrived" })
	ok(not shown, "gone once arrived")
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.rider.ride: Found screen, the live summon tracker needs Advanced and follows the RITUAL event", function()
	local g = { phase = "h", tapped = 1, need = 2 }
	local w, r, s = found({ state = "ingroup", ritual = g }, { advanced = true })
	ok(s.kitchen:IsShown(), "tracker shown in Advanced")
	eq(s.kitchen.text:GetText(), "Opening rift... 1/2 clickers tapped")
	g.phase, g.tapped = "s", 2
	r.W.Fire("RITUAL")
	w:advance(1)
	eq(s.kitchen.text:GetText(), "Summon sent - accept it!", "the tracker moved on") -- Ride.lua:1290 W.Listen("RITUAL")
	T.clean(w)
	w, r, s = found({ state = "ingroup", ritual = { phase = "h", tapped = 1, need = 2 } }, { advanced = false })
	ok(not s.kitchen:IsShown(), "no tracker in the plain look") -- Ride.lua:221
	T.clean(w)
end)

-- NEEDS FAKE-GAME: a stranger's trade (TradeFrame open with a partner who is not the driver) so the amber "isn't your driver"
-- card and the dimmed pay card can be driven; the harness has no trade-window fake that sets UnitName("npc").
-- NEEDS FAKE-GAME: the PARTY_INVITE static popup (StaticPopup_FindVisible) to pin invitePending when Wuber did not auto-accept.
