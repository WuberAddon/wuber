-- AUD-58's proof test, moved in by the lead: group L's fix for AUD-49 (saved riders put back in saved order) fixes it too.
local T = ...
local H, test, eq, ok = T.H, T.test, T.eq, T.ok
local ANA, DAN, EVE = "Ana Smith", "Dan Miller", "Eve Stone"
local function key(n) return (n:lower():gsub("[%s%-]+", " ")) end

test("r28 AUD-58: after a driver reload the rider who asked first is still summoned first", function()
	local w = H.NewWorld({})
	local a = w:addClient(ANA, { spot = "Orgrimmar", class = "WARLOCK", shards = 10 })
	w:addBot(DAN, { spot = "Ironforge", acceptsInvites = false })
	w:addBot(EVE, { spot = "Ironforge", acceptsInvites = true })
	w:advance(15)
	local DR = a.W.Drive
	ok(DR.SetOpen(true), "open")
	w:advance(3)
	w:botWhisper(DAN, a, "summon pls")   -- Dan asks first
	w:advance(1)
	w:botWhisper(EVE, a, "summon pls")   -- Eve second
	w:advance(10)
	-- Eve's game accepts at once; Dan clicks the invite late
	w:join(w:player(ANA), w:player(DAN))
	w:advance(5)
	local dan, eve = DR.customers[key(DAN)], DR.customers[key(EVE)]
	ok(dan and eve, "both riders are listed")
	eq(dan.state, "joined", "control: Dan is joined"); eq(eve.state, "joined", "control: Eve is joined")
	ok(dan.order < eve.order, "control: before the reload Dan (asked first) is ahead of Eve")
	eq(DR.NextSummon().key, key(DAN), "control: the next summon is Dan")
	a = w:reload(a)
	w:advance(5)
	DR = a.W.Drive
	local nxt = DR.NextSummon()
	eq(nxt and nxt.key, key(DAN), "after the /reload the next summon is " .. tostring(nxt and nxt.name) .. " although Dan asked first and has waited longer")
	T.clean(w)
end)
