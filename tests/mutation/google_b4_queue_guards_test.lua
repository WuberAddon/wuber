-- Guard tests for Wuber/Drive/Queue.lua (Batch 4, lane b3).
-- Each test guards a line from the mutation audit that no other test protected.
local T = ...
local test, eq, ok = T.test, T.eq, T.ok
local ANITA, BOB = T.ANITA, T.BOB
local DAN = "Dan Miller"

local function openDriver(w, opts)
	local d = T.driver(w, ANITA, opts or { spot = "Undercity" })
	T.settle(w)
	return d
end

local function firedCount(a, name)
	local n = 0
	for _, f in ipairs(a.fired) do if f.name == name then n = n + 1 end end
	return n
end

-- guards Wuber/Drive/Queue.lua:839 (drop statement: system invite failure resets inviteMisses)
test("mutation b4 queue: a system decline message resets the invite-miss counter", function()
	local w = T.newWorld()
	local d = openDriver(w)
	local DR = d.W.Drive
	ok(DR.SetOpen(true), "driver opens")
	d.env.ERR_DECLINE_GROUP_S = "%s declines your group invitation."
	DR.Request(DAN, "whisper", "summon pls")
	DR.inviteMisses = 2
	d:fire("CHAT_MSG_SYSTEM", DAN .. " declines your group invitation.")
	eq(DR.inviteMisses, 0, "inviteMisses resets to 0 after system decline")
	T.clean(w)
end)

-- guards Wuber/Drive/Queue.lua:458 (drop statement: elsewhere request fires DRIVE_STATE with queued)
test("mutation b4 queue: request for an unserved place fires DRIVE_STATE queued for listeners", function()
	local w = T.newWorld()
	local d = openDriver(w)
	local DR = d.W.Drive
	ok(DR.SetOpen(true), "driver opens")
	local before = #d.fired
	DR.Route = function(c)
		c.station = "Ratchet"
		return "elsewhere"
	end
	DR.Request(DAN, "whisper", "summon pls")
	local found
	for i = before + 1, #d.fired do
		local f = d.fired[i]
		if f.name == "DRIVE_STATE" and f.args[2] == "queued" then found = f end
	end
	ok(found ~= nil, "DRIVE_STATE fired with queued for elsewhere request")
	eq(found and found.args[1] and found.args[1].state, "lead", "customer remains a lead")
	T.clean(w)
end)

-- guards Wuber/Drive/Queue.lua:427 (drop statement: repeat no-place whisper from elsewhere lead redraws window)
test("mutation b4 queue: repeat no-place request from an elsewhere lead refreshes the driver window", function()
	local w = T.newWorld()
	local d = openDriver(w)
	local DR = d.W.Drive
	ok(DR.SetOpen(true), "driver opens")
	DR.Request(DAN, "whisper", "summon ratchet")
	local c = DR.customers[d.W.Key(DAN)]
	ok(c and c.askedFor, "control: lead has askedFor an unserved place")
	w:advance(0.5)
	local before = firedCount(d, "DRIVE")
	DR.Request(DAN, "whisper", "summon pls")
	w:advance(0.06)
	ok(firedCount(d, "DRIVE") > before, "driver window is told to redraw")
	eq(c.msg, "summon pls", "latest message is kept")
	T.clean(w)
end)

-- guards Wuber/Drive/Queue.lua:1242 (drop statement: rebooking with a new rideId removes old row with rebook reason)
test("mutation b4 queue: crew state with a new ride id removes the old rider row as rebook", function()
	local w = T.newWorld()
	local d = openDriver(w)
	local DR = d.W.Drive
	ok(DR.SetOpen(true), "driver opens")
	local dk = d.W.Key(DAN)
	DR.units[dk] = "party1"
	local c = DR.Create(DAN, "joined", "group")
	c.rideId = "aaaaaa"
	local removedReason
	d.W.Listen("DRIVE_REMOVED", function(who, why)
		if who and who.key == dk then removedReason = why end
	end)
	DR.Apply("ST", d.W.Key(BOB), DAN, "joined", "", "", "", "", "", "0", "bbbbbb")
	eq(removedReason, "rebook", "old rider row is removed with reason rebook")
	eq(DR.customers[dk].rideId, "bbbbbb", "new rider row carries the new ride id")
	T.clean(w)
end)

