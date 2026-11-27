local T = ...
local test, ok = T.test, T.ok

-- Round 33 c3 (HUNT-56, HUNT-57): a Name-Realm is left out of a bug report whole, in an error line
-- (a known player) and in the "What happened?" note (a known or unknown player).

local function world()
	local w = T.newWorld()
	local r = T.rider(w)
	T.settle(w)
	r.W.db.favs = r.W.db.favs or {}
	r.W.db.favs["Zed Quinn"] = true
	return w, r
end

test("r33 c3: a known player written Name-Realm in an error line leaves no realm in the report", function()
	local w, r = world()
	r.W.Error("trade", "could not trade Zed-Argentdawn today")
	local text = r.W.UI.Bug.Report("it broke")
	ok(not text:find("Argentdawn", 1, true), "realm left out: " .. text)
	ok(not text:find("Zed", 1, true), "name left out: " .. text)
	ok(text:find("player 1", 1, true), "still says player 1: " .. text)
	r.W.lastError = nil
	T.clean(w)
end)

test("r33 c3: a Name-Realm typed in What happened? is left out, known or not", function()
	local w, r = world()
	local text = r.W.UI.Bug.Report("Quinn-Argentdawn and Zed-Argentdawn did it")
	ok(not text:find("Argentdawn", 1, true), "no realm: " .. text)
	ok(not text:find("Quinn", 1, true), "no unknown name: " .. text)
	ok(not text:find("Zed", 1, true), "no known name: " .. text)
	T.clean(w)
end)
