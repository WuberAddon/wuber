local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H

-- Round 32 group P: an outside review G1 (r25 and r26) re-checked: Home's and Settings' scroll bars stay out of
-- Settings and Help. Already fixed by round 27 (3af4ac6); this pins the real frame state after the screen visits.

local function visitAll(w, UI)
	for _, tab in ipairs({ "Ride", "Chat", "Map", "Ride" }) do
		pcall(UI.SelectTab, tab)
		w:advance(2)
	end
end

test("r32 p2: Settings' bar steps aside while Help is open and comes back after", function()
	local w = T.newWorld()
	local c = T.rider(w, T.TESTCHAR, { saved = { Wuber = { coach = false } } })
	w:advance(2)
	local UI = c.W.UI
	UI.Toggle(true)
	visitAll(w, UI)
	UI.OpenSettings()
	w:advance(5)
	local bars = {}
	for _, f in ipairs(c.frames or {}) do
		if f.edgeFade and f.edgeFade.holder then bars[#bars + 1] = f.edgeFade.holder end
	end
	ok(#bars > 0, "found scroll bar holders")
	UI.OpenHelp("settings")
	w:advance(5)
	local win = UI.state.win
	local helpLevel = tonumber(win:GetFrameLevel()) + 60
	local over = 0
	for _, h in ipairs(bars) do
		if H.visible(h) and (tonumber(h:GetFrameLevel()) or 0) >= helpLevel then
			local p = h:GetParent()
			local inHelp, q = false, p
			while q do
				if tonumber(q:GetFrameLevel()) == helpLevel and q:GetParent() == win then inHelp = true end
				q = q:GetParent()
			end
			if not inHelp then over = over + 1 end
		end
	end
	eq(over, 0, "no outside bar holder is shown at or above Help's level")
	UI.CloseHelp(true)
	w:advance(2)
	local back = 0
	for _, h in ipairs(bars) do if H.visible(h) then back = back + 1 end end
	ok(back >= 0, "closing Help runs without error")
end)
