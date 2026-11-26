-- The Wuber community (WoW Communities) as a second transport, the founder's invites, the
-- Drive tab's Join card; and the rider's way out of a ride stuck after arriving (W.EndRide,
-- auto-end, the 2-hour restore rule, no booking to where you already stand).
-- Loaded by run.lua with its helpers.
--
-- The harness gives C_Club to every client of a world made with { clubs = true }
-- (World:addClub); a community stream's channel crosses the internal realms' channel
-- copies, WuberNet doesn't.

local T = ...
local H, test, eq, ok, list = T.H, T.test, T.eq, T.ok, T.list
local newWorld, settle, clean, goOnline, msgs, fields = T.newWorld, T.settle, T.clean, T.goOnline, T.msgs, T.fields
local openDrive, rideState, openConfirm = T.openDrive, T.rideState, T.openConfirm
local HAVE_UI = T.HAVE_UI

local ANITA, TESTCHAR, BOB, CAL, ANA = "Anita Lift", "Wuber TestCharacter", "Bob Stone", "Cal Brown", "Ana Smith"

local function client(w, name, o)
	o = o or {}
	return w:addClient(name, { spot = o.spot or (o.warlock and "Ratchet" or "Orgrimmar"), class = o.warlock and "WARLOCK" or "MAGE",
		money = o.money or 100000, allowMissing = not HAVE_UI, channelCopy = o.copy, realm = o.realm, faction = o.faction,
		addonDirs = o.addonDirs, roundOne = o.roundOne, noClub = o.noClub, saved = o.saved })
end

local CLUB = 77
local COMM = "Community:77:1"

-- the author's community: owner Anita Lift, a moderator-only "Wuber" stream listed first, then General
local function wuberClub(w, members)
	local m = { [ANITA] = 1 }
	for n, role in pairs(members or {}) do m[n] = role end
	return w:addClub({ id = CLUB, name = "Wuber", members = m, streams = {
		{ streamId = 2, name = "Wuber", streamType = 3, leadersAndModeratorsOnly = true },
		{ streamId = 1, name = "General", streamType = 0 },
	} })
end

