local T = ...
local test, eq, ok = T.test, T.eq, T.ok

-- #61: a rider who paid, was dropped and whispers again must show their earlier ride in Advanced mode.
-- The row cache held the 0 counted while that ride was still going on, and nothing cleared it on the drop.
test("returning rider: the ride count is not stuck at 0 after the rider paid, was dropped and came back", function()
	local w = T.newWorld()
	local ana = w:addClient("Ana Smith", { spot = "Undercity", class = "WARLOCK", allowMissing = true })
	w:addBot("Zed Return", { spot = "Undercity" })
	w:advance(1)
	local DR, D = ana.W.Drive, ana.W.Driver
	DR.SetOpt("autoTrade", false)
	DR.SetOpen(true)
	w:advance(2)
	local function whisper() ana:chatEvent("CHAT_MSG_WHISPER", "summon", "Zed Return") end
	whisper()
	w:advance(1)
	ok(DR.customers["zed return"], "Zed is in the queue")
	DR.Do("PAID", "Zed Return", 5000, "m")
	w:advance(2)
	eq(D.RideCount("Zed Return"), 0, "control: while the first ride is going on it is not counted")
	DR.Do("DROP", "Zed Return")
	w:advance(2)
	whisper()
	w:advance(1)
	ok(DR.customers["zed return"], "Zed is back in the queue")
	eq(D.RideCount("Zed Return"), 1, "the earlier paid ride is counted on the returning row")
	T.clean(w)
end)
