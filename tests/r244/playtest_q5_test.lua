-- The Customers line and the Note sheet show the last ride's tip and the total tipped, worked out from the logged
-- payments (gold paid minus the price); nothing new is saved.
local T = ...
local H, test, eq, ok = T.H, T.test, T.eq, T.ok

local DAN, EVE = "Dan Rider", "Eve Night"

local function world()
	local w = T.newWorld()
	local a = T.driver(w, T.ANITA, { spot = "Undercity" })
	w:advance(15)
	return w, a, a.W, a.W.Drive
end

local function logRide(DR, at, copper, name, price)
	local l = DR.Log()
	l.rides[#l.rides + 1] = table.concat({ at, copper, name, "Orgrimmar", "t", price }, ",")
end

test("playtest Q5: the facts line shows the last ride's tip with its percent and the total", function()
	local w, a, W, DR = world()
	local t0 = a.env.time()
	logRide(DR, t0 - 400000, 5250, DAN, 5000) -- tip 250 (2s 50c)
	logRide(DR, t0 - 1000, 5500, DAN, 5000)   -- tip 500 = 5s, 10%
	local line = W.Driver.CustomerFacts(DAN)
	ok(line:find("tipped 5s (10%)", 1, true), "the last ride's tip: " .. line)
	ok(line:find("7s 50c tipped in all", 1, true), "the total tipped: " .. line)
	ok(line:find("2 rides with you", 1, true), "the rides are still there: " .. line)
	local f = DR.CustomerFacts(DAN)
	eq(f.lastTip, 500, "last tip") eq(f.lastPrice, 5000, "last price") eq(f.tipTotal, 750, "total")
	T.clean(w)
end)

test("playtest Q5: a last ride without a tip says so", function()
	local w, a, W, DR = world()
	local t0 = a.env.time()
	logRide(DR, t0 - 400000, 5500, DAN, 5000)
	logRide(DR, t0 - 1000, 5000, DAN, 5000)
	local line = W.Driver.CustomerFacts(DAN)
	ok(line:find("no tip", 1, true), line)
	ok(line:find("5s tipped in all", 1, true), line)
	T.clean(w)
end)

-- guard: an old log line with no price (or a rider who never paid) shows no tip text and no error
test("playtest Q5: a log line with no price and a rider with no rides show no tip words", function()
	local w, a, W, DR = world()
	local t0 = a.env.time()
	local l = DR.Log()
	l.rides[#l.rides + 1] = table.concat({ t0 - 1000, 5000, EVE, "Undercity", "t" }, ",")
	local line = W.Driver.CustomerFacts(EVE)
	ok(line:find("1 ride with you", 1, true) and not line:find("tip", 1, true), line)
	eq(W.Driver.CustomerFacts("Nobody Here"), "No rides with you yet", "no rides")
	T.clean(w)
end)

test("playtest Q5: the Note sheet shows the tip words too", function()
	local w, a, W, DR = world()
	local t0 = a.env.time()
	logRide(DR, t0 - 1000, 5500, DAN, 5000)
	local dan = { name = DAN, key = DAN:lower(), state = "lead", source = "whisper", at = 0, price = 5000, paid = 0 }
	DR.Sorted = function() return { dan } end
	DR.customers = { [dan.key] = dan }
	DR.IsOpen = function() return true end
	T.openDrive(a)
	if W.UI and W.UI.ShowDrive then W.UI.ShowDrive("console") end
	w:advance(2)
	W.Driver.RefreshNow()
	w:advance(1)
	local D = W.Driver
	D.OpenMenu(dan)
	w:advance(1)
	a:clickOn(D.ui.sheets.menu.items.custnote.note)
	w:advance(1)
	ok(D.ui.sheets.note and D.ui.sheets.note.frame.open, "the Note sheet")
	local all = table.concat(a:visibleTexts(), " | ")
	ok(all:find("tipped 5s (10%)", 1, true), all)
	T.clean(w)
end)
