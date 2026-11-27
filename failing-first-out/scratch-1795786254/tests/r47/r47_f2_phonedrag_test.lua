local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H

local function setup()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, { spot = "Orgrimmar" })
	T.settle(w)
	r.W.db.coach = true
	H.state[r.env.UIParent].w, H.state[r.env.UIParent].h = 979, 768 -- a squarer game window (as tests/ui/chatclear_test.lua)
	r.physW, r.physH = 2662, 2089
	r.wide = true
	r:fire("DISPLAY_SIZE_CHANGED")
	local f = r.env.DEFAULT_CHAT_FRAME
	f:ClearAllPoints() f:SetPoint("BOTTOMLEFT", r.env.UIParent, "BOTTOMLEFT", 32, 95) f:SetSize(430, 120) f:Show()
	r.W.UI.Toggle(true) w:advance(3)
	return w, r
end

test("r47 f2: AUD-186 after the phone is dragged clear of the chat, the fold button still says it is kept narrow for the chat", function()
	local w, r = setup()
	local W = r.W
	w:advance(5)
	local fits, why = W.UI.Fold.Fits()
	eq(why, "chat", "control: at the default place the wide phone would cover the chat (Fits says chat)")
	eq(W.db.pos, nil, "control: no saved place yet")
	local btn = W.UI.state.phone.fold
	local before = btn:GetAlpha()
	-- the player drags the phone by its top bar to the right, clear of the chat
	local top = W.UI.state.phone.status
	r:drag(top, 400, 0)
	w:advance(1)
	ok(W.db.pos ~= nil, "control: the drag saved the player's own place")
	local fits2, why2 = W.UI.Fold.Fits()
	ok(fits2, "control: Fits is now true (a place the player chose is never moved): " .. tostring(why2))
		-- the player now sees a dimmed fold button that still claims the chat is in the way
	eq(W.UI.Fold.IsUnfolded(), true, "after the drag the phone unfolds, fold button alpha " .. tostring(btn:GetAlpha()))
	T.clean(w)
end)
