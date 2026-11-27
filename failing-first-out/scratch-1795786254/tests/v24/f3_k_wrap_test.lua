-- Wuber 2.4 fix round 3, group K (stage A of "wrap, then grow, then scroll, never ..."): the two hand cuts
-- ("Stranglethorn V..." on the route pill, a customer's note) wrap instead, and a label allowed two lines wraps
-- at full size before it shrinks. Loaded by tests/run.lua with its helper table T.
local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H

test("v24 f3k: a long place name on the route pill wraps onto a second line, whole, at full size", function()
	local w = T.newWorld()
	local r = T.rider(w)
	local W = r.W
	local h = W.Mod("UI.Rider.Booking").RouteHeader(r.env.UIParent, 324)
	h:SetPoint("TOPLEFT", r.env.UIParent, "TOPLEFT", 10, -10)
	local name = "The Stranglethorn Vale Rebel Camp Of The Long Name"
	h:Set(name, "Undercity", "zeppelin")
	w:advance(0.1)
	eq(h.fromShown, name, "the origin is whole, not cut with ...")
	eq(h.from.wuberText, name, "the label holds the whole name")
	ok(not tostring(h.from:GetText() or ""):find("...", 1, true), "no ... in what is drawn")
	ok(h.from.wuberWrapOn or h.from.wuberWrapped, "the label wraps")
	eq(h.from.wuberPx, 12, "at full size")
	ok(H.rect(h).w <= 324.5, "the pill stays inside its width: " .. H.rect(h).w)
	local r1, r2 = H.rect(h.from), H.rect(h)
	ok(r1.h <= r2.h + 0.5, "the two lines sit inside the pill: label " .. r1.h .. " pill " .. r2.h)
	T.clean(w)
end)

test("v24 f3k: a long customer note on the Customers list wraps, whole, and the row grows to hold it", function()
	local w = T.newWorld()
	local a = T.driver(w, T.ANITA, { spot = "Undercity" })
	w:advance(15)
	local W, DR = a.W, a.W.Drive
	DR.IsOpen = function() return true end
	T.openDrive(a)
	local note = "Tips well, always Orgrimmar. Asked about Pioneers and the raid on Thursday night"
	DR.Log().rides[1] = table.concat({ a.env.time() - 600, 5000, "Dan Rider", "Orgrimmar", "t", 5000 }, ",")
	DR.SetNote("Dan Rider", note)
	DR.Log().rides[2] = table.concat({ a.env.time() - 700, 5000, "Eve Night", "Orgrimmar", "t", 5000 }, ",")
	W.UI.ShowDrive("console")
	W.Driver.ShowScreen("customers")
	w:advance(1)
	local s = W.Driver.ui.subs.customers
	local long, short
	for i = 1, s.rowsShown or 0 do
		local row = s.pool.list[i]
		if row.e and row.e.name == "Dan Rider" then long = row else short = short or row end
	end
	ok(long and short, "both rows are there")
	local text = long.sub:GetText() or ""
	ok(text:find(note, 1, true), "the whole note is there: " .. text)
	ok(not text:find("...", 1, true), "never cut with ...")
	ok(long:GetHeight() > short:GetHeight(), "the row with the long note is taller: " .. long:GetHeight() .. " vs " .. short:GetHeight())
	for i = 1, (s.rowsShown or 0) - 1 do
		local cur, nxt = s.pool.list[i], s.pool.list[i + 1]
		eq(nxt.top - cur.top, cur:GetHeight() + 6, "row " .. (i + 1) .. " starts right below row " .. i)
	end
	T.clean(w)
end)

test("v24 f3k: a label allowed two lines wraps at full size before it shrinks; a one-line label still shrinks", function()
	local w = T.newWorld()
	local r = T.rider(w)
	local Th = r.W.Theme
	local function label(lines, width, text)
		local f = r.env.CreateFrame("Frame", nil, r.env.UIParent)
		f:SetSize(width, 40)
		local fs = Th.Text(f, 12, "white", "LEFT", "medium")
		fs:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
		fs:SetWidth(width)
		if lines then Th.Lines(fs, lines) end
		fs:SetText(text)
		return fs
	end
	local text = "Waiting for the driver to open the trade"
	local full = Th.MeasureText(text, 12, "medium")
	local width = math.floor(full * 0.6)
	ok(full > width and full < width * 1.8, "setup: too wide for one line, fits two (" .. full .. " in " .. width .. ")")
	local two = label(2, width, text)
	eq(two.wuberPx, 12, "a two-line label keeps its full size")
	ok(two.wuberWrapped, "and wraps")
	local one = label(nil, width, text)
	ok(one.wuberPx < 12, "a one-line label shrinks as before: " .. tostring(one.wuberPx))
	-- two lines would still not hold it at 12: shrinks, but only as far as two lines hold it (not to the size
	-- where one line would, which is the 80% floor here)
	local best
	for k = 55, 40, -1 do
		local fs = label(2, math.floor(full * k / 100), text)
		if fs.wuberPx < 12 and fs.wuberPx >= 10 and fs.wuberWrapped then best = fs end
	end
	ok(best, "two lines not enough at 12: it shrinks a notch or two, not to the floor")
	T.clean(w)
end)
