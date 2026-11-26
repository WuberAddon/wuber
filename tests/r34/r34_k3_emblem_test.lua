-- Round 34 k3: pioneer emblem fixes (HUNT-69 preview in an instance / with emblems off, HUNT-70 the
-- hide line is true at once, HUNT-99 the badge over another player's plate sits on BACKGROUND strata).
local T = ...
local test, eq, ok = T.test, T.eq, T.ok
local TESTCHAR, BOB, CAL, ANITA = T.TESTCHAR, T.BOB, T.CAL, T.ANITA

local function world()
	local w = T.newWorld({ realm = T.H.FOUNDER_REALM })
	local r = T.rider(w, TESTCHAR)
	for _, n in ipairs({ BOB, CAL, ANITA }) do w:addBot(n, { spot = "Orgrimmar", class = "MAGE" }) end
	T.settle(w)
	local shipped = r.W.PIONEERS
	r.W.PIONEERS = { riders = { ["EU-PvE"] = { BOB, TESTCHAR, ANITA } }, drivers = { ["EU-PvE"] = { CAL } } }
	return w, r, function() r.W.PIONEERS = shipped end
end

local function emblemOn(c, name)
	for _, f in ipairs(c:onPlate(name)) do
		if f.orb and f.halo and f.ring then return f end
	end
end

test("r34 k3: the badge over another player's nameplate is on BACKGROUND strata (HUNT-99)", function()
	local w, r, restore = world()
	r:showPlate(BOB, { force = true })
	w:advance(2.5)
	local f = emblemOn(r, BOB)
	ok(f, "an emblem is on Bob's plate")
	eq(f and f:GetFrameStrata(), "BACKGROUND", "behind the Drive button's text")
	restore() T.clean(w)
end)

test("r34 k3: /wuber emblem mine off|on sends the beacon at once (HUNT-70)", function()
	local w, r, restore = world()
	local W = r.W
	local n = 0
	local real = W.SendBeacon
	W.SendBeacon = function(...) n = n + 1 return real(...) end
	W.SlashCommand("emblem mine off")
	eq(n, 1, "the beacon goes out after hiding")
	W.SlashCommand("emblem mine on")
	eq(n, 2, "and after showing again")
	W.SendBeacon = real
	restore() T.clean(w)
end)

test("r34 k3: the preview shows inside an instance and over my target with emblems off (HUNT-69)", function()
	local w, r, restore = world()
	local W = r.W
	r:showPlate(BOB, { force = true })
	w:advance(2.5)
	r.env.IsInInstance = function() return true, "party" end
	r.player.target = w:player(BOB)
	W.SlashCommand("emblem preview")
	w:advance(2.5)
	ok(W.Emblem.SelfHolder() and W.Emblem.SelfHolder():IsShown(), "inside an instance: the preview is over my head")
	ok(emblemOn(r, BOB), "and over my target")
	W.SlashCommand("emblem stop")
	r.env.IsInInstance = function() return false, "none" end
	W.SlashCommand("emblem off")
	r.player.target = w:player(BOB)
	W.SlashCommand("emblem preview")
	w:advance(2.5)
	ok(W.Emblem.SelfHolder():IsShown(), "emblems off: over my head")
	ok(emblemOn(r, BOB), "emblems off: over my target too")
	eq(W.Emblem.Count(), 1, "but no one else's")
	restore() T.clean(w)
end)
