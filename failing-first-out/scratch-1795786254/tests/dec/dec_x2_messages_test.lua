-- Decisions X2: the Messages editor with a switch card (the greeting's): Save and Reset stay on top of the
-- scrolling editor, and a refused save shows its red reason clear of Reset, Save and the switch card.
local T = ...
local test, ok, H = T.test, T.ok, T.H

local function editor(kind)
	local w = T.newWorld()
	local a = T.driver(w, T.ANITA, { spot = "Undercity" })
	w:advance(15)
	local W, DR = a.W, a.W.Drive
	DR.Sorted = function() return {} end
	DR.customers = {}
	DR.IsOpen = function() return true end
	W.UI.WindowWide(false)
	T.openDrive(a)
	if W.UI.ShowDrive then W.UI.ShowDrive("console") end
	w:advance(2)
	W.Driver.RefreshNow()
	W.Driver.ShowScreen("messages")
	w:advance(1)
	local s = W.UI.drive.screens.messages
	s.edit(kind)
	return w, a, s, s.editor
end

local function overlaps(a, b)
	return a.l < b.l + b.w - 0.5 and b.l < a.l + a.w - 0.5 and a.b < b.b + b.h - 0.5 and b.b < a.b + a.h - 0.5
end

for _, kind in ipairs({ "greet", "pay", "next" }) do
	test("dec x2: the " .. kind .. " editor's Save and Reset take the click, not the switch card scrolled under them", function()
		local w, a, s, e = editor(kind)
		ok(e.auto:IsShown(), "the switch card shows in this editor")
		e.field:SetText(string.rep("word ", 41))
		s.preview()
		for _, name in ipairs({ "save", "reset" }) do
			local b = e[name]
			local r = H.rect(b)
			-- every corner and the middle: the card's switch sits at the right
			for _, p in ipairs({ { 0.5, 0.5 }, { 0.04, 0.5 }, { 0.96, 0.5 }, { 0.9, 0.2 }, { 0.9, 0.8 } }) do
				local f = a:frameAt(r.l + r.w * p[1], r.b + r.h * p[2])
				local up = f
				while up and up ~= b do up = up:GetParent() end
				ok(up == b, name .. " is on top at " .. p[1] .. "," .. p[2] .. " (the switch card took it: " .. tostring(f == e.auto or f == e.auto.toggle) .. ")")
			end
		end
		T.clean(w)
	end)
end

test("dec x2: a refused save of the greeting shows its red reason clear of Reset, Save and the switch card", function()
	local w, a, s, e = editor("greet")
	e.field:SetText(string.rep("word ", 41)) -- 204 letters once trimmed, over the 190 a whisper may carry
	s.preview()
	ok(not e.why:IsShown(), "control: no red line before the save")
	a:clickOn(e.save)
	w:advance(0.5)
	ok(e.why:IsShown(), "the refusal text shows: " .. tostring(e.why:GetText()))
	ok(tostring(e.why:GetText()):find("Not saved: it is 204 letters long: whispers are 190 at most", 1, true), "the reason is whole: " .. tostring(e.why:GetText()))
	local rw, rs, rr, ra = H.rect(e.why), H.rect(e.save), H.rect(e.reset), H.rect(e.auto)
	ok(not overlaps(rw, rs) and not overlaps(rw, rr), "the red reason is clear of Reset and Save (why bottom " .. rw.b .. ", reset top " .. (rr.b + rr.h) .. ")")
	ok(not overlaps(rw, ra), "the red reason is clear of the switch card (why bottom " .. rw.b .. ", card top " .. (ra.b + ra.h) .. ")")
	ok(rw.b >= ra.b + ra.h - 0.5, "the reason sits above the card")
	ok(not overlaps(ra, rs) and not overlaps(ra, rr), "scrolled to its foot, the switch card is clear of Reset and Save (card bottom " .. ra.b .. ", reset top " .. (rr.b + rr.h) .. ")")
	T.clean(w)
end)