-- guards Wuber/Drive/Queue.lua:1692 (drop statement: prepaid rider arriving increments session rides)
test("mutation b4 queue: prepaid rider arriving by summon increments session rides", function()
	local w = T.newWorld()
	local d = openDriver(w)
	local DR = d.W.Drive
	ok(DR.SetOpen(true), "driver opens")
	local dk = d.W.Key(DAN)
	DR.units[dk] = "party1"
	local c = DR.Create(DAN, "joined", "group")
	c.prepaid = true
	DR.ArrivedAt = function() return true end
	local before = DR.session.rides or 0
	DR.QueueTick(d.env.GetTime())
	eq(c.state, "paid", "prepaid rider moves to paid on arrival")
	eq(DR.session.rides, before + 1, "session.rides increments when prepaid rider arrives")
	T.clean(w)
end)

-- guards Wuber/Drive/Queue.lua:1402 (swap and->or: own echoed UBL fact does not call Unblacklist)
test("mutation b4 queue: own echoed unblacklist fact does not trigger Unblacklist", function()
	local w = T.newWorld()
	local d = openDriver(w)
	local DR = d.W.Drive
	local calls = 0
	DR.Unblacklist = function() calls = calls + 1 end
	DR.Apply("UBL", d.W.Key(ANITA), DAN)
	eq(calls, 0, "own UBL fact does not invoke Unblacklist")
	DR.Apply("UBL", d.W.Key(BOB), DAN)
	eq(calls, 1, "crew UBL fact invokes Unblacklist")
	T.clean(w)
end)

-- guards Wuber/Drive/Queue.lua:1650 (swap or->and: rider who already paid is never dropped as arrived-another-way)
test("mutation b4 queue: a joined rider who already paid is not treated as arrived another way", function()
	local w = T.newWorld()
	local d = openDriver(w)
	local DR = d.W.Drive
	local c = DR.Create(DAN, "joined", "group")
	c.farSeen = true
	c.paid = 5000
	eq(DR.ArrivedAnotherWay(c, d.env.GetTime()), false, "paid rider is not arrived-another-way")
	T.clean(w)
end)

-- guards Wuber/Drive/Queue.lua:909 (swap and->or: OwingTick never reports a rider who owes nothing as a non-payer)
test("mutation b4 queue: OwingTick does not report a rider who paid in full as a non-payer", function()
	local w = T.newWorld()
	local d = openDriver(w)
	local DR = d.W.Drive
	local flagged = 0
	DR.NonPayer = function() flagged = flagged + 1 end
	local c = DR.Create(DAN, "arrived", "group")
	c.price, c.paid = 5000, 5000
	DR.owing[c.key] = { c = c, at = 10, grace = 10 }
	DR.OwingTick(25)
	eq(flagged, 0, "fully paid rider is not flagged as non-payer")
	T.clean(w)
end)

-- guards Wuber/Drive/Queue.lua:907 (cmp >=-><: OwingTick waits until grace expires before flagging non-payer)
test("mutation b4 queue: OwingTick waits for grace period to elapse before flagging a non-payer", function()
	local w = T.newWorld()
	local d = openDriver(w)
	local DR = d.W.Drive
	local flagged = 0
	DR.NonPayer = function() flagged = flagged + 1 end
	local c = DR.Create(DAN, "arrived", "group")
	c.price, c.paid = 5000, 0
	DR.owing[c.key] = { c = c, at = 10, grace = 10 }
	DR.OwingTick(15)
	eq(flagged, 0, "before grace expires, rider is not flagged")
	DR.OwingTick(20)
	eq(flagged, 1, "at exact grace expiry, rider is flagged")
	T.clean(w)
end)

