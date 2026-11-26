-- A driver addon that is still installed next to Wuber (job 2743): the stand-in in tests/fixtures/addons/OldDriver
-- registers itself through WuberAPI.SetDriver. These tests check what Wuber does with such an addon: what riders see,
-- how its requests, declines, cancels and queue places travel, and which window beacons. (Loaded by tests/run.lua.)
local T = ...
local test, eq, ok = T.test, T.eq, T.ok
local H = T.H

local function team(w, n)
	local cs = {}
	local names = { T.ANA, T.BEA, T.CAL }
	for i = 1, n or 3 do
		cs[i] = w:addClient(names[i], { spot = "Ratchet", class = "WARLOCK", loadRR = "1.4.1", allowMissing = not T.HAVE_UI })
	end
	if #cs > 1 then w:group(names) end
	w:advance(1)
	for i = 2, #cs do cs[i].env.RitualRides.cfg.lead = false end -- only the leader's window beacons
	return cs
end

local function senders(w, kind, since)
	local s, n = {}, 0
	for _, e in ipairs(T.msgs(w, kind)) do
		if not since or e.at > since then
			if not s[e.from] then n = n + 1 end
			s[e.from] = true
		end
	end
	return s, n
end

test("old driver addon: it is the driver, Wuber's own driving stays off, only the leader's window beacons", function()
	local w = T.newWorld()
	local cs = team(w)
	local r = T.rider(w)
	T.settle(w)
	for _, c in ipairs(cs) do
		eq(c.W.Drive.Lock(), "rr", c.player.name .. " Wuber's engine is locked while the old addon is loaded")
		eq(c.W.Provider(), "Ritual Rides", c.player.name .. " provider set")
		eq(c.env.WuberAPI.Driving(), "provider")
		eq(c.W.Driver and c.W.Driver.SetOnline(true), false, "Wuber's own driver mode stays off with a provider")
	end
	w:advance(10)
	local s, n = senders(w, "D")
	eq(n, 1, "one window beacons")
	ok(s[T.ANA], "the leader beacons")
	local dd = r.W.drivers["ana smith"]
	ok(dd, "the rider sees the team")
	eq(dd.team, 3, "team of three")
	eq(dd.dest, "Ratchet")
	T.clean(w)
end)

test("old driver addon: a beacon that is nil (closed window) sends nothing and the driver leaves the list", function()
	local w = T.newWorld()
	local cs = team(w, 1)
	local r = T.rider(w)
	T.settle(w, 20)
	ok(r.W.drivers["ana smith"], "listed while open")
	cs[1].env.RitualRides.cfg.open = false
	w:advance(200)
	local _, n = senders(w, "D", w.time - 60)
	eq(n, 0, "no beacon while closed")
	eq(r.W.drivers["ana smith"], nil, "gone from the rider's list")
	T.clean(w)
end)

