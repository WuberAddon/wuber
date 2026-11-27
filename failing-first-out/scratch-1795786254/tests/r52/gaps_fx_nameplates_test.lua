-- Final home: tests/fx/nameplates_test.lua; add it to the per-module list in tests/run.lua.
-- Pins: who gets what over their head (LookFor: founder crown wins, a Pioneer, a driver's badge, a hidden driver nothing);
-- Pins: a crown shows on the founder's plate and goes with the plate; a recycled token never keeps the old crown;
-- Pins: the plates setting (off: nothing, back on: picked up from plates already there), a new zone rebuilds the plates;
-- Pins: the tooltip line (founder, driver with price and destination, Pioneer, nothing);
-- Pins: TurnOnFriendlyPlates (refused in combat without touching the game's settings, on: friendly plates appear);
-- Pins: the founder's own crown (only the founder, hidden with the setting, 34 px over the head on foot).
-- Why it matters to a player: the crown and badges are how riders spot the founder and the real drivers in a crowd. If this
-- broke, a hidden driver would still wear a badge, a stale crown would float over a stranger, or friendly plates would never come on.
local T = ...
local test, eq, ok = T.test, T.eq, T.ok

local function world()
	-- the founder's crown only shows on the founders' ruleset (Core/Base.lua W.IsCreator -> W.OnFounderRuleset)
	local w = T.newWorld({ realm = T.H.FOUNDER_REALM })
	local r = T.rider(w, T.TESTCHAR, { spot = "Orgrimmar" })
	w:addBot(T.ANITA, { spot = "Orgrimmar", class = "WARLOCK" })
	w:addBot(T.BOB, { spot = "Orgrimmar", class = "MAGE" })
	T.settle(w)
	return w, r, r.W, r.W.Plates
end

-- the kinds of Wuber frame (crown, badge, pioneer) shown on a player's plate
local function kinds(r, name)
	local out = {}
	for _, f in ipairs(r:onPlate(name)) do if f.plateKind then out[#out + 1] = f.plateKind end end
	return out
end

local function has(list, kind)
	for _, k in ipairs(list) do if k == kind then return true end end
	return false
end

local function near(a, b) return math.abs(a - b) < 0.001 end

test("fx.nameplates: contract (registered, deps, header, public names)", function()
	-- (the header's Uses line carries a parenthetical, "Theme.Widgets (T.PioneerLook, ... at run time)": the contract helper reads
	-- every word of it as a dependency, so the deps check may fail here until the header or the helper is fixed)
	local W, w, r, Mod = T.contract("FX.Nameplates", "tests/fx/nameplates_test.lua", {
		["W.Plates"] = "table", ["W.Plates.Refresh"] = "function", ["W.Plates.TurnOnFriendlyPlates"] = "function",
		["W.Plates.FriendlyPlatesOn"] = "function", ["W.Plates.Count"] = "function", ["W.Plates.LookFor"] = "function",
		["W.Plates.TooltipLine"] = "function", ["W.Plates.OnPlateAdded"] = "function", ["W.Plates.OnPlateRemoved"] = "function",
		["W.Plates.ReleaseAll"] = "function", ["W.Plates.Sweep"] = "function", ["W.Plates.EnsureSelf"] = "function",
		["W.Plates.SelfCrown"] = "function", ["W.Plates.GetPlate"] = "function", ["W.Plates.HookTooltip"] = "function",
	})
	ok(Mod, "W.Mod(\"FX.Nameplates\")")
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("fx.nameplates: LookFor - the founder's crown wins, then a Pioneer, then a driver's badge; a hidden driver gets nothing", function()
	local w, r, W, P = world()
	local bob, anita = W.Key(T.BOB), W.Key(T.ANITA)
	eq(P.LookFor(nil), nil, "no key") -- Nameplates.lua:116-117
	eq(P.LookFor(bob), nil, "a plain player")
	eq(P.LookFor(anita), "crown", "the founder")
	W.PIONEERS = { riders = { ["EU-PvE"] = { T.BOB, T.ANITA } }, drivers = {} }
	local kind, what = P.LookFor(bob)
	eq(kind, "pioneer", "a Pioneer")
	eq(what, "rider")
	eq(P.LookFor(anita), "crown", "a founder who is also a Pioneer keeps the crown") -- Nameplates.lua:118-119
	W.drivers[bob] = { badge = "bolt" }
	kind, what = P.LookFor(bob)
	eq(kind, "pioneer", "a Pioneer's look beats the plain badge") -- Nameplates.lua:119-124
	W.PIONEERS = { riders = {}, drivers = {} }
	kind, what = P.LookFor(bob)
	eq(kind, "badge", "a driver with a badge")
	eq(what, "bolt")
	W.db.hidden = { [bob] = true }
	eq(P.LookFor(bob), nil, "a driver the rider hid wears nothing") -- Nameplates.lua:101-105
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("fx.nameplates: the founder's plate gets a crown and loses it when the plate goes", function()
	local w, r, W, P = world()
	eq(P.Count(), 0, "control: none")
	r:showPlate(T.ANITA, { force = true })
	eq(P.Count(), 1, "one crown") -- Nameplates.lua:220-233
	ok(has(kinds(r, T.ANITA), "crown"), "a crown frame is on her plate")
	r:hidePlate(T.ANITA)
	eq(P.Count(), 0, "released with the plate") -- Nameplates.lua:244-250
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("fx.nameplates: a plain player's plate gets nothing", function()
	local w, r, W, P = world()
	r:showPlate(T.BOB, { force = true })
	eq(P.Count(), 0)
	eq(#kinds(r, T.BOB), 0, "no Wuber frame on it")
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("fx.nameplates: a plate token handed to someone else does not keep the old crown", function()
	local w, r, W, P = world()
	local unit = r:showPlate(T.ANITA, { force = true })
	eq(P.Count(), 1)
	-- the game re-uses the token for another player without a REMOVED (a missed event)
	r:showPlate(T.BOB, { force = true, index = tonumber(unit:match("%d+")) })
	eq(P.Count(), 0, "the old crown is dropped, Bob earns none") -- Nameplates.lua:236-242
	eq(#kinds(r, T.BOB), 0, "nothing on the plate")
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("fx.nameplates: a driver's badge shows on his plate and goes when the rider hides him", function()
	local w, r, W, P = world()
	local bob = W.Key(T.BOB)
	W.drivers[bob] = { badge = "bolt", price = 5000, dest = "Undercity" }
	r:showPlate(T.BOB, { force = true })
	eq(P.Count(), 1, "a badge")
	ok(has(kinds(r, T.BOB), "badge"), "the badge frame")
	W.db.hidden = { [bob] = true }
	W.Fire("DRIVERS")
	eq(P.Count(), 0, "the sweep drops it") -- Nameplates.lua:532-535, 257-278
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("fx.nameplates: with the plates setting off there are no crowns; turning it on again picks up plates already there", function()
	local w, r, W, P = world()
	W.db.plates = false
	r:showPlate(T.ANITA, { force = true })
	eq(P.Count(), 0, "off: no crown") -- Nameplates.lua:73-75
	W.db.plates = nil
	W.Fire("SETTINGS", "plates")
	eq(P.Count(), 1, "on: the plate that was already there gets its crown")
	W.db.plates = false
	W.Fire("SETTINGS", "plates")
	eq(P.Count(), 0, "off again: released")
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("fx.nameplates: a new zone drops every frame and the sweep puts them back a second later", function()
	local w, r, W, P = world()
	r:showPlate(T.ANITA, { force = true })
	eq(P.Count(), 1)
	r:fire("PLAYER_ENTERING_WORLD")
	eq(P.Count(), 0, "released at once") -- Nameplates.lua:519-526
	w:advance(1.5)
	eq(P.Count(), 1, "back after the sweep")
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("fx.nameplates: the tooltip line - founder, driver with price and destination, Pioneer, nothing", function()
	local w, r, W, P = world()
	local bob, anita = W.Key(T.BOB), W.Key(T.ANITA)
	local text, red, green, blue = P.TooltipLine(anita)
	ok(text:find(" Wuber founder$"), "founder: " .. tostring(text)) -- Nameplates.lua:447-450
	ok(near(red, 0.976) and near(green, 0.773) and near(blue, 0.243), "gold")
	eq(P.TooltipLine(bob), nil, "a plain player has none")
	W.drivers[bob] = { badge = "bolt", price = 5000, dest = "Undercity" }
	text, red, green, blue = P.TooltipLine(bob)
	ok(text:find("Wuber driver \194\183 " .. W.Money(5000) .. " to Undercity", 1, true), "driver: " .. tostring(text)) -- Nameplates.lua:453-470
	ok(near(red, 0.804) and near(green, 0.490) and near(blue, 0.961), "violet")
	W.drivers[bob] = { badge = "bolt", dest = "Undercity" }
	ok(P.TooltipLine(bob):find("Wuber driver \194\183 to Undercity", 1, true), "no price: just the destination")
	W.drivers[bob] = { badge = "bolt" }
	text = P.TooltipLine(bob)
	ok(text:find("Wuber driver", 1, true) and not text:find("\194\183", 1, true), "no price or destination: just 'Wuber driver'")
	W.PIONEERS = { riders = { ["EU-PvE"] = { T.BOB } }, drivers = {} }
	text = P.TooltipLine(bob)
	ok(text:find("Wuber driver", 1, true) and text:find(W.Theme.PIONEER.rider.tip, 1, true) and text:find("\n", 1, true), "Pioneer line under the driver's")
	W.drivers[bob] = nil
	text = P.TooltipLine(bob)
	eq(text, "|TInterface\\AddOns\\Wuber\\Media\\pin:14:14|t " .. W.Theme.PIONEER.rider.tip, "a Pioneer who does not drive: the Pioneer line") -- Nameplates.lua:451-457
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("fx.nameplates: TurnOnFriendlyPlates refuses in combat and leaves the game's settings alone", function()
	local w, r, W, P = world()
	eq(P.FriendlyPlatesOn(), false, "control: off (the world starts with nameplateShowFriends 0)") -- Nameplates.lua:391-404
	w:enterCombat(r)
	local seen = {}
	local orig = W.UI.Toast
	W.UI.Toast = function(msg, kind, ...) seen[#seen + 1] = { tostring(msg), kind } return orig(msg, kind, ...) end
	eq(P.TurnOnFriendlyPlates(), false)
	W.UI.Toast = orig
	w:leaveCombat(r)
	eq(r.cvars.nameplateShowFriends, "0", "the setting was not touched") -- Nameplates.lua:413-417
	eq(seen[1][1], "Can't change nameplates in combat. Try again after the fight.")
	eq(seen[1][2], "error")
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("fx.nameplates: TurnOnFriendlyPlates switches them on and the founder's crown appears on a plate that was waiting", function()
	local w, r, W, P = world()
	r:showPlate(T.ANITA) -- friendly plates are off: the game shows nothing
	eq(P.Count(), 0, "control: no plate, no crown")
	eq(P.TurnOnFriendlyPlates(), true)
	eq(r.cvars.nameplateShowFriends, "1", "the setting is on") -- Nameplates.lua:418-430
	eq(P.FriendlyPlatesOn(), true)
	w:advance(1)
	eq(P.Count(), 1, "her plate came up and got its crown")
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("fx.nameplates: the founder's own crown shows 34 px over her head, hides with the setting; others have none", function()
	local w = T.newWorld()
	local r = T.rider(w, T.ANITA, { spot = "Orgrimmar" })
	T.settle(w)
	local W, P = r.W, r.W.Plates
	local crown = P.SelfCrown()
	ok(crown and crown:IsShown(), "the founder's own crown") -- Nameplates.lua:294-358
	local _, _, _, _, y = crown:GetPoint(1)
	eq(y, 34, "on foot, 34 up (r47_m2)")
	W.db.plates = false
	W.Fire("SETTINGS", "plates")
	ok(not crown:IsShown(), "hidden with the setting off")
	W.db.plates = nil
	W.Fire("SETTINGS", "plates")
	ok(P.SelfCrown():IsShown(), "back on")
	T.clean(w)
	local w2 = T.newWorld()
	local g = T.rider(w2, T.TESTCHAR, { spot = "Orgrimmar" })
	T.settle(w2)
	eq(g.W.Plates.SelfCrown(), nil, "nobody else has one")
	T.clean(w2)
end)

-- NEEDS FAKE-GAME: a mouse-over tooltip (UPDATE_MOUSEOVER_UNIT with GameTooltip:NumLines / AddLine and OnTooltipSetUnit or
-- TooltipDataProcessor) so onTooltip can be driven end to end: the line appears once, not in combat, not twice for one tooltip
-- (Nameplates.lua:475-500). TooltipLine itself is covered above.