-- guards Wuber/Drive/Queue.lua:622 (swap and->or: public auto-offer does not call CountAuto when autoInvite is off)
test("mutation b4 queue: public auto-offer does not count toward auto-invite cap when autoInvite is off", function()
	local w = T.newWorld()
	local d = openDriver(w)
	local DR = d.W.Drive
	ok(DR.SetOpen(true), "driver opens")
	DR.opts().autoPublic = true
	DR.opts().autoInvite = false
	local counted = 0
	DR.CountAuto = function() counted = counted + 1 end
	DR.PublicLine("lf summon uc pls", DAN, true)
	eq(counted, 0, "CountAuto is not called when autoInvite is false")
	T.clean(w)
end)

-- guards Wuber/Drive/Queue.lua:770 (swap and->or: ClickInvites refuses when driver is closed)
test("mutation b4 queue: ClickInvites returns false when driver service is closed", function()
	local w = T.newWorld()
	local d = openDriver(w)
	local DR = d.W.Drive
	DR.opts().autoInvite = false
	local c = DR.Create(DAN, "queued", "whisper")
	eq(DR.ClickInvites(c), false, "closed driver cannot click-invite")
	T.clean(w)
end)

-- guards Wuber/Drive/Queue.lua:874 (cmp ==->~=: caster window decides non-payer even when not group leader)
test("mutation b4 queue: caster window decides non-payer even when another crew member is leader", function()
	local w = T.newWorld()
	local d = openDriver(w)
	local DR = d.W.Drive
	DR.IsLeader = function() return false end
	DR.IsCaptain = function() return false end
	local c = DR.Create(DAN, "arrived", "group")
	c.caster = d.W.myKey
	eq(DR.DecidesNonPayer(c), true, "caster window decides non-payer")
	T.clean(w)
end)

-- guards Wuber/Drive/Queue.lua:195 (cmp >-><=: recentLeft entry at exact LEFT_KEEP age is kept for late PAID)
test("mutation b4 queue: recentLeft entry at exact LEFT_KEEP boundary is still kept", function()
	local w = T.newWorld()
	local d = openDriver(w)
	local DR = d.W.Drive
	local c1 = DR.Create(DAN, "arrived", "group")
	DR.Remove(c1, "left")
	local k1 = c1.key
	w:advance(DR.LEFT_KEEP)
	local c2 = DR.Create(BOB, "arrived", "group")
	DR.Remove(c2, "left")
	ok(DR.recentLeft[k1] ~= nil, "entry at exact LEFT_KEEP age is kept")
	T.clean(w)
end)

-- guards Wuber/Drive/Queue.lua:259 (if cond negated: Classify uses Summonish for fuzzy summon words)
test("mutation b4 queue: Classify recognizes a fuzzy summon word via Summonish", function()
	local w = T.newWorld()
	local d = openDriver(w)
	local DR = d.W.Drive
	DR.Summonish = function(word) return word == "sumonpls" end
	eq(DR.Classify("sumonpls"), "request", "Summonish word classifies as request")
	T.clean(w)
end)

-- guards Wuber/Drive/Queue.lua:400 (drop statement: held rider sending new words updates c.msg)
test("mutation b4 queue: held rider sending new words updates their stored message", function()
	local w = T.newWorld()
	local d = openDriver(w)
	local DR = d.W.Drive
	ok(DR.SetOpen(true), "driver opens")
	DR.SetServeHold(DAN, true)
	DR.Request(DAN, "whisper", "first words")
	DR.Request(DAN, "whisper", "second words")
	local c = DR.customers[d.W.Key(DAN)]
	eq(c and c.msg, "second words", "held rider message updates to latest words")
	T.clean(w)
end)

-- guards Wuber/Drive/Queue.lua:1233 (drop statement: LockPrice changing price redraws the driver window)
test("mutation b4 queue: LockPrice changing a rider fare refreshes the driver window", function()
	local w = T.newWorld()
	local d = openDriver(w)
	local DR = d.W.Drive
	local c = DR.Create(DAN, "joined", "group")
	c.price = 5000
	w:advance(0.5)
	local before = firedCount(d, "DRIVE")
	DR.LockPrice(c, 8000)
	w:advance(0.06)
	eq(c.price, 8000, "fare updated")
	ok(firedCount(d, "DRIVE") > before, "driver window redraws after price change")
	T.clean(w)
end)

