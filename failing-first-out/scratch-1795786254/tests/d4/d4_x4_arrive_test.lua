-- d4 X4: a summon of the driver's own that lands is an arrival, not a rider who "walked up" (design round 4).
-- The harness's World:summon now tells a driver caster's Wuber about its cast, as UNIT_SPELLCAST_START does in
-- the game (customer tries >= 1), so the older tests that use w:summon as their shortcut reach "arrived" and pay.
local T = ...
local H, test, eq, ok = T.H, T.test, T.eq, T.ok

local ANITA, TESTCHAR = T.ANITA or "Anita Lift", T.TESTCHAR or "Wuber TestCharacter"

local function stages(w, from)
	local out = {}
	for _, m in ipairs(w:messages("S", from)) do out[#out + 1] = tostring(m.text or m[1] or m) end
	return table.concat(out, " ")
end

local function ride()
	local w = T.newWorld()
	local d = T.driver(w)
	local r = T.rider(w)
	T.settle(w)
	r.W.db.autoAccept = false
	T.goOnline(d)
	r.W.RequestRide("anita lift")
	w:advance(1)
	T.take(d)
	w:advance(1)
	r.W.UI.Toggle(true)
	w:advance(2.5)
	r:clickText("Accept invite")
	w:advance(1)
	return w, d, r
end

test("d4 X4: the driver's summon counts as cast (tries 1), the ride arrives, S arrived goes out, nobody is dropped", function()
	local w, d, r = ride()
	local DR = d.W.Drive
	DR.SetOpt("autoTrade", false) -- the trade would open 3 s after landing and the rider would read "paying"
	local c = DR.customers["wuber testcharacter"]
	eq(c and c.tries or 0, 0, "nothing cast yet")
	w:summon(d, TESTCHAR)
	ok(DR.customers["wuber testcharacter"].tries >= 1, "the cast is counted: " .. tostring(DR.customers["wuber testcharacter"].tries))
	w:advance(1)
	r:clickText("Accept summon")
	w:advance(8)
	eq(T.rideState(r), "arrived", "the rider's ride arrived (not stuck at invited)")
	ok(stages(w, ANITA):find("arrived", 1, true), "S arrived was sent: " .. stages(w, ANITA))
	eq(#w:messages("DROP", ANITA), 0, "no DROP")
	T.clean(w)
end)

test("d4 X4: ... and the rider's payment still ends in paid, with S paid sent", function()
	local w, d, r = ride()
	w:summon(d, TESTCHAR)
	w:advance(1)
	r:clickText("Accept summon")
	w:advance(4)
	w:openTrade(d, r)
	w:tradeMoney(r, 5000)
	w:tradeAccept(d)
	w:tradeAccept(r)
	w:advance(2)
	eq(T.rideState(r), "done")
	ok(stages(w, ANITA):find("paid", 1, true), "S paid was sent: " .. stages(w, ANITA))
	eq(#w:messages("DROP", ANITA), 0, "no DROP")
	T.clean(w)
end)

test("d4 X4: control: a rider who walks up with no cast is still dropped (the harness only adds a cast for w:summon)", function()
	local w = T.newWorld()
	local a = w:addClient(ANITA, { spot = "Orgrimmar", class = "WARLOCK", allowMissing = true })
	local A = a.W.Drive
	A.SetOpen(true)
	w:addBot("Dan Miller", { spot = "Undercity" })
	a:chatEvent("CHAT_MSG_WHISPER", "summon pls", "Dan Miller")
	w:advance(9)
	w:move("Dan Miller", "Orgrimmar")
	w:advance(10)
	ok(not A.customers["dan miller"], "walked up: gone")
	T.clean(w)
end)
