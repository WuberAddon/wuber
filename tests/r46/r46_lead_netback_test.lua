local T = ...
local SI = "s" -- (design 1 H: money is letters, "23s", no coin icons)
local function G(s) return "|cfff9c53e" .. s .. "|r" end -- (design 1 P) an amount beside a time is gold letters
local test, eq, ok, H = T.test, T.eq, T.ok, T.H

-- Round 46 lead (found in the transcript review of HUNT-39): once the summon side of the Fly or summon dial
-- may wrap, a side that wrapped for one driver was measured at its full size for the next, so "(net 27s)"
-- stepped aside for a busy driver although it fits there once shrunk. The side goes back to one line
-- before its new words.
test("r46 lead: the unfolded dial keeps (net 27s) for a busy driver after a ready driver's summon side wrapped", function()
	local w = T.newWorld()
	local r = T.rider(w)
	local W = r.W
	local Mod = W.Mod("UI.Rider.Booking")
	W.TravelSaved = function() return 540 end
	W.FlightCost = function() return 2300, 1 end
	local dial = Mod.Dial(r.env.UIParent, 324, 88)
	dial:SetPoint("CENTER", r.env.UIParent, "CENTER")
	dial:SetSize(324, 120)
	local busy, ready = { dest = "Undercity", price = 5000, queue = 3 }, { dest = "Undercity", price = 5000, queue = 0 }
	dial:Set(Mod.DialInfo(busy, 5000))
	eq(dial.summonText.wuberText, G("50" .. SI) .. " (net " .. G("27" .. SI) .. ")", "a busy driver on a fresh dial: the net shows")
	dial:Set(Mod.DialInfo(ready, 5000))
	eq(dial.summonText.wuberText, "30 sec · costing " .. G("50" .. SI), "a ready driver: the wait, no net")
	ok(not H.truncation(dial.summonText), "ready: not cut")
	dial:Set(Mod.DialInfo(busy, 5000))
	eq(dial.summonText.wuberText, G("50" .. SI) .. " (net " .. G("27" .. SI) .. ")", "the busy driver again: the net is back")
	ok(not H.truncation(dial.summonText), "busy again: not cut")
	T.clean(w)
end)
