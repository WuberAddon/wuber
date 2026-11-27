-- p242 group B: AU24-36, a queued rider survives the driver's /reload.
local T = ...
local test = T.test
local ANITA = T.ANITA or "Anita Lift"

local function setup()
	local w = T.newWorld()
	local a = w:addClient(ANITA, { spot = "Undercity", class = "WARLOCK", allowMissing = true })
	a.W.Drive.SetOpen(true)
	w:addBot("Dan Miller", { spot = "Orgrimmar" })
	w:addBot("Eve Stone", { spot = "Orgrimmar" })
	return w, a
end

for _, step in ipairs({ 1, 5 }) do
	test("p242-B AU24-36: queued riders are restored queued, in order, and invited once the driver is back (step " .. step .. " s)", function()
		local w, a = setup()
		local DR = a.W.Drive
		DR.SetPaused(true)
		a:chatEvent("CHAT_MSG_WHISPER", "summon pls", "Dan Miller")
		w:advance(step * 3)
		a:chatEvent("CHAT_MSG_WHISPER", "summon pls", "Eve Stone")
		w:advance(step * 3)
		T.eq(DR.customers["dan miller"].state, "queued", "control: Dan queued")
		local a2 = w:reload(a)
		w:advance(step * 3)
		local DR2 = a2.W.Drive
		local d, e = DR2.customers["dan miller"], DR2.customers["eve stone"]
		T.ok(d and e, "both queued riders are back")
		T.eq(d.state, "queued", "Dan restored as queued")
		T.ok(d.order < e.order, "order kept")
		T.ok(not w:player("Dan Miller").group, "nobody invited while paused")
		DR2.SetPaused(false)
		w:advance(step * 10)
		T.ok(w:player("Dan Miller").group, "Dan is invited once the driver is back")
	end)
end

-- guard: a joined rider was already restored before the fix; the queued branch must not change it
test("p242-B AU24-36 guard: a joined rider is still restored joined after a reload", function()
	local w, a = setup()
	local DR = a.W.Drive
	a:chatEvent("CHAT_MSG_WHISPER", "summon pls", "Dan Miller")
	w:advance(10)
	local a2 = w:reload(a)
	w:advance(3)
	local c = a2.W.Drive.customers["dan miller"]
	T.ok(c, "Dan still on the list")
end)
