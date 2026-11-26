-- Proof tests of job 2620 (audit-241), area J: Shell, maps, toasts, what is new.
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
local H, eq, ok = T.H, T.eq, T.ok

local function up(Mod)
	local c = Mod.Card()
	return c and H.visible(c) and c or nil
end

local function advanceBy(w, total, step)
	local t = 0
	while t < total do w:advance(step) t = t + step end
end

-- The What's new card waits for a ride to end and "comes back later" (WhatsNew header). Its retries stop after
-- K.TRIES x K.RETRY = 10 minutes of being held back, so a long ride (or a long crew job) loses it for the session.
for _, step in ipairs({ 1, 5 }) do
	proof("AU24-12", "the What's new card still comes back after a ride that lasted over 10 minutes (step " .. step .. " s)", function()
		local w = T.newWorld()
		local c = T.rider(w, T.TESTCHAR, { saved = { Wuber = { coach = true, newsSeen = "2.3.4" } } })
		local W = c.W
		local Mod = W.Mod("UI.WhatsNew")
		w:advance(1)
		W.ride = { id = "r1", driver = "Anita Lift", state = "summoning", dest = "Undercity" }
		advanceBy(w, 11 * 60, step)
		ok(not up(Mod), "held back during the ride")
		W.ride = nil
		advanceBy(w, 30, step)
		ok(up(Mod), "the ride is over and nothing else is up: the held-back card must show, but it never does this session")
		T.clean(w)
	end)
end

-- AU24-14: the mid-flight offer is for a summon that beats the flight ("Wuber may offer a faster summon", What's new),
-- but UI.InFlight only checks 90 s left, never the driver's own summon time.
local UC_TM = {
	{ name = "Undercity, Tirisfal", type = "CURRENT", cost = 0, x = 0.42, y = 0.31 },
	{ name = "Tarren Mill, Hillsbrad", type = "REACHABLE", cost = 330, x = 0.47, y = 0.44 },
}
local function offerShown(avg)
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, { spot = "Undercity", screenW = 1365, screenH = 768 })
	T.settle(w)
	r.W.db.flights = r.W.db.flights or {}
	r.W.db.flights["H|undercity|tarren mill"] = { t = 200, tat = r.env.time(), tsrc = "own" }
	r.W.drivers = r.W.drivers or {}
	r.W.drivers["mia runner"] = { name = "Mia Runner", key = "mia runner", dest = "Tarren Mill", price = 5000, state = "open",
		team = 3, service = "Mia's Rides", heard = r.env.GetTime(), avgSummon = avg }
	w:openTaxiMap(r, UC_TM)
	w:fly(r, 2, 200, "Tarren Mill")
	w:advance(8)
	local Mod = r.W.Mod("UI.InFlight")
	local shown = Mod.Card() and H.visible(Mod.Card()) and true or false
	T.clean(w)
	return shown
end
-- guard: control for AU24-14's proof (job 2620), passes on the base by design
test("AU24-14 control: a driver who summons in 30 s is offered mid-flight", function()
	ok(offerShown(30), "offer shows for a fast summon")
end)
test("AU24-14: no mid-flight offer when the driver's summon (600 s) is slower than the flight left (about 190 s)", function()
	ok(not offerShown(600), "the card says 'About 3 min left. A summon takes about 600 sec.': a slower summon offered as a faster one")
end)

-- AU24-24: Reset says what it did and offers Undo (UI.UndoToast); a portal toast (sticky 8 s) swallows it whole.
test("AU24-24: a reset made while the portal toast is up still shows its message and Undo", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, {})
	T.settle(w)
	local UI = r.W.UI
	UI.Toast("Click the portal now", "portal")
	w:advance(2)
	local undone = false
	local t = UI.UndoToast("3 settings reset.", function() undone = true end)
	ok(t ~= nil and UI.UndoPending(), "the reset has no toast and no Undo: the player is told nothing and cannot put the settings back")
	T.clean(w)
end)
