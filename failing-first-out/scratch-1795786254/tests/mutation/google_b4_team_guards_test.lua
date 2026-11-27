-- Guard tests for Wuber/Drive/Team.lua (Batch 4, lane d2).
-- Each test guards a line from the mutation audit that no other test protected.
local T = ...
local test, eq, ok = T.test, T.eq, T.ok
local TESTCHAR, BOB, CAP = T.TESTCHAR, T.BOB, "Captain Lock"
local DAN = "Dan Miller"

local function firedCount(a, name, arg)
	local n = 0
	for _, f in ipairs(a.fired) do
		if f.name == name and (arg == nil or f.args[1] == arg or f.args[2] == arg) then
			n = n + 1
		end
	end
	return n
end

-- guards Wuber/Drive/Team.lua:156 (if cond negated: coalescing LATEST only replaces same kind)
test("mutation b4 team: queuing CFG while PAU is waiting keeps both in the outbox", function()
	local w = T.newWorld()
	local d = T.driver(w, TESTCHAR)
	T.rider(w, BOB)
	T.settle(w)
	w:group({ TESTCHAR, BOB })
	w:advance(1)
	local DR = d.W.Drive
	DR.on = true
	local realSend = d.env.C_ChatInfo.SendAddonMessage
	local throttled = true
	d.env.C_ChatInfo.SendAddonMessage = function(...)
		if throttled then return 3 end
		return realSend(...)
	end
	DR.Send("PAU", 1)
	DR.Send("CFG", 1, 500)
	local mark = #w.addonLog
	throttled = false
	d.env.C_ChatInfo.SendAddonMessage = realSend
	w:advance(2.5)
	DR.FlushComm()
	local sawPau, sawCfg = false, false
	for i = mark + 1, #w.addonLog do
		local txt = tostring(w.addonLog[i].text)
		if txt:find("^PAU~") then sawPau = true end
		if txt:find("^CFG~") then sawCfg = true end
	end
	ok(sawPau, "PAU was not overwritten by CFG")
	ok(sawCfg, "CFG was also sent")
	T.clean(w)
end)

