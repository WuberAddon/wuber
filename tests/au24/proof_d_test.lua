-- Proof tests of job 2620 (audit-241), area D: Drive engine (queue) and theme.
local T = ...
local test = T.test
-- r50 (job 2609): these bugs are fixed in 2.4.1; their proofs now run as normal tests
local FIXED = { ["AU24-01"] = true, ["AU24-02"] = true, ["AU24-03"] = true, ["AU24-06"] = true, ["AU24-09"] = true, ["AU24-10"] = true, ["AU24-12"] = true, ["AU24-13"] = true, ["AU24-15"] = true, ["AU24-17"] = true, ["AU24-18"] = true, ["AU24-19"] = true, ["AU24-20"] = true, ["AU24-21"] = true, ["AU24-22"] = true, ["AU24-26"] = true, ["AU24-27"] = true, ["AU24-28"] = true, ["AU24-29"] = true, ["AU24-31"] = true, ["AU24-33"] = true, ["AU24-34"] = true, ["AU24-35"] = true }
local function proof(id, name, fn)
	if os.getenv("WUBER_AU24_PROOF") or FIXED[id] then
		test(id .. ": " .. name, fn)
	else
		test(id .. " (expected fail until fixed): " .. name, function()
			local okp = pcall(fn)
			assert(not okp, id .. " now passes: the bug looks fixed; make this a normal test")
		end)
	end
end

local ANITA = T.ANITA or "Anita Lift"

local function whisper(text)
	local w = T.newWorld()
	local a = w:addClient(ANITA, { spot = "Orgrimmar", class = "WARLOCK", allowMissing = true })
	local DR = a.W.Drive
	w:addBot("Dan Miller", { spot = "Orgrimmar" })
	DR.SetOpen(true)
	w:advance(2)
	a:chatEvent("CHAT_MSG_WHISPER", text, "Dan Miller")
	w:advance(2)
	local c = DR.customers["dan miller"]
	T.clean(w)
	return c
end

-- control: a real price question is read as one
-- guard: control for AU24-09's proof (job 2620), passes on the base by design
test("AU24-09 control: a whisper that asks how much is read as asking the price", function()
	local c = whisper("summon me pls how much")
	T.ok(c, "a row was made")
	T.ok(c.wantsPrice, "asking how much marks the row as asking the price")
end)

-- promise: a line that asks for a summon and never asks about money is never listed as "asks the price"
proof("AU24-09", "a whisper that only contains the letters fee, cost or charge inside another word (feel, costume, recharge) is not read as a price question", function()
	local lines = {
		"summon me pls, i feel stuck",
		"inv pls my feet hurt",
		"summon me pls nice costume",
		"inv pls i will recharge",
	}
	local bad = {}
	for _, text in ipairs(lines) do
		local c = whisper(text)
		T.ok(c, "a row was made for: " .. text)
		if c.wantsPrice then bad[#bad + 1] = text end
	end
	T.ok(#bad == 0, "the row says asks the price for lines that never ask one: " .. table.concat(bad, " | "))
end)

local function key(n) return n:lower() end

-- the away guard: "a rider waits 4 minutes and nobody summons: the driver is away"
proof("AU24-01", "a driver who is busy summoning other riders is not paused as away because the rider at the back of the queue has waited 4 minutes", function()
	local w = T.newWorld()
	local a = w:addClient(ANITA, { spot = "Undercity", class = "WARLOCK", allowMissing = true })
	local DR = a.W.Drive
	DR.SetOpen(true)
	local names = { "Dan Miller", "Eve Long", "Fay Stone", "Gus Hale" }
	for _, n in ipairs(names) do
		w:addBot(n, { spot = "Orgrimmar" })
		a:chatEvent("CHAT_MSG_WHISPER", "summon pls", n)
		w:advance(3)
	end
	for _, n in ipairs(names) do
		T.eq(DR.customers[key(n)] and DR.customers[key(n)].state, "joined", n .. " is in the group, waiting for a summon")
	end
	local start = 12 -- seconds since the first rider joined, about
	local clock = 0
	local function at(t) if t > clock then w:advance(t - clock) clock = t end end
	-- the driver summons the first three, one about every 80 s (each ride takes a minute or more)
	local lastSummon
	for i = 1, 3 do
		at((i - 1) * 80 + 5)
		DR.Do("CAST", names[i])
		DR.Do("END", names[i], 1)
		lastSummon = clock
	end
	at(225)
	T.ok(not DR.IsPaused(), "not paused before any rider has waited 4 minutes")
	at(255) -- Gus joined about 255 s ago; the driver summoned Fay 30 s ago
	T.eq(DR.customers[key(names[4])].state, "joined", "Gus still waits his turn")
	T.ok(DR.Busy(), "a ride is in progress (Fay's summon waits for her accept), so the driver is not away")
	T.ok(not DR.IsPaused(), "the driver summoned a rider " .. (clock - lastSummon) .. " s ago and a ride is in progress, yet Wuber paused the whole service as 'away'")
end)

-- Resume after an away pause
proof("AU24-02", "Resume after the away pause stays resumed while the driver gets to the waiting rider", function()
	local w = T.newWorld()
	local a = w:addClient(ANITA, { spot = "Undercity", class = "WARLOCK", allowMissing = true })
	local DR = a.W.Drive
	DR.SetOpen(true)
	w:addBot("Dan Miller", { spot = "Orgrimmar" })
	a:chatEvent("CHAT_MSG_WHISPER", "summon pls", "Dan Miller")
	w:advance(3)
	T.eq(DR.customers["dan miller"].state, "joined", "Dan is in the group")
	w:advance(250)
	T.ok(DR.IsPaused(), "control: the away guard paused the driver after 4 minutes")
	DR.SetPaused(false) -- the driver is back and clicks Resume
	for _ = 1, 5 do w:advance(1) end
	T.ok(not DR.IsPaused(), "five seconds after Resume the away guard has paused the driver again for the same rider, who has not waited any longer than before the driver came back")
end)