-- guards Wuber/Drive/Queue.lua:1585 (drop statement: leaving typed dest resets dest and redraws driver window)
test("mutation b4 queue: leaving a typed destination clears dest and refreshes the driver window", function()
	local w = T.newWorld()
	local d = openDriver(w, { spot = "Undercity" })
	local DR = d.W.Drive
	ok(DR.SetOpen(true), "driver opens")
	DR.char().dest = "Undercity"
	DR.PlaceSweep()
	d.env.GetRealZoneText = function() return "Orgrimmar" end
	d.env.GetZoneText = function() return "Orgrimmar" end
	d.env.GetSubZoneText = function() return "Orgrimmar" end
	w:advance(0.5)
	local before = firedCount(d, "DRIVE")
	DR.PlaceSweep()
	w:advance(0.06)
	eq(DR.char().dest, "", "dest cleared after leaving typed place")
	ok(firedCount(d, "DRIVE") > before, "driver window redraws after followMe clears dest")
	T.clean(w)
end)

-- guards Wuber/Drive/Queue.lua:1577 (drop statement: leaving typed dest clears follow.at so re-setting dest works again)
test("mutation b4 queue: leaving a typed destination twice still clears dest the second time", function()
	local w = T.newWorld()
	local d = openDriver(w, { spot = "Undercity" })
	local DR = d.W.Drive
	ok(DR.SetOpen(true), "driver opens")
	DR.char().dest = "Undercity"
	DR.PlaceSweep()
	d.env.GetRealZoneText = function() return "Orgrimmar" end
	d.env.GetZoneText = function() return "Orgrimmar" end
	d.env.GetSubZoneText = function() return "Orgrimmar" end
	DR.PlaceSweep()
	eq(DR.char().dest, "", "first departure clears dest")
	-- Return to Orgrimmar as new typed dest, then leave to Ratchet without visiting Orgrimmar?
	-- No: set dest to Undercity while standing in Orgrimmar; follow.at must be nil so it doesn't fire prematurely,
	-- and only fires after visiting Undercity again (or if follow.at stayed Undercity, setting dest=Undercity while in Orgrimmar immediately clears it!).
	DR.char().dest = "Undercity"
	DR.PlaceSweep()
	eq(DR.char().dest, "Undercity", "re-setting dest while elsewhere does not immediately clear before visiting")
	T.clean(w)
end)

-- guards Wuber/Drive/Queue.lua:1213 (drop statement: 2.3.0 app rider paying before arrival sets c.prepaid)
test("mutation b4 queue: 2.3.0 app rider paying by trade before arrival is marked prepaid", function()
	local w = T.newWorld()
	local d = openDriver(w)
	local DR = d.W.Drive
	local c = DR.Create(DAN, "joined", "group")
	c.wuberVer = "2.3.0"
	c.price = 5000
	DR.Apply("PAID", d.W.Key(BOB), DAN, "5000", "auto")
	eq(c.state, "joined", "rider remains joined until arrival")
	eq(c.prepaid, true, "prepaid flag is set for arrival")
	T.clean(w)
end)

-- guards Wuber/Drive/Queue.lua:1202 (drop statement: late PAID for a rider who left redraws driver window)
test("mutation b4 queue: late PAID for a rider who already left refreshes the driver window", function()
	local w = T.newWorld()
	local d = openDriver(w)
	local DR = d.W.Drive
	local c = DR.Create(DAN, "arrived", "group")
	c.price = 5000
	DR.Remove(c, "left")
	w:advance(0.5)
	local before = firedCount(d, "DRIVE")
	DR.Apply("PAID", d.W.Key(BOB), DAN, "5000", "auto")
	w:advance(0.06)
	ok(firedCount(d, "DRIVE") > before, "driver window redraws after late PAID")
	T.clean(w)
end)

