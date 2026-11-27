-- Verifier V1 of job 2620 (audit-241): probe tests.
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

-- Promise: the away guard pauses a driver who is away (nobody summons a waiting rider). A rider who
-- logged off while in the group cannot be summoned by anyone: waiting 4 minutes for them is no sign
-- that the driver is away, and the driver (at the keyboard) must not be paused with "Dan waited 4 minutes
-- for a summon", nor be re-paused after Resume.
proof("AU24-29", "a rider who logged off in the group does not pause the present driver as 'away'", function()
	local w = T.newWorld()
	local a = w:addClient(ANITA, { spot = "Undercity", class = "WARLOCK", allowMissing = true })
	local DR = a.W.Drive
	DR.SetOpen(true)
	w:addBot("Dan Miller", { spot = "Orgrimmar" })
	a:chatEvent("CHAT_MSG_WHISPER", "summon pls", "Dan Miller")
	w:advance(3)
	T.eq(DR.customers["dan miller"].state, "joined", "Dan is in the group")
	w:player("Dan Miller").online = false -- Dan's game closes; he stays in the group, shown offline
	for _ = 1, 50 do w:advance(5) end -- 250 s: the driver is at the keyboard, there is nothing to summon
	T.ok(not DR.IsPaused(), "Dan is offline, nobody can summon him, yet Wuber paused the driver as away: " .. tostring(DR.Plan and DR.Plan().title))
end)
