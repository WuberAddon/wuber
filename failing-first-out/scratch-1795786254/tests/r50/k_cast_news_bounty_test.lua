-- r50 group K: AU24-06 (only the ritual channel is a portal click), AU24-12 (the What's new card still shows when a
-- long hold ends), AU24-13 (a bounty cancel survives a /reload).
local T = ...
local test = T.test
local H, ok = T.H, T.ok

local function castSetup()
	local ANITA, SPOT = T.ANITA or "Anita Lift", "Undercity"
	local w = T.newWorld()
	local lock = w:addClient(ANITA, { spot = SPOT, class = "WARLOCK" })
	w:addBot("Bob Helper", { spot = SPOT })
	w:group({ ANITA, "Bob Helper" })
	w:advance(1)
	lock.W.Drive.SetOpen(true)
	w:advance(2)
	w:addBot("Dan Moss", { spot = "Orgrimmar" })
	w:botWhisper("Dan Moss", lock, "summon pls")
	w:advance(3)
	local helped = {}
	lock.W.Listen("DRIVE_RITUAL", function(name, phase, data)
		if phase == "h" and type(data) == "table" then helped[#helped + 1] = tostring(data.helperName or data.helper) end
	end)
	local b = lock.env.WuberDriveButton
	assert(b and H.visible(b), "the big button is not shown")
	lock:click(b)
	w:advance(1)
	return w, lock, helped
end
local function token(lock, name)
	for i = 1, 4 do
		if lock.W.UnitName("party" .. i) == name then return "party" .. i end
	end
	error("no party token for " .. name)
end

-- guard: the ritual itself (spell 698) held 3 s by a member without Wuber is still a helper
test("r50 K: a group member holding the ritual channel 3 s is still credited as a helper (AU24-06 neighbour)", function()
	local w, lock, helped = castSetup()
	lock:fire("UNIT_SPELLCAST_CHANNEL_START", token(lock, "Bob Helper"), "Bob-r", 698)
	w:advance(3)
	lock:fire("UNIT_SPELLCAST_CHANNEL_STOP", token(lock, "Bob Helper"), "Bob-r", 698)
	w:advance(3)
	local found
	for _, h in ipairs(helped) do if h:lower():find("bob", 1, true) then found = true end end
	ok(found, "Bob held the portal but is not credited: " .. table.concat(helped, ","))
	T.clean(w)
end)

test("r50 K: a group member channelling another spell is not a helper (AU24-06)", function()
	local w, lock, helped = castSetup()
	lock:fire("UNIT_SPELLCAST_CHANNEL_START", token(lock, "Bob Helper"), "Bob-mf", 15407)
	w:advance(3)
	lock:fire("UNIT_SPELLCAST_CHANNEL_STOP", token(lock, "Bob Helper"), "Bob-mf", 15407)
	w:advance(3)
	ok(#helped == 0, "credited: " .. table.concat(helped, ","))
	T.clean(w)
end)

local function up(Mod)
	local c = Mod.Card()
	return c and H.visible(c) and c or nil
end
for _, step in ipairs({ 1, 5 }) do
	test("r50 K: the What's new card shows when a hold longer than 10 minutes ends (AU24-12, step " .. step .. " s)", function()
		local w = T.newWorld()
		local c = T.rider(w, T.TESTCHAR, { saved = { Wuber = { coach = true, newsSeen = "2.3.4" } } })
		local Mod = c.W.Mod("UI.WhatsNew")
		w:advance(1)
		c.W.ride = { id = "r1", driver = "Anita Lift", state = "summoning", dest = "Undercity" }
		for _ = 1, math.floor(25 * 60 / step) do w:advance(step) end
		ok(not up(Mod), "held back during the ride")
		c.W.ride = nil
		for _ = 1, math.floor(60 / step) do w:advance(step) end
		ok(up(Mod), "card not shown after the hold ended")
		T.clean(w)
	end)
end

local function copperOf(w, from)
	local out = {}
	for _, e in ipairs(T.msgs(w, "W", from, "CHANNEL")) do
		if e.target == nil or type(e.target) == "number" then out[#out + 1] = T.fields(e)[4] end
	end
	return out
end

-- guard: a cancel is sent once after a reload, and not again later
test("r50 K: the cancel kept over a /reload goes once and is then forgotten (AU24-13)", function()
	local w = T.newWorld()
	local r = T.rider(w)
	T.settle(w)
	assert(r.W.Bounty.Pin("Gadgetzan", 6000), "pinned")
	w:advance(10)
	assert(r.W.Bounty.Cancel(), "cancelled")
	w:advance(1)
	local r2 = w:reload(r)
	w:advance(140)
	local got = copperOf(w, T.TESTCHAR)
	local zeros = 0
	for _, c in ipairs(got) do if c == "0" then zeros = zeros + 1 end end
	ok(zeros == 1, "cancel sent " .. zeros .. " times: " .. table.concat(got, ","))
	ok(r2.W.db.bountyCancel == nil, "the saved cancel is still there after it went")
	w:advance(200)
	got = copperOf(w, T.TESTCHAR)
	local z2 = 0
	for _, c in ipairs(got) do if c == "0" then z2 = z2 + 1 end end
	ok(z2 == 1, "sent again: " .. table.concat(got, ","))
	T.clean(w)
end)
