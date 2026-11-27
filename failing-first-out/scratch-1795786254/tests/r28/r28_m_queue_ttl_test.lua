local T = ...
local H, test, eq, ok = T.H, T.test, T.eq, T.ok
local ANITA = T.ANITA or "Anita Lift"

local function scene()
	local w = T.newWorld()
	local a = w:addClient(ANITA, { spot = "Orgrimmar", class = "WARLOCK", allowMissing = true })
	local A = a.W.Drive
	A.SetOpen(true)
	A.opts().autoInvite = false -- the driver is not inviting for now: the rider waits in the queue
	w:addBot("Dan Miller", { spot = "Orgrimmar" })
	a:chatEvent("CHAT_MSG_WHISPER", "summon pls", "Dan Miller")
	w:advance(3)
	return w, a, A
end

test("r28 AUD-66: a rider who asked 20 minutes before the driver closed gets no invite on reopen", function()
	local w, a, A = scene()
	local c = A.customers["dan miller"]
	ok(c and c.state == "queued", "Dan waits in the queue, state " .. tostring(c and c.state))
	A.SetOpen(false)
	w:advance(1200) -- twenty minutes closed: the queue's clock (DR.QUEUE_TTL = 900 s) does not run while closed
	A.opts().autoInvite = true
	A.SetOpen(true)
	local c2 = A.customers["dan miller"]
	ok(not (c2 and c2.state ~= "queued"),
		"the driver reopened after 20 minutes and Dan, who asked for a summon 20 minutes ago, got a group invite at once (state " .. tostring(c2 and c2.state) .. ", expiry is " .. A.QUEUE_TTL .. " s)")
	T.clean(w)
end)
test("r28 AUD-66: a rider who asked 2 minutes before the driver closed is invited on reopen", function()
	local w, a, A = scene()
	local c = A.customers["dan miller"]
	ok(c and c.state == "queued", "Dan waits in the queue")
	A.SetOpen(false)
	w:advance(120)
	A.opts().autoInvite = true
	A.SetOpen(true)
	local c2 = A.customers["dan miller"]
	ok(c2 and c2.state ~= "queued", "Dan is invited, state " .. tostring(c2 and c2.state))
	T.clean(w)
end)
