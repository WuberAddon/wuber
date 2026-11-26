-- Proof tests of job 2620 (audit-241), area D, pass 3: action sequences on the queue engine.
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

test("AU24-36: a rider waiting in the queue (not invited yet) is still served after the driver reloads", function()
	local w = T.newWorld()
	local a = w:addClient(ANITA, { spot = "Undercity", class = "WARLOCK", allowMissing = true })
	local DR = a.W.Drive
	DR.SetOpen(true)
	w:addBot("Dan Miller", { spot = "Orgrimmar" })
	DR.SetPaused(true) -- the driver steps away for a moment: nobody is invited while paused
	a:chatEvent("CHAT_MSG_WHISPER", "summon pls", "Dan Miller")
	w:advance(3)
	T.eq(DR.customers["dan miller"] and DR.customers["dan miller"].state, "queued", "control: Dan is queued while paused")
	local a2 = w:reload(a)
	w:advance(3)
	local DR2 = a2.W.Drive
	DR2.SetPaused(false)
	w:advance(10)
	local c = DR2.customers["dan miller"]
	T.ok(c, "Dan asked for a summon and is not on the list after the reload: nobody will ever invite him")
	T.ok(c.state ~= "lead" and c.state ~= "done", "Dan is back in the queue")
	T.ok(w:player("Dan Miller").group, "Dan is invited once the driver is back")
end)
