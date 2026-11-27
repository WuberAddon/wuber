local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H

-- (design 3) a Fly or summon card whose verdict is two lines at the body size (14): a priced flight that costs less than
-- the fare, the longest of the verdicts. (The old zeppelin sentence is one line at 14 now; the old setup counted on the
-- unfolded card drawing it a notch bigger, 13 against 15, and that notch is gone.)
local function info()
	return { dest = "Undercity", flySecs = 1500, flyAbout = true, flightCost = 12345, fare = 1234567,
		wait = 30, waitKnown = true, timeSaved = 1470 }
end

test("r47 h: unfolding the Fly or summon card makes room for a two-line verdict (AUD-155)", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, { spot = "Orgrimmar" })
	T.settle(w)
	local B = r.W.Mod("UI.Rider.Booking")
	local Tk = r.W.Theme
	local function dial(h)
		local d = B.Dial(r.env.UIParent, 324, h)
		d:SetPoint("CENTER", r.env.UIParent, "CENTER", 0, 0)
		d:SetSize(324, h)
		return d
	end
	-- Control: the card built at the unfolded size knows the verdict needs two lines
	local wide = dial(96)
	wide:Set(info())
	wide.line:SetText("about 1 min back")
	wide.line:Show()
	local text = wide.verdict.wuberText
	ok(Tk.MeasureText(text, 14, "bold") > 308 and Tk.MeasureText(text, 11, "bold") <= 308 * 2, "setup: '" .. text .. "' is wider than one line at 14 px")
	ok((wide.extra or 0) > 0, "control: a card opened unfolded counts the second verdict line (extra " .. tostring(wide.extra) .. ")")
	eq(wide.verdict.wuberPx, 14, "the verdict keeps the body size and wraps")
	-- The real path (Confirm.lua:469 then :749): Set folded at 88, then SetSize(INNER, 96)
	local d = dial(88)
	d:Set(info())
	d.line:SetText("about 1 min back")
	d.line:Show()
	ok((d.extra or 0) > 0, "folded: the second line is counted too (extra " .. tostring(d.extra) .. ")")
	d:SetSize(324, 96)
	eq(d.verdict.wuberPx, 14, "unfolded: the verdict is still the body size")
	ok(d.verdict.wuberWrapped == true, "unfolded: the verdict wraps")
	eq(d.extra, wide.extra, "the same room as a card opened unfolded")
	-- the second line ends above the small line (the verdict is centred, so its box is as tall as its lines)
	local vb, lt = H.rect(d.verdict), H.rect(d.line)
	ok(vb and lt and vb.b + 0.5 >= lt.b + lt.h, "the verdict's lines end above the small line (verdict bottom " .. tostring(vb and vb.b) .. ", line top " .. tostring(lt and lt.b + lt.h) .. ")")
	-- folding again keeps the room: the words are the same two lines
	d:SetSize(324, 88)
	eq(d.extra, wide.extra, "folded again: still two lines")
	T.clean(w)
end)
