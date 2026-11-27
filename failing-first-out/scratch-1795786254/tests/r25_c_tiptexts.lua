-- Round 25 T3: the 14 login-tip texts and "Show me".
local T = ...
local test, eq, ok = T.test, T.eq, T.ok

local function open(w, r)
	w:advance(15)
	r.W.db.coach = true
	return r.W.Mod("UI.TipTexts")
end

test("r25 C: tip texts are complete, unique, short, plain", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR)
	local M = open(w, r)
	ok(#M.list >= 1, "the tip list is not empty")
	-- the rider tips come first, then the driver tips: the driver flag turns on once and stays on
	local firstDriver
	for i, t in ipairs(M.list) do
		if t.driver and not firstDriver then firstDriver = i end
	end
	ok(firstDriver, "there are driver tips")
	local ids = {}
	for i, t in ipairs(M.list) do
		ok(type(t.id) == "string" and t.id:match("^[a-z_]+$"), "id " .. i)
		ok(not ids[t.id], "unique " .. t.id)
		ids[t.id] = true
		ok(type(t.text) == "string" and #t.text > 10 and #t.text <= 110, "length " .. t.id .. " " .. #t.text)
		ok(not t.text:lower():find("free"), "no free in " .. t.id)
		ok(not t.text:find("%(Drivers%)"), "no prefix " .. t.id)
		ok(type(t.screen) == "string", "screen " .. t.id)
		eq(t.driver, i >= firstDriver, "driver flag " .. t.id)
	end
	T.clean(w)
end)

test("r25 C: Show opens a screen for every tip", function()
	local w = T.newWorld()
	local d = T.driver(w, T.BOB)
	T.settle(w)
	local M = open(w, d)
	for _, t in ipairs(M.list) do
		d.W.UI.Toggle(false)
		w:advance(1)
		ok(M.Show(t) == true, "opens " .. t.id .. " (" .. t.screen .. ")")
		w:advance(1)
		ok(d.W.UI.IsShown(), "window shown for " .. t.id)
	end
	ok(M.Show("fly_or_summon"), "by id")
	eq(M.Show("nope"), false, "unknown")
	T.clean(w)
end)