-- guards Wuber/Drive/Queue.lua:892 (drop statement: paid rider leaving group sets c.gone so QueueTick cleans up)
test("mutation b4 queue: paid rider leaving the group is marked gone for cleanup", function()
	local w = T.newWorld()
	local d = openDriver(w)
	local DR = d.W.Drive
	DR.Roster = function() return { { name = DAN, key = d.W.Key(DAN), unit = "party1" } } end
	DR.GroupSize = function() return 2 end
	d.W.InGroup = function() return true end
	local c = DR.Create(DAN, "paid", "group")
	DR.SyncRoster()
	DR.Roster = function() return {} end
	DR.GroupSize = function() return 1 end
	d.W.InGroup = function() return false end
	DR.SyncRoster()
	eq(c.gone, true, "paid rider who left is marked gone")
	T.clean(w)
end)

-- guards Wuber/Drive/Queue.lua:1704 (drop statement: awayGuard marks c.awayAt so resuming does not immediately re-pause)
test("mutation b4 queue: awayGuard marks the waiting rider so it does not re-pause immediately", function()
	local w = T.newWorld()
	local d = openDriver(w)
	local DR = d.W.Drive
	ok(DR.SetOpen(true), "driver opens")
	DR.opts().awayGuard = true
	DR.IsLeader = function() return true end
	local paused = false
	DR.IsPaused = function() return paused end
	DR.SetPaused = function(v) paused = v end
	local dk = d.W.Key(DAN)
	DR.units[dk] = "party1"
	local c = DR.Create(DAN, "joined", "group")
	DR.Online = function() return true end
	DR.ArrivedAt = function() return false end
	DR.driverActAt = d.env.GetTime() - (DR.AWAY_AFTER + 10)
	c.at = d.env.GetTime() - (DR.AWAY_AFTER + 10)
	DR.QueueTick(d.env.GetTime())
	eq(paused, true, "control: awayGuard pauses driver")
	paused = false
	DR.driverActAt = d.env.GetTime() - (DR.AWAY_AFTER + 10)
	DR.QueueTick(d.env.GetTime())
	eq(paused, false, "same waiting rider does not re-pause once marked awayAt")
	T.clean(w)
end)

-- guards Wuber/Drive/Queue.lua:1471 (drop statement: nameless HELP fact records current build in opts.helpSeen)
test("mutation b4 queue: nameless HELP fact stamps opts.helpSeen with the addon build", function()
	local w = T.newWorld()
	local d = openDriver(w)
	local DR = d.W.Drive
	DR.opts().helpSeen = nil
	local c = DR.Create(DAN, "summoning", "group")
	DR.Apply("HELP", d.W.Key(BOB), DAN)
	eq(DR.opts().helpSeen, d.W.Build(), "helpSeen stamped with current build")
	T.clean(w)
end)

-- guards Wuber/Drive/Queue.lua:1323 (swap or->and: crew TPL fact falls back to W.SentenceSpam when TemplateSpam is nil)
test("mutation b4 queue: crew TPL fact saves template using SentenceSpam fallback", function()
	local w = T.newWorld()
	local d = openDriver(w)
	local DR = d.W.Drive
	local origSpam = DR.TemplateSpam
	DR.TemplateSpam = nil
	DR.db.templates.advert = nil
	DR.Apply("TPL", d.W.Key(BOB), "advert", "Summons at Undercity, 50s")
	DR.TemplateSpam = origSpam
	eq(DR.db.templates.advert, "Summons at Undercity, 50s", "TPL saved via SentenceSpam fallback")
	T.clean(w)
end)

-- guards Wuber/Drive/Queue.lua:1389 (swap and->or: ADD fact does not re-queue a done rider who is not in the group)
test("mutation b4 queue: ADD fact does not move a done rider back to joined when not in group", function()
	local w = T.newWorld()
	local d = openDriver(w)
	local DR = d.W.Drive
	local c = DR.Create(DAN, "done", "group")
	DR.Apply("ADD", d.W.Key(BOB), DAN)
	eq(c.state, "done", "done rider not in group stays done on ADD fact")
	T.clean(w)
end)
