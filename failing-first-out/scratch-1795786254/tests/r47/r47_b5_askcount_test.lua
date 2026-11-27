local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H

local function header(d)
	local out = {}
	for _, fs in ipairs(d:findText("^%d+ in progress$", true)) do out[#out+1] = fs:GetText() end
	for _, fs in ipairs(d:findText("asking$", true)) do out[#out+1] = fs:GetText() end
	return table.concat(out, "|")
end
test("r47 b5: the Riders header says '1 asking' when the only rider has already paid", function()
	local w = T.newWorld()
	local d = T.driver(w, T.ANITA, { spot = "Ratchet" })
	local r = T.rider(w, T.TESTCHAR, { spot = "Orgrimmar" })
	T.settle(w)
	T.goOnline(d) w:advance(5)
	r.W.RequestRide(d.W.Key and d.W.Key(T.ANITA) or "anita lift") w:advance(3)
	d.W.Char().wizard = true
	d.W.UI.Toggle(true) w:advance(2.5)
	d:clickText("Drive") w:advance(1)
	local list = d.W.Drive.Sorted()
	ok(#list == 1, "one rider in the list, got " .. #list)
	local c = list[1]
	ok(header(d):find("in progress", 1, true), "control: a rider being served reads 'in progress': [" .. header(d) .. "]")
	c.state = "paid" d.W.Driver.Refresh() w:advance(0.05)
	ok(c.state == "paid", "state is " .. tostring(c.state))
	ok(not header(d):find("asking", 1, true), "the only rider has PAID, yet the Riders header reads [" .. header(d) .. "]")
	T.clean(w)
end)
