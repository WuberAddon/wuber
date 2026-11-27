-- Decisions round, group N2: two faults the whole suite and the whole layout sweep found in group N's work.
-- 1. Help covers the whole window, and Settings hid its list's soft edges under it (they would draw over Help) but left
--    the rows drawn: a section taller than the list (Riding, since "What Wuber sends") sat cut by a hard edge there.
--    The rows under Help are not drawn either now, once Help has come in; they are back when it closes.
-- 2. A toast pushed beside the phone could land on the What's new card, which stands beside the phone too.
local T = ...
local H, test, eq, ok = T.H, T.test, T.eq, T.ok

local function open(where, wide)
	local w = T.newWorld()
	local c = T.driver(w, T.BOB)
	T.settle(w)
	c.W.db.coach = true
	if wide then c.wide = true else c.W.db.fold = { v = 1, pages = {}, narrow = true } end
	c.W.UI.Toggle(true)
	w:advance(3)
	c.W.UI.OpenSettings(where)
	w:advance(1)
	return w, c, c.W.UI.settings
end

test("dec n2: under Help the Settings rows are not drawn (no row cut by a hard edge there); they are back when Help closes", function()
	for _, wide in ipairs({ false, true }) do
		local how = wide and "unfolded" or "folded"
		local w, c, st = open("riding", wide)
		local UI = c.W.UI
		ok(H.visible(st.clip) and H.visible(st.sendingRow), "before: the Riding rows show (" .. how .. ")")
		UI.OpenHelp("settings")
		ok(H.visible(st.clip), "they stay while Help comes in (" .. how .. ")")
		w:advance(1)
		ok(UI.HelpShown(), "Help is up")
		ok(not H.visible(st.clip), "Help covers the window: the rows under it are not drawn (" .. how .. ")")
		UI.LayoutSettings()
		ok(not H.visible(st.clip), "a layout while Help is up does not bring them back (" .. how .. ")")
		UI.CloseHelp()
		ok(H.visible(st.clip) and H.visible(st.sendingRow), "Help closes: the rows are back at once (" .. how .. ")")
		w:advance(1)
		ok(H.visible(st.sendingRow), "and stay (" .. how .. ")")
		-- opened and closed at once: the rows never go
		UI.OpenHelp("settings")
		UI.CloseHelp(true)
		w:advance(1)
		ok(H.visible(st.clip), "Help opened and closed within a moment: the rows stay (" .. how .. ")")
		-- Settings opened again while Help is up closes Help: the rows show
		UI.OpenHelp("settings")
		w:advance(1)
		UI.OpenSettings("riding")
		w:advance(1)
		ok(not UI.HelpShown() and H.visible(st.sendingRow), "Settings asked for again: Help closed, the rows show (" .. how .. ")")
		eq(#w.errors, 0, "Lua errors (" .. table.concat(w.errors, "; ") .. ")")
		T.clean(w)
	end
end)

local function meet(a, b)
	local ra, rb = H.rect(a), H.rect(b)
	local wd = math.min(ra.l + ra.w, rb.l + rb.w) - math.max(ra.l, rb.l)
	local ht = math.min(ra.b + ra.h, rb.b + rb.h) - math.max(ra.b, rb.b)
	return wd > 0.5 and ht > 0.5, ("%d x %d"):format(wd, ht)
end

test("dec n2: a toast keeps clear of the What's new card (the Undo toast beside the phone, where the card stands too)", function()
	local w = T.newWorld()
	local c = T.rider(w, T.TESTCHAR)
	T.settle(w)
	local W = c.W
	local UI = W.UI
	W.db.coach = true
	UI.Toggle(true)
	w:advance(3)
	UI.OpenSettings("window")
	w:advance(1)
	local News = W.Mod("UI.WhatsNew")
	ok(News.Show(News.Longest()), "the What's new card is up")
	local card = News.Card()
	-- the card stands where the toast would go
	local tx, ty = UI.ToastPlace()
	card:ClearAllPoints()
	card:SetPoint("TOP", c.env.UIParent, "TOP", tx, ty)
	ok(H.visible(card), "the card shows there")
	local t = UI.UndoToast("12 settings reset.", function() end)
	ok(type(t) == "table" and t.undo and H.visible(t.undo), "the Undo toast is up")
	w:advance(1.5)
	local hit, by = meet(t, card)
	ok(not hit, "the toast is not on the card (they meet by " .. by .. ")")
	local phone = UI.state.phone or UI.state.win
	ok(not (meet(t, phone)), "nor on the phone")
	local sr = H.rect(c.env.UIParent)
	local r = H.rect(t)
	ok(r.l >= sr.l - 0.5 and r.l + r.w <= sr.l + sr.w + 0.5 and r.b >= sr.b - 0.5 and r.b + r.h <= sr.b + sr.h + 0.5, "and on the screen")
	-- the card closed: the toast goes back to its usual place
	News.Hide()
	w:advance(1)
	local x2, y2 = UI.ToastPlace()
	eq(x2, tx, "the card gone: the toast's usual place again (x)")
	eq(y2, ty, "(y)")
	eq(#w.errors, 0, "Lua errors (" .. table.concat(w.errors, "; ") .. ")")
	T.clean(w)
end)
