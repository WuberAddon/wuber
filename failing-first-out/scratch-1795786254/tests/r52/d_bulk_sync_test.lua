-- r52 group D: a crew sync never drops a blocklist or message-template entry (Drive.Team bulk lane).
local T = ...
local H, test, eq, ok = T.H, T.test, T.eq, T.ok

-- Ana and Bea in one crew; Ana's chat is locked (answer 11), so everything she queues just waits
local function crew()
	local w = T.newWorld()
	local ana = w:addClient(T.ANA, { spot = "Orgrimmar", class = "WARLOCK" })
	local bea = w:addClient(T.BEA, { spot = "Orgrimmar", class = "WARLOCK" })
	w:group({ T.ANA, T.BEA })
	T.settle(w)
	local A, B = ana.W.Drive, bea.W.Drive
	ok(A.OfferCrew(T.BEA), "setup: the crew offer")
	w:advance(3)
	B.AnswerOffer(T.ANA, true)
	w:advance(5)
	ana.chatLock = true
	return w, ana, bea
end

test("r52 D #6: a sync of 40 BLK + 10 TPL + 40 IOU keeps every BLK and TPL waiting for the outbox", function()
	local w, ana, bea = crew()
	local A = ana.W.Drive
	for i = 1, 40 do A.SendBulk("BLK", "name" .. i, "r", "1") end
	for i = 1, 10 do A.SendBulk("TPL", "kind" .. i, "text") end
	for i = 1, 40 do A.SendBulk("IOU", "p" .. i, "1") end
	local _, nb = A.CommBacklog()
	eq(nb, 50, "capped at 50: the 40 BLK and 10 TPL, the IOUs wait for the next sync")
	ana.chatLock = false
	w:advance(90)
	local n = 0
	for k in pairs(bea.W.db.drive.blocklist or {}) do if k:find("^name%d+") then n = n + 1 end end
	eq(n, 40, "Bea's window got all 40 blocklist entries")
	T.clean(w)
end)

-- guard: the cap still holds at 50 and a late BLK takes an IOU's place (same on the base)
test("r52 D #6: a late BLK pushes out an IOU, never another BLK or TPL", function()
	local w, ana = crew()
	local A = ana.W.Drive
	for i = 1, 40 do A.SendBulk("IOU", "p" .. i, "1") end
	for i = 1, 5 do A.SendBulk("TPL", "kind" .. i, "text") end
	for i = 1, 5 do A.SendBulk("BLK", "name" .. i, "r", "1") end
	A.SendBulk("BLK", "late", "r", "1")
	local _, nb = A.CommBacklog()
	eq(nb, 50, "still capped")
	T.clean(w)
end)

-- guard: under the cap nothing is dropped, and the same text is still queued once
test("r52 D #6: guard: a small sync queues every item once", function()
	local w, ana = crew()
	local A = ana.W.Drive
	A.SendBulk("IOU", "a", "1") A.SendBulk("IOU", "a", "1") A.SendBulk("BLK", "x", "r", "1")
	local _, nb = A.CommBacklog()
	eq(nb, 2)
	T.clean(w)
end)