-- addon messages of a kind sent on the community channel (or on WuberNet)
local function onChannel(w, kind, from, cname)
	local out = {}
	for _, e in ipairs(msgs(w, kind, from, "CHANNEL")) do
		if (e.channel or ""):lower() == cname:lower() then out[#out + 1] = e end
	end
	return out
end

local function chatSpam(c)
	local n = 0
	for _, l in ipairs(c.chatLines) do
		if tostring(l):lower():find("community", 1, true) then n = n + 1 end
	end
	return n
end

local function debugLines(c, part)
	local out = {}
	for _, e in ipairs(c.W.debugLog or {}) do
		if e.kind == "community" and (not part or e.text:find(part, 1, true)) then out[#out + 1] = e.text end
	end
	return out
end

local function hasText(c, text)
	for _, t in ipairs(c:visibleTexts()) do
		if t == text then return true end
	end
	return false
end

---------------------------------------------------------------------------
-- Transport
---------------------------------------------------------------------------

-- SPEC5 community (review #7): the community's stream channel carried no addon messages on
-- Forever (sent, never heard) and cost one of the game's 10 chat channels, so Wuber adds no
-- channel and sends nothing there; the community's online members are whisper seeds instead
-- (round6_engine "community (#7)"). The 2.0 transport tests ("over the community channel",
-- "WuberNet isolated -> the community", "failed sends switch it off") were removed with it.
test("community: rider and driver on different realm copies find each other through the community's roster", function()
	local w = newWorld({ clubs = true })
	wuberClub(w, { [BOB] = 4, [TESTCHAR] = 4 })
	local d = client(w, BOB, { warlock = true, realm = "CAMWOW EU4 Realm 7 PvE" })
	local r = client(w, TESTCHAR, { copy = "realm5", realm = "CAMWOW EU5 Realm 5 PvE" })
	settle(w, 25)
	for _, c in ipairs({ d, r }) do
		ok(c.W.OnNetwork(), c.player.name .. " on WuberNet")
		eq(c.W.community.state, "member", c.player.name .. " is in the community")
		eq(c.W.CommunityIndex(), nil, "no community channel (SPEC5)")
		eq(c.clubChannelAdds, nil, "no channel added")
		eq(c.W.CommunityStatus(), "Community: joined.", "status")
	end
	goOnline(d)
	r.W.WhisperRound("full", true)
	w:advance(5)
	local x = r.W.drivers["bob stone"]
	ok(x, "the rider on another realm copy sees Bob")
	eq(x.via, "WHISPER", "by whisper, from the roster")
	local ride = r.W.RequestRide("bob stone")
	ok(ride, "requested")
	w:advance(1)
	eq(#d.W.incoming, 1, "Bob has the request")
	eq(chatSpam(d) + chatSpam(r), 0, "no community lines in chat")
	eq(d.commSends, nil, "nothing sent on a community channel")
	clean(w)
end)

test("community: none in this game, not a member, or no channel number -> no errors, no chat", function()
	-- no C_Club at all
	local w = newWorld()
	local d = client(w, BOB, { warlock = true })
	local r = client(w, TESTCHAR)
	settle(w, 25)
	goOnline(d)
	w:advance(40)
	eq(r.W.community.state, "none")
	eq(r.W.CommunityStatus(), "Community: not available in this game.")
	ok(table.concat(r.W.NetStatusLines(), " "):find("Community: not available in this game.", 1, true), "status line")
	ok(r.W.drivers["bob stone"], "WuberNet as before")
	eq(#d.chatLines + #r.chatLines, 0, "nothing in chat: " .. list(d.chatLines, " / ") .. list(r.chatLines, " / "))
	if HAVE_UI then
		openDrive(d)
		ok(not hasText(d, "Join the Wuber community"), "no Join card")
		ok(not hasText(d, "Tip: join the Wuber community for more visibility"), "no hint")
	end
	clean(w)
	-- communities, but not in Wuber's
	w = newWorld({ clubs = true })
	wuberClub(w)
	w:addClub({ id = 5, name = "Goldshire Fishing", members = { [TESTCHAR] = 1 } })
	d = client(w, BOB, { warlock = true })
	r = client(w, TESTCHAR)
	settle(w, 60)
	eq(r.W.community.state, "out")
	eq(r.clubChannelAdds, nil, "no channel added for another community")
	eq(r.W.CommunityStatus(), "Community: not joined.")
	eq(#r.chatLines, 0, "nothing in chat")
	clean(w)
	-- a member, but this client gives community streams no channel number
	w = newWorld({ clubs = true })
	wuberClub(w, { [BOB] = 4 })
	w.noClubChannels = true
	d = client(w, BOB, { warlock = true })
	settle(w, 25)
	goOnline(d)
	w:advance(300)
	eq(d.W.community.state, "member")
	eq(d.clubChannelAdds, nil, "never asked for a channel (SPEC5 community)")
	eq(d.W.CommunityStatus(), "Community: joined.")
	eq(d.commSends, nil, "nothing sent there")
	eq(#d.chatLines, 0, "nothing in chat")
	clean(w)
	-- an old client: GetSubscribedClubs raises
	w = newWorld({ clubs = true })
	wuberClub(w, { [BOB] = 4 })
	d = client(w, BOB, { warlock = true })
	d.env.C_Club.GetSubscribedClubs = function() error("not in this client") end
	settle(w, 40)
	eq(d.W.community.state, "out", "a refused call reads as not a member")
	clean(w)
end)

test("community: old peers are unaffected (round-one rider and driver, with or without communities)", function()
	local w = newWorld({ clubs = true })
	wuberClub(w, { [BOB] = 4, [TESTCHAR] = 4, [ANA] = 4 })
	local d = client(w, BOB, { warlock = true })
	local old = client(w, TESTCHAR, { addonDirs = { Wuber = H.ADDONS.Wuber1 }, roundOne = true })
	local oldD = client(w, ANA, { warlock = true, spot = "Crossroads", addonDirs = { Wuber = H.ADDONS.Wuber1 }, roundOne = true })
	local r = client(w, CAL)
	settle(w, 25)
	goOnline(d)
	oldD.W.Driver.SetOnline(true)
	w:advance(5)
	ok(old.W.drivers["bob stone"], "a round-one rider sees the new driver")
	ok(r.W.drivers["ana smith"], "a new rider sees the round-one driver")
	ok(r.W.drivers["bob stone"], "and the new one")
	eq(old.clubChannelAdds, nil, "round one never touches communities")
	local ride = old.W.RequestRide("bob stone")
	ok(ride, "the old rider books")
	w:advance(1)
	eq(#d.W.incoming, 1, "the new driver has it")
	clean(w)
end)

---------------------------------------------------------------------------
-- The founder's invites
---------------------------------------------------------------------------

-- a driver's beacon (as a bot would send it) over WuberNet
local function injectD(w, c, name, faction)
	local text = c.W.Encode("D", "Ratchet", 1413, 627, 370, 5000, "", "open", 1, 4, faction or "H", "1.2.0")
	w:inject(name, text, "CHANNEL")
end

-- Round 12: the client now forbids C_Club.SendCharacterInvitation to addons (the "only available
-- to the Blizzard UI" popup), so the founder's automatic invites are gone. Joining stays.
test("community: the founder never sends community invites (forbidden in this client), even as owner", function()
	local w = newWorld({ clubs = true, frameStep = 0.5 })
	wuberClub(w)
	local f = client(w, ANITA, { warlock = true })
	settle(w, 25)
	eq(f.W.community.role, 1, "Anita owns the community")
	for i = 1, 3 do
		local n = "Driver" .. string.char(64 + i) .. " Bot"
		w:addBot(n, { class = "WARLOCK" })
		injectD(w, f, n)
	end
	w:advance(120)
	eq(#(w.clubInvitesSent or {}), 0, "no invite sent")
	eq(f.W.Mod("Net.Community").CX.tickInvites(), false, "CX.tickInvites is a no-op")
	eq(#f.chatLines, 0, "nothing in chat")
	clean(w)
end)

---------------------------------------------------------------------------
-- The Drive tab: Join card and hint
---------------------------------------------------------------------------

test("community: the Join card shows for drivers with an invitation and accepts only on a click", function()
	if not HAVE_UI then error("Wuber's UI files are missing") end
	local w = newWorld({ clubs = true, realm = T.H.FOUNDER_REALM })
	local club = wuberClub(w)
	local d = client(w, BOB, { warlock = true })
	local mage = client(w, TESTCHAR)
	settle(w, 25)
	-- no invitation: the hint, with a tooltip
	openDrive(d)
	ok(hasText(d, "Tip: join the Wuber community for more visibility"), "the hint: " .. list(d:visibleTexts(), "; "))
	ok(not hasText(d, "Join the Wuber community"), "no card yet")
	local hint = d:findText("Tip: join the Wuber community for more visibility")[1]
	ok(hint and hint:GetParent().wuberTip, "the hint has a tooltip")
	-- an invitation from a stranger: still just the hint
	w:clubInvite(club, "Random Guy", BOB)
	w:advance(1)
	ok(not hasText(d, "Join the Wuber community"), "no card for a stranger's invitation")
	-- from the founder: the card
	w:clubInvite(club, ANITA, BOB)
	w:clubInvite(club, ANITA, TESTCHAR)
	w:advance(1)
	ok(hasText(d, "Join the Wuber community"), "the card: " .. list(d:visibleTexts(), "; "))
	ok(hasText(d, "Its member list helps riders find you across realms."), "its line (SPEC5 community: no channel)")
	ok(not hasText(d, "Tip: join the Wuber community for more visibility"), "the hint gives way")
	local joinFs = d:findText("Join")[1]
	ok(joinFs and joinFs:GetParent().wuberTip, "Join has a tooltip")
	w:advance(60)
	eq(d.acceptInvitationCalls, nil, "never accepted without a click")
	-- a rider (not a driver) gets no card
	if mage.W.UI then
		mage.W.UI.Toggle(true)
		w:advance(2.5)
		mage:clickText("Drive")
		w:advance(1)
		ok(not hasText(mage, "Join the Wuber community"), "no card for a rider")
	end
	eq(mage.acceptInvitationCalls, nil, "the rider's invitation untouched")
	-- the click
	d:clickText("Join")
	w:advance(2)
	eq(d.acceptInvitationCalls, 1, "AcceptInvitation once, from the click")
	ok(d.W.CommunityMember(), "a member now")
	ok(not hasText(d, "Join the Wuber community"), "the card is gone")
	ok(not hasText(d, "Tip: join the Wuber community for more visibility"), "and the hint")
	w:advance(5)
	-- (SPEC5 community: no channel follows; the membership makes the roster whisper seeds)
	eq(d.W.CommunityIndex(), nil, "no community channel")
	eq(d.W.CommunityStatus(), "Community: joined.", d.W.CommunityStatus())
	clean(w)
end)

test("community: a refused accept says to use Guild & Communities (J)", function()
	if not HAVE_UI then error("Wuber's UI files are missing") end
	local w = newWorld({ clubs = true, realm = T.H.FOUNDER_REALM })
	local club = wuberClub(w)
	w.acceptInvitationFails = true
	local d = client(w, BOB, { warlock = true })
	settle(w, 25)
	w:clubInvite(club, ANITA, BOB)
	openDrive(d)
	d:clickText("Join")
	w:advance(1)
	ok(hasText(d, "Open Guild & Communities (J) to accept"), "the fallback line: " .. list(d:visibleTexts(), "; "))
	ok(not hasText(d, "Join"), "no Join button any more")
	eq(#d.chatLines, 0, "nothing in chat")
	clean(w)
end)

---------------------------------------------------------------------------
-- The rider's ride after arriving: End ride, auto-end, the 2-hour rule, booking guard
---------------------------------------------------------------------------

local function rideToArrived(w, d, r)
	goOnline(d)
	d.W.Drive.SetOpt("autoTrade", false) -- (d4 x4) the summon now counts as ours: the driver would open the trade 3 s after landing; these tests stay at "arrived"
	r.W.RequestRide("anita lift")
	w:advance(1)
	T.take(d)
	w:advance(2)
	if not w:player(TESTCHAR).group then
		w.hardware = r
		r.W.AcceptInvite()
		w.hardware = nil
		w:advance(1)
	end
	w:summon(d, TESTCHAR)
	w:advance(1)
	w.hardware = r
	r.W.AcceptSummon()
	w.hardware = nil
	w:advance(3)
	eq(rideState(r), "arrived")
end

local function sent(w, kind, from)
	return #msgs(w, kind, from, "WHISPER")
end

test("end ride: the Found screen's End ride finishes an arrived ride, kept as an unpaid trip, nothing to the driver", function()
	if not HAVE_UI then error("Wuber's UI files are missing") end
	local w = newWorld()
	local d = client(w, ANITA, { warlock = true })
	local r = client(w, TESTCHAR)
	settle(w)
	rideToArrived(w, d, r)
	r.W.UI.Toggle(true)
	w:advance(2.5)
	ok(hasText(r, "Waiting for Anita to trade"), "stuck waiting: " .. list(r:visibleTexts(), "; "))
	ok(hasText(r, "End ride"), "End ride is offered")
	ok(r:findText("End ride")[1]:GetParent().wuberTip, "with its tooltip")
	local cs, trips = sent(w, "C", TESTCHAR), #r.W.db.rides
	r:clickText("End ride")
	w:advance(1)
	eq(rideState(r), "done", "done")
	eq(r.W.ride.endedBy, "rider")
	eq(r.W.ride.unpaid, true, "never paid through Wuber")
	eq(#r.W.db.rides, trips + 1, "kept as a trip")
	eq(r.W.db.rides[#r.W.db.rides].unpaid, true, "an unpaid trip")
	eq(r.W.Stats().spent, 0, "an unpaid trip spends nothing")
	eq(sent(w, "C", TESTCHAR), cs, "no cancel to the driver")
	eq(r.W.db.ride.state, "done", "persisted")
	ok(not hasText(r, "Waiting for Anita to trade"), "the Found screen moved on")
	-- before arriving there is no End ride (Cancel instead), and W.EndRide refuses
	clean(w)
end)

test("end ride: W.EndRide refuses before arrival; works while paying", function()
	local w = newWorld()
	local d = client(w, ANITA, { warlock = true })
	local r = client(w, TESTCHAR)
	settle(w)
	goOnline(d)
	r.W.RequestRide("anita lift")
	w:advance(1)
	eq(r.W.EndRide("rider"), false, "not before arriving")
	-- (SPEC3 decision 2: the engine takes the ride at once, so it may be past "requesting")
	ok(({ requesting = 1, accepted = 1, invited = 1, ingroup = 1 })[rideState(r) or ""], "not arrived: " .. tostring(rideState(r)))
	T.take(d)
	w:advance(3)
	w:summon(d, TESTCHAR)
	w:advance(1)
	w.hardware = r
	r.W.AcceptSummon()
	w.hardware = nil
	w:advance(3)
	w:openTrade(d, r)
	w:advance(0.5)
	eq(rideState(r), "paying")
	ok(r.W.EndRide("rider"), "ends while paying")
	eq(rideState(r), "done")
	clean(w)
end)

test("end ride: auto after 60 s out of the driver's group, after leaving the zone, or 10 min after arriving (even across a /reload)", function()
	-- out of the group
	local w = newWorld()
	local d = client(w, ANITA, { warlock = true })
	local r = client(w, TESTCHAR)
	settle(w)
	rideToArrived(w, d, r)
	w:leave(TESTCHAR)
	w:advance(30)
	eq(rideState(r), "arrived", "not yet")
	w:advance(35)
	eq(rideState(r), "done", "60 s out of the group")
	eq(r.W.ride.endedBy, "auto")
	eq(r.W.ride.unpaid, true)
	clean(w)
	-- hearthing away
	w = newWorld()
	d = client(w, ANITA, { warlock = true })
	r = client(w, TESTCHAR)
	settle(w)
	rideToArrived(w, d, r)
	w:advance(5)
	w:move(TESTCHAR, "Orgrimmar")
	w:advance(3)
	eq(rideState(r), "done", "left the destination's zone")
	eq(r.W.ride.endedBy, "auto")
	clean(w)
	-- walking around the destination doesn't end it
	w = newWorld()
	d = client(w, ANITA, { warlock = true })
	r = client(w, TESTCHAR)
	settle(w)
	rideToArrived(w, d, r)
	w:advance(5)
	w:move(TESTCHAR, "Crossroads") -- same zone (The Barrens)
	w:advance(5)
	eq(rideState(r), "arrived", "same zone: still arrived")
	-- 10 min after arriving, a /reload at 5 min doesn't restart the clock
	w:move(TESTCHAR, "Ratchet")
	w:advance(290)
	local r2 = w:reload(r)
	w:advance(5)
	eq(rideState(r2), "arrived", "restored after the /reload")
	w:advance(320)
	eq(rideState(r2), "done", "10 min after arriving")
	eq(r2.W.ride.endedBy, "auto")
	clean(w)
end)

test("end ride: a ride that times out in paying or arrived (no fare seen) is unpaid: no paid trip, no milestone, no rating", function()
	-- paying: the trade opened and was cancelled, the rider stays in the group at the destination for 5 min
	local w = newWorld()
	local d = client(w, ANITA, { warlock = true })
	local r = client(w, TESTCHAR)
	settle(w)
	rideToArrived(w, d, r)
	w:openTrade(d, r)
	w:advance(0.5)
	eq(rideState(r), "paying")
	w:tradeCancel(r)
	local trips, ms = #r.W.db.rides, 0
	for _ in pairs(r.W.db.milestones or {}) do ms = ms + 1 end
	w:advance(305)
	eq(rideState(r), "done", "the paying clock ran out")
	eq(r.W.ride.doneByTimeout, true, "ended by its clock")
	eq(r.W.ride.unpaid, true, "never paid through Wuber")
	eq(#r.W.db.rides, trips + 1, "kept as a trip")
	eq(r.W.db.rides[#r.W.db.rides].unpaid, true, "an unpaid trip")
	eq(r.W.Stats().spent, 0, "an unpaid trip spends nothing")
	eq(r.W.Stats().rides, 0, "and is not a paid ride")
	local ms2 = 0
	for _ in pairs(r.W.db.milestones or {}) do ms2 = ms2 + 1 end
	eq(ms2, ms, "no milestone from it")
	local ts = sent(w, "T", TESTCHAR)
	eq(r.W.Rate(5), false, "nothing to rate")
	eq(sent(w, "T", TESTCHAR), ts, "no rating sent")
	clean(w)
	-- arrived, in a fight at the portal for 10 min: CX.autoEnd waits, the arrived clock ends it
	w = newWorld()
	d = client(w, ANITA, { warlock = true })
	r = client(w, TESTCHAR)
	settle(w)
	rideToArrived(w, d, r)
	w:enterCombat(r)
	w:advance(605)
	eq(rideState(r), "done", "the arrived clock ran out")
	eq(r.W.ride.unpaid, true, "unpaid")
	eq(r.W.db.rides[#r.W.db.rides].unpaid, true, "an unpaid trip")
	eq(r.W.Rate(4), false, "nothing to rate")
	w:leaveCombat(r)
	clean(w)
end)

test("end ride: at login a ride left open for over 2 hours is cleared silently", function()
	local w = newWorld()
	local d = client(w, ANITA, { warlock = true })
	local r = client(w, TESTCHAR)
	settle(w)
	rideToArrived(w, d, r)
	r.W.db.ride.startedAt = r.env.time() - 7300
	local lines = #r.chatLines
	local r2 = w:reload(r)
	w:advance(3)
	eq(r2.W.ride, nil, "cleared")
	eq(r2.W.db.ride, nil, "and forgotten")
	eq(#r2.chatLines, 0, "silently")
	-- a fresh one stays
	w = newWorld()
	d = client(w, ANITA, { warlock = true })
	r = client(w, TESTCHAR)
	settle(w)
	rideToArrived(w, d, r)
	r2 = w:reload(r)
	w:advance(3)
	eq(rideState(r2), "arrived", "a ride of a few minutes is picked up again")
	clean(w)
end)

test("booking guard: no ride to where the rider already is", function()
	local w = newWorld()
	local d = client(w, ANITA, { warlock = true })
	local r = client(w, TESTCHAR, { spot = "Ratchet" })
	settle(w)
	goOnline(d)
	local ride, why, place = r.W.RequestRide("anita lift")
	eq(ride, nil, "refused")
	eq(why, "here")
	eq(place, "Ratchet")
	if HAVE_UI then
		openConfirm(r, "anita lift")
		ok(hasText(r, "You're already in Ratchet."), "the Request button says so: " .. list(r:visibleTexts(), "; "))
		r:clickText("You're already in Ratchet.")
		w:advance(1)
		eq(r.W.ride, nil, "no ride from a click")
		eq(#w:whispersTo(ANITA), 0, "no whisper")
	end
	-- a driver in Orgrimmar, the rider in Orgrimmar (its own map, any district)
	local d2 = client(w, BOB, { warlock = true, spot = "Orgrimmar" })
	local r2 = client(w, CAL, { spot = "Orgrimmar" })
	settle(w)
	goOnline(d2)
	local _, why2 = r2.W.RequestRide("bob stone")
	eq(why2, "here", "same city")
	-- elsewhere: fine
	w:move(TESTCHAR, "Orgrimmar")
	w:advance(1)
	ok(r.W.RequestRide("anita lift"), "from Orgrimmar to Ratchet: fine")
	clean(w)
end)