-- guards Wuber/Drive/Team.lua:157 (drop statement: LATEST replaces queued older item in-place)
test("mutation b4 team: queuing a newer PAU while throttled sends the latest pause state", function()
	local w = T.newWorld()
	local d = T.driver(w, TESTCHAR)
	T.rider(w, BOB)
	T.settle(w)
	w:group({ TESTCHAR, BOB })
	w:advance(1)
	local DR = d.W.Drive
	DR.on = true
	local realSend = d.env.C_ChatInfo.SendAddonMessage
	local throttled = true
	d.env.C_ChatInfo.SendAddonMessage = function(...)
		if throttled then return 3 end
		return realSend(...)
	end
	DR.Send("PAU", 1)
	DR.Send("PAU", 0)
	local mark = #w.addonLog
	throttled = false
	d.env.C_ChatInfo.SendAddonMessage = realSend
	w:advance(2.5)
	DR.FlushComm()
	local sent = {}
	for i = mark + 1, #w.addonLog do
		local txt = tostring(w.addonLog[i].text)
		if txt:find("^PAU~") then sent[#sent + 1] = txt end
	end
	eq(#sent, 1, "coalesced to one PAU message")
	ok(sent[1] and sent[1]:find("~0$") ~= nil, "latest PAU value (0) was sent")
	T.clean(w)
end)

-- guards Wuber/Drive/Team.lua:158 (drop statement: LATEST replace triggers FlushComm)
test("mutation b4 team: replacing a queued PAU flushes immediately once chat lock clears", function()
	local w = T.newWorld()
	local d = T.driver(w, TESTCHAR)
	T.rider(w, BOB)
	T.settle(w)
	w:group({ TESTCHAR, BOB })
	w:advance(1)
	local DR = d.W.Drive
	DR.on = true
	local realSend = d.env.C_ChatInfo.SendAddonMessage
	local locked = true
	d.env.C_ChatInfo.SendAddonMessage = function(...)
		if locked then return 11 end
		return realSend(...)
	end
	w:advance(0.5)
	DR.Send("PAU", 1)
	eq(DR.CommBacklog(), 1, "first PAU stays queued during lock")
	locked = false
	d.env.C_ChatInfo.SendAddonMessage = realSend
	w:advance(2.01)
	eq(DR.CommBacklog(), 1, "control: PAU still queued before second Send")
	DR.Send("PAU", 0)
	eq(DR.CommBacklog(), 0, "replacing queued PAU flushes immediately")
	T.clean(w)
end)

-- guards Wuber/Drive/Team.lua:166 (drop statement: ST replaces queued older ST for same rider)
test("mutation b4 team: queuing a newer ST for the same rider replaces the stale state", function()
	local w = T.newWorld()
	local d = T.driver(w, TESTCHAR)
	T.rider(w, BOB)
	T.settle(w)
	w:group({ TESTCHAR, BOB })
	w:advance(1)
	local DR = d.W.Drive
	DR.on = true
	local realSend = d.env.C_ChatInfo.SendAddonMessage
	local throttled = true
	d.env.C_ChatInfo.SendAddonMessage = function(...)
		if throttled then return 3 end
		return realSend(...)
	end
	DR.Send("ST", "p1", "waiting")
	DR.Send("ST", "p1", "summoning")
	local mark = #w.addonLog
	throttled = false
	d.env.C_ChatInfo.SendAddonMessage = realSend
	w:advance(2.5)
	DR.FlushComm()
	local sent = {}
	for i = mark + 1, #w.addonLog do
		local txt = tostring(w.addonLog[i].text)
		if txt:find("^ST~") then sent[#sent + 1] = txt end
	end
	eq(#sent, 1, "coalesced to one ST message")
	ok(sent[1] and sent[1]:find("summoning", 1, true) ~= nil, "latest ST state (summoning) was sent")
	T.clean(w)
end)

-- guards Wuber/Drive/Team.lua:167 (drop statement: ST replace triggers FlushComm)
test("mutation b4 team: replacing a queued ST flushes immediately once chat lock clears", function()
	local w = T.newWorld()
	local d = T.driver(w, TESTCHAR)
	T.rider(w, BOB)
	T.settle(w)
	w:group({ TESTCHAR, BOB })
	w:advance(1)
	local DR = d.W.Drive
	DR.on = true
	local realSend = d.env.C_ChatInfo.SendAddonMessage
	local locked = true
	d.env.C_ChatInfo.SendAddonMessage = function(...)
		if locked then return 11 end
		return realSend(...)
	end
	w:advance(0.5)
	DR.Send("ST", "p1", "waiting")
	eq(DR.CommBacklog(), 1, "first ST stays queued during lock")
	locked = false
	d.env.C_ChatInfo.SendAddonMessage = realSend
	w:advance(2.01)
	eq(DR.CommBacklog(), 1, "control: ST still queued before second Send")
	DR.Send("ST", "p1", "summoning")
	eq(DR.CommBacklog(), 0, "replacing queued ST flushes immediately")
	T.clean(w)
end)

-- guards Wuber/Drive/Team.lua:295 (cmp ==->~=: StationsWire emits :0 only for disabled off-list stations)
test("mutation b4 team: StationsWire includes disabled saved stations as :0 and ignores enabled ones", function()
	local w = T.newWorld()
	local d = T.driver(w, TESTCHAR)
	T.settle(w)
	local DR = d.W.Drive
	local origStations = DR.Stations
	DR.Stations = function() return {} end
	DR.char().captain = ""
	DR.char().stations = { ["Ratchet"] = false, ["Booty Bay"] = true }
	local wire = DR.StationsWire()
	DR.Stations = origStations
	ok(wire:find("Ratchet:0", 1, true) ~= nil, "disabled station is encoded as :0")
	ok(wire:find("Booty Bay", 1, true) == nil, "enabled off-list station is not encoded as :0")
	T.clean(w)
end)

-- guards Wuber/Drive/Team.lua:336 (swap or->and: sendBlockBatch gives up waiting after 90 retries)
test("mutation b4 team: SendBlocklist sends remaining batch after 90 bulk-backlog retries", function()
	local w = T.newWorld()
	local d = T.driver(w, TESTCHAR)
	T.rider(w, BOB)
	T.settle(w)
	w:group({ TESTCHAR, BOB })
	w:advance(1)
	local DR = d.W.Drive
	DR.on = true
	for i = 1, 41 do
		DR.db.blocklist["spammer" .. i] = { reason = "spam", at = 100 }
	end
	local origBacklog = DR.CommBacklog
	DR.CommBacklog = function() return 0, 1 end
	local mark = #w.addonLog
	DR.SendBlocklist()
	for _ = 1, 95 do w:advance(2.1) end
	DR.CommBacklog = origBacklog
	local blkCount = 0
	for i = mark + 1, #w.addonLog do
		if tostring(w.addonLog[i].text):find("^BLK~") then blkCount = blkCount + 1 end
	end
	eq(blkCount, 41, "second batch eventually sends after 90 waits instead of looping forever")
	T.clean(w)
end)

-- guards Wuber/Drive/Team.lua:342 (swap or->and: sendBlockBatch includes block reason in BLK)
test("mutation b4 team: SendBlocklist preserves the block reason in BLK messages", function()
	local w = T.newWorld()
	local d = T.driver(w, TESTCHAR)
	T.rider(w, BOB)
	T.settle(w)
	w:group({ TESTCHAR, BOB })
	w:advance(1)
	local DR = d.W.Drive
	DR.on = true
	DR.db.blocklist["dan miller"] = { reason = "rude", at = 123 }
	local mark = #w.addonLog
	DR.SendBlocklist()
	w:advance(1)
	local sent = false
	for i = mark + 1, #w.addonLog do
		local txt = tostring(w.addonLog[i].text)
		if txt:find("^BLK~") and txt:find("rude", 1, true) then sent = true end
	end
	ok(sent, "BLK message carries the block reason")
	T.clean(w)
end)

-- guards Wuber/Drive/Team.lua:445 (drop statement: heardHello fires DRIVE_STATIONS when peer place changes)
test("mutation b4 team: heardHello fires DRIVE_STATIONS when a peer changes place", function()
	local w = T.newWorld()
	local d = T.driver(w, TESTCHAR)
	T.rider(w, BOB)
	T.settle(w)
	w:group({ TESTCHAR, BOB })
	w:advance(1)
	local DR = d.W.Drive
	DR.on = true
	DR.char().crew = { { name = BOB, role = "lock" } }
	DR.OnTeamAddon(DR.TPREFIX, "HI~0~" .. d.W.VERSION .. "~5~0~0~0~L~WARLOCK~Orgrimmar~1454", "PARTY", BOB)
	local before = firedCount(d, "DRIVE_STATIONS")
	DR.OnTeamAddon(DR.TPREFIX, "HI~0~" .. d.W.VERSION .. "~5~0~0~0~L~WARLOCK~Undercity~1458", "PARTY", BOB)
	ok(firedCount(d, "DRIVE_STATIONS") > before, "DRIVE_STATIONS fired when peer moved")
	T.clean(w)
end)

-- guards Wuber/Drive/Team.lua:458 (drop statement: heardHello fires DRIVE_REMOVED for stale customer)
test("mutation b4 team: heardHello fires DRIVE_REMOVED with crew when clearing a stale customer", function()
	local w = T.newWorld()
	local d = T.driver(w, TESTCHAR)
	local b = T.driver(w, BOB)
	T.settle(w)
	w:group({ TESTCHAR, BOB })
	w:advance(1)
	local DR = d.W.Drive
	DR.on = true
	b.W.Drive.on = true
	local bKey = d.W.Key(BOB)
	DR.char().crew = { { name = BOB, role = "lock" } }
	DR.customers[bKey] = { name = BOB, state = "waiting" }
	local before = firedCount(d, "DRIVE_REMOVED", "crew")
	b.W.Drive.Hello(true)
	w:advance(0.2)
	ok(firedCount(d, "DRIVE_REMOVED", "crew") > before, "DRIVE_REMOVED fired with crew reason")
	T.clean(w)
end)

-- guards Wuber/Drive/Team.lua:462 (drop statement: versionHint prevents repeating version mismatch print)
test("mutation b4 team: version mismatch hint is printed only once per session", function()
	local w = T.newWorld()
	local d = T.driver(w, TESTCHAR)
	T.rider(w, BOB)
	T.rider(w, DAN)
	T.settle(w)
	w:group({ TESTCHAR, BOB, DAN })
	w:advance(1)
	local DR = d.W.Drive
	DR.on = true
	DR.versionHint = nil
	DR.char().crew = { { name = BOB, role = "lock" }, { name = DAN, role = "lock" } }
	local mark = #d.chatLines
	DR.OnTeamAddon(DR.TPREFIX, "HI~0~0.0.1~5~0~0~0~L~WARLOCK~Orgrimmar~1454", "PARTY", BOB)
	DR.OnTeamAddon(DR.TPREFIX, "HI~0~0.0.1~5~0~0~0~L~WARLOCK~Orgrimmar~1454", "PARTY", DAN)
	local hits = 0
	for i = mark + 1, #d.chatLines do
		if tostring(d.chatLines[i]):find("update the older one", 1, true) then hits = hits + 1 end
	end
	eq(hits, 1, "version mismatch hint prints once")
	T.clean(w)
end)

-- guards Wuber/Drive/Team.lua:609 (drop statement: RestoreOwnConfig fires SETTINGS drive)
test("mutation b4 team: RestoreOwnConfig fires SETTINGS drive for the UI", function()
	local w = T.newWorld()
	local d = T.driver(w, TESTCHAR)
	T.settle(w)
	local DR = d.W.Drive
	DR.char().captain = CAP
	DR.KeepOwnConfig()
	local before = firedCount(d, "SETTINGS", "drive")
	ok(DR.RestoreOwnConfig(), "RestoreOwnConfig succeeded")
	ok(firedCount(d, "SETTINGS", "drive") > before, "SETTINGS drive fired")
	T.clean(w)
end)

-- guards Wuber/Drive/Team.lua:631 (drop statement: AnswerOffer restores own config before KeepOwnConfig)
test("mutation b4 team: accepting a new captain restores own config before snapshotting it", function()
	local w = T.newWorld()
	local d = T.driver(w, TESTCHAR)
	T.settle(w)
	local DR = d.W.Drive
	DR.char().captain = CAP
	DR.char().price = 7000
	DR.KeepOwnConfig()
	DR.char().price = 9999
	DR.pendingOffers[d.W.Key(BOB)] = { name = BOB, at = d.env.GetTime() }
	ok(DR.AnswerOffer(BOB, true), "accepted new captain")
	eq(DR.char().price, 7000, "own price was restored rather than overwritten by old captain's price")
	T.clean(w)
end)

-- guards Wuber/Drive/Team.lua:662 (local value -> nil: RemoveCrew checks m.app before whispering TL)
test("mutation b4 team: RemoveCrew does not whisper TL to a plain helper without Wuber", function()
	local w = T.newWorld()
	local d = T.driver(w, TESTCHAR)
	T.settle(w)
	local DR = d.W.Drive
	DR.char().captain = ""
	DR.char().crew = { { name = "Plain Helper", role = "helper", app = false } }
	local mark = #w.addonLog
	ok(DR.RemoveCrew("Plain Helper"), "removed plain helper")
	w:advance(0.2)
	local sentTL = false
	for i = mark + 1, #w.addonLog do
		local e = w.addonLog[i]
		if e.from == TESTCHAR and e.target == "Plain Helper" and tostring(e.text):find("TL", 1, true) then
			sentTL = true
		end
	end
	eq(sentTL, false, "plain helper without Wuber is not whispered TL")
	T.clean(w)
end)

-- guards Wuber/Drive/Team.lua:666 (drop statement: RemoveCrew clears DR.offers[k])
test("mutation b4 team: captain RemoveCrew clears any pending offer for that player", function()
	local w = T.newWorld()
	local d = T.driver(w, TESTCHAR)
	T.settle(w)
	local DR = d.W.Drive
	local bKey = d.W.Key(BOB)
	DR.char().captain = ""
	DR.char().crew = { { name = BOB, role = "lock" } }
	DR.offers[bKey] = { name = BOB, at = d.env.GetTime(), state = "yes" }
	ok(DR.RemoveCrew(BOB), "removed crew member")
	eq(DR.offers[bKey], nil, "offer entry is cleared")
	T.clean(w)
end)

-- guards Wuber/Drive/Team.lua:680 (drop statement: LeaveCrew clears captain from DR.peers)
test("mutation b4 team: LeaveCrew clears the captain from DR.peers", function()
	local w = T.newWorld()
	local d = T.driver(w, TESTCHAR)
	T.settle(w)
	local DR = d.W.Drive
	local capKey = d.W.Key(CAP)
	DR.char().captain = CAP
	DR.peers[capKey] = { name = CAP, at = d.env.GetTime() }
	ok(DR.LeaveCrew(), "left crew")
	eq(DR.peers[capKey], nil, "captain removed from peers")
	T.clean(w)
end)

-- guards Wuber/Drive/Team.lua:694 (return true->false: LeaveCrew returns true)
test("mutation b4 team: LeaveCrew returns true", function()
	local w = T.newWorld()
	local d = T.driver(w, TESTCHAR)
	T.settle(w)
	local DR = d.W.Drive
	eq(DR.LeaveCrew(), true, "LeaveCrew returns true")
	T.clean(w)
end)

-- guards Wuber/Drive/Team.lua:721 (drop statement: applyCrew clears crew member from DR.customers)
-- guards Wuber/Drive/Team.lua:722 (drop statement: applyCrew fires DRIVE_REMOVED with crew)
test("mutation b4 team: captain CRW removes matching crew member from customers and fires DRIVE_REMOVED", function()
	local w = T.newWorld()
	local d = T.driver(w, TESTCHAR)
	T.settle(w)
	local DR = d.W.Drive
	DR.char().captain = CAP
	local bKey = d.W.Key(BOB)
	DR.customers[bKey] = { name = BOB, state = "waiting" }
	local before = firedCount(d, "DRIVE_REMOVED", "crew")
	DR.OnTeamAddon(DR.TPREFIX, "CRW~0~" .. CAP .. ":L," .. BOB .. ":L", "WHISPER", CAP)
	eq(DR.customers[bKey], nil, "crew member cleared from customers")
	ok(firedCount(d, "DRIVE_REMOVED", "crew") > before, "DRIVE_REMOVED fired with crew")
	T.clean(w)
end)

-- guards Wuber/Drive/Team.lua:757 (drop statement: full crew marks late TY offer as no)
test("mutation b4 team: TY whisper when crew is full marks the offer no and whispers TL", function()
	local w = T.newWorld()
	local d = T.driver(w, TESTCHAR)
	T.settle(w)
	local DR = d.W.Drive
	DR.char().captain = ""
	DR.char().crew = {}
	for i = 1, 8 do
		DR.char().crew[i] = { name = "Member " .. i, role = "helper" }
	end
	local bKey = d.W.Key(BOB)
	DR.offers[bKey] = { name = BOB, at = d.env.GetTime(), state = "waiting" }
	local mark = #w.addonLog
	DR.OnTeamAddon(DR.TPREFIX, "TY~0~L", "WHISPER", BOB)
	w:advance(0.2)
	eq(DR.offers[bKey].state, "no", "offer marked no when crew is full")
	local sentTL = false
	for i = mark + 1, #w.addonLog do
		local e = w.addonLog[i]
		if e.from == TESTCHAR and e.target == BOB and tostring(e.text):find("TL", 1, true) then
			sentTL = true
		end
	end
	ok(sentTL, "TL whispered when crew is full")
	T.clean(w)
end)

-- guards Wuber/Drive/Team.lua:790 (drop statement: captain hearing TL clears DR.offers[key])
-- guards Wuber/Drive/Team.lua:791 (drop statement: captain hearing TL broadcasts updated CRW)
test("mutation b4 team: captain hearing TL clears the member offer and broadcasts CRW", function()
	local w = T.newWorld()
	local d = T.driver(w, TESTCHAR)
	T.rider(w, BOB)
	T.settle(w)
	w:group({ TESTCHAR, BOB })
	w:advance(1)
	local DR = d.W.Drive
	DR.on = true
	local bKey = d.W.Key(BOB)
	DR.char().captain = ""
	DR.char().crew = { { name = BOB, role = "lock" } }
	DR.offers[bKey] = { name = BOB, at = d.env.GetTime(), state = "yes" }
	local mark = #w.addonLog
	DR.OnTeamAddon(DR.TPREFIX, "TL~0", "WHISPER", BOB)
	w:advance(0.2)
	eq(DR.offers[bKey], nil, "offer cleared on TL")
	local sentCrw = false
	for i = mark + 1, #w.addonLog do
		if tostring(w.addonLog[i].text):find("^CRW~") then sentCrw = true end
	end
	ok(sentCrw, "updated CRW broadcast after TL")
	T.clean(w)
end)

-- guards Wuber/Drive/Team.lua:869 (drop statement: stopping raid mode clears raidRows and fires DRIVE_RAID)
test("mutation b4 team: CFG ending raid mode clears mirrored raidRows and fires DRIVE_RAID", function()
	local w = T.newWorld()
	local d = T.driver(w, TESTCHAR)
	T.rider(w, BOB)
	T.settle(w)
	w:group({ TESTCHAR, BOB })
	w:advance(1)
	local DR = d.W.Drive
	DR.RaidMirror = function() end
	DR.OnTeamAddon(DR.TPREFIX, "HI~0~" .. d.W.VERSION .. "~5~0~0~0~L~WARLOCK~Orgrimmar~1454~R", "PARTY", BOB)
	DR.raidRows = DR.raidRows or {}
	DR.raidRows["dan miller"] = { name = DAN }
	local before = firedCount(d, "DRIVE_RAID")
	DR.OnTeamAddon(DR.TPREFIX, "CFG~0~1~0~5~0~auto~~Undercity:1~sell~0~1~1~", "PARTY", BOB)
	eq(next(DR.raidRows), nil, "mirrored raidRows cleared")
	ok(firedCount(d, "DRIVE_RAID") > before, "DRIVE_RAID fired")
	T.clean(w)
end)

-- guards Wuber/Drive/Team.lua:900 (drop statement: system offline message drops offer and fires DRIVE_CREW)
test("mutation b4 team: system offline message drops waiting offer and fires DRIVE_CREW", function()
	local w = T.newWorld()
	local d = T.driver(w, TESTCHAR)
	T.settle(w)
	local DR = d.W.Drive
	local orig = d.W.NotFoundName
	d.W.NotFoundName = function(txt) return txt:match("Nobody called (.+) is playing%.") end
	local bKey = d.W.Key(BOB)
	DR.offers[bKey] = { name = BOB, at = d.env.GetTime(), state = "waiting" }
	local before = firedCount(d, "DRIVE_CREW")
	d:fire("CHAT_MSG_SYSTEM", "Nobody called " .. BOB .. " is playing.")
	d.W.NotFoundName = orig
	eq(DR.offers[bKey], nil, "waiting offer removed")
	ok(firedCount(d, "DRIVE_CREW") > before, "DRIVE_CREW fired")
	T.clean(w)
end)

-- guards Wuber/Drive/Team.lua:911 (drop statement: OfferTick fires DRIVE_CREW when offer becomes noapp)
test("mutation b4 team: OfferTick fires DRIVE_CREW when an unanswered offer becomes noapp", function()
	local w = T.newWorld()
	local d = T.driver(w, TESTCHAR)
	T.settle(w)
	local DR = d.W.Drive
	local bKey = d.W.Key(BOB)
	DR.offers[bKey] = { name = BOB, at = d.env.GetTime() - 25, state = "waiting" }
	local before = firedCount(d, "DRIVE_CREW")
	DR.OfferTick()
	eq(DR.offers[bKey].state, "noapp", "offer flipped to noapp")
	ok(firedCount(d, "DRIVE_CREW") > before, "DRIVE_CREW fired")
	T.clean(w)
end)

-- guards Wuber/Drive/Team.lua:916 (drop statement: OfferTick fires DRIVE_CREW when offer expires)
test("mutation b4 team: OfferTick fires DRIVE_CREW when an answered offer expires past OFFER_TTL", function()
	local w = T.newWorld()
	local d = T.driver(w, TESTCHAR)
	T.settle(w)
	local DR = d.W.Drive
	local bKey = d.W.Key(BOB)
	local origContacts = d.W.Contacts
	d.W.Contacts = function() return { { key = bKey } } end
	DR.offers[bKey] = { name = BOB, at = d.env.GetTime() - 350, state = "waiting" }
	local before = firedCount(d, "DRIVE_CREW")
	DR.OfferTick()
	d.W.Contacts = origContacts
	eq(DR.offers[bKey], nil, "expired offer removed")
	ok(firedCount(d, "DRIVE_CREW") > before, "DRIVE_CREW fired")
	T.clean(w)
end)

-- guards Wuber/Drive/Team.lua:919 (drop statement: OfferTick prunes old non-waiting offers)
test("mutation b4 team: OfferTick prunes old non-waiting offers after 4x OFFER_TTL", function()
	local w = T.newWorld()
	local d = T.driver(w, TESTCHAR)
	T.settle(w)
	local DR = d.W.Drive
	local bKey = d.W.Key(BOB)
	DR.offers[bKey] = { name = BOB, at = d.env.GetTime() - 1250, state = "no" }
	DR.OfferTick()
	eq(DR.offers[bKey], nil, "stale non-waiting offer pruned")
	T.clean(w)
end)
