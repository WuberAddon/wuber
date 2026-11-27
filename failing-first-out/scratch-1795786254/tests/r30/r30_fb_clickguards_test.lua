local T = ...
-- Round 30 follow-up B (HUNT-12): with "Invite riders who whisper me" off, a click on a queued
-- rider's row invites them only when the timer would invite them with the switch on: never while
-- Paused, nor with the group full. Otherwise the click opens the menu as before.
local H, test, eq, ok = T.H, T.test, T.eq, T.ok
local ANA, DAN = "Ana Lock", "Dan Miller"
local MIA, BEA = "Mia Frost", "Bea Jones"
local function key(name) return (name:lower():gsub("[%s%-]+", " ")) end
local function invitesTo(w, name)
	local n = 0
	for _, i in ipairs(w.invites or {}) do if key(i.to) == key(name) then n = n + 1 end end
	return n
end

local function setup()
	local w = T.newWorld()
	local a = w:addClient(ANA, { spot = "Undercity", class = "WARLOCK", shards = 10 })
	w:addBot(DAN, { spot = "Ratchet" })
	w:advance(15)
	local DR = a.W.Drive
	DR.opts().autoInvite = false
	ok(DR.SetOpen(true), "open")
	w:advance(3)
	w:botWhisper(DAN, a, "summon pls")
	w:advance(2)
	local c = DR.customers[key(DAN)]
	eq(c and c.state, "queued", "Dan is on the list")
	return w, a, DR, c
end

local function rowClick(w, a, c)
	w.hardware = a
	a.W.Driver.RowClick(c, "LeftButton")
	w.hardware = nil
	w:advance(1)
end

test("r30 fb clickguards: Paused: a row click does not invite, after Resume it does", function()
	local w, a, DR, c = setup()
	DR.SetPaused(true)
	w:advance(1)
	ok(DR.IsPaused(), "paused")
	eq(DR.ClickInvites(c), false, "no click invite while Paused")
	rowClick(w, a, c)
	eq(invitesTo(w, DAN), 0, "the console says Paused: nobody new is invited, yet the click invited Dan")
	eq(DR.Plan().sub, "nobody new is invited: tap Resume", "the big button says Paused")
	DR.SetPaused(false)
	w:advance(2)
	eq(invitesTo(w, DAN), 0, "Resume alone does not invite with the switch off")
	eq(DR.ClickInvites(c), true, "after Resume a click invites")
	rowClick(w, a, c)
	eq(invitesTo(w, DAN), 1, "after Resume a click on Dan's row invites Dan")
	T.clean(w)
end)

test("r30 fb clickguards: group full: a row click does not invite", function()
	local w, a, DR, c = setup()
	w:addBot(MIA, { spot = "Undercity" })
	w:addBot(BEA, { spot = "Undercity" })
	w:group({ ANA, MIA, BEA })
	DR.opts().maxGroup = 3
	w:advance(2)
	eq(DR.GroupSize(), 3, "three in the group")
	eq(c.state, "queued", "Dan still waits")
	eq(DR.ClickInvites(c), false, "no click invite with the group full")
	rowClick(w, a, c)
	eq(invitesTo(w, DAN), 0, "the group is full, yet the click invited Dan")
	T.clean(w)
end)
