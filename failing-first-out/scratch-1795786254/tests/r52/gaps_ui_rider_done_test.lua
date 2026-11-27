-- Final home: tests/ui/rider/done_test.lua; add it to the per-module list in tests/run.lua.
-- Pins: the Done screen's words (place and what was really paid, to whom; thank-you; time-saved line with "about" unless measured);
-- Pins: the star rating (one rating per ride, the singular/plural thanks, a refused rating can be retried, an already-rated ride is locked);
-- Pins: the unpaid end ("Ride ended", no stars, no saved-to-trips line) and its Done tip;
-- Pins: RaincheckAskable (defers to Net's CanAsk; else paid in full, not unpaid, not arrived, within 30 min, asked once);
-- Pins: the Sorry screen's words per ending (declined reasons, no answer, cancelled with and without a raincheck to ask, failed);
-- Pins: the Ask for a raincheck pill (sent / refused toasts) and the Next best driver card (cheapest other open or busy driver to the same place).
-- Why it matters to a player: this is the last thing a rider sees. If it broke, a rider would be told "nothing to pay" when they paid,
-- could not rate their driver, would see a victory screen for a ride they never paid for, or would not be offered the next driver after a no.
local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H

local MIA = "Mia Runner"
local DOT = "\194\183"

-- a rider with a ride in the given state, the window open on that ride's screen (the shape of tests/d3/d3_f3_rider_fixes_test.lua)
local function rideScreen(state, extra, screen)
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, { screenW = 1365, screenH = 768 })
	w:advance(15)
	local ride = { id = "r9", driver = MIA, driverKey = "mia runner", dest = "Undercity", price = 5000, state = state,
		at = r.env.GetTime(), payee = MIA, payto = "Mia", service = "Mia's Rides" }
	for k, v in pairs(extra or {}) do ride[k] = v end
	r.W.ride = ride
	r.W.db.tipPct = 0
	r.W.DriversSorted = nil -- the plain W.drivers list (Kit.lua:271)
	r.W.Fire("RIDE")
	r.W.UI.Toggle(true)
	w:advance(2)
	r.W.UI.Show(screen)
	w:advance(3)
	return w, r, r.W.UI.state.screens[screen]
end

local function has(r, text) return #r:findText(text, nil, true) > 0 end

