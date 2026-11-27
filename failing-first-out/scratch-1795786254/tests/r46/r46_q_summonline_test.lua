-- Round 46 q: FEAT-01 (a), the driver's side of the average summon time. The Drive console's "Today's takings"
-- card shows one grey line under the gold figure, "Your summons: about 45 sec" (the Fly or summon card's own words
-- for the same seconds), with its own tooltip. Before the third counted ride there is no line and the card is 64 high.
local T = ...
local test, eq, ok = T.test, T.eq, T.ok

local function plain(t) return (tostring(t):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end
local function has(a, text)
	for _, t in ipairs(a:visibleTexts()) do if plain(t):find(text, 1, true) then return true end end
	return false
end

-- a driver with the wide console up; list: { { total, cast }, ... } seeded as W.db.drive.summons
local function console(list)
	local w = T.newWorld()
	local a = T.driver(w, T.ANITA, { spot = "Undercity" })
	w:advance(15)
	local W = a.W
	W.db.drive = W.db.drive or {}
	local s = {}
	for i, v in ipairs(list or {}) do s[i] = { total = v[1], cast = v[2] } end
	W.db.drive.summons = s
	a.wide = true
	W.db.coach = true
	W.UI.WindowWide(true)
	T.openDrive(a)
	W.UI.ShowDrive("console")
	w:advance(1)
	W.Driver.RefreshNow()
	w:advance(1)
	W.Driver.RefreshNow()
	return w, a, W
end

-- the takings card: the parent of its "Today's takings" heading
local function today(a)
	local f = a:findText("Today's takings", false, true)[1]
	return f and f:GetParent()
end

test("r46 q: three counted summons show 'Your summons: about 45 sec' and the card is 16 taller", function()
	local w, a, W = console({ { 40, 10 }, { 45, 20 }, { 50, 30 } })
	ok(has(a, "Your summons: about 45 sec"), "the line shows: " .. table.concat(a:visibleTexts(), " | "))
	local c = today(a)
	ok(c, "the takings card")
	eq(c:GetHeight(), 80, "64 + 16")
	local tip = c.avgHit and c.avgHit.wuberTip
	ok(tip, "the line has its own tooltip")
	eq(tip.title, "Your summons")
	eq(tip.text, "Request to arrival, averaged over your last 3 counted summons. Counted: no queue, arrived, paid by trade. Cast to arrival: about 20 sec.")
	T.clean(w)
end)

test("r46 q: a minute or more uses the minute words; the longest is 'about 15 min'", function()
	local w, a = console({ { 120, 20 }, { 120, 20 }, { 120, 20 } })
	ok(has(a, "Your summons: about 2 min"), "2 min")
	T.clean(w)
	local w2, a2 = console({ { 900, 60 }, { 900, 60 }, { 900, 60 } })
	ok(has(a2, "Your summons: about 15 min"), "15 min")
	T.clean(w2)
end)

test("r46 q: fewer than three counted summons: no line and the card keeps 64", function()
	local w, a, W = console({ { 40, 10 }, { 45, 20 } })
	ok(not has(a, "Your summons"), "no line")
	eq(today(a):GetHeight(), 64, "today's height")
	T.clean(w)
end)

test("r46 q: the line follows the card's refresh", function()
	local w, a, W = console({ { 40, 10 }, { 45, 20 } })
	W.db.drive.summons[3] = { total = 100, cast = 30 }
	W.Driver.RefreshNow()
	w:advance(1)
	ok(has(a, "Your summons: about 62 sec") or has(a, "Your summons: about 1 min"), "shows after the third ride")
	eq(today(a):GetHeight(), 80)
	W.db.drive.summons[3] = nil
	W.Driver.RefreshNow()
	w:advance(1)
	ok(not has(a, "Your summons"), "gone again")
	eq(today(a):GetHeight(), 64)
	T.clean(w)
end)
