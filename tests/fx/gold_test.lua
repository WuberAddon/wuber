-- Tests of the founder gold portal art and moments. Loaded by tests/run.lua with its helper table T.
local T = ...
local test, eq, ok, H, S = T.test, T.eq, T.ok, T.H, T.S

local MEDIA = T.dir .. "/../Wuber/Media"

local function tgaInfo(path)
	local t = T.readFile(path)
	if not t then return nil end
	local idLen, kind = t:byte(1), t:byte(3)
	local wd, ht, bpp, desc = t:byte(13) + t:byte(14) * 256, t:byte(15) + t:byte(16) * 256, t:byte(17), t:byte(18)
	return { w = wd, h = ht, bpp = bpp, kind = kind, size = #t, full = #t == 18 + idLen + wd * ht * 4, alphaBits = desc % 16 }
end

local function pow2(x) return x >= 1 and math.floor(math.log(x) / math.log(2) + 0.5) == math.log(x) / math.log(2) end

test("gold media: *_gold sheets exist, uncompressed 32-bit, power of two, same size as their violet twins", function()
	for violet, gold in pairs({ ["fx/portal_open"] = "fx/portal_open_gold", ["fx/portal_loop"] = "fx/portal_loop_gold",
		["fx/arrival"] = "fx/arrival_gold", ["fx/runes"] = "fx/runes_gold" }) do
		local v, g = tgaInfo(MEDIA .. "/" .. violet .. ".tga"), tgaInfo(MEDIA .. "/" .. gold .. ".tga")
		ok(v and g, gold .. " exists")
		eq(g.kind, 2, gold .. " uncompressed")
		eq(g.bpp, 32, gold .. " 32-bit")
		eq(g.alphaBits, 8, gold .. " alpha bits")
		ok(g.full, gold .. " not truncated")
		ok(pow2(g.w) and pow2(g.h), gold .. " power of two")
		eq(g.w, v.w, gold .. " width = violet twin")
		eq(g.h, v.h, gold .. " height = violet twin")
	end
end)

test("new media: fold 64x32, dash 32x8, shield 64x64; uncompressed 32-bit power of two", function()
	for name, want in pairs({ fold = { 64, 32 }, dash = { 32, 8 }, shield = { 64, 64 } }) do
		local g = tgaInfo(MEDIA .. "/" .. name .. ".tga")
		ok(g, name .. ".tga exists")
		eq(g.kind, 2, name .. " uncompressed")
		eq(g.bpp, 32, name .. " 32-bit")
		ok(g.full, name .. " not truncated")
		eq(g.w, want[1], name .. " width")
		eq(g.h, want[2], name .. " height")
		ok(pow2(g.w) and pow2(g.h), name .. " power of two")
	end
end)

local function textures(c, part)
	local n = 0
	for _, o in ipairs(c.widgets) do
		local s = S[o]
		if s.otype == "Texture" and type(s.texture) == "string" and s.texture:lower():find(part, 1, true) then n = n + 1 end
	end
	return n
end

-- records what FX.Fullscreen is asked to play (the gold option resolved to its twin's name), passing it on
local function spy(FX)
	local seen, real = {}, FX.Fullscreen
	FX.Fullscreen = function(name, opts)
		seen[#seen + 1] = type(opts) == "table" and opts.gold and FX.Goldify(name, true) or name
		return real(name, opts)
	end
	return seen
end

-- counts math.random calls while fn runs
local function randoms(fn)
	local real, n = math.random, 0
	math.random = function(...) n = n + 1 return real(...) end
	local ok_, err = pcall(fn)
	math.random = real
	if not ok_ then error(err, 0) end
	return n
end

test("gold effects: FX knows them; the real effect loads only gold sheets", function()
	local w = T.newWorld()
	local r = T.rider(w)
	T.settle(w)
	local FX = r.W.FX
	for _, n in ipairs({ "portal_open_gold", "portal_loop_gold", "arrival_gold" }) do ok(FX.Has(n), n) end
	eq(FX.Goldify("portal_open", true), "portal_open_gold")
	eq(FX.Goldify("arrival", true), "arrival_gold")
	eq(FX.Goldify("arrival", false), "arrival")
	eq(FX.Goldify("paid", true), "paid", "only the portal effects have a gold twin")
	eq(textures(r, "portal_open_gold"), 0, "lazy: nothing set before the first play")
	FX.Fullscreen("portal_open_gold")
	w:advance(0.3)
	ok(textures(r, "portal_open_gold") > 0, "the gold flipbook is shown")
	ok(textures(r, "runes_gold") > 0, "the gold rune ring is shown")
	eq(textures(r, "fx\\portal_open."), 0, "no violet sheet in the gold effect")
	eq(textures(r, "fx\\runes."), 0, "no violet runes in the gold effect")
	T.clean(w)
end)

test("gold moments: genuine founder summon plays gold; anything else violet; fx off plays nothing", function()
	local w = T.newWorld()
	local r = T.rider(w)
	T.settle(w)
	local FX, W = r.W.FX, r.W
	local seen = spy(FX)
	local function ride(id, genuine)
		W.FounderSummon = function() return genuine end
		FX.OnRide({ id = id, state = "portal" })
		FX.OnRide({ id = id, state = "arrived" })
		w:advance(0.5)
	end
	ride("g1", true)
	eq(table.concat(seen, ","), "portal_open_gold,arrival_gold", "founder ride: gold names")
	seen[1], seen[2] = nil, nil
	ride("v1", false)
	eq(table.concat(seen, ","), "portal_open,arrival", "non-founder ride: violet names")
	seen[1], seen[2] = nil, nil
	W.FounderSummon = nil
	FX.OnRide({ id = "n1", state = "portal" })
	eq(seen[1], "portal_open", "no check available: violet")
	W.FounderSummon = function() return "yes" end
	FX.OnRide({ id = "t1", state = "portal" })
	eq(seen[2], "portal_open", "only exactly true counts as genuine")
	W.FounderSummon = function() error("boom") end
	FX.OnRide({ id = "e1", state = "portal" })
	eq(seen[3], "portal_open", "a failing check: violet")
	-- fx off: nothing is drawn, gold or violet
	W.db.fx = "off"
	W.Fire("SETTINGS", "fx")
	W.FounderSummon = function() return true end
	local before = textures(r, "_gold")
	FX.OnRide({ id = "o1", state = "portal" })
	w:advance(0.3)
	eq(textures(r, "_gold"), before, "fx off: no gold textures")
	T.clean(w)
end)

test("gold moments: the founder's own cast (DRIVE_RITUAL c) plays gold once, only for a founder, only for me", function()
	local w = T.newWorld({ realm = T.H.FOUNDER_REALM })
	local d = T.driver(w, T.ANITA)
	local r = T.rider(w)
	T.settle(w)
	-- Tester is no founder: his window never plays it
	local rseen = spy(r.W.FX)
	r.W.FX.OnDriveRitual("Bob", "c", { caster = "me" })
	eq(#rseen, 0, "not a founder: nothing")
	local FX = d.W.FX
	local seen = spy(FX)
	FX.OnDriveRitual("Bob", "t", {})
	eq(#seen, 0, "only the cast phase")
	FX.OnDriveRitual("Bob", "c", { caster = "Someone-Else" })
	eq(#seen, 0, "another caster: nothing")
	FX.OnDriveRitual("Bob", "c", { caster = "me" })
	eq(seen[1], "portal_open_gold", "the founder's own cast: gold")
	FX.OnDriveRitual("Bob", "c", { caster = "anita lift" })
	eq(#seen, 1, "once per rider")
	FX.OnDriveRitual("Bob", "c", { caster = "anita lift", ride = "R2" })
	eq(seen[2], "portal_open_gold", "her own key, a new ride: again")
	-- off the founders' ruleset her own name is no founder (Net.Portal's check)
	d.W.FounderSummon = function() return false end
	FX.OnDriveRitual("Cy", "c", {})
	eq(#seen, 2, "Net.Portal says no: nothing")
	T.clean(w)
end)

test("gold moments: hooks on FX.Fullscreen see the moment's own name; gold costs the shared randoms violet did", function()
	local w = T.newWorld()
	local r = T.rider(w)
	T.settle(w)
	local FX, W = r.W.FX, r.W
	local names, real = {}, FX.Fullscreen
	FX.Fullscreen = function(name, opts)
		local h = real(name, opts)
		names[#names + 1] = name .. (h and "+" or "-")
		return h
	end
	W.FounderSummon = function() return true end
	FX.OnRide({ id = "h1", state = "portal" })
	FX.OnRide({ id = "h1", state = "arrived" })
	w:advance(0.5)
	eq(table.concat(names, ","), "portal_open+,arrival+", "a gold summon is still portal_open then arrival, both played")
	ok(textures(r, "arrival_gold") > 0, "the arrival played gold")
	FX.Fullscreen = real
	-- the rider's gold twins draw exactly what the violet ones draw (the twins have the same particles)
	for _, n in ipairs({ "portal_open", "arrival" }) do
		local v = randoms(function() FX.Fullscreen(n) end)
		local g = randoms(function() FX.Fullscreen(n, { gold = true }) end)
		ok(v > 0, n .. " draws particles")
		eq(g, v, n .. ": gold draws as many randoms as violet")
	end
	-- the founder's own cast is new in 2.3.0: it plays, but leaves math.random alone
	W.FounderSummon = function() return true end
	local h
	eq(randoms(function() h = FX.OnDriveRitual("Zed", "c", { caster = "me" }) end), 0, "own cast: no shared randoms")
	ok(h, "own cast: the gold portal plays")
	ok(textures(r, "portal_open_gold") > 0, "own cast: gold flipbook")
	T.clean(w)
end)

---------------------------------------------------------------------------
-- End to end: a real ride on the harness, Net.Portal's check (W.FounderSummon), the rider's
-- Found screen ring (UI.Rider.Ride) and the driver's own cast (Drive.Queue's DRIVE_RITUAL "c")
---------------------------------------------------------------------------

-- every FX.Fullscreen on a window: the moment's name, "(gold)" for the gold option, "+" when it played
local function playLog(c)
	local log, FX = {}, c.W.FX
	local real = FX.Fullscreen
	FX.Fullscreen = function(name, opts)
		local h = real(name, opts)
		log[#log + 1] = tostring(name) .. (type(opts) == "table" and opts.gold and "(gold)" or "") .. (h and "+" or "-")
		return h
	end
	return log
end

local function has(log, entry)
	for _, e in ipairs(log) do if e == entry then return true end end
	return false
end

-- A Wuber driver (a Warlock at Ratchet, two helpers without Wuber in the group) takes Tester's request,
-- casts on its button, the helpers click; Tester's window is open on the ride. opts.driver: the driver's
-- name; opts.realm: both windows' realm; opts.forge(r): runs on Tester's window once he is in the group.
local function goldRide(opts)
	opts = opts or {}
	local w = T.newWorld({ realm = T.H.FOUNDER_REALM })
	local dn = opts.driver or T.ANITA
	local d = T.driver(w, dn)
	local r = T.rider(w)
	if opts.realm then d.realm, r.realm = opts.realm, opts.realm end
	w:addBot(T.BEA, { spot = "Ratchet" })
	w:addBot(T.CAL, { spot = "Ratchet" })
	w:group({ dn, T.BEA, T.CAL })
	T.settle(w)
	T.goOnline(d)
	local out = { w = w, d = d, r = r, dlog = playLog(d), rlog = playLog(r), phases = {} }
	d.W.Listen("DRIVE_RITUAL", function(_, phase) out.phases[#out.phases + 1] = phase end)
	T.requestVia(r, dn:lower())
	local forged = false
	for _ = 1, 15 do
		w:advance(2)
		local st = r.W.ride and r.W.ride.state
		if st == "portal" then break end
		if st == "ingroup" and opts.forge and not forged then forged = true opts.forge(r) end
		local p = d.W.Drive.Plan and d.W.Drive.Plan()
		if p and p.title and p.title:find("^Summon") then d:click(d.W.Drive.button) end
		if w.ritual and w.ritual.stage == "channel" then
			w:clickPortal(T.BEA)
			w:clickPortal(T.CAL)
		end
	end
	eq(r.W.ride and r.W.ride.state, "portal", "the summon is up on Tester's window")
	r.W.UI.Toggle(true)
	w:advance(3)
	local found = r.W.UI.state and r.W.UI.state.screens and r.W.UI.state.screens.found
	out.ringGold = found and found.hero and found.hero.gold
	-- (design 4, A) the live portal is one still: gold = desaturated, the same file
	out.bookGold = found and found.hero and found.hero.art and found.hero.art:IsDesaturated()
	out.bookViolet = found and found.hero and found.hero.art and not found.hero.art:IsDesaturated()
	out.ringTex = found and found.hero and found.hero.runes and tostring(found.hero.runes:GetTextureFilePath())
	r:clickText("Accept summon")
	w:advance(5)
	ok(r.W.RIDE_RANK[r.W.ride.state] >= r.W.RIDE_RANK.arrived, "Tester arrived")
	return out
end

test("gold end to end: a founder's summon is gold on both windows (portal, ring, arrival, the founder's own cast)", function()
	local o = goldRide()
	local w, d, r = o.w, o.d, o.r
	eq(r.W.ride.summonedBy, "anita lift", "the game named Anita in the summon box")
	-- (2.3.0 riders hear G: its caster must reach FounderSummon as Anita's key, not her short name)
	local gk = type(r.W.ride.ritual) == "table" and r.W.ride.ritual.casterKey or nil
	ok(gk == nil or gk == "anita lift", "G's caster believed as 'anita lift', got " .. tostring(gk)
		.. " (Drive.Kitchen sends W.Short(caster); Net.Portal keys it as is)")
	ok(has(o.phases, "c"), "the driver's window heard its own cast (DRIVE_RITUAL c): " .. table.concat(o.phases, ","))
	-- the founder's own screen: the gold portal on her own cast
	ok(has(o.dlog, "portal_open(gold)+"), "Anita's own cast: gold portal (" .. table.concat(o.dlog, " ") .. ")")
	ok(textures(d, "portal_open_gold") > 0, "Anita's window drew the gold flipbook")
	-- the rider: gold portal, gold ring, gold arrival; never a violet one
	ok(has(o.rlog, "portal_open(gold)+"), "Tester: gold portal (" .. table.concat(o.rlog, " ") .. ")")
	ok(has(o.rlog, "arrival(gold)+"), "Tester: gold arrival")
	ok(not has(o.rlog, "portal_open+") and not has(o.rlog, "arrival+"), "Tester: no violet portal or arrival")
	eq(o.ringGold, true, "Tester's Found screen: the gold ring")
	eq(o.bookGold, true, "the live portal still is desaturated and gold for a founder")
	eq(o.bookViolet, false, "the still is not the plain violet one for a founder")
	ok(o.ringTex and o.ringTex:find("runes_gold", 1, true), "the gold rune sheet: " .. tostring(o.ringTex))
	-- (the portal's sheet turns into its loop sheet once it is open)
	ok(textures(r, "portal_open_gold") + textures(r, "portal_loop_gold") > 0, "the gold portal drawn on Tester's window")
	for _, part in ipairs({ "arrival_gold", "runes_gold" }) do ok(textures(r, part) > 0, part .. " drawn on Tester's window") end
	T.clean(w)
end)

test("gold end to end: a non-founder's summon is violet everywhere; his own cast plays nothing new", function()
	local o = goldRide({ driver = T.BOB })
	local w, d, r = o.w, o.d, o.r
	ok(has(o.phases, "c"), "Bob's window heard his cast")
	eq(#o.dlog, 0, "Bob's own cast: no screen effect (" .. table.concat(o.dlog, " ") .. ")")
	ok(has(o.rlog, "portal_open+") and has(o.rlog, "arrival+"), "Tester: violet portal and arrival (" .. table.concat(o.rlog, " ") .. ")")
	eq(o.ringGold, false, "Tester's ring stays violet")
	eq(textures(r, "_gold"), 0, "no gold art anywhere on Tester's window")
	eq(textures(d, "_gold"), 0, "nor on Bob's")
	T.clean(w)
end)

test("gold end to end: a forged founder stays violet (a founder named in the ride, Bob summoning)", function()
	-- Bob's ride claims Anita as its caster and payee; Anita isn't in the group and the game names Bob
	local o = goldRide({ driver = T.BOB, forge = function(r)
		r.W.ride.payee = T.ANITA
		r.W.ride.ritual = { casterKey = "anita lift", phase = "c" }
	end })
	local w, d, r = o.w, o.d, o.r
	eq(r.W.ride.summonedBy, "bob stone", "the game named Bob")
	ok(has(o.rlog, "portal_open+") and has(o.rlog, "arrival+"), "Tester: violet (" .. table.concat(o.rlog, " ") .. ")")
	eq(o.ringGold, false, "violet ring")
	eq(textures(r, "_gold"), 0, "no gold art")
	T.clean(w)
end)

test("gold end to end: a founder's name on another ruleset is violet, and her own cast plays nothing new", function()
	local o = goldRide({ realm = "CAMWOW US2 Realm 1 PvP" })
	local w, d, r = o.w, o.d, o.r
	eq(#o.dlog, 0, "no own-cast portal off the founders' ruleset (" .. table.concat(o.dlog, " ") .. ")")
	ok(has(o.rlog, "portal_open+") and has(o.rlog, "arrival+"), "Tester: violet (" .. table.concat(o.rlog, " ") .. ")")
	eq(o.ringGold, false, "violet ring")
	eq(textures(r, "_gold"), 0, "no gold art")
	T.clean(w)
end)
