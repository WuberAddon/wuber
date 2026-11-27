-- Round 47 lead: follow-up to AUD-218 (found by the independent read of the round's diff): a short tail with a
-- digit ("Alt-1", "Wuber-2") is not a realm, so the bug report keeps such words readable.
local T = ...
local test, ok = T.test, T.ok
local function has(s, p) return s:find(p, 1, true) ~= nil end

test("r47 lead: the bug report keeps words like Alt-1 and Wuber-2 (a short digit tail is no realm)", function()
	local w = T.newWorld()
	local r = T.rider(w, T.BOB, { spot = "Orgrimmar" })
	T.settle(w)
	r.W.lastError = nil
	r.W.Error("KEYS", "pressed Alt-1 on the Wuber-2 build")
	local t1 = r.W.UI.Bug.Report("")
	ok(has(t1, "Alt-1") and has(t1, "Wuber-2"), "a key name and a build name stay readable:\n" .. t1)
	r.W.Error("WHISPER", "could not whisper Dan-CAMWOWEU4Realm7PvE or Eve-Realm7")
	local t2 = r.W.UI.Bug.Report("")
	ok(not has(t2, "Dan") and not has(t2, "CAMWOW") and not has(t2, "Eve-"), "control: real server tails are still hidden:\n" .. t2)
	r.W.lastError = nil
	T.clean(w)
end)
