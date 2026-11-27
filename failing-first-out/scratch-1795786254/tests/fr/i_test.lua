-- Fix round 2.4, group i: the driver console's strip, Fix button, provider caption and invite pill.
-- Loaded by tests/run.lua with its helper table T.
local T = ...
local H, test, eq, ok = T.H, T.test, T.eq, T.ok

local function fits(W, fs)
	local room = fs:GetRight() - fs:GetLeft()
	local need = W.Theme.MeasureText(fs.wuberText or "", fs.wuberPx, fs.wuberWeight)
	return need <= room + 1, ("%q needs %.1f, has %.1f"):format(fs.wuberText or "", need, room)
end

local function strip(spot, today, wide, combat)
	local w = T.newWorld()
	local a = T.driver(w, T.ANITA, { spot = spot })
	w:advance(15)
	local W = a.W
	W.Drive.Shards = function() return 10 end
	W.Drive.Today = function() return 16, today end
	if W.Driver then W.Driver.Today = W.Drive.Today end
	if wide then a.wide = true W.db.coach = true W.UI.WindowWide(true) end
	if combat then w:enterCombat(a) end
	T.openDrive(a)
	W.UI.ShowDrive("console")
	w:advance(2)
	W.Driver.RefreshNow()
	w:advance(1)
	return w, W, W.Driver.ui.console
end

for _, c in ipairs({ { false, false }, { true, false }, { false, true }, { true, true } }) do
test("fr i HUNT-130: the fare line to Booty Bay fits with a day's take " .. tostring(c[1]) .. tostring(c[2]), function()
	local w, W, v = strip("Booty Bay", 46055, c[1], c[2])
	local fs = v.fare.text
	local f, msg = fits(W, fs)
	ok(not fs:IsTruncated(), "not cut: " .. msg)
	ok(f or fs.wuberWrapped, msg)
	T.clean(w)
end)
end

test("fr i HUNT-134: the Fix pill on the Ready to drive card fits \"Set up my crew\"", function()
	local w = T.newWorld()
	local a = T.driver(w, T.ANITA, { spot = "Undercity" })
	w:advance(15)
	local W = a.W
	T.openDrive(a)
	W.UI.ShowDrive("console")
	w:advance(2)
	W.Char().wizard = false
	W.db.advanced = false
	W.Driver.RefreshNow()
	w:advance(1)
	local v = W.Driver.ui.console
	local found
	for _, line in ipairs(v.ready and v.ready.lines or {}) do
		if line:IsShown() and line.fix:IsShown() and line.fix.fixData and line.fix.fixData.label == "Set up my crew" then found = line end
	end
	ok(found, "the Set up my crew line shows")
	ok(not found.fix.label:IsTruncated(), "label not cut")
	ok(not found.text:IsTruncated(), "words not cut")
	T.clean(w)
end)

test("fr i HUNT-140: the Driving with another addon line wraps, never cut", function()
	local w = T.newWorld()
	local a = T.driver(w, T.ANITA, { spot = "Undercity" })
	w:advance(15)
	local W = a.W
	W.provider = { name = "Other Rides" }
	T.openDrive(a)
	W.Driver.RefreshNow()
	w:advance(2)
	local v = W.Driver.ui.provider
	ok(v, "the provider screen exists")
	local sub = v.sub
	ok(sub:IsShown() and (sub:GetText() or ""):find("Other Rides answers your Wuber requests", 1, true), "its words: " .. tostring(sub:GetText()))
	ok(not sub:IsTruncated(), "the words are not cut")
	T.clean(w)
end)

-- ING-10: the Invite to Wuber pill never lies on the row's Options button, at any row width and height
local function rowSetup()
	local w = T.newWorld()
	local a = T.driver(w, T.ANITA, { spot = "Undercity" })
	w:advance(15)
	local W = a.W
	W.Drive.GetAppState = function() return "ok" end
	W.Drive.RideCount = function() return 1 end
	local parent = a.env.CreateFrame("Frame", nil, a.env.UIParent)
	parent:SetSize(500, 300)
	parent:SetPoint("CENTER")
	parent:Show()
	return w, W.Driver, parent
end

local function overlap(a, b)
	local x = math.min(a:GetRight(), b:GetRight()) - math.max(a:GetLeft(), b:GetLeft())
	local y = math.min(a:GetTop(), b:GetTop()) - math.max(a:GetBottom(), b:GetBottom())
	return x > 0.01 and y > 0.01, x, y
end

test("fr i ING-10: the Invite to Wuber pill never lies on the row's Options button (rows 44 and 52 high, widths 220 to 420, scale 1 and 1.15)", function()
	local w, D, parent = rowSetup()
	for _, scale in ipairs({ 1, 1.15 }) do
		for _, base in ipairs({ 44, 52 }) do
			for wdt = 220, 420, 4 do
				for _, again in ipairs({ true, false }) do
					local r = D.Row(parent, wdt)
					r:SetScale(scale)
					r:SetHeight(base)
					r:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
					D.PaintRow(r, { name = "Dan Rider", state = "joined", source = "whisper", at = 1000 }, 1000)
					if not again then r.again:Hide() D.LayRow(r) end
					if r.getapp and r.getapp:IsShown() then
						local hit, x, y = overlap(r.getapp, r.more)
						ok(not hit, ("pill over Options at width %d, height %d, scale %s, again %s (%.1f x %.1f)"):format(wdt, base, scale, tostring(again), x, y))
					end
					r:Hide()
				end
			end
		end
	end
	T.clean(w)
end)