local function toasts(r)
	local said = {}
	local UI = r.W.UI
	local toast = UI.Toast
	UI.Toast = function(text, ...) said[#said + 1] = tostring(text) return toast(text, ...) end
	return said
end

local function tipWords(f)
	local tip = f.wuberTip
	return type(tip.text) == "function" and tip.text(f) or tip.text
end

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.rider.done: contract (registered, deps, header, public names)", function()
	local W, w, r, Mod = T.contract("UI.Rider.Done", "tests/ui/rider/done_test.lua", {
		["Mod.buildDone"] = "function", ["Mod.buildSorry"] = "function", ["UI.RaincheckAskable"] = "function",
	})
	ok(Mod, "W.Mod(\"UI.Rider.Done\")")
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.rider.done: a paid ride says where, what was really paid and to whom, and thanks the driver", function()
	local w, r, s = rideScreen("done", { paid = 6000, saved = 840 }, "done")
	eq(s.title.wuberText, "Undercity " .. DOT .. " Paid 60s to Mia", "the tip is in what was paid") -- Done.lua:336-338
	ok(has(r, "riding with Mia"), "the thank-you (" .. T.list(r:visibleTexts()):sub(1, 400) .. ")") -- Done.lua:340
	eq(s.saved.wuberText, "You saved about 14 min of flying " .. DOT .. " saved to your trips", "an estimate says about") -- Done.lua:350
	eq(s.unpaid, false, "not an unpaid end")
	eq(tipWords(s.done), "Back to the drivers. This trip is saved in Trips.", "the Done tip for a paid ride") -- Done.lua:228
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.rider.done: a measured flight time says no about; no time saved says only that it is saved", function()
	local w, r, s = rideScreen("done", { paid = 5000, saved = 840, savedHow = "own" }, "done")
	eq(s.saved.wuberText, "You saved 14 min of flying " .. DOT .. " saved to your trips", "own time: exact") -- Done.lua:348-350
	r.W.ride.savedHow = "shared"
	r.W.UI.RefreshNow()
	w:advance(0.5)
	eq(s.saved.wuberText, "You saved 14 min of flying " .. DOT .. " saved to your trips", "a shared time: exact too")
	r.W.ride.saved = 0
	r.W.UI.RefreshNow()
	w:advance(0.5)
	eq(s.saved.wuberText, "Saved to your trips", "nothing saved: just the note") -- Done.lua:352
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.rider.done: the title falls back to the fare, then to the driver's short name, then to the place alone", function()
	local w, r, s = rideScreen("done", { paid = 0 }, "done")
	eq(s.title.wuberText, "Undercity " .. DOT .. " Paid 50s to Mia", "no trade total: the fare; payee Mia") -- Done.lua:337-338
	r.W.ride.payto, r.W.ride.payee = nil, nil
	r.W.UI.RefreshNow()
	w:advance(0.5)
	eq(s.title.wuberText, "Undercity " .. DOT .. " Paid 50s to Mia", "no payee: the driver's short name") -- Done.lua:338
	r.W.ride.price, r.W.ride.paid = 0, nil
	r.W.UI.RefreshNow()
	w:advance(0.5)
	eq(s.title.wuberText, "Undercity", "a free ride: the place alone") -- Done.lua:338
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.rider.done: one star click rates once (singular thanks); a second click changes nothing", function()
	local w, r, s = rideScreen("done", { paid = 5000 }, "done")
	local calls = {}
	r.W.Rate = function(n) calls[#calls + 1] = n return true end
	ok(has(r, "Tap a star"), "before rating") -- Done.lua:274
	r:clickOn(s.stars[1])
	w:advance(1)
	eq(#calls, 1, "Rate called once")
	eq(calls[1], 1, "with the star clicked")
	ok(has(r, "Thanks! You gave 1 star."), "singular: 1 star (" .. T.list(r:visibleTexts()):sub(1, 400) .. ")") -- Done.lua:186
	r:clickOn(s.stars[5])
	w:advance(1)
	eq(#calls, 1, "a second click on another star sends nothing more") -- Done.lua:178
	ok(not has(r, "You gave 5 stars"), "and the note is unchanged")
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.rider.done: plural thanks; a refused rating says so and may be tried again", function()
	local w, r, s = rideScreen("done", { paid = 5000 }, "done")
	local calls, answer = {}, false
	r.W.Rate = function(n) calls[#calls + 1] = n return answer end
	r:clickOn(s.stars[4])
	w:advance(1)
	ok(has(r, "Couldn't send your rating"), "refused: the note says so") -- Done.lua:186 (ok ~= false)
	answer = true
	r:clickOn(s.stars[4])
	w:advance(1)
	eq(#calls, 2, "the refused click did not lock the stars")
	ok(has(r, "Thanks! You gave 4 stars."), "plural: 4 stars")
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.rider.done: a ride already rated shows its stars, says thanks and ignores clicks", function()
	local w, r, s = rideScreen("done", { paid = 5000, rated = true, stars = 3 }, "done")
	local calls = 0
	r.W.Rate = function() calls = calls + 1 return true end
	ok(has(r, "Thanks for rating"), "the note (" .. T.list(r:visibleTexts()):sub(1, 400) .. ")") -- Done.lua:274
	ok(s.stars[3].fill:IsShown() and not s.stars[4].fill:IsShown(), "three stars are lit") -- Done.lua:151-157, 273
	r:clickOn(s.stars[5])
	w:advance(1)
	eq(calls, 0, "no second rating")
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.rider.done: an unpaid end is no victory - Ride ended, no stars, no saved line, and Done says it is not saved", function()
	local w, r, s = rideScreen("done", { unpaid = true, saved = 840 }, "done")
	eq(s.title.wuberText, "Ride ended", "the title") -- Done.lua:313
	eq(s.unpaid, true, "marked unpaid")
	for i = 1, 5 do ok(not s.stars[i]:IsShown(), "no star " .. i) end -- Done.lua:307
	ok(not s.savedPill:IsShown(), "no 'saved to your trips' line for a ride that is not saved") -- Done.lua:327
	ok(not s.flightPill:IsShown(), "no flight line")
	ok(not s.avatar:IsShown(), "no driver portal")
	eq(tipWords(s.done), "Back to the drivers. An unpaid ride isn't saved in Trips.", "the Done tip") -- Done.lua:228
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.rider.done: the Done button puts the ride away and leaves the rider on the driver list", function()
	local w, r, s = rideScreen("done", { paid = 5000 }, "done")
	r:clickText("Done")
	w:advance(2)
	eq(r.W.ride, nil, "the ended ride is cleared") -- Window.lua:666-672
	eq(r.W.UI.state.screen, "home", "back on the list")
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.rider.done: RaincheckAskable - the fallback rules when Net has no CanAsk", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR)
	w:advance(15)
	local W, UI = r.W, r.W.UI
	W.Raincheck.CanAsk = nil -- an older Net: the screen's own rules (Done.lua:52-57)
	local function rv(over, raw)
		local x = { id = "x", price = 5000, state = "cancelled", raw = { paid = 5000 } }
		for k, v in pairs(over or {}) do x[k] = v end
		for k, v in pairs(raw or {}) do x.raw[k] = v end
		return x
	end
	eq(UI.RaincheckAskable(nil), false, "no ride")
	eq(UI.RaincheckAskable(rv()), true, "paid in full, ended, not arrived: worth asking")
	eq(UI.RaincheckAskable(rv(nil, { paid = 4000 })), false, "paid less than the fare") -- Done.lua:53
	eq(UI.RaincheckAskable(rv({ price = 0 })), false, "a free ride")
	eq(UI.RaincheckAskable(rv(nil, { unpaid = true })), false, "marked unpaid")
	eq(UI.RaincheckAskable(rv(nil, { arrived = true })), false, "the rider arrived: nothing failed") -- Done.lua:54
	eq(UI.RaincheckAskable(rv(nil, { arrivedAt = 123 })), false, "arrived by time")
	eq(UI.RaincheckAskable(rv({ state = "done" })), false, "a finished ride")
	if r.env.time then
		local t = r.env.time()
		eq(UI.RaincheckAskable(rv(nil, { paidAt = t - 29 * 60 })), true, "paid 29 min ago: still in the window") -- Done.lua:56
		eq(UI.RaincheckAskable(rv(nil, { paidAt = t - 31 * 60 })), false, "paid 31 min ago: too late")
	end
	UI.state.rcAsked = { x = true }
	eq(UI.RaincheckAskable(rv()), false, "asked once already") -- Done.lua:49
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.rider.done: RaincheckAskable defers to Net's CanAsk when it exists, and only a true counts", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR)
	w:advance(15)
	local W, UI = r.W, r.W.UI
	W.Raincheck.CanAsk = function(id) if id == "yes" then return true end return false, "late" end
	eq(UI.RaincheckAskable({ id = "yes", price = 0, raw = {} }), true, "Net says yes: yes, whatever the fields say") -- Done.lua:51
	eq(UI.RaincheckAskable({ id = "no", price = 5000, raw = { paid = 5000 } }), false, "Net says no (late): no")
	W.Raincheck.CanAsk = function() return "yes" end
	eq(UI.RaincheckAskable({ id = "yes", raw = {} }), false, "a truthy non-true answer is not a yes") -- Done.lua:51 (== true)
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.rider.done: Sorry says what happened for each ending and each decline reason", function()
	local w, r, s = rideScreen("declined", { reason = "busy" }, "sorry")
	eq(s.title.wuberText, "Mia can't take this one", "declined") -- Done.lua:475
	eq(s.sub.wuberText, "They're busy with another ride.", "busy") -- Done.lua:374
	local function look(state, reason)
		r.W.ride.state, r.W.ride.reason = state, reason
		r.W.UI.RefreshNow()
		w:advance(0.5)
		return s.title.wuberText, s.sub.wuberText
	end
	local _, sub = look("declined", "full")
	eq(sub, "Their group is full right now.", "full")
	_, sub = look("declined", "closed")
	eq(sub, "They've just closed for now.", "closed")
	_, sub = look("declined", "blocked")
	eq(sub, "They can't take your request.", "blocked")
	_, sub = look("declined", "price")
	eq(sub, "Their price has just changed.", "price")
	_, sub = look("declined", "something new")
	eq(sub, "They can't take your ride right now.", "an unknown reason gets the plain words") -- Done.lua:476
	_, sub = look("declined", nil)
	eq(sub, "They can't take your ride right now.", "no reason")
	local title
	title, sub = look("timeout", nil)
	eq(title, "No answer from Mia", "timeout") -- Done.lua:458
	eq(sub, "Drivers sometimes step away. Try another one.", "timeout words")
	title, sub = look("failed", nil)
	eq(title, "This ride didn't work out", "failed") -- Done.lua:471
	eq(sub, "Something went wrong along the way. Try another driver.", "failed words")
	title, sub = look("cancelled", nil)
	eq(title, "Ride cancelled", "cancelled") -- Done.lua:462
	eq(sub, "Nothing to pay. Pick another driver when you're ready.", "cancelled with nothing paid: nothing to pay") -- Done.lua:467
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.rider.done: a cancelled ride the rider paid for does not say 'Nothing to pay' and offers the raincheck pill", function()
	local w, r, s = rideScreen("cancelled", { paid = 5000 }, "sorry")
	r.W.Raincheck.CanAsk = function() return true end
	r.W.UI.RefreshNow()
	w:advance(0.5)
	eq(s.sub.wuberText, "Pick another driver when you're ready.", "AUD-190: no 'Nothing to pay' beside the ask button") -- Done.lua:464-466
	ok(s.ask:IsShown(), "the Ask for a raincheck pill shows") -- Done.lua:479-480
	local said = toasts(r)
	r.W.Raincheck.Ask = function() return false end
	r:clickText("Ask for a raincheck")
	w:advance(1)
	ok(s.ask:IsShown(), "a refused ask leaves the pill")
	eq(said[#said], "Couldn't ask right now", "the refusal toast") -- Done.lua:73
	r.W.Raincheck.Ask = function() return true end
	r:clickText("Ask for a raincheck")
	w:advance(1)
	eq(said[#said], "Asked Mia for a raincheck", "the sent toast names the driver") -- Done.lua:71
	ok(r.W.UI.state.rcAsked and r.W.UI.state.rcAsked["r9"], "remembered: one ask per ride") -- Done.lua:69-70
	ok(not s.ask:IsShown(), "the pill goes after asking")
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.rider.done: Next best driver is the cheapest other open or busy driver to the same place, and a click books them", function()
	local w, r, s = rideScreen("declined", { reason = "busy" }, "sorry")
	local W, t = r.W, r.env.GetTime()
	W.drivers = W.drivers or {}
	local function add(name, key, dest, price, state)
		W.drivers[key] = { name = name, key = key, dest = dest, price = price, state = state or "open", team = 3, service = name:match("^(%S+)") .. "'s Rides", heard = t }
	end
	add("Mia Runner", "mia runner", "Undercity", 3000) -- the one who said no: never offered back
	add("Cal Brown", "cal brown", "Undercity", 4000, "paused") -- paused: never
	add("Dan Fox", "dan fox", "Ratchet", 3500) -- another place: never
	add("Bea Jones", "bea jones", "Undercity", 6000)
	add("Eve Stone", "eve stone", "Undercity", 7000, "busy")
	W.UI.RefreshNow()
	w:advance(1)
	ok(s.alt:IsShown(), "the card shows")
	eq(s.alt.key, "bea jones", "the cheapest eligible driver") -- Done.lua:382-392
	eq(s.alt.name.wuberText, "Bea's Rides " .. DOT .. " Bea", "service and short name") -- Done.lua:484
	eq(s.alt.price.wuberText, "60s", "their fare")
	W.drivers["bea jones"] = nil
	W.UI.RefreshNow()
	w:advance(1)
	eq(s.alt.key, "eve stone", "a busy driver is still an option") -- Done.lua:385 (only paused is excluded)
	W.drivers["eve stone"] = nil
	W.UI.RefreshNow()
	w:advance(1)
	eq(s.alt.key, nil, "nobody left: no card") -- Done.lua:488
	ok(not s.alt:IsShown(), "hidden")
	add("Bea Jones", "bea jones", "Undercity", 6000)
	W.UI.RefreshNow()
	w:advance(1)
	r:clickOn(s.alt)
	w:advance(3)
	eq(W.UI.state.screen, "confirm", "the click opens Bea's booking card") -- Done.lua:437-438
	ok(has(r, "Summon to Undercity"), "with her card (" .. T.list(r:visibleTexts()):sub(1, 400) .. ")")
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.rider.done: Try another driver clears the ended ride", function()
	local w, r, s = rideScreen("timeout", nil, "sorry")
	r:clickText("Try another driver")
	w:advance(2)
	eq(r.W.ride, nil, "the ride is cleared") -- Done.lua:446, Window.lua:666
	eq(r.W.UI.state.screen, "home", "back on the list")
	T.clean(w)
end)
