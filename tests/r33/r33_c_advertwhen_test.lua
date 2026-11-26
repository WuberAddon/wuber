-- Round 33 c, HUNT-113: the grey line over the Messages editor ("Sent in public chat when you click Advertise.
-- Wuber adds [Wuber] in front.") is never cut, folded or unfolded, and nothing below it is covered by it.
local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H

test("r33 c HUNT-113: the Messages editor's explaining line is whole for every kind, folded and unfolded", function()
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
		for _, kind in ipairs({ "greet", "price", "pay", "thanks", "tip", "short", "busy", "advert", "where", "getapp" }) do
			if s.edit then
				s.edit(kind)
				w:advance(1)
				local e = s.editor
				local tag = (wide and "unfolded " or "folded ") .. kind
				looked = looked + 1
				local when = e.when
				local text = when:GetText() or ""
				if H.truncation(when) then bad[#bad + 1] = tag .. ": the line is cut: " .. text end
				local wb, ft = when:GetBottom(), e.field:GetTop()
				if wb and ft and wb < ft - 0.5 then bad[#bad + 1] = tag .. ": the line runs into the box" end
				local wl, wrr, el, er = when:GetLeft(), when:GetRight(), e:GetLeft(), e:GetRight()
				if wrr and er and wrr > er + 0.5 then bad[#bad + 1] = tag .. ": the line runs off the editor" end
			end
		end
	end
	ok(looked >= 20, "editors looked at (" .. looked .. ")")
	eq(#bad, 0, "lines:\n  " .. table.concat(bad, "\n  "))
	eq(#w.errors, 0, "Lua errors (" .. table.concat(w.errors, "; ") .. ")")
	T.clean(w)
end)
