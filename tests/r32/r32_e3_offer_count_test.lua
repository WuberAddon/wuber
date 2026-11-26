local T = ...
local H, test, eq, ok = T.H, T.test, T.eq, T.ok
local ANA, BEA, TESTCHAR = "Ana Smith", "Bea Jones", "Wuber TestCharacter"
local function key(n) return (n:lower():gsub("[%s%-]+", " ")) end
local function crewSaved(me, names, captain)
	local crew = {}
	for _, n in ipairs(names) do if n ~= me then crew[#crew + 1] = { name = n, role = "lock", app = true } end end
	return { chars = { [key(me)] = { crew = crew, captain = (me == captain) and "" or captain, wizard = true } } }
end
local function count(c) local d = c.W.db.drive.iouDay; return d and d.n or 0 end

local function scene()
	local w = H.NewWorld({})
	local names = { BEA, ANA }
	local cs = {}
	for i, name in ipairs(names) do
		cs[i] = w:addClient(name, { spot = "Undercity", class = "WARLOCK", saved = { Wuber = crewSaved(name, names, BEA) } })
	end
	w:group(names)
	w:advance(15)
	return w, cs[2]
end

test("r32 e3: a declined raincheck offer gives its place back, an accepted one keeps it", function()
	local w, ana = scene()
	local exp = ana.env.time() + 7 * 86400
	ana.W.Drive.Do("IOU", "i", "Offer001", key(TESTCHAR), 5000, exp, "")
	ana.W.Drive.Do("IOU", "i", "Offer002", key(TESTCHAR) .. "x", 5000, exp, "")
	eq(count(ana), 2, "two open offers count")
	ok(ana.W.Drive.RaincheckHeard("no", key(TESTCHAR), TESTCHAR, "Offer001"), "decline heard")
	eq(count(ana), 1, "the declined offer gave its place back")
	ok(ana.W.Drive.RaincheckHeard("ok", key(TESTCHAR) .. "x", TESTCHAR, "Offer002"), "accept heard")
	eq(count(ana), 1, "the accepted one still counts")
	T.clean(w)
end)

test("r32 e3: a lapsed raincheck offer gives its place back", function()
	local w, ana = scene()
	local exp = ana.env.time() + 7 * 86400
	ana.W.Drive.Do("IOU", "i", "Offer003", key(TESTCHAR), 5000, exp, "")
	eq(count(ana), 1, "open offer counts")
	for i = 1, 31 do w:advance(60) end
	eq(ana.W.db.drive.iou.Offer003.why, "lapsed", "lapsed")
	eq(count(ana), 0, "the lapsed offer gave its place back")
	T.clean(w)
end)
