-- Wuber 2.2.1 round seven: the driver screens rebuilt to the author's picks (ref/google/round2:
-- "06 v2" console hero, "08 v3" earnings). Loaded by run.lua with the round-six helpers.
-- Test names start "r7 driver:". The look itself is checked in tools/preview7_driver.png
-- (tools/preview/scene7_driver.lua + sheet7_driver.py); these pin what the look rests on.

local T = ...
local H, test, eq, ok = T.H, T.test, T.eq, T.ok
local newWorld, clean = T.newWorld, T.clean
local S = H.state

local DAN, EVE = "Dan Rider", "Eve Night"

-- a driver with the console open, two riders and the big button about to summon Dan
local function console(planColour)
	local w = newWorld()
	local a = T.driver(w, T.ANITA, { spot = "Undercity" })
	w:advance(15)
	local W, DR = a.W, a.W.Drive
	local t0 = a.env.GetTime()
	local cs = {
		{ name = DAN, key = "dan rider", state = "joined", at = t0 - 40, source = "wuber" },
		{ name = EVE, key = "eve night", state = "arrived", at = t0 - 90, price = 5000, paid = 0 },
	}
	DR.Sorted = function() return cs end
	DR.customers = { ["dan rider"] = cs[1], ["eve night"] = cs[2] }
	DR.IsOpen = function() return planColour ~= "off" end
	DR.Active = function() return true end
	DR.SkipTarget = function() return planColour ~= "off" and cs[1] or nil, "cast" end
	DR.Plan = function()
		if planColour == "off" then return { marks = {}, color = "off", title = "Closed", sub = "tap Open to take riders" } end
		return { type = "macro", macrotext = "/target Dan Rider\n/cast Ritual of Summoning", marks = {}, color = "go",
			title = "Summon Dan", sub = "click: targets and casts" }
	end
	T.openDrive(a)
	if W.UI and W.UI.ShowDrive then W.UI.ShowDrive("console") end
	w:advance(2)
	if W.Driver.RefreshNow then W.Driver.RefreshNow() end
	if DR.Button and DR.Button.Refresh then DR.Button.Refresh() end
	w:advance(1)
	return w, a, W, DR
end

local function hasGradient(slice)
	for _, t in pairs(slice.parts) do
		local g = S[t].gradient
		if not (g and g[1]) then return false end
	end
	return true
end

test("r7 driver: the hero card is a filled violet card (gradient 9-slices), lit for a click", function()
	local w, a, W = console("go")
	local hero = W.Driver.ui.console.hero
	ok(hero and hero.fill, "the hero card has its violet fill")
	ok(H.visible(hero), "the hero card shows")
	ok(hasGradient(hero.fill.violet) and hasGradient(hero.fill.night), "both layers carry a vertex gradient")
	eq(hero.fill.lit, 1, "fully lit while a click is due")
	-- the violet fades left to right: the left column brighter than the right
	local tl, tr = S[hero.fill.violet.parts.TL].gradient, S[hero.fill.violet.parts.TR].gradient
	ok(tl[2].a > tr[3].a, "bright at the left, dim at the right")
	-- the night deepens downwards: clear at the top, dark at the bottom
	local top, bottom = S[hero.fill.night.parts.T].gradient, S[hero.fill.night.parts.B].gradient
	ok(top[3].a < 0.05 and bottom[2].a > 0.4, "clear at the top, dark at the bottom")
	clean(w)
end)

test("r7 driver: closed, the hero card dims (the gold Open pill is the one bright thing)", function()
	local w, a, W = console("off")
	local hero = W.Driver.ui.console.hero
	ok(hero.fill.lit < 0.6, "dimmed: " .. tostring(hero.fill.lit))
	ok(not W.Driver.ui.console.skip:IsShown(), "no Skip with nobody to skip")
	clean(w)
end)

test("r7 driver: the docked big button stays the secure WuberDriveButton, its own face hidden, over the slot", function()
	local w, a, W, DR = console("go")
	local b = DR.button or a.env.WuberDriveButton
	ok(b, "the big button")
	ok(b:IsProtected() ~= false, "a secure button")
	ok(DR.Button.Docked(), "docked over the console's slot")
	eq(b:GetFrameStrata(), "FULLSCREEN_DIALOG", "docked in the FULLSCREEN_DIALOG strata")
	ok(b.fill, "it has the same violet face for floating")
	for _, t in pairs(b.fill.violet.parts) do ok(not t:IsShown(), "its own face is hidden while docked") break end
	eq(b.title:GetText(), "Summon Dan", "its words say the click")
	-- Skip sits in the card's top band, never over the button
	local skip = W.Driver.ui.console.skip
	ok(skip:IsShown(), "Skip shows")
	local rs, rb = H.rect(skip), H.rect(b)
	ok(rs.b >= rb.b + rb.h - 0.5, "Skip is above the button's area")
	clean(w)
end)

test("r7 driver: the hero's words fit (no cut title or subtitle)", function()
	local w, a, W, DR = console("go")
	local b = DR.button
	local T2 = W.Theme
	local rb = H.rect(b)
	local tw = T2.MeasureText(b.title:GetText(), 32, "bold")
	ok(tw <= rb.w - 36 or (b.title.wuberMin ~= nil), "the title fits or shrinks: " .. tw .. " in " .. rb.w)
	local rt = H.rect(b.title)
	ok(rt.l >= rb.l and rt.l + rt.w <= rb.l + rb.w, "the title stays inside the card")
	clean(w)
end)

test("r7 driver: earnings with nothing logged: the note shows over the squares, no tapped square or pill", function()
	local w = newWorld()
	local a = T.driver(w, T.ANITA, { spot = "Undercity" })
	w:advance(15)
	local W, DR = a.W, a.W.Drive
	T.openDrive(a)
	DR.Heatmap = function(days)
		local g = { days = days }
		for d = 0, 6 do g[d] = {} for h = 0, 23 do g[d][h] = { copper = 0, rides = 0, open = 0, asks = 0 } end end
		g[5][20] = { copper = 40000, rides = 8, open = 60, asks = 6 }
		return g
	end
	W.UI.ShowDrive("earnings")
	w:advance(1)
	local e = W.UI.drive.screens.earnings
	local hm = e.heat
	local cell
	for _, b in ipairs(hm.cells) do if b.wday == 5 and b.hour == 20 then cell = b end end
	H.runScript(cell, "OnClick", "LeftButton")
	w:advance(1)
	ok(hm.sel:IsShown() and hm.sel:GetFrameLevel() > cell:GetFrameLevel(), "the tapped square's frame is above the squares")
	ok(hm.pill:IsShown() and hm.info:GetText():find("Fri 20:00", 1, true), "its numbers: " .. tostring(hm.info:GetText()))
	-- now nothing is logged
	DR.Heatmap = function() return nil end
	e.update()
	w:advance(1)
	ok(H.visible(hm.empty), "the note shows")
	ok(hm.empty:GetFrameLevel() > hm.cells[1]:GetFrameLevel(), "above the squares (not hidden under them)")
	ok(not hm.sel:IsShown(), "no tapped square")
	ok(not hm.pill:IsShown(), "no numbers pill")
	eq(e.per:GetText(), "-", "no number yet")
	clean(w)
end)
