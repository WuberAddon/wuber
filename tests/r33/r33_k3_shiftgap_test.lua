local T = ...
local test, eq, ok = T.test, T.eq, T.ok

test("r33 k3: AUD-81: logging back in hours later starts a fresh shift, the offline hours are not counted", function()
	local w = T.newWorld()
	local a = w:addClient("Ana Smith", { spot = "Undercity", class = "WARLOCK" })
	w:advance(10)
	ok(a.W.Drive.SetOpen(true), "open")
	w:advance(600)
	local s0 = a.W.Drive.ShiftSummary()
	ok(s0 and s0.open >= 590 and s0.open <= 700, "control: about 10 minutes so far")
	local saved = w:logout(a)
	for _ = 1, 180 do w:advance(60) end
	local b = w:addClient("Ana Smith", { spot = "Undercity", class = "WARLOCK", saved = saved, allowMissing = true })
	w:advance(10)
	local D = b.W.Drive
	local s = D.ShiftSummary()
	ok(s ~= nil, "a shift exists")
	if D.Selling() then
		ok(s.open < 1200, "still open after 3 h shut: the new shift is short (got " .. s.open .. " s)")
	else
		ok(s.open < 1200, "closed: the shift ended when last seen open (got " .. s.open .. " s)")
	end
	T.clean(w)
end)