test("old driver addon: a request reaches onRequest once, is accepted through WuberAPI, and a Wuber cancel reaches onCancel", function()
	local w = T.newWorld()
	local cs = team(w)
	local r = T.rider(w)
	T.settle(w, 20)
	local SI = cs[1].env.RitualRides
	ok(r.W.drivers["ana smith"], "seen")
	r.W.RequestRide("ana smith")
	w:advance(3)
	eq(SI.count(SI.customers), 1, "one customer in the old addon")
	eq(#T.msgs(w, "A", T.ANA, "WHISPER"), 1, "accepted through WuberAPI.Accept")
	r.W.CancelRide()
	w:advance(3)
	eq(SI.count(SI.customers), 0, "off the old addon's list")
	eq(#SI.cancels, 1, "onCancel once")
	T.clean(w)
end)

test("old driver addon: a decline travels as N with its reason: closed, price, blocked", function()
	local w = T.newWorld()
	local cs = team(w, 1)
	local r = T.rider(w)
	T.settle(w, 20)
	local SI = cs[1].env.RitualRides
	-- a request under the beacon's price
	w:inject(T.TESTCHAR, "R~1~ABCDEF~Ratchet~100", "WHISPER", cs[1])
	w:advance(2)
	local N = T.msgs(w, "N", T.ANA)
	eq(#N, 1, "N for a low price")
	eq(T.fields(N[1])[4], "price")
	-- a blocked rider
	SI.blocked["bob stone"] = true
	w:addBot(T.BOB)
	w:inject(T.BOB, "R~1~GHIJKL~Ratchet~50000", "WHISPER", cs[1])
	w:advance(2)
	N = T.msgs(w, "N", T.ANA)
	eq(#N, 2, "N for a blocked rider")
	eq(T.fields(N[2])[4], "blocked")
	-- closed
	SI.cfg.open = false
	w:inject(T.TESTCHAR, "R~1~MNOPQR~Ratchet~50000", "WHISPER", cs[1])
	w:advance(2)
	N = T.msgs(w, "N", T.ANA)
	eq(#N, 3, "N for a closed window")
	eq(T.fields(N[3])[4], "closed")
	eq(SI.count(SI.customers), 0, "nobody was taken")
	T.clean(w)
end)

test("old driver addon: a queued Wuber rider is told their place (P through WuberAPI.Queue)", function()
	local w = T.newWorld()
	local cs = team(w)
	local r1 = T.rider(w)
	local r2 = T.rider(w, T.BOB, { spot = "Undercity" })
	T.settle(w, 20)
	ok(r1.W.drivers["ana smith"] and r2.W.drivers["ana smith"], "both see the team")
	cs[1].env.RitualRides.cfg.max = 1 -- the second waits in the queue
	w:advance(1)
	r1.W.RequestRide("ana smith")
	w:advance(3)
	r2.W.RequestRide("ana smith")
	w:advance(8)
	local P = T.msgs(w, "P", T.ANA, "WHISPER")
	ok(#P >= 1, "a P from the team (" .. #P .. ")")
	local toBob
	for _, e in ipairs(P) do if e.target:gsub("%-", " ") == T.BOB then toBob = e end end
	ok(toBob, "Bob (second) is told his place")
	T.clean(w)
end)

test("old driver addon: a price under 50s never goes out under 50s", function()
	local w = T.newWorld()
	local cs = team(w)
	local r = T.rider(w)
	T.settle(w, 20)
	ok(r.W.drivers["ana smith"], "listed at the normal price")
	cs[1].env.RitualRides.cfg.price = 1000
	w:advance(70)
	local late = 0
	for _, e in ipairs(T.msgs(w, "D", T.ANA)) do
		if e.at > w.time - 60 then
			late = late + 1
			ok(tonumber(T.fields(e)[7]) >= 5000, "no beacon under 50s: " .. e.text)
		end
	end
	ok(late >= 1, "the team still beacons, at the 50s floor")
	ok(r.W.drivers["ana smith"] and r.W.drivers["ana smith"].price >= 5000, "listed at 50s or more")
	T.clean(w)
end)

test("old driver addon: with a provider, a whispered Q is answered by the leader's window only", function()
	local w = T.newWorld({ realm = H.FOUNDER_REALM })
	local cs = {}
	for i, n in ipairs({ T.ANITA, "Farra Way", "Hayley Cab" }) do
		cs[i] = w:addClient(n, { spot = "Ratchet", class = "WARLOCK", loadRR = "1.4.1", allowMissing = not T.HAVE_UI })
	end
	w:group({ T.ANITA, "Farra Way", "Hayley Cab" })
	w:advance(1)
	for i = 2, 3 do cs[i].env.RitualRides.cfg.lead = false end
	local r = T.rider(w, "Wuber Rocks", { copy = "other" })
	T.settle(w, 20)
	r.W.Ping()
	w:advance(5)
	local x = r.W.drivers["anita lift"]
	ok(x and x.via == "WHISPER", "the leader answers by whisper")
	eq(r.W.drivers["farra way"], nil, "a teammate's window doesn't")
	T.clean(w)
end)
