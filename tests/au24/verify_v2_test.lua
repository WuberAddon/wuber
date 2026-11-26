-- Verifier V2 of job 2620: probe tests.
local T = ...
local test = T.test
local H, eq, ok = T.H, T.eq, T.ok
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
local DRU, LEA, CAL, RAY = "Dru Oak", "Lea Dorn", T.CAL, "Ray Ash"
local RAIDSPOT = "Blackrock Mountain"
local function key(name) return (name:lower():gsub("[%s%-]+", " ")) end
local function raidWorld()
	local w = H.NewWorld({})
	w:addBot(LEA, { spot = RAIDSPOT, class = "WARRIOR" })
	local dru = w:addClient(DRU, { spot = RAIDSPOT, class = "DRUID" })
	local cal = w:addClient(CAL, { spot = RAIDSPOT, class = "WARLOCK" })
	local names = { LEA, DRU, CAL, RAY }
	for i = 1, 4 do
		local n = "Raider R" .. string.char(96 + i)
		w:addBot(n, { spot = "Orgrimmar", class = "WARRIOR" })
		names[#names + 1] = n
	end
	local ray = T.rider(w, RAY, { spot = "Orgrimmar" })
	w:group(names)
	w:setAssist(DRU, true)
	T.settle(w)
	local DD = dru.W.Drive
	ok(DD.SetMode("raid"))
	ok(DD.RaidPick(CAL, true))
	w:advance(1)
	cal.W.Drive.AnswerOffer(DRU, true)
	w:advance(3)
	ok(DD.SetOpen(true), "Start")
	w:advance(20)
	return w, dru, cal, ray
end
-- AU24-30: the raid runner leaves the group; a raider types 123 afterwards.
test("AU24-30: after the runner left the group a crew window never says raid summons run while nobody can queue a raider", function()
	local w, dru, cal = raidWorld()
	local C = cal.W.Drive
	ok(C.RaidOn(), "Cal's window knows raid summons run before the runner leaves")
	w:leave(DRU)
	w:advance(20)
	ok(not dru.W.Drive.RaidOn(), "the runner's own window stopped raid summons when it left the group")
	w:botWhisper("Raider Ra", cal, "123")
	w:advance(5)
	local queued = C.raidRows[key("Raider Ra")] ~= nil
	for _, pc in ipairs({ cal }) do
		ok(queued or not C.RaidOn(), "the runner left and Ra typed 123: Cal's window still says raid summons run (console: 'raiders type 123') but nobody lists Ra; RaidOn=" .. tostring(C.RaidOn()) .. " answerer=" .. tostring(C.SyncAnswerer()))
	end
	T.clean(w)
end)
