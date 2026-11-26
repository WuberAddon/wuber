-- Flight recorder, lane B1: how the fake game reports a blocked action, checked against the real client
-- (WoW Forever, 17-21 Nov 2026; facts in tests/fixtures/rec/lab-real-facts.lua).
local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H

local function listen(name, fn)
	local got, orig = {}, H.Client.fire
	H.Client.fire = function(self, ev, ...)
		if self.player and self.player.name == name and (ev == "ADDON_ACTION_FORBIDDEN" or ev == "ADDON_ACTION_BLOCKED") then
			got[#got + 1] = { ev = ev, args = { n = select("#", ...), ... } }
		end
		return orig(self, ev, ...)
	end
	local okf, err = pcall(fn, got)
	H.Client.fire = orig
	if not okf then error(err, 0) end
	return got
end

-- trade.forbidden.func (every block line in the lines): "Wuber Rocks 18 Nov 01:04:05 'block ADDON_ACTION_FORBIDDEN
-- addon=Wuber func=UNKNOWN() combat=false'", and the same for the test addon's own blocked calls (3 lines). The
-- game never names the function. The fake named it in two places (a call that needs a real click, and
-- C_TradeInfo.SetTradeMoney).
test("rec: real: a call that needs a real click is refused as ADDON_ACTION_FORBIDDEN(addon, 'UNKNOWN()') (trade.forbidden.func)", function()
	local w = T.newWorld({ confirmSummonNeedsClick = true }) -- ConfirmSummon needs no click in this client (measured), so the strict rule is asked for
	local r = T.rider(w, T.TESTCHAR)
	T.settle(w)
	local got = listen(T.TESTCHAR, function() r.env.C_SummonInfo.ConfirmSummon() end)
	eq(#got, 1, "one refusal")
	eq(got[1] and got[1].ev, "ADDON_ACTION_FORBIDDEN", "forbidden")
	eq(got[1] and got[1].args[2], "UNKNOWN()", "the function is not named")
	ok(#w.violations == 1 and w.violations[1]:find("ConfirmSummon", 1, true), "the fake's violation still names it, for the test")
	T.clean(w, { violations = true })
end)

test("rec: real: C_TradeInfo.SetTradeMoney is refused as ADDON_ACTION_FORBIDDEN(addon, 'UNKNOWN()') (trade.forbidden.func)", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR)
	T.settle(w)
	local got = listen(T.TESTCHAR, function() r.env.C_TradeInfo.SetTradeMoney(100) end)
	eq(#got, 1, "one refusal")
	eq(got[1] and got[1].args[2], "UNKNOWN()", "the function is not named")
	T.clean(w, { violations = true })
end)

-- What Wuber does with an unnamed refusal of an action it tried through W.Try: the capability is remembered as
-- refused on this build (WuberDB.blockedBuild[build][cap], as the real saved variables showed for 70938) and the
-- chat says it in plain words, never "UNKNOWN()".
test("rec: real: Wuber remembers an unnamed refusal under the capability it tried and says it in plain words (trade.forbidden.func)", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR)
	T.settle(w)
	local W = r.W
	local okTry = W.Try("trade", function() r:fire("ADDON_ACTION_FORBIDDEN", "Wuber", "UNKNOWN()") end)
	eq(okTry, false, "the try failed")
	eq(W.IsBlocked("trade"), true, "trade is blocked on this build")
	eq(W.db.blockedBuild["71037"] and W.db.blockedBuild["71037"].trade, true, "saved under the build")
	local said = false
	for _, l in ipairs(r.chatLines or {}) do
		local t = type(l) == "table" and (l.text or l[1]) or l
		if tostring(t):find("UNKNOWN", 1, true) then error("the chat said UNKNOWN(): " .. tostring(t)) end
		if tostring(t):find("blocked one of Wuber's actions", 1, true) then said = true end
	end
	ok(said, "the plain-words line")
	T.clean(w)
end)
