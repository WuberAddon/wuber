local T = ...
local test, eq, ok, clean = T.test, T.eq, T.ok, T.clean

test("r34 c2: TryHours suggests an hour only from asks that came while closed, not in an hour open for a few minutes", function()
	local w = T.newWorld()
	local c = w:addClient(T.ANITA, { spot = "Undercity", class = "WARLOCK" })
	local DR = c.W.Drive
	local now = c.env.time()
	local l = DR.Log()
	local function at(daysAgo, hour, min)
		local d = os.date("*t", now - daysAgo * 86400)
		return os.time({ year = d.year, month = d.month, day = d.day, hour = hour, min = min or 10, sec = 0 })
	end
	local function hk(t) return os.date("%Y%m%d%H", t) end
	-- 18:xx yesterday: open 10 minutes, two buyers asked (while open); 21:xx: closed all hour, one buyer
	l.open = { [hk(at(1, 18))] = 10 }
	l.asks = { at(1, 18, 5) .. ",match,X X,m,Undercity,wtb summon", at(1, 18, 6) .. ",match,Y Y,m,Undercity,lf sum",
		at(1, 21, 1) .. ",match,Z Z,m,Undercity,wtb summon" }
	local try = DR.TryHours(7, 3)
	eq(#try, 1, "only the closed hour")
	eq(try[1].hour, 21) eq(try[1].asks, 1)
	clean(w)
end)
