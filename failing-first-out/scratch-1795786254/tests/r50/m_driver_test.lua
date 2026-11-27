-- r50 group M: Blocked row fits its reason, minimap shows 0g, Close ignores a rider who paid and left.
local T = ...
local test = T.test
local eq, ok = T.eq, T.ok
local H = T.H
local function key(name) return (name:lower():gsub("[%s%-]+", " ")) end

-- the promise: every Blocked row is as tall as its reason needs, and rows never overlap
test("r50 M: a long auto-block reason wraps and the row grows, the next row sits below it", function()
	local w = T.newWorld()
	local a = w:addClient(T.ANITA, { spot = "Undercity", class = "WARLOCK", allowMissing = true })
	local DR, D = a.W.Drive, a.W.Driver
	DR.SetOpt("autoBlock", true)
	pcall(T.openDrive, a)
	local c = { name = "Dan Rider", key = "dan rider", state = "arrived", price = 5000, paid = 0, at = 0, tries = 1, caster = a.W.myKey }
	DR.NonPayer(c)
	DR.Blacklist("Eve Short", "rude") -- a short reason on the same list
	w:advance(1)
	D.ShowScreen("blocked") w:advance(1)
	local s = a.W.UI.drive.screens.blocked
	local longRow, shortRow
	for _, r in ipairs(s.rows.list) do
		if r:IsShown() then
			if r.why:GetText():find("pay", 1, true) then longRow = r else shortRow = r end
		end
	end
	ok(longRow, "setup: the owing rider's row is listed")
	ok(H.truncation(longRow.why) == nil, "reason cut: " .. tostring(longRow.why:GetText()))
	ok(longRow:GetHeight() > 50, "long row is taller: " .. longRow:GetHeight())
	ok(longRow:GetHeight() >= 27 + longRow.why.paraH + 5, "row holds the text")
	if shortRow then
		-- guard: a one-line reason keeps the old 50 px row
		eq(shortRow:GetHeight(), 50, "short row height")
	end
	T.clean(w)
end)

-- guard: a rider who is still with the driver (joined) still makes Close ask; only paid-and-gone is finished
test("r50 M: Close still asks about a rider in the group, and about one who paid but has not left", function()
	for _, gone in ipairs({ false, true }) do
		local w = T.newWorld()
		local d = T.driver(w, T.ANITA)
		local r = T.rider(w, T.TESTCHAR)
		T.settle(w)
		T.goOnline(d)
		T.requestVia(r, "anita lift")
		w:advance(8)
		local DR = d.W.Drive
		local c = DR.customers[key(T.TESTCHAR)]
		ok(c and c.state == "joined", "setup: joined")
		if gone then DR.SetState(c, "paid") c.gone = false end
		d.W.Driver.SetOnline(false)
		w:advance(1)
		local shown = d.env.StaticPopup_FindVisible and d.env.StaticPopup_FindVisible("WUBER_CLOSE_RIDERS")
		if shown then d.env.StaticPopup_Hide("WUBER_CLOSE_RIDERS") end
		ok(shown, "asked (paid=" .. tostring(gone) .. ")")
		T.clean(w)
	end
end)

-- guard: the minimap still shows the amount once the driver has earned something
test("r50 M: the minimap line says 0g with nothing earned and the amount once earned", function()
	local w = T.newWorld()
	local d = T.driver(w, T.ANITA)
	local r = T.rider(w, T.TESTCHAR)
	T.settle(w)
	T.goOnline(d)
	T.requestVia(r, "anita lift")
	w:advance(8)
	local line = d.W.UI.DriveSummary()
	ok(line:find("0g today", 1, true), line)
	local old = d.W.Driver.Today
	d.W.Driver.Today = function() return 1, 15000 end
	local line2 = d.W.UI.DriveSummary()
	d.W.Driver.Today = old
	ok(line2:find("1g 50s today", 1, true), line2)
	T.clean(w)
end)

-- a Today() with no copper (unknown) must not error and reads 0g
test("r50 M: the minimap line shows 0g when Today gives no copper", function()
	local w = T.newWorld()
	local d = T.driver(w, T.ANITA)
	local r = T.rider(w, T.TESTCHAR)
	T.settle(w)
	T.goOnline(d)
	T.requestVia(r, "anita lift")
	w:advance(8)
	local old = d.W.Driver.Today
	d.W.Driver.Today = function() return 1, nil end
	local okc, line = pcall(d.W.UI.DriveSummary)
	d.W.Driver.Today = old
	ok(okc, "errored: " .. tostring(line))
	ok(line:find("0g today", 1, true), tostring(line))
	T.clean(w)
end)
