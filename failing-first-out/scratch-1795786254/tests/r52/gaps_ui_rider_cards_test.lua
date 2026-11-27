-- Tests of UI.Rider.Cards. Adopted in r52 from the fable-2411 draft (job 2694); loaded by tests/run.lua with its helper table T.
-- Pins: matches (place filter vs text filter, case, no filter), chipFor and usualSummon (every refusal and the sec / min rounding).
-- Pins: UI.DangerOf (clamp 0..2, "level:secs" strings, dangerAt wins) and UI.DangerLine words; updatedText.
-- Pins: favourites and hiding (saved-variable fallback, odd answers, toasts) and the heart button; a driver row's words
-- Pins: (second line per team / summoner / state, price, Founder and rank chips, shield) and its tap (book, or "paused for now").
-- Pins: applySearch (trim, place vs text, lastDest only on a final search) and the search box's Enter toasts and Clear.
-- Why it matters to a player: the driver list is what a rider books from. If these broke a paused driver could look bookable,
-- a hot-drop warning could vanish, a search could keep a stale filter, or the favourite heart could lie.
local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H

local function drv(env, name, dest, price, extra)
	local d = { name = name, key = name:lower(), short = name, dest = dest, price = price, state = "open", team = 3,
		service = name .. "'s Rides", heard = env.GetTime(), queue = 0 }
	for k, v in pairs(extra or {}) do d[k] = v end
	return d
end

-- a rider with Home open and the drivers given (the shape tests/d2/d2_g_home_test.lua uses)
local function world(make)
	local w = T.newWorld()
	local c = T.rider(w, T.TESTCHAR, { spot = "Orgrimmar" })
	T.settle(w)
	local UI = c.W.UI
	local list = make and make(c.env) or {}
	UI.Drivers = function() return list end
	UI.Driver = function(key)
		for _, d in ipairs(list) do if d.key == key then return d end end
	end
	c.W.Usual = function() return nil end
	c.W.AlreadyAt = function() return nil end
	UI.Toggle(true)
	w:advance(3)
	UI.Refresh(true)
	w:advance(2)
	return w, c, UI.state.screens.home, list
end

