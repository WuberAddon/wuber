-- Round r50 L: AU24-31, leaving a crew gives back every setting the crew overwrote.
local T = ...
local test = T.test
local H, eq, ok = T.H, T.eq, T.ok
local CAL, BEA = T.CAL, T.BEA
local function crewWorld(before, step)
	local w = T.newWorld()
	local cap = T.driver(w, T.ANITA, { spot = "Undercity" })
	local cal = w:addClient(CAL, { spot = "Undercity", class = "WARLOCK" })
	local bea = w:addClient(BEA, { spot = "Undercity", class = "WARLOCK" })
	w:group({ T.ANITA, CAL, BEA })
	w:advance(15)
	if before then before(cal) end
	cap.W.Drive.OfferCrew(CAL) cap.W.Drive.OfferCrew(BEA)
	w:advance(2)
	cal.W.Drive.AnswerOffer(T.ANITA, true)
	bea.W.Drive.AnswerOffer(T.ANITA, true)
	for _ = 1, 5 / step do w:advance(step) end
	return w, cap, cal, bea
end
for _, step in ipairs({ 1, 5 }) do
	test("r50 L: leaving a crew restores service, words, pause and caster (steps of " .. step .. " s)", function()
		local own
		local w, cap, cal = crewWorld(function(c)
			ok(c.W.Drive.SetService("Cal Express"))
			c.W.Drive.SetOpt("keywords", "hop ride")
			c.W.Drive.SetCaster(CAL)
			own = c.W.Drive.char().caster
		end, step)
		local D = cap.W.Drive
		D.SetService("Fast Rides") D.SetOpt("keywords", "taxi portal") D.SetCaster(BEA) D.SetPaused(true)
		for _ = 1, 5 / step do w:advance(step) end
		eq(cal.W.Drive.char().service, "Fast Rides", "in the crew he follows the captain")
		ok(cal.W.Drive.IsPaused(), "and the pause")
		cal.W.Drive.LeaveCrew()
		for _ = 1, 5 / step do w:advance(step) end
		local ch, opts = cal.W.Drive.char(), cal.W.Drive.opts()
		eq(ch.service, "Cal Express")
		eq(table.concat(opts.keywords, " "), "hop ride")
		ok(not cal.W.Drive.IsPaused(), "his own shop is not paused")
		eq(ch.caster, own, "his own 'who casts' is back")
		eq(ch.crewOwn, nil, "nothing kept aside")
		T.clean(w)
	end)
end
-- guard: a member who was already Paused before joining is Paused again after leaving
test("r50 L: a member paused before joining is paused again after leaving", function()
	local w, cap, cal = crewWorld(function(c) c.W.Drive.SetPaused(true) end, 1)
	cap.W.Drive.SetPaused(false)
	w:advance(5)
	cal.W.Drive.LeaveCrew()
	w:advance(5)
	ok(cal.W.Drive.IsPaused(), "his own pause is back")
	T.clean(w)
end)
