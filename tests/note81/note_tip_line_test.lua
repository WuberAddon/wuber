-- #81: the Note sheet shows the whole tip line (two lines), clear of the note box under it.
local T = ...
local test, eq, ok = T.test, T.eq, T.ok

local function sheet(adv)
	local w = T.newWorld()
	local a = T.driver(w, T.ANITA, { spot = "Orgrimmar" })
	w:advance(15)
	local W = a.W
	local DR, D = W.Drive, W.Driver
	W.SetAdvanced(adv)
	local now = (type(GetServerTime) == "function" and GetServerTime()) or os.time()
	local rides = W.db.drive.log.rides
	-- two paid rides on different days, both tipped: the longest tip line
	rides[#rides + 1] = (now - 3 * 86400) .. ",60000,Zed Return,Orgrimmar,t,50000"
	rides[#rides + 1] = (now - 86400) .. ",55000,Zed Return,Orgrimmar,t,50000"
	w:advance(1)
	T.openDrive(a)
	D.ShowSheet("note", { name = "Zed Return" })
	w:advance(1)
	return w, a, D.ui.sheets.note
end

test("note tip line #81: the Note sheet's tip line is shown whole and ends above the note box", function()
	local w, a, s = sheet(true)
	local f = s.facts
	local full = a.W.Driver.CustomerFacts("Zed Return")
	ok(full:find("tipped in all", 1, true), "control: a real tip line: " .. full)
	eq(f:GetText(), full, "the label holds the whole line")
	-- the whole line at full size: it wraps (the fake game's own measure of a wrapped label, as the other pages' tests use)
	ok(f.wuberWrapped == true, "the line wraps instead of being cut or shrunk (width " .. f:GetStringWidth() .. " in " .. f:GetWidth() .. " px)")
	eq(f.wuberPx, 11, "at full size")
	local _, _, _, _, fieldY = s.field:GetPoint(1)
	local _, _, _, _, factsY = f:GetPoint(1)
	ok(-fieldY >= -factsY + 2 * 13.2 - 0.5, "the note box starts below two lines of the tip line: field " .. fieldY .. ", label " .. factsY)
	T.clean(w)
end)

-- guard: the Customers right pane (unfolded) already gives its tip line two lines
test("note tip line #81: guard: the sheet's other labels keep their place order (privacy under the note, Serve under the privacy)", function()
	local w, a, s = sheet(true)
	local _, _, _, _, fy = s.field:GetPoint(1)
	local _, _, _, _, py = s.privacy:GetPoint(1)
	local _, _, _, _, sy = s.serve:GetPoint(1)
	ok(-py >= -fy + s.field:GetHeight() - 0.5, "privacy line is under the note box")
	ok(-sy > -py, "Serve pill is under the privacy line")
	T.clean(w)
end)
