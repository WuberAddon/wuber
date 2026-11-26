local T = ...
local test, eq, ok = T.test, T.eq, T.ok
local ANITA = T.ANITA or "Anita Lift"

local function scene()
	local w = T.newWorld()
	local a = w:addClient(ANITA, { spot = "Undercity", class = "WARLOCK", allowMissing = true })
	local DR = a.W.Drive
	DR.SetOpen(true)
	w:addBot("Dan Miller", { spot = "Orgrimmar" })
	return w, a, DR
end

local function unpaidRide(w, a, DR)
	a:chatEvent("CHAT_MSG_WHISPER", "summon pls", "Dan Miller")
	w:advance(3)
	DR.Do("CAST", "Dan Miller")
	DR.Do("END", "Dan Miller", 1)
	w:move("Dan Miller", "Undercity")
	w:advance(2)
	w:leave("Dan Miller")
	w:advance(3)
end

local function refusalPending(DR)
	for _, p in ipairs(DR.Pending()) do
		if p.kind == "refuse" then return p end
	end
end

-- guard: run1 item 13, the refusal is queued for the driver's click and shown in Pending
test("r51 A: an unpaid rider who asks again a minute later is refused, the driver sees it", function()
	local w, a, DR = scene()
	unpaidRide(w, a, DR)
	ok(DR.BlockEntry("dan miller"), "blocked after the unpaid ride")
	w:advance(60)
	a:chatEvent("CHAT_MSG_WHISPER", "summon please", "Dan Miller")
	w:advance(1)
	ok(DR.refusals["dan miller"], "refusal recorded")
	ok(refusalPending(DR), "the driver's pending list carries the 'why not' whisper")
	T.clean(w)
end)

-- guard: run1 item 13, waiving the fee lets the next ask through
test("r51 A: after the fee is waived the next ask queues", function()
	local w, a, DR = scene()
	unpaidRide(w, a, DR)
	a:chatEvent("CHAT_MSG_WHISPER", "summon please", "Dan Miller")
	w:advance(1)
	DR.Unblacklist("Dan Miller")
	a:chatEvent("CHAT_MSG_WHISPER", "summon please", "Dan Miller")
	w:advance(3)
	ok(DR.customers["dan miller"], "queued after the unblock")
	T.clean(w)
end)

-- guard: run1 item 13, tellBlocked off sends nothing, autoBlock off does not block
test("r51 A: tellBlocked off tells nobody; autoBlock off blocks nobody", function()
	local w, a, DR = scene()
	DR.opts().tellBlocked = false
	unpaidRide(w, a, DR)
	a:chatEvent("CHAT_MSG_WHISPER", "summon please", "Dan Miller")
	w:advance(1)
	ok(not DR.refusals["dan miller"], "no refusal with tellBlocked off")
	T.clean(w)
	local w2, a2, D2 = scene()
	D2.opts().autoBlock = false
	unpaidRide(w2, a2, D2)
	ok(not D2.BlockEntry("dan miller"), "not blocked with autoBlock off")
	T.clean(w2)
end)
