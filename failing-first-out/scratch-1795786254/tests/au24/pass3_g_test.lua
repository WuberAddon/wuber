-- Proof tests of job 2620 (audit-241), pass 3, area G: crew sync with three windows, FX.
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
local SPOT = "Undercity"
local CAL, BEA = T.CAL, T.BEA
-- Anita (captain, Warlock), Cal and Bea (Warlocks with Wuber) in one party; both join Anita's crew.
-- before(cal): runs on Cal's window before he joins (his own settings).
local function crewWorld(before)
	local w = T.newWorld()
	local cap = T.driver(w, T.ANITA, { spot = SPOT })
	local cal = w:addClient(CAL, { spot = SPOT, class = "WARLOCK" })
	local bea = w:addClient(BEA, { spot = SPOT, class = "WARLOCK" })
	w:group({ T.ANITA, CAL, BEA })
	w:advance(15)
	if before then before(cal) end
	local D = cap.W.Drive
	D.OfferCrew(CAL) D.OfferCrew(BEA)
	w:advance(2)
	cal.W.Drive.AnswerOffer(T.ANITA, true)
	bea.W.Drive.AnswerOffer(T.ANITA, true)
	w:advance(5)
	return w, cap, cal, bea
end

-- AU24-31: the captain's service name and keywords stay on a member's own window after he leaves the crew.
proof("AU24-31", "a member who leaves a crew gets his own service name and invite keywords back", function()
	local w, cap, cal = crewWorld(function(c)
		ok(c.W.Drive.SetService("Cal Express"))
		c.W.Drive.SetOpt("keywords", "hop ride")
	end)
	local D = cap.W.Drive
	D.SetService("Fast Rides")
	D.SetOpt("keywords", "taxi portal")
	w:advance(5)
	eq(cal.W.Drive.char().service, "Fast Rides", "in the crew Cal's window uses the captain's service name")
	cal.W.Drive.LeaveCrew()
	w:advance(5)
	local ch, opts = cal.W.Drive.char(), cal.W.Drive.opts()
	ok(ch.service == "Cal Express" and table.concat(opts.keywords, " ") == "hop ride",
		"after leaving, Cal's own window reads service '" .. tostring(ch.service) .. "' and keywords '" .. table.concat(opts.keywords, " ") .. "' (his own were 'Cal Express' and 'hop ride')")
	T.clean(w)
end)

-- AU24-31: the captain's Pause stays on a member's own window after he leaves the crew.
proof("AU24-31", "a member who leaves a crew the captain had paused is not left paused", function()
	local w, cap, cal = crewWorld()
	ok(not cal.W.Drive.IsPaused(), "Cal was not paused before")
	cap.W.Drive.SetPaused(true)
	w:advance(5)
	ok(cal.W.Drive.IsPaused(), "in the crew Cal's window follows the captain's pause")
	cal.W.Drive.LeaveCrew()
	w:advance(5)
	ok(not cal.W.Drive.IsPaused(), "after leaving, Cal's own window is still Paused (the captain's pause), so his own shop starts with no invites")
	T.clean(w)
end)


-- AU24-31: the captain's "who casts" choice stays on a member's own window after he leaves the crew.
proof("AU24-31", "a member who leaves a crew has his own 'who casts' choice back, not the old captain's pick", function()
	local w, cap, cal = crewWorld()
	-- r50: Cal follows the captain's pick as soon as he joins, so his own choice is read in tests/r50/l_leavecrew_test.lua
	cap.W.Drive.SetCaster(BEA)
	w:advance(5)
	eq(cal.W.Drive.char().caster, "Bea Jones", "in the crew Cal's window names Bea as main caster")
	cal.W.Drive.LeaveCrew()
	w:advance(5)
	ok(cal.W.Drive.char().caster ~= "Bea Jones", "after leaving, Cal's 'who casts' no longer names the old captain's pick")
	T.clean(w)
end)
