local T = ...
local test, eq, ok = T.test, T.eq, T.ok
local function has(s, p) return s:find(p, 1, true) ~= nil end

test("r47 a2: a party member still loading ('Unknown') does not turn the word unknown into a player", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, { spot = "Orgrimmar" })
	T.settle(w)
	local bot = w:addBot("Unknown", { spot = "Orgrimmar" })
	w:join(r.player, bot)
	w:advance(1)
	eq(r.env.UnitName("party1"), "Unknown", "the game answers Unknown for the loading member")
	r.W.lastError = nil
	r.W.Error("RIDE", "second unknown error")
	local t2 = r.W.UI.Bug.Report("it says unknown")
	ok(has(t2, "second unknown error") and has(t2, "it says unknown"),
		"the player's own words 'unknown' must stay:\n" .. t2)
	r.W.lastError = nil
	T.clean(w)
end)

test("r47 a2: Name-CAMWOW realm names are hidden in the bug report", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, { spot = "Orgrimmar" })
	T.settle(w)
	r.W.Error("RIDE", "no reply from Zed-Argent")
	local t1 = r.W.UI.Bug.Report("")
	ok(not has(t1, "Zed"), "control: Zed-Argent is hidden:\n" .. t1)
	r.W.Error("WHISPER", "could not whisper Dan-CAMWOWEU4Realm7PvE")
	local t2 = r.W.UI.Bug.Report("")
	ok(not has(t2, "Dan") and not has(t2, "CAMWOW"), "the stranger's name is left in the report:\n" .. t2)
	r.W.Error("WHISPER", "could not whisper Eve-Realm7")
	local t3 = r.W.UI.Bug.Report("")
	ok(not has(t3, "Eve-"), "a digit tail is hidden too:\n" .. t3)
	r.W.lastError = nil
	T.clean(w)
end)