local function toasts(UI)
	local got = {}
	UI.Toast = function(msg, kind) got[#got + 1] = { msg, kind } end
	return got
end

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.rider.cards: contract (registered, deps, header, public names)", function()
	local W, w, r, Mod = T.contract("UI.Rider.Cards", "tests/ui/rider/cards_test.lua", {
		["UI.IsFav"] = "function", ["UI.ToggleFav"] = "function", ["UI.HideDriver"] = "function", ["UI.HeartButton"] = "function",
		["UI.DangerOf"] = "function", ["UI.DangerLine"] = "function",
		["Mod.applySearch"] = "function", ["Mod.buildCard"] = "function", ["Mod.buildSearch"] = "function", ["Mod.chipFor"] = "function",
		["Mod.fillCard"] = "function", ["Mod.heartButton"] = "function", ["Mod.isFav"] = "function", ["Mod.matches"] = "function",
		["Mod.updatedText"] = "function", ["Mod.usualSummon"] = "function",
	})
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.rider.cards: matches - no filter shows everyone, a place filter is exact, a text filter looks in place, service and name", function()
	local w = T.newWorld()
	local r = T.rider(w)
	local M = r.W.Mod("UI.Rider.Cards")
	local d = { dest = "Undercity", service = "Anita's Portals", name = "Anita" }
	eq(M.matches(d, nil), true, "no filter") -- Cards.lua:530
	eq(M.matches(d, { place = "Undercity", text = "Undercity" }), true, "the place")
	eq(M.matches(d, { place = "Orgrimmar", text = "Undercity" }), false, "a place filter ignores the text (Cards.lua:531)")
	eq(M.matches(d, { text = "under" }), true, "text in the place")
	eq(M.matches(d, { text = "PORTAL" }), true, "text in the service, any case") -- Cards.lua:538
	eq(M.matches(d, { text = "anita" }), true, "text in the name")
	eq(M.matches(d, { text = "zzz" }), false, "no match")
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.rider.cards: chipFor and usualSummon word a driver's state and refuse every case where no average should be shown", function()
	local w = T.newWorld()
	local r = T.rider(w)
	local W = r.W
	local M = W.Mod("UI.Rider.Cards")
	local label, colour = M.chipFor({ state = "open" })
	eq(label, "Open", "open") eq(colour, "glow", "open colour") -- Cards.lua:466
	label, colour = M.chipFor({ state = "busy", queue = 3 })
	eq(label, "Busy · 3 waiting", "busy with a queue") eq(colour, "muted", "busy colour")
	eq((M.chipFor({ state = "busy", queue = 0 })), "Busy · about 2 min", "busy, nobody waiting") -- Cards.lua:469
	eq((M.chipFor({ state = "busy" })), "Busy · about 2 min", "busy, queue unknown")
	label, colour = M.chipFor({ state = "paused" })
	eq(label, "Paused", "paused") eq(colour, "off", "paused colour")
	eq((M.chipFor({ state = "mystery" })), "Paused", "anything else reads as paused")
	local function us(extra) local d = { state = "open", queue = 0, avgSummon = 45 } for k, v in pairs(extra or {}) do d[k] = v end return M.usualSummon(d) end
	eq(us(), "about 45 sec", "an open driver with nobody waiting") -- Cards.lua:482
	eq(us({ avgSummon = 10 }), "about 10 sec", "10 is the least") -- Cards.lua:480
	eq(us({ avgSummon = 59.9 }), "about 59 sec", "floored by SummonWait, under a minute in seconds")
	eq(us({ avgSummon = 60 }), "about " .. W.UI.Duration(60), "a minute and over: Duration's words")
	eq(us({ avgSummon = 900 }), "about " .. W.UI.Duration(900), "900 is the most")
	eq(us({ avgSummon = 9 }), nil, "under 10: not believed")
	eq(us({ avgSummon = 901 }), nil, "over 900: not believed")
	eq(us({ avgSummon = false }), nil, "no average sent")
	eq(us({ state = "busy" }), nil, "busy: no average")
	eq(us({ queue = 1 }), nil, "somebody waiting: no average")
	eq(us({ queue = false }), nil, "queue unknown: no average (Cards.lua:478)")
	eq(M.usualSummon(nil), nil, "no driver")
	eq(M.usualSummon("x"), nil, "not a driver")
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.rider.cards: DangerOf clamps the level to 0..2 and reads strings and times; DangerLine words each level", function()
	local w = T.newWorld()
	local r = T.rider(w)
	local W = r.W
	local UI = W.UI
	local now = W.Mod("UI.Kit").now
	local l, s = UI.DangerOf(nil)
	eq(l, 0, "nil") eq(s, nil, "nil secs")
	eq((UI.DangerOf("x")), 0, "not a table")
	eq((UI.DangerOf({})), 0, "no danger")
	eq((UI.DangerOf({ danger = 1 })), 1, "level 1")
	eq((UI.DangerOf({ danger = 5 })), 2, "clamped to 2") -- Cards.lua:419
	eq((UI.DangerOf({ danger = -3 })), 0, "clamped to 0")
	eq((UI.DangerOf({ danger = 1.9 })), 1, "floored")
	l, s = UI.DangerOf({ danger = "2:90" })
	eq(l, 2, "string level") eq(s, 90, "string secs") -- Cards.lua:415
	l, s = UI.DangerOf({ danger = "1" })
	eq(l, 1, "bare string level") eq(s, nil, "no secs in it")
	l, s = UI.DangerOf({ danger = "2:90", dangerSecs = 30 })
	eq(s, 30, "dangerSecs given: it stays") -- Cards.lua:416
	eq((UI.DangerOf({ raw = { danger = 2 } })), 2, "the record's raw table")
	l, s = UI.DangerOf({ danger = 2, dangerAt = now() - 120 })
	ok(math.abs(s - 120) < 0.01, "dangerAt: the age keeps growing: " .. tostring(s)) -- Cards.lua:413
	l, s = UI.DangerOf({ danger = 2, dangerAt = now() + 500 })
	eq(s, 0, "a fight in the future is now, never negative")
	eq(UI.DangerLine(0, nil, "Anita"), nil, "level 0: no warning") -- Cards.lua:427
	eq(UI.DangerLine(nil), nil, "nil: no warning")
	local head, body = UI.DangerLine(1, nil, "Anita")
	eq(head, "Hot drop", "head") eq(body, "Enemy players were seen near the summon spot.", "level 1 body")
	head, body = UI.DangerLine(2, nil, "Anita")
	eq(body, "Anita's crew fought enemy players recently. You may land in a fight.", "level 2, age unknown") -- Cards.lua:430
	_, body = UI.DangerLine(2, nil, nil)
	eq(body, "The crew fought enemy players recently. You may land in a fight.", "no name")
	_, body = UI.DangerLine(2, 30, "Anita")
	eq(body, "Anita's crew fought enemy players just now. You may land in a fight.", "under a minute")
	_, body = UI.DangerLine(2, 120, "Anita")
	eq(body, "Anita's crew fought enemy players " .. UI.Duration(120) .. " ago. You may land in a fight.", "older")
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.rider.cards: favourites and hiding use the saved variables when Net has no answer, toast the change, and survive odd answers", function()
	local w = T.newWorld()
	local r = T.rider(w)
	T.settle(w)
	local W, UI = r.W, r.W.UI
	UI.Toggle(true)
	w:advance(3)
	local got = toasts(UI)
	W.IsFav, W.ToggleFav, W.HideDriver = nil, nil, nil -- the plain saved-variable path
	local fired = {}
	W.Listen("SETTINGS", function(key) fired[#fired + 1] = key end)
	eq(UI.IsFav(nil), false, "no key") -- Cards.lua:45
	eq(UI.IsFav("mia-k"), false, "not a favourite yet")
	eq(UI.ToggleFav(nil, "Mia"), nil, "no key: nothing happens")
	eq(UI.ToggleFav("mia-k", "Mia Smith"), true, "on")
	eq(UI.IsFav("mia-k"), true, "saved")
	eq(got[1][1], W.Short("Mia Smith") .. " is a favourite. We'll tell you when they're online.", "toast on") -- Cards.lua:64
	eq(got[1][2], "fav", "kind")
	eq(UI.ToggleFav("mia-k"), false, "off")
	eq(got[2][1], "This driver is no longer a favourite", "no name given")
	eq(got[2][2], "info", "kind")
	ok(W.db.favs["mia-k"] == nil, "removed from the saved table, not set to false")
	UI.HideDriver("bob-k", "Bob Stone")
	eq(W.db.hidden["bob-k"], true, "hidden, saved") -- Cards.lua:76
	eq(got[3][1], W.Short("Bob Stone") .. " is hidden. Show them again in Settings.", "toast")
	UI.HideDriver("cal-k")
	eq(got[4][1], "That driver is hidden. Show them again in Settings.", "no name given")
	local n = #got
	UI.HideDriver(nil, "Nobody")
	eq(#got, n, "no key: no toast")
	local seen = {}
	for _, k in ipairs(fired) do seen[k] = (seen[k] or 0) + 1 end
	ok((seen.favs or 0) == 2 and (seen.hidden or 0) == 2, "SETTINGS favs and hidden fired for each change") -- Cards.lua:61
	-- Net answers, but not with a boolean: the saved state decides
	W.ToggleFav = function() return "weird" end
	W.IsFav = function() return true end
	eq(UI.ToggleFav("zed-k", "Zed"), true, "falls back to IsFav") -- Cards.lua:56
	W.IsFav = function() return "yes" end
	eq(UI.IsFav("zed-k"), false, "only true counts") -- Cards.lua:46
	local hid
	W.HideDriver = function(key) hid = key end
	UI.HideDriver("dan-k", "Dan")
	eq(hid, "dan-k", "Net's own hide is asked")
	eq(W.db.hidden["dan-k"], nil, "and the table is left to it")
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.rider.cards: the heart button shows its filled or outline look, ignores a click with no driver and flips a favourite", function()
	local w = T.newWorld()
	local r = T.rider(w)
	T.settle(w)
	local W, UI = r.W, r.W.UI
	UI.Toggle(true)
	w:advance(3)
	toasts(UI)
	W.IsFav, W.ToggleFav = nil, nil
	local h = UI.HeartButton(r.env.UIParent, 13)
	eq(h:GetWidth(), 21, "size + 8") -- Cards.lua:87
	h:SetFav(true)
	ok(h.fill:IsShown() and not h.outline:IsShown(), "filled when a favourite") -- Cards.lua:96
	h:SetFav(false)
	ok(not h.fill:IsShown() and h.outline:IsShown(), "outline when not")
	h:Click()
	eq(W.db.favs and next(W.db.favs), nil, "no driver on the heart: a click does nothing") -- Cards.lua:103
	h.key, h.name = "mia-k", "Mia Smith"
	h:Click()
	eq(UI.IsFav("mia-k"), true, "a click makes a favourite")
	ok(h.on and h.fill:IsShown(), "and the heart fills")
	h:Click()
	eq(UI.IsFav("mia-k"), false, "again, and it is not")
	ok(not h.on and h.outline:IsShown(), "outline again")
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.rider.cards: a driver row's second line, price and state words follow team, summoner, state and seats", function()
	local w, c, home = world(function(env)
		return {
			drv(env, "Ana", "Undercity", 5000),
			drv(env, "Bea", "Ratchet", 7500, { team = 2 }),
			drv(env, "Cal", "Booty Bay", 7500, { team = 1, state = "busy", queue = 4 }),
			drv(env, "Dan", "Orgrimmar", 5000, { summoner = "Warla", state = "paused" }),
			drv(env, "Eve", "Gadgetzan", 5000, { seats = 0 }),
			drv(env, "Fay", "Ironforge", 5000, { state = "busy", seats = 0 }),
			drv(env, "Gus", "Darnassus", 5000, { avgSummon = 45 }),
			drv(env, "Hal", "Stormwind City", 5000, { avgSummon = 45, queue = 2 }),
		}
	end)
	local UI, W = c.W.UI, c.W
	local Kit = W.Mod("UI.Kit")
	local function row(key) return UI.state.cards[key] end
	eq(row("ana").subText, "To Undercity · No helpers needed", "full team") -- Cards.lua:504
	eq(row("bea").subText, "To Ratchet · Bring 1 helper", "one short: singular") -- Cards.lua:462
	eq(row("cal").subText, "To Booty Bay · Bring 2 helpers · Busy · 4 waiting", "two short, busy with a queue")
	eq(row("dan").subText, "To Orgrimmar · Summoned by Warla · Paused", "a Warlock casts for them; paused")
	ok(row("dan").disabled, "a paused row is disabled")
	eq(row("eve").subText, "To Gadgetzan · No helpers needed · Group full", "no seats") -- Cards.lua:498
	eq(row("fay").subText, "To Ironforge · No helpers needed · Busy · about 2 min · Group full", "busy and full")
	eq(row("gus").subText, "To Darnassus · No helpers needed · Usually about 45 sec", "the usual summon") -- Cards.lua:501
	eq(row("hal").subText, "To Stormwind City · No helpers needed", "somebody waiting: no usual")
	eq(row("ana").stateText, nil, "an open plain driver has no state words")
	eq(row("cal").stateText, "Busy · 4 waiting", "the state words alone")
	eq(row("ana").titleText, "Ana's Rides", "the row's title is the service")
	eq(row("bea").valueText, Kit.money(7500), "the price") -- Cards.lua:508
	eq(row("bea").key, "bea", "key") eq(row("bea").short, "Bea", "short")
	eq(row("bea").heart.key, "bea", "the heart knows the driver") -- Cards.lua:515
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.rider.cards: Founder and rank chips, the PvP shield and the avatar initial come and go with the driver", function()
	local w, c, home, list = world(function(env)
		return { drv(env, "Ana", "Undercity", 5000, { creator = true, rank = 3 }), drv(env, "Bea", "Ratchet", 5000) }
	end)
	local W, UI = c.W, c.W.UI
	W.RankOf = function(n) return n, "Rookie" end
	UI.Refresh(true)
	w:advance(1)
	local a = UI.state.cards["ana"]
	ok(a.royal and a.royal.chip:IsShown(), "the Founder badge shows") -- Cards.lua:206
	eq(a.rankTitle, "Rookie", "rank title") -- Cards.lua:232
	eq(a.rankTipBody, "3 verified summons. A summon is verified when a rider who asked through Wuber arrives by it.", "rank tip, plural")
	ok(a.rankChip:IsShown(), "rank chip shown")
	list[1].creator, list[1].rank = false, 1
	UI.Refresh(true)
	w:advance(1)
	ok(not a.royal.chip:IsShown(), "Founder badge hidden once not a founder")
	eq(a.rankTipBody, "1 verified summon. A summon is verified when a rider who asked through Wuber arrives by it.", "singular")
	list[1].rank = 0
	UI.Refresh(true)
	w:advance(1)
	ok(not a.rankChip:IsShown(), "rank 0: no chip") -- Cards.lua:212
	eq(a.rankTitle, nil, "and no title")
	list[1].rank = 3
	W.RankOf = nil
	UI.Refresh(true)
	w:advance(1)
	ok(not a.rankChip:IsShown(), "no W.RankOf in the game: no chip, no error")
	-- the picture's initial
	eq(a.avatar.initial:GetText(), "A", "the initial of the name") -- Cards.lua:329
	list[2].name = "élan"
	UI.Refresh(true)
	w:advance(1)
	eq(UI.state.cards["bea"].avatar.initial:GetText(), "é", "a two-byte first letter stays whole (Cards.lua:299)")
	-- the shield
	list[2].name = "Bea"
	list[2].danger = 2
	UI.Refresh(true)
	w:advance(1)
	local b = UI.state.cards["bea"]
	eq(b.dangerLevel, 2, "level") ok(b.shield and b.shield:IsShown(), "the shield shows on a hot summon spot") -- Cards.lua:519
	list[2].danger = 0
	UI.Refresh(true)
	w:advance(1)
	ok(not b.shield:IsShown(), "and goes when it cools")
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.rider.cards: tapping a row books an open driver; a paused driver only says so", function()
	local w, c, home, list = world(function(env)
		return { drv(env, "Ana", "Undercity", 5000), drv(env, "Bea", "Ratchet", 5000, { state = "paused" }) }
	end)
	local UI = c.W.UI
	local got = toasts(UI)
	local shown = {}
	local real = UI.Show
	UI.Show = function(screen, key) shown[#shown + 1] = screen .. ":" .. tostring(key) end
	UI.state.cards["ana"]:Click()
	eq(shown[1], "confirm:ana", "an open driver: the booking opens") -- Cards.lua:275
	UI.state.cards["bea"]:Click()
	eq(#shown, 1, "a paused driver: no booking") -- Cards.lua:271
	eq(got[#got][1], "Bea has paused for now", "the toast says so")
	eq(got[#got][2], "info", "kind")
	UI.Show = real
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.rider.cards: applySearch trims the text, finds a place only from two letters, saves the destination only on a final search", function()
	local w, c, home = world(nil)
	local W, UI = c.W, c.W.UI
	local Kit = W.Mod("UI.Kit")
	local M = W.Mod("UI.Rider.Cards")
	W.db.lastDest = nil
	Kit.ui.scrollTarget = 99
	M.applySearch("  Undercity  ", false)
	eq(Kit.ui.filter.place, "Undercity", "a known place") -- Cards.lua:549
	eq(Kit.ui.filter.text, "Undercity", "the trimmed text")
	eq(W.db.lastDest, nil, "not remembered while typing") -- Cards.lua:552
	eq(Kit.ui.scrollTarget, 0, "the list goes back to the top")
	M.applySearch("Undercity", true)
	eq(W.db.lastDest, "Undercity", "a final search remembers the destination")
	M.applySearch("U", true)
	eq(Kit.ui.filter.place, nil, "one letter is never a place") eq(Kit.ui.filter.text, "U", "just text")
	M.applySearch("zzzq", true)
	eq(Kit.ui.filter.place, nil, "no such place") eq(Kit.ui.filter.text, "zzzq", "text only")
	eq(W.db.lastDest, "Undercity", "an unknown place does not overwrite the last destination")
	M.applySearch("   ", false)
	eq(Kit.ui.filter, nil, "blank clears the filter") -- Cards.lua:546
	M.applySearch(nil, false)
	eq(Kit.ui.filter, nil, "nil clears too")
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.rider.cards: the search box's Enter tells you when nobody goes there or no place matches; Clear empties it", function()
	local w, c, home = world(function(env) return { drv(env, "Ana", "Undercity", 5000) } end)
	local W, UI = c.W, c.W.UI
	local Kit = W.Mod("UI.Kit")
	local got = toasts(UI)
	local e = home.search.edit
	local enter = e:GetScript("OnEnterPressed")
	e:SetText("Undercity")
	enter(e)
	eq(#got, 0, "a driver goes there: no toast") -- Cards.lua:610
	e:SetText("Gadgetzan")
	enter(e)
	eq(got[1][1], "No drivers to Gadgetzan right now", "a real place nobody serves") -- Cards.lua:610
	eq(got[1][2], "info", "kind")
	e:SetText("zzzq")
	enter(e)
	eq(got[2][1], "No place called zzzq", "no such place") -- Cards.lua:616
	eq(got[2][2], "warn", "kind")
	home.search.clear:Click()
	eq(e:GetText(), "", "Clear empties the box")
	eq(Kit.ui.filter, nil, "and the search")
	T.clean(w)
end)
