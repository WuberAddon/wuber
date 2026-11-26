local T = ...
local H, test, eq, ok = T.H, T.test, T.eq, T.ok
local ANITA = T.ANITA or "Anita Lift"

-- HUNT-80: a rider who left the group within the grace and then pays by trade gets the paid line.
local function run(leave)
	local w = T.newWorld({ tradeOrder = "real" })
	local a = w:addClient(ANITA, { spot = "Undercity", class = "WARLOCK", allowMissing = true })
	local A = a.W.Drive
	A.SetOpt("autoTrade", false)
	A.SetOpen(true)
	w:addBot("Dan Miller", { spot = "Undercity" })
	local c = { name = "Dan Miller", key = "dan miller", state = "arrived", price = 5000, paid = 0, at = 0, tries = 1 }
	A.customers["dan miller"] = c
	local lines = {}
	local real = a.W.Print
	a.W.Print = function(s, ...) lines[#lines + 1] = tostring(s); return real(s, ...) end
	local dan = w:player("Dan Miller")
	ok(w:openTrade(dan, a.player), "trade opens")
	w:typeTradeMoney(dan, 0, 50, 0)
	if leave then
		-- the rider's row goes (left the group), the owing entry keeps the fare for the grace
		A.customers["dan miller"] = nil
		A.owing["dan miller"] = { c = c, at = a.env.GetTime(), grace = 10 }
	end
	w:tradeAccept(w:player(ANITA))
	w:tradeAccept(dan)
	w:advance(3)
	return w, lines, c
end

local function has(lines, pat)
	for _, l in ipairs(lines) do if l:find(pat) then return true end end
	return false
end

test("r33 HUNT-80: control, a rider in the list who pays gets the paid line", function()
	local w, lines = run(false)
	ok(has(lines, "Dan Miller paid "), "paid line: " .. table.concat(lines, " | "))
	T.clean(w)
end)

test("r33 HUNT-80: a rider who left the group a moment ago and pays by trade gets the paid line, not 'gave you'", function()
	local w, lines, c = run(true)
	ok(has(lines, "Dan Miller paid "), "paid line: " .. table.concat(lines, " | "))
	eq(has(lines, "gave you"), false, "no 'gave you' line")
	T.clean(w)
end)
