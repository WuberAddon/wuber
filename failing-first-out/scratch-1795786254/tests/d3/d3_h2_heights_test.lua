-- Design round 3, group H2: heights that follow the text. The Fly or summon dial grows by one line of its verdict's own
-- size and spacing, the Tips card and the coach bubble by one line of "sub" per extra line, and the Done headline
-- keeps clear of the pulse ring round the tick badge (shot done_paid).
local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H

local function world()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, { screenW = 1365, screenH = 768 })
	w:advance(15)
	return w, r
end

test("d3 h2: the dial's second verdict line adds the drawn size plus the line spacing", function()
	local w, r = world()
	local Th = r.W.Theme
	local dial = r.W.Mod("UI.Rider.Booking").Dial(r.env.UIParent, 324, 88)
	dial:SetPoint("CENTER", r.env.UIParent, "CENTER")
	dial.verdict:SetText("This is a long verdict that cannot possibly fit on one line of the dial, so it must go on a second line")
	dial:SetSize(324, 88)
	ok(dial.verdict.wuberWrapped == true, "control: the verdict wrapped")
	local px = dial.verdict.wuberPx
	ok((dial.extra or 0) >= Th.DrawnSize(px) + Th.Spacing(px), "the dial grew by a line: " .. tostring(dial.extra))
	ok(dial:GetHeight() >= 88 + Th.DrawnSize(px) + Th.Spacing(px), "and its height holds it: " .. dial:GetHeight())
	T.clean(w)
end)

test("d3 h2: the Tips card grows by one line of text for each extra line (1, 2 and 3+ lines)", function()
	local w, r = world()
	local Th = r.W.Theme
	local TM = r.W.Mod("UI.Tips")
	local c = TM.Card()
	local words = "Wuber only says what to type and the trade needs your own steps. "
	local first
	for rep = 1, 4 do
		c.text:SetText(string.rep(words, rep * 2))
		local _, ht = TM.Layout(c)
		local n = Th.ParaLines(c.text:GetText(), "sub", "regular", r.W.Mod("UI.Kit").WIN_W - 32)
		first = first or { n = n, h = ht }
		eq(ht - first.h, (n - first.n) * (Th.DrawnSize("sub") + Th.Spacing("sub")), "each extra line adds a line of sub plus its spacing (" .. n .. " lines)")
	end
	T.clean(w)
end)

test("d3 h2: done: the headline starts clear of the pulse ring round the badge, and its row holds two lines", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, { screenW = 1365, screenH = 768 })
	w:advance(15)
	local ride = { id = "d3h2", driver = "Mia Runner", driverKey = "mia runner", dest = "Undercity", price = 5000, state = "done",
		at = r.env.GetTime(), payee = "Mia Runner", payto = "Mia", service = "Mia's Rides", paid = 6000 }
	r.W.ride = ride
	r.W.Fire("RIDE")
	r.W.UI.Toggle(true)
	w:advance(2)
	r.W.UI.Show("done")
	w:advance(3)
	local s = r.W.UI.state.screens.done
	local Th = r.W.Theme
	local b, t = H.rect(s.badge), H.rect(s.title)
	ok(t.l - (b.l + b.w) >= (70 - 32) / 2 + 4, "the words start " .. (t.l - (b.l + b.w)) .. " from the badge: the ring reaches 19 past it")
	local need = 2 * Th.DrawnSize("heading") + Th.Spacing("heading")
	ok(s.title:GetNumLines() < 2 or s.top:GetHeight() >= need, "two lines fit the row: " .. s.top:GetHeight() .. " vs " .. need)
	T.clean(w)
end)
