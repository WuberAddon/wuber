-- r50 H: the away pause is about the driver, not one rider's wait (AU24-01/02/29/09)
local T = ...
local test = T.test
local ANITA = T.ANITA or "Anita Lift"
local function mk()
	local w = T.newWorld()
	local a = w:addClient(ANITA, { spot = "Undercity", class = "WARLOCK", allowMissing = true })
	a.W.Drive.SetOpen(true)
	return w, a, a.W.Drive
end
local function run(w, secs, step) for _ = 1, math.floor(secs / step) do w:advance(step) end end

for _, step in ipairs({ 1, 5 }) do
	-- guard: the pause still fires for a driver who does nothing (passes on the base too)
	test("r50 H away pause still fires for an idle driver, step " .. step, function()
		local w, a, DR = mk()
		w:addBot("Dan Miller", { spot = "Orgrimmar" })
		a:chatEvent("CHAT_MSG_WHISPER", "summon pls", "Dan Miller")
		w:advance(3)
		run(w, 235, step)
		T.ok(not DR.IsPaused(), "not yet")
		run(w, 20, step)
		T.ok(DR.IsPaused(), "idle driver paused after the window")
	end)
	test("r50 H Resume holds for the whole window, step " .. step, function()
		local w, a, DR = mk()
		w:addBot("Dan Miller", { spot = "Orgrimmar" })
		a:chatEvent("CHAT_MSG_WHISPER", "summon pls", "Dan Miller")
		w:advance(3)
		run(w, 250, step)
		T.ok(DR.IsPaused(), "paused")
		DR.SetPaused(false)
		run(w, 200, step)
		T.ok(not DR.IsPaused(), "still resumed 200 s after Resume")
		run(w, 60, step)
		T.ok(DR.IsPaused(), "an idle driver is paused again once a full window has passed")
	end)
	test("r50 H a crew mate's Resume (PAU) holds, step " .. step, function()
		local w, a, DR = mk()
		w:addBot("Dan Miller", { spot = "Orgrimmar" })
		a:chatEvent("CHAT_MSG_WHISPER", "summon pls", "Dan Miller")
		w:advance(3)
		run(w, 250, step)
		T.ok(DR.IsPaused(), "paused as away")
		DR.Apply("PAU", "bea lock", "0")
		run(w, 200, step)
		T.ok(not DR.IsPaused(), "still resumed 200 s after the crew Resume")
	end)
	test("r50 H a busy driver is not paused for the rider at the back, step " .. step, function()
		local w, a, DR = mk()
		local names = { "Dan Miller", "Eve Long", "Fay Stone", "Gus Hale" }
		for _, n in ipairs(names) do
			w:addBot(n, { spot = "Orgrimmar" })
			a:chatEvent("CHAT_MSG_WHISPER", "summon pls", n)
			w:advance(3)
		end
		for i = 1, 3 do
			run(w, 75, step)
			DR.Do("CAST", names[i]); DR.Do("END", names[i], 1)
		end
		run(w, 85, step)
		T.ok(not DR.IsPaused(), "driver summoned a rider 85 s ago")
	end)
	test("r50 H an offline rider does not pause the driver, step " .. step, function()
		local w, a, DR = mk()
		w:addBot("Dan Miller", { spot = "Orgrimmar" })
		a:chatEvent("CHAT_MSG_WHISPER", "summon pls", "Dan Miller")
		w:advance(3)
		w:player("Dan Miller").online = false
		run(w, 300, step)
		T.ok(not DR.IsPaused(), "offline rider")
	end)
end

test("r50 H price words are whole words", function()
	local DR = T.newWorld():addClient(ANITA, { spot = "Undercity", class = "WARLOCK", allowMissing = true }).W.Drive
	for _, s in ipairs({ "how much?", "whats the price", "prices?", "any fee", "what does it cost", "costs?", "is there a charge", "charged?" }) do
		T.eq(DR.Classify(s), "price", s)
	end
	for _, s in ipairs({ "i feel stuck", "my feet hurt", "nice costume", "will recharge", "feed me" }) do
		T.ok(DR.Classify(s) ~= "price", s)
	end
end)
