local T = ...
local test, eq, ok = T.test, T.eq, T.ok
local ANITA = T.ANITA or "Anita Lift"

local function scene(sender)
	local w = T.newWorld()
	local a = w:addClient(ANITA, { spot = "Orgrimmar", class = "WARLOCK", allowMissing = true })
	local DR = a.W.Drive
	w:addBot("Dan Miller", { spot = "Orgrimmar" })
	DR.SetOpen(true)
	DR.Blacklist("Dan Miller", "owes gold", false)
	w:advance(2)
	a:chatEvent("CHAT_MSG_WHISPER", "summon", sender)
	w:advance(2)
	return w, a, DR
end

test("r33 AUD-83: a blocked player's refusal name has no realm tail", function()
	local w, a, DR = scene("Dan Miller-CAMWOWEU4Realm7PvE")
	local r = DR.refusals["dan miller"]
	ok(r, "the request is recorded as a refusal")
	ok(not r.name:find("CAMWOW", 1, true), "name kept its realm tail: " .. tostring(r.name))
	T.clean(w)
end)

test("r33 AUD-83: a plain sender keeps a plain refusal name", function()
	local w, a, DR = scene("Dan Miller")
	local r = DR.refusals["dan miller"]
	ok(r, "recorded")
	eq(r.name, "Dan Miller")
	T.clean(w)
end)
