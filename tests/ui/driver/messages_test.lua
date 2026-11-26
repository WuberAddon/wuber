-- Tests of UI.Driver.Messages (round 13, A). Loaded by tests/run.lua with its helper table T.
--   I6: in the editor every placeholder chip is as wide as its word: none reads '{pric...' or
--   '{guil...' (7 of 13 did in Google's shots), folded and unfolded, and none is shrunk to fit.
local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H

test("ui.driver.messages r13 I6: every placeholder chip is sized to its word, folded and unfolded", function()
	local w = T.newWorld()
	local d = T.driver(w, T.BOB)
	T.settle(w)
	local W = d.W
	local UI = W.UI
	W.db.coach = true
	W.Char().wizard = true
	UI.Toggle(true)
	w:advance(3)
	UI.SelectTab("Drive")
	w:advance(1)
	W.Drive.SetMode("sell")
	w:advance(1)
	local bad, looked = {}, 0
	for _, wide in ipairs({ false, true }) do
		d.wide = wide
		W.db.fold = (not wide) and { v = 1, pages = {}, narrow = true } or nil
		UI.Fold.Apply()
		w:advance(1)
		W.Driver.ShowScreen("messages")
		w:advance(1)
		local D = W.Driver
		local s = (D.ui.subs and D.ui.subs.messages) or UI.drive.screens.messages
		ok(s and s.edit, "the Messages screen")
		s.edit("greet")
		w:advance(1)
		local e = s.editor
		ok(e and H.visible(e), (wide and "unfolded" or "folded") .. ": the editor shows")
		for _, b in ipairs(e.chips) do
			if H.visible(b) then
				looked = looked + 1
				local lab = b.label
				local text = lab:GetText()
				local need = W.Theme.MeasureText(text, lab.wuberBase or 11, lab.wuberWeight)
				if H.truncation(lab) then bad[#bad + 1] = text .. " is cut short" end
				-- the game's own width for a Wuber font can run past our measure (a font loads late): a
				-- chip's word is never held to a width that only just fits
				local room = H.textRoom(lab)
				if room and room < need * 1.08 then bad[#bad + 1] = ("%s: held to %d px, its word needs %d (no spare)"):format(text, room, need) end
				if lab.wuberPx ~= lab.wuberBase then bad[#bad + 1] = text .. " is shrunk to fit (" .. tostring(lab.wuberPx) .. " px)" end
				if b:GetWidth() < need + 16 then bad[#bad + 1] = ("%s: the chip is %d wide, its word needs %d and some room"):format(text, b:GetWidth(), need) end
				local br, er = H.rect(b), H.rect(e)
				if br.l + br.w > er.l + er.w + 0.5 then bad[#bad + 1] = text .. " runs off the editor" end
			end
		end
	end
	ok(looked >= 20, "chips looked at (" .. looked .. ")")
	eq(#bad, 0, "chips:\n  " .. table.concat(bad, "\n  "))
	eq(#w.errors, 0, "Lua errors (" .. table.concat(w.errors, "; ") .. ")")
	T.clean(w)
end)

test("ui.driver.messages 2.3.2 S5: the tip preview is never below the fare; Greeting reads the same in the list and the editor", function()
	local w = T.newWorld()
	local d = T.driver(w, T.BOB)
	T.settle(w)
	local W = d.W
	local UI = W.UI
	W.db.coach = true
	W.Char().wizard = true
	UI.Toggle(true)
	w:advance(3)
	UI.SelectTab("Drive")
	w:advance(1)
	W.Drive.SetMode("sell")
	w:advance(1)
	W.Driver.ShowScreen("messages")
	w:advance(1)
	local s = (W.Driver.ui.subs and W.Driver.ui.subs.messages) or UI.drive.screens.messages
	ok(s and s.rows, "the Messages screen")
	local price = (W.Driver.kit.Price and W.Driver.kit.Price()) or W.MIN_PRICE
	-- (2.4, the word rule) a list card shows its title and when only; the words it sends are in its tooltip
	local gt = d.env.GameTooltip
	local function row(kind)
		for _, r in ipairs(s.rows) do
			if r.kind == kind then
				H.state[r].scripts.OnEnter(r)
				local all = table.concat(H.state[gt].tipLines or {}, "\n")
				H.state[r].scripts.OnLeave(r)
				return (all:match("Click to change it%.%s*(.*)$") or "")
			end
		end
	end
	local function say(kind, paid)
		return W.Drive.Text(kind, { name = "Dan Rider", key = "dan rider", price = price, paid = paid, state = "arrived" })
	end
	s.list()
	w:advance(1)
	eq(row("thanks"), say("thanks", price), "Thanks says the fare")
	eq(row("tip"), say("tip", math.floor(price * 1.2)), "the tip says more than the fare")
	eq(row("short"), say("short", math.floor(price * 0.6)), "Paid too little says less")
	local listed = row("greet")
	s.edit("greet")
	w:advance(1)
	eq(s.editor.prev.wuberText or s.editor.prev:GetText(), listed, "Greeting: the editor reads as the list")
	eq(#w.errors, 0, "Lua errors (" .. table.concat(w.errors, "; ") .. ")")
	T.clean(w)
end)

-- (BRIEF20 B6, design round 4) a chip's tip never covers the "118 / 190" counter above the row; since Wuber's own tip
-- card (design 4, I2) the chip asks for no side and the card's own order applies (beside the chip, never over it)
test("ui.driver.messages BRIEF20 B6: a placeholder chip's tooltip never covers the counter or the chip", function()
	local w = T.newWorld()
	local d = T.driver(w, T.BOB)
	T.settle(w)
	local W = d.W
	local UI = W.UI
	W.db.coach = true
	W.Char().wizard = true
	UI.Toggle(true)
	w:advance(3)
	UI.SelectTab("Drive")
	w:advance(1)
	W.Drive.SetMode("sell")
	w:advance(1)
	W.Driver.ShowScreen("messages")
	w:advance(1)
	local sc = (W.Driver.ui.subs and W.Driver.ui.subs.messages) or UI.drive.screens.messages
	sc.edit("greet")
	w:advance(1)
	local e = sc.editor
	local S = H.state
	local chip
	for _, b in ipairs(e.chips) do if b.code == "{price}" then chip = b end end
	ok(chip, "the {price} chip exists")
	S[chip].scripts.OnEnter(chip)
	local card = d.env.WuberTip
	ok(card and card:IsShown() and W.Theme.TipOwner() == chip, "its tip card shows")
	eq(chip.wuberTip.anchor, nil, "the chip asks for no side")
	local m = e.meter
	ok(card:GetTop() <= m:GetBottom() or card:GetBottom() >= m:GetTop() or card:GetRight() <= m:GetLeft() or card:GetLeft() >= m:GetRight(), "the card is clear of the counter")
	ok(card:GetBottom() >= chip:GetTop() or card:GetTop() <= chip:GetBottom() or card:GetLeft() >= chip:GetRight() or card:GetRight() <= chip:GetLeft(), "and of the chip")
	S[chip].scripts.OnLeave(chip)
	eq(#w.errors, 0, "Lua errors (" .. table.concat(w.errors, "; ") .. ")")
	T.clean(w)
end)

-- (BRIEF22 L2) the texts of a page the view's bottom edge slices at the top of the page (what the layout
-- checker calls "clipped": partly in, partly out)
local function slicedAtBottom(sc, content)
	local out, bottom = {}, sc:GetBottom()
	local function walk(f)
		for _, r in ipairs({ f:GetRegions() }) do
			local tx = r:GetObjectType() == "FontString" and r:IsVisible() and r:GetText()
			if type(tx) == "string" and tx:match("%S") then
				local t, b = r:GetTop(), r:GetBottom()
				if t and b and t > bottom + 0.5 and b < bottom - 0.5 then out[#out + 1] = ("%q (%.0f below the edge)"):format(tx:sub(1, 24), bottom - b) end
			end
		end
		for _, ch in ipairs({ f:GetChildren() }) do if ch:IsVisible() then walk(ch) end end
	end
	walk(content)
	return out
end

test("ui.driver.messages BRIEF22 L2: narrow Messages, no card's text is sliced by the bottom edge at the top of the list", function()
	local w = T.newWorld()
	local d = T.driver(w, T.BOB)
	T.settle(w)
	local W = d.W
	local UI = W.UI
	W.db.coach = true
	W.Char().wizard = true
	UI.Toggle(true)
	w:advance(3)
	UI.SelectTab("Drive")
	w:advance(1)
	W.Drive.SetMode("sell")
	w:advance(1)
	d.wide = false
	W.db.fold = { v = 1, pages = {}, narrow = true }
	UI.Fold.Apply()
	w:advance(1)
	W.Driver.ShowScreen("messages")
	w:advance(1)
	local s = UI.drive.screens.messages
	local sc = s.scroll
	-- the phone at several heights (the view's height decides which card the edge would cut)
	for _, cut in ipairs({ 0, 30, 60, 90, 130 }) do
		s.frame:ClearAllPoints()
		s.frame:SetPoint("TOPLEFT", s.frame:GetParent(), "TOPLEFT", 0, 0)
		s.frame:SetPoint("BOTTOMRIGHT", s.frame:GetParent(), "BOTTOMRIGHT", 0, cut)
		s.list()
		w:advance(0.5)
		sc:ScrollTo(0, true)
		local bad = slicedAtBottom(sc, s.content)
		ok(#bad == 0, "phone " .. cut .. " shorter: nothing sliced at the bottom: " .. table.concat(bad, ", "))
		ok((sc.max or 0) > 0, "phone " .. cut .. " shorter: the list still scrolls to the rest")
		ok(sc:GetHeight() >= s.frame:GetHeight() - 56 - 70, "phone " .. cut .. " shorter: the view gives up at most a card's height")
	end
	-- the editor (folded): the whole page again
	s.frame:SetAllPoints(s.frame:GetParent())
	s.edit("greet")
	w:advance(0.5)
	-- (Design 2) the editor keeps the room for its main button (Save) and the Reset link under the view: 12 + 46 + 6 + 34 + 6
	eq(math.floor(sc:GetBottom() + 0.5), math.floor(s.frame:GetBottom() + 6 + 104 + 0.5), "the editor: the view goes down to the room above Save and Reset")
	T.clean(w)
end)

test("ui.driver.messages E1-16: Drive console and its Business rows stay hidden while Messages is open across refreshes", function()
	local w = T.newWorld()
	local d = T.driver(w, T.BOB)
	T.settle(w)
	local W = d.W
	local UI = W.UI
	W.db.coach = true
	W.Char().wizard = true
	UI.Toggle(true)
	w:advance(3)
	UI.SelectTab("Drive")
	w:advance(1)
	W.Drive.SetMode("sell")
	w:advance(1)
	ok(W.Driver.ui.console:IsVisible(), "console is visible before pushing Messages")
	W.Driver.ShowScreen("messages")
	w:advance(1.5)
	W.Driver.RefreshNow()
	local s = UI.drive.screens.messages
	ok(s and s.frame:IsVisible(), "Messages screen is visible")
	ok(not W.Driver.ui.console:IsShown(), "console stays hidden while Messages is open after refresh")
	for i, link in ipairs(W.Driver.ui.console.links or {}) do
		ok(not link:IsVisible(), "console Business row " .. i .. " is not visible under Messages")
	end
	W.Driver.ShowScreen("console")
	w:advance(1)
	ok(W.Driver.ui.console:IsVisible(), "console is visible again after returning from Messages")
	ok(not s.frame:IsShown(), "Messages screen is hidden after returning to console")
	T.clean(w)
end)
