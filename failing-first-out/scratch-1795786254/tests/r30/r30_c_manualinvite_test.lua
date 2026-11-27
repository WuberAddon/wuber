local T = ...
-- Round 30 group C (HUNT-12): "Invite riders who whisper me" off. A whispering rider waits in the
-- list, nothing invites them by itself, a click on their row invites them (what the switch's
-- tooltip says), and the big button never says the invite goes out by itself.
local H, test, eq, ok = T.H, T.test, T.eq, T.ok
local ANA, DAN = "Ana Lock", "Dan Miller"
local MIA, BEA = "Mia Frost", "Bea Jones"
local function key(name) return (name:lower():gsub("[%s%-]+", " ")) end
local function invitesTo(w, name)
	local n = 0
	for _, i in ipairs(w.invites or {}) do if key(i.to) == key(name) then n = n + 1 end end
	return n
end

-- a solo Warlock driver in Undercity, open, with whisper invites on or off
local function setup(auto)
	local w = T.newWorld()
	local a = w:addClient(ANA, { spot = "Undercity", class = "WARLOCK", shards = 10 })
	w:addBot(DAN, { spot = "Ratchet" })
	w:advance(15)
	local DR = a.W.Drive
	DR.opts().autoInvite = auto
	ok(DR.SetOpen(true), "open")
	w:advance(3)
	w:botWhisper(DAN, a, "summon pls")
	w:advance(2)
	return w, a, DR
end

local function rowClick(w, a, c)
	w.hardware = a
	a.W.Driver.RowClick(c, "LeftButton")
	w.hardware = nil
end

test("r30 C HUNT-12: whisper invites off: nobody is invited by itself, and the big button does not say so", function()
	local w, a, DR = setup(false)
	local c = DR.customers[key(DAN)]
	eq(c and c.state, "queued", "Dan is on the list")
	w:advance(60)
	eq(invitesTo(w, DAN), 0, "nothing invites Dan while the switch is off")
	local p = DR.Plan()
	ok(not tostring(p.sub):find("as soon as there is room", 1, true),
		"the big button says the invite goes out by itself, and it never does: " .. tostring(p.title) .. " / " .. tostring(p.sub))
	ok(tostring(p.sub):find("click a name in the list to invite", 1, true), "the big button says to click the name: " .. tostring(p.sub))
	ok(a.W.Driver.RowTip(c):find("Click: invite them.", 1, true), "the row's tooltip says a click invites them")
	T.clean(w)
end)

test("r30 C HUNT-12: whisper invites off: a click on the queued rider's row invites them", function()
	local w, a, DR = setup(false)
	local c = DR.customers[key(DAN)]
	eq(c and c.state, "queued", "Dan is on the list")
	rowClick(w, a, c)
	w:advance(1)
	eq(invitesTo(w, DAN), 1, "a click on Dan's row invites Dan (the switch's tooltip: click a name in the list to invite)")
	local st = DR.customers[key(DAN)] and DR.customers[key(DAN)].state
	ok(st == "invited" or st == "joined", "Dan is marked invited (or has joined): " .. tostring(st))
	w:advance(30)
	eq(invitesTo(w, DAN), 1, "one click, one invite")
	T.clean(w)
end)

test("r30 C HUNT-12: whisper invites on: unchanged (invited by itself, the row click opens the menu)", function()
	local w, a, DR = setup(true)
	eq(invitesTo(w, DAN), 1, "Dan is invited by itself")
	T.clean(w)
end)

-- the crew case: Mia's window leads the group, Bea's does not (DR.CanInvite: the leader invites)
local function crewSaved(me, captain)
	local crew = {}
	for _, n in ipairs({ MIA, BEA }) do
		if n ~= me then crew[#crew + 1] = { name = n, role = "lock", app = true } end
	end
	return { chars = { [key(me)] = { crew = crew, captain = captain, wizard = true } } }
end

test("r30 C HUNT-12: whisper invites off, in a crew: only the leading window's row click invites", function()
	local w = T.newWorld()
	local mia = w:addClient(MIA, { spot = "Undercity", class = "WARLOCK", shards = 10, saved = { Wuber = crewSaved(MIA, MIA) } })
	local bea = w:addClient(BEA, { spot = "Undercity", class = "WARLOCK", shards = 10, saved = { Wuber = crewSaved(BEA, MIA) } })
	w:group({ MIA, BEA })
	w:advance(2)
	mia.W.Drive.opts().autoInvite = false
	bea.W.Drive.opts().autoInvite = false
	ok(mia.W.Drive.SetOpen(true), "Mia opens") w:advance(3)
	ok(bea.W.Drive.SetOpen(true), "Bea opens") w:advance(3)
	ok(mia.W.Drive.IsLeader(), "Mia's window leads the group")
	ok(not bea.W.Drive.IsLeader(), "Bea's window does not lead")
	w:addBot(DAN, { spot = "Ratchet" })
	w:botWhisper(DAN, bea, "summon pls")
	w:advance(4)
	eq(invitesTo(w, DAN), 0, "nobody invites Dan by himself")
	local cb, cm = bea.W.Drive.customers[key(DAN)], mia.W.Drive.customers[key(DAN)]
	eq(cb and cb.state, "queued", "Dan is queued in Bea's window")
	eq(cm and cm.state, "queued", "the leader's window lists Dan too")
	eq(bea.W.Drive.ClickInvites(cb), false, "Bea's window (not the leader) does not invite")
	eq(bea.W.Drive.Plan().sub, "the group leader invites", "Bea's big button: the group leader invites")
	eq(mia.W.Drive.Plan().sub, "click a name in the list to invite", "Mia's big button: click a name")
	rowClick(w, mia, cm)
	w:advance(1)
	eq(invitesTo(w, DAN), 1, "a click on Dan's row in the leader's window invites Dan")
	T.clean(w)
end)
