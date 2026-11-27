-- Proof tests of job 2620 (audit-241), area E: secure clicks, casting, chat, auto replies.
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

local H = T.H

local function printed(W)
	local out = {}
	W.Print = function(t) out[#out + 1] = tostring(t) end
	return out
end

-- Verifier V4: AU24-15 corrected. The original also failed on the "off" line ("Closed. Nobody is invited or
-- asked to pay."), which is true in raid mode; a correct fix of the "on" line alone must pass.
local function raidRunner()
	local DRU, LEA, CAL = "Dru Oak", "Lea Dorn", T.CAL
	local w = H.NewWorld({})
	w:addBot(LEA, { spot = "Blackrock Mountain", class = "WARRIOR" })
	local dru = w:addClient(DRU, { spot = "Blackrock Mountain", class = "DRUID" })
	local cal = w:addClient(CAL, { spot = "Blackrock Mountain", class = "WARLOCK" })
	local names = { LEA, DRU, CAL }
	for i = 1, 5 do
		local n = "Raider R" .. string.char(96 + i)
		w:addBot(n, { spot = "Orgrimmar", class = "WARRIOR" })
		names[#names + 1] = n
	end
	w:group(names)
	w:setAssist(DRU, true)
	T.settle(w)
	local DD = dru.W.Drive
	assert(DD.SetMode("raid"))
	assert(DD.RaidPick(CAL, true))
	w:advance(1)
	cal.W.Drive.AnswerOffer(DRU, true)
	w:advance(3)
	return w, dru, DD
end

proof("AU24-15", "(V4 corrected) /wuber drive on in raid mode talks about raid summons, not about riders whispering a word or a fare", function()
	local w, dru, DD = raidRunner()
	local out = printed(dru.W)
	DD.Command("on")
	w:advance(3)
	assert(DD.IsOpen(), "raid summons started")
	local onText = table.concat(out, "\n")
	assert(#out > 0, "control: the command answered")
	assert(not onText:find("Riders whisper", 1, true), "raid mode 'on' tells the driver riders whisper a word: " .. onText)
	assert(not onText:find("50s", 1, true), "raid mode 'on' quotes a fare although raid summons are free: " .. onText)
	T.clean(w)
end)
