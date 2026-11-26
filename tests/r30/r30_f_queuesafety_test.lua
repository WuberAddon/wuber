local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H
local function key(name) return (name:lower():gsub("[%s%-]+", " ")) end

-- top edge (pixels below the screen's top) of a frame placed with one TOPLEFT/TOP point
local function topOf(fr)
	local _, _, _, _, y = fr:GetPoint(1)
	return -(y or 0)
end

test("r30 F HUNT-05: the queue line and the PvP warning card are one under the other, not on top of each other", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, {})
	w:advance(15)
	local ANA = "Ana Smith"
	r.W.ride = { id = "r30f", driver = ANA, driverKey = key(ANA), dest = "Ratchet", price = 5000, state = "accepted",
		at = r.env.GetTime(), position = 2, eta = 50, ritual = { danger = 3 } }
	r.W.Fire("RIDE")
	r.W.UI.Toggle(true)
	w:advance(3)
	local s = r.W.UI.state.screens.found
	ok(H.visible(s.queue) and #r:findText("in line") > 0, "control: the queue line shows")
	ok(H.visible(s.alert) and #r:findText("enemy players") > 0, "control: the PvP warning card shows")
	local qt, at = topOf(s.queue), topOf(s.alert)
	ok(at >= qt + 36, "the card starts at " .. at .. " but the queue line (36 high) starts at " .. qt .. ": they overlap")
	ok(at + 72 <= 600 - 56 - 20, "the card still fits in the window, bottom at " .. (at + 72))
	T.clean(w)
end)
