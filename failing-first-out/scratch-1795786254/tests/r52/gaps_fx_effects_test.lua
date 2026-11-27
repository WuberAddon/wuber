-- Final home: tests/fx/effects_test.lua; add it to the per-module list in tests/run.lua.
-- Pins: the small pure helpers (Hash, Mode, BadgeFirst / BADGE_IDS, FrameCoords, Goldify, Has);
-- Pins: Play and Fullscreen refuse bad input and the Off / Light / combat cases without a Lua error;
-- Pins: a gold summon plays the *_gold twin, a handle's IsPlaying / Stop, a finished effect frees its slot and calls onDone once;
-- Pins: a new full-screen effect replaces the running one, StopAll and Refresh (fx set to Off) end everything.
-- Why it matters to a player: these effects play on the rider's screen during a summon. If this broke, effects would play in a fight,
-- would not stop when the player turns them off in Settings, or would raise Lua errors in the middle of a ride.
local T = ...
local test, eq, ok = T.test, T.eq, T.ok

local function setup(mode)
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR)
	w:advance(15)
	r.W.db.fx = mode
	return w, r, r.W.FX, r.env.UIParent
end

-- guard: coverage, fable-2411 draft adopted in r52
test("fx.effects: contract (registered, deps, header, public names)", function()
	local W, w, r, Mod = T.contract("FX.Effects", "tests/fx/effects_test.lua", {
		["W.FX"] = "table", ["W.FX.BADGE_IDS"] = "table", ["W.FX.BadgeFirst"] = "function", ["W.FX.Hash"] = "function",
		["W.FX.Mode"] = "function", ["W.FX.FrameCoords"] = "function", ["W.FX.TryNative"] = "function", ["W.FX.Crown"] = "function",
		["W.FX.Badge"] = "function", ["W.FX.Flipbook"] = "function", ["W.FX.Has"] = "function", ["W.FX.Play"] = "function",
		["W.FX.Fullscreen"] = "function", ["W.FX.StopAll"] = "function", ["W.FX.Refresh"] = "function", ["W.FX.Stats"] = "function",
		["W.FX.Model"] = "function", ["W.FX.Goldify"] = "function",
	})
	ok(Mod, "W.Mod(\"FX.Effects\")")
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("fx.effects: the six badges and where their frames start", function()
	local w, r, FX = setup()
	eq(table.concat(FX.BADGE_IDS, ","), "bolt,star,flame,moon,crystal,skull", "the badge ids, in order") -- Effects.lua:70
	local want = { bolt = 0, star = 10, flame = 20, moon = 30, crystal = 40, skull = 50 }
	for id, first in pairs(want) do eq(FX.BadgeFirst(id), first, id .. " starts at frame " .. first) end -- Effects.lua:69
	eq(FX.BadgeFirst("nonsense"), nil, "an unknown badge has no frames")
	eq(FX.BadgeFirst(nil), nil, "nil is no badge")
	for _, id in ipairs(FX.BADGE_IDS) do ok(FX.BadgeFirst(id), id .. " has a start") end
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("fx.effects: Hash is a small stable number from a name or a number", function()
	local w, r, FX = setup()
	eq(FX.Hash(5), 5, "a small number is itself") -- Effects.lua:130
	eq(FX.Hash(-5), 5, "the sign is dropped")
	eq(FX.Hash(2.9), 2, "the fraction is dropped")
	eq(FX.Hash(997), 0, "wraps at 997")
	eq(FX.Hash(1000), 3, "1000 wraps to 3")
	eq(FX.Hash(""), 0, "an empty name")
	eq(FX.Hash(nil), 0, "no seed")
	eq(FX.Hash("a"), 97, "one letter is its byte") -- Effects.lua:131-133
	eq(FX.Hash("ab"), 114, "(97 * 31 + 98) mod 997")
	eq(FX.Hash("Mia Runner"), FX.Hash("Mia Runner"), "stable")
	for _, name in ipairs({ "Anita Lift", "Wuber TestCharacter-Kazzak", "A very long driver name that goes on and on and on", "x" }) do
		local h = FX.Hash(name)
		ok(h >= 0 and h <= 996 and h == math.floor(h), "in 0..996: " .. name .. " -> " .. h)
	end
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("fx.effects: Mode is full unless the saved setting says light or off", function()
	local w, r, FX = setup()
	local W = r.W
	for _, case in ipairs({ { "light", "light" }, { "off", "off" }, { "full", "full" }, { "junk", "full" }, { 42, "full" }, { true, "full" } }) do
		W.db.fx = case[1]
		eq(FX.Mode(), case[2], "fx = " .. tostring(case[1])) -- Effects.lua:137-141
	end
	W.db.fx = nil
	eq(FX.Mode(), "full", "never set: full")
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("fx.effects: FrameCoords gives a cell's rectangle on its sheet", function()
	local w, r, FX = setup()
	local l, rr, t, b = FX.FrameCoords("crown", 0) -- 512 x 256 sheet, 64 cells, 8 columns
	eq(l, 0, "crown 0: left") eq(rr, 0.125, "right") eq(t, 0, "top") eq(b, 0.25, "bottom") -- Effects.lua:151-156
	l, rr, t, b = FX.FrameCoords("crown", 9) -- column 1, row 1
	eq(l, 0.125, "crown 9: left") eq(rr, 0.25, "right") eq(t, 0.25, "top") eq(b, 0.5, "bottom")
	l, rr, t, b = FX.FrameCoords("portal_open", 3) -- 1024 x 512 sheet, 128 cells
	eq(l, 0.375, "portal_open 3: left") eq(rr, 0.5, "right") eq(t, 0, "top") eq(b, 0.25, "bottom")
	l, rr, t, b = FX.FrameCoords("portal_open", 8) -- the next row
	eq(l, 0, "portal_open 8: left") eq(t, 0.25, "top") eq(b, 0.5, "bottom")
	l, rr, t, b = FX.FrameCoords("coins", 0) -- the grid starts 192 px down the shared parts sheet
	eq(t, 0.75, "coins: top at y0 = 192 of 256") eq(b, 1, "bottom at the sheet's end") -- Effects.lua:65, 155
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("fx.effects: Goldify turns only the three portal effects into their gold twins", function()
	local w, r, FX = setup()
	eq(FX.Goldify("portal_open", true), "portal_open_gold", "open") -- Effects.lua:743-746
	eq(FX.Goldify("portal_loop", true), "portal_loop_gold", "loop")
	eq(FX.Goldify("arrival", true), "arrival_gold", "arrival")
	eq(FX.Goldify("portal_open", false), "portal_open", "not a founder: unchanged")
	eq(FX.Goldify("portal_open", nil), "portal_open", "no flag: unchanged")
	eq(FX.Goldify("coins", true), "coins", "other effects have no gold twin")
	eq(FX.Goldify("portal_open_gold", true), "portal_open_gold", "already gold: not gilded twice")
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("fx.effects: Has knows crowns, badges, books and effects, and nothing else", function()
	local w, r, FX = setup()
	for _, name in ipairs({ "crown", "portal_open", "portal_loop", "arrival", "coins", "portal_open_gold", "arrival_gold", "badge_bolt", "badge_skull", "coin", "milestone" }) do
		ok(FX.Has(name), name .. " is known") -- Effects.lua:73-86, 750-753
	end
	for _, name in ipairs({ "nonsense", "", "badge_unicorn", "Portal_Open" }) do ok(not FX.Has(name), "'" .. name .. "' is not") end
	ok(not FX.Has(nil), "nil is not") ok(not FX.Has(42), "a number is not") ok(not FX.Has({}), "a table is not")
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("fx.effects: Play refuses bad names, bad types and Off, quietly", function()
	local w, r, FX, UIP = setup("full")
	eq(FX.Play(nil, UIP), nil, "no name") -- Effects.lua:1061
	eq(FX.Play(42, UIP), nil, "a number")
	eq(FX.Play("nonsense", UIP), nil, "an effect that does not exist") -- Effects.lua:1077
	local junk = FX.Play("portal_open", UIP, "junk")
	ok(junk and junk:IsPlaying(), "a junk opts value is read as no options") -- Effects.lua:1063
	junk:Stop(true)
	r.W.db.fx = "off"
	eq(FX.Play("portal_open", UIP), nil, "Off: nothing plays") -- Effects.lua:1075
	eq(FX.Stats().playing, 0, "and nothing is running")
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("fx.effects: a gold summon plays the gold twin; a handle says if it plays and Stop(true) ends it", function()
	local w, r, FX, UIP = setup("full")
	local h = FX.Play("portal_open", UIP, { gold = true })
	ok(h, "a handle") -- Effects.lua:1076
	eq(h.name, "portal_open_gold", "the gold twin") -- Effects.lua:1056
	ok(h:IsPlaying(), "playing") -- Effects.lua:1009
	eq(FX.Stats().playing, 1, "one effect running")
	h:Stop(true)
	ok(not h:IsPlaying(), "stopped at once")
	eq(FX.Stats().playing, 0, "none running")
	h:Stop(true) -- a second stop of a stopped handle does nothing
	local plain = FX.Play("portal_open", UIP)
	eq(plain.name, "portal_open", "no gold flag: the plain effect")
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("fx.effects: a one-shot effect finishes by itself, frees its slot and calls onDone once", function()
	local w, r, FX, UIP = setup("full")
	local done = 0
	local h = FX.Play("arrival", UIP, { onDone = function() done = done + 1 end })
	ok(h and h:IsPlaying(), "playing")
	w:advance(5) -- the effect lasts about 1.9 s (Effects.lua:659)
	ok(not h:IsPlaying(), "it ended on its own")
	eq(FX.Stats().playing, 0, "no effect left running")
	eq(done, 1, "onDone once") -- Effects.lua:992-995
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("fx.effects: Fullscreen plays only in Full, never in a fight, and a new one replaces the running one", function()
	local w, r, FX, UIP = setup("light")
	eq(FX.Fullscreen("portal_open"), nil, "Light: no full-screen effects") -- Effects.lua:1099
	r.W.db.fx = "off"
	eq(FX.Fullscreen("portal_open"), nil, "Off: none")
	r.W.db.fx = "full"
	eq(FX.Fullscreen("nonsense"), nil, "no such effect") -- Effects.lua:1102
	eq(FX.Fullscreen(nil), nil, "no name")
	w:enterCombat(r)
	w:advance(1)
	eq(FX.Fullscreen("portal_open"), nil, "never in combat") -- Effects.lua:1099
	w:leaveCombat(r)
	w:advance(1)
	local a = FX.Fullscreen("arrival")
	ok(a and a:IsPlaying(), "out of combat it plays")
	local b = FX.Fullscreen("coins")
	ok(b and b:IsPlaying(), "the second plays")
	ok(not a:IsPlaying(), "and the first was stopped to make room") -- Effects.lua:1111-1114
	FX.StopAll(true)
	ok(not b:IsPlaying(), "StopAll ends the running one") -- Effects.lua:1124-1129
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("fx.effects: turning fx Off in Settings (Refresh) ends everything that plays", function()
	local w, r, FX, UIP = setup("full")
	local a = FX.Play("portal_loop", UIP)
	local b = FX.Fullscreen("coins")
	ok(a and a:IsPlaying() and b and b:IsPlaying(), "both play")
	r.W.db.fx = "off"
	FX.Refresh()
	ok(not a:IsPlaying() and not b:IsPlaying(), "both ended") -- Effects.lua:1133-1138
	eq(FX.Stats().playing, 0, "nothing running")
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("fx.effects: Model is off unless the hidden setting is on, and a bad file id gives nothing", function()
	local w, r, FX, UIP = setup()
	eq(FX.Model(UIP, 64, 123), nil, "default: off") -- Effects.lua:1159
	r.W.db.fxModels = true
	eq(FX.Model(UIP, 64, nil), nil, "no file id") -- Effects.lua:1160-1161
	eq(FX.Model(UIP, 64, "junk"), nil, "a junk file id")
	T.clean(w)
end)
