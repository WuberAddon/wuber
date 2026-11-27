-- #36 "the back arrow does nothing in the game". Run 3's mouse-focus samples proved: a frame inside a clipping tab body
-- ranks as the body's level (2) against the header drag strip (ui.top, level 2), and at an equal level the strip wins.
-- Promise: on every pushed page (Settings, Help, Drive/customers, Ride/confirm) a REAL click (the fake game's hit test,
-- Client:clickOn: frameAt at the arrow's centre, then the mouse scripts of whatever is on top) on the back arrow reaches
-- the arrow, leads back to the exact screen before, and that screen takes the next real click.
-- Never arrow:GetScript("OnClick") or Client:click(arrow): they skip the hit test, which is the very thing at fault.
local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H

local function backButtons(a)
	local out = {}
	for _, f in ipairs(a.frames) do
		local ok1, ot = pcall(f.GetObjectType, f)
		local g = ok1 and ot == "Button" and rawget(f, "glyph") or nil
		local tex = g and g.GetTextureFilePath and g:GetTextureFilePath() or nil
		if type(tex) == "string" and tex:sub(-4) == "back" and H.visible(f) then out[#out + 1] = f end
	end
	return out
end

local function name(f) return (f and f.GetName and f:GetName()) or ("level " .. tostring(f and f:GetFrameLevel()) .. " " .. tostring(f and f:GetObjectType())) end

local function world()
	local w = T.newWorld()
	local a = T.driver(w, T.ANITA, { spot = "Undercity", screenW = 1920, screenH = 1080 })
	w:advance(15)
	a.W.UI.Toggle(true) w:advance(3)
	return w, a, a.W
end

-- the one back arrow on screen: a real click on it must land on it
local function realBack(w, a, what)
	local backs = backButtons(a)
	eq(#backs, 1, what .. ": exactly one back arrow shows")
	local arrow = backs[1]
	local hit = a:clickOn(arrow) w:advance(2)
	eq(hit == arrow, true, what .. ": the strip took the click (the real click landed on " .. name(hit) .. ", not the back arrow)")
	return arrow
end

-- the screen before takes the next real click: the cog (a header control, shown again once no pushed page is up)
local function cogWorks(w, a, W, what)
	local cog = W.UI.state.gear
	eq(cog:IsShown(), true, what .. ": the cog shows again")
	local hit = a:clickOn(cog) w:advance(2)
	eq(hit == cog, true, what .. ": the real click on the cog landed on " .. name(hit))
	eq(W.UI.SettingsShown(), true, what .. ": the cog opened Settings")
end

test("#36 back arrow: Settings opened from Ride, a real click leads back to Ride/home", function()
	local w, a, W = world()
	W.UI.SelectTab("Ride") w:advance(2)
	local K = W.Mod("UI.Kit")
	eq(K.ui.screen, "home", "control: Ride/home")
	W.UI.OpenSettings() w:advance(2)
	eq(W.UI.SettingsShown(), true, "control: Settings shows")
	realBack(w, a, "Settings from Ride")
	eq(W.UI.SettingsShown(), false, "Settings is put away")
	eq(W.UI.state.tab, "Ride", "back on the Ride tab")
	eq(K.ui.screen, "home", "back on Ride/home")
	cogWorks(w, a, W, "Ride/home after Settings")
	T.clean(w)
end)

test("#36 back arrow: Settings opened from the Drive cog, a real click leads back to Drive/console", function()
	local w, a, W = world()
	W.UI.SelectTab("Drive") w:advance(2)
	W.UI.OpenSettings("drive") w:advance(2)
	eq(W.UI.SettingsShown(), true, "control: Settings shows")
	realBack(w, a, "Settings from Drive") -- the Driving section opens first: the arrow steps back to Settings' home
	eq(W.UI.SettingsShown(), true, "the first back step stays in Settings (its home)")
	realBack(w, a, "Settings home")
	eq(W.UI.SettingsShown(), false, "Settings is put away")
	eq(W.UI.state.tab, "Drive", "back on the Drive tab")
	eq(W.Driver.CurrentScreen(), "console", "back on Drive/console")
	cogWorks(w, a, W, "Drive/console after Settings")
	T.clean(w)
end)

test("#36 back arrow: Help, a real click leads back to Ride/home", function()
	local w, a, W = world()
	W.UI.SelectTab("Ride") w:advance(2)
	local K = W.Mod("UI.Kit")
	W.UI.OpenHelp("home") w:advance(2)
	eq(W.UI.HelpShown(), true, "control: Help shows")
	realBack(w, a, "Help")
	eq(W.UI.HelpShown(), false, "Help is put away")
	eq(K.ui.screen, "home", "back on Ride/home")
	cogWorks(w, a, W, "Ride/home after Help")
	T.clean(w)
end)

test("#36 back arrow: Help opened from Settings, a real click reaches Help's arrow and leads back to Settings", function()
	local w, a, W = world()
	W.UI.SelectTab("Ride") w:advance(2)
	W.UI.OpenSettings() w:advance(2)
	W.UI.OpenHelp("settings") w:advance(2)
	eq(W.UI.HelpShown(), true, "control: Help shows")
	local backs = backButtons(a)
	local seen = {}
	for _, b in ipairs(backs) do seen[#seen + 1] = name(b) .. " strata " .. b:GetFrameStrata() .. " parent shown " .. tostring(b:GetParent():IsShown()) end
	-- Settings' page stays under Help (its arrow is shown too); Help's arrow is the one drawn on top
	table.sort(backs, function(x, y) return x:GetFrameLevel() > y:GetFrameLevel() end)
	local mine = backs[1]
	local arrow = a:clickOn(mine) w:advance(2)
	eq(arrow == mine, true, "Help from Settings: the real click landed on " .. name(arrow) .. ", not Help's arrow (arrows: " .. table.concat(seen, "; ") .. ")")
	eq(W.UI.HelpShown(), false, "Help is put away")
	eq(W.UI.SettingsShown(), true, "back on Settings (exact screen)")
	local backs2 = backButtons(a)
	eq(#backs2, 1, "only Settings' own arrow shows now")
	T.clean(w)
end)

test("#36 back arrow: Drive/customers after Drive, Trips, Drive, a real click leads back to Drive/console", function()
	local w, a, W = world()
	W.UI.SelectTab("Drive") w:advance(2)
	W.Driver.ShowScreen("customers") w:advance(2)
	W.UI.SelectTab("Trips") w:advance(2)
	W.UI.SelectTab("Drive") w:advance(2)
	eq(W.Driver.CurrentScreen(), "customers", "control: still on Customers")
	realBack(w, a, "Drive/customers")
	eq(W.Driver.CurrentScreen(), "console", "back on Drive/console")
	cogWorks(w, a, W, "Drive/console after Customers")
	T.clean(w)
end)

test("#36 back arrow: Ride/confirm, a real click leads back to Ride/home", function()
	local w = T.newWorld()
	local c = T.rider(w, T.TESTCHAR, { screenW = 1920, screenH = 1080 })
	w:advance(15)
	local UI, K = c.W.UI, c.W.Mod("UI.Kit")
	UI.Toggle(true) w:advance(3)
	local key = "Mia Runner-Test"
	c.W.drivers = c.W.drivers or {}
	c.W.drivers[key] = { name = "Mia Runner", key = key, dest = "Undercity", price = 5000, state = "open", team = 3, service = "Mia's Rides", heard = c.env.GetTime() }
	UI.Show("confirm", key) w:advance(1)
	eq(K.ui.screen, "confirm", "control: on confirm")
	realBack(w, c, "Ride/confirm")
	eq(K.ui.screen, "home", "back on Ride/home")
	cogWorks(w, c, c.W, "Ride/home after confirm")
	T.clean(w)
end)

test("#36 Drive switch: a real click on Raid summons / Sell summons reaches the switch", function()
	local w = T.newWorld()
	local d = T.driver(w, T.ANITA, { spot = "Undercity", screenW = 1920, screenH = 1080 })
	w:advance(15)
	T.goOnline(d, { price = 5000 })
	T.openDrive(d)
	local W2 = d.W
	local bar = W2.Driver.ui.console.modeBar
	eq(bar:IsShown(), true, "control: the Sell / Raid switch shows")
	for _, word in ipairs({ "Raid summons", "Sell summons" }) do
		local label
		for _, b in ipairs(bar.buttons) do if b.label:GetText() == word then label = b.label end end
		local hit = d:clickOn(label) w:advance(1)
		eq(hit == label:GetParent(), true, word .. ": the strip took the click (the real click landed on " .. name(hit) .. ", not the switch)")
		eq(bar.value, word == "Raid summons" and "raid" or "sell", word .. ": the switch changed")
	end
	T.clean(w)
end)

-- guard: with the Drive switch showing the strip still starts a drag to the right of it, and the switch takes its own clicks
test("#36 Drive switch guard: the strip still starts a drag to the right of the switch", function()
	local w = T.newWorld()
	local d = T.driver(w, T.ANITA, { spot = "Undercity", screenW = 1920, screenH = 1080 })
	w:advance(15)
	T.goOnline(d, { price = 5000 })
	T.openDrive(d)
	local ui = d.W.UI.state
	local bar = d.W.Driver.ui.console.modeBar
	eq(bar:IsShown(), true, "control: the switch shows")
	local r, br = H.rect(ui.top), H.rect(bar)
	local x, y = br.l + br.w + 4, r.b + r.h / 2
	local hit = d:frameAt(x, y)
	eq(hit == ui.top, true, "the strip takes the mouse just right of the switch (found " .. name(hit) .. ")")
	local l0 = H.rect(ui.win).l
	d:drag(hit, 40, -30, { x, y }) w:advance(1) -- pressed right of the switch, where the strip was found
	ok(H.rect(ui.win).l ~= l0, "the window moved with the drag")
	T.clean(w)
end)

-- guard: the header's x and cog still take their real clicks, with no pushed page and with one up
test("#36 back arrow guard: the x and the cog take their real clicks", function()
	local w, a, W = world()
	W.UI.SelectTab("Ride") w:advance(2)
	local ui = W.UI.state
	eq(a:clickOn(ui.gear) == ui.gear, true, "the cog takes the click on Ride/home")
	w:advance(2)
	eq(W.UI.SettingsShown(), true, "the cog opened Settings")
	eq(a:clickOn(ui.close) == ui.close, true, "the x takes the click while Settings shows")
	w:advance(2)
	eq(ui.win:IsShown(), false, "the x closed Wuber")
	W.UI.Toggle(true) w:advance(3)
	W.UI.SelectTab("Ride") w:advance(2)
	eq(a:clickOn(ui.close) == ui.close, true, "the x takes the click on Ride/home")
	w:advance(2)
	eq(ui.win:IsShown(), false, "the x closed Wuber again")
	T.clean(w)
end)

-- guard: the window is dragged by the header strip with no pushed page, and by its right part while one shows
test("#36 back arrow guard: the header strip still starts a drag (no page, and on the right part with Settings up)", function()
	local w, a, W = world()
	W.UI.SelectTab("Ride") w:advance(2)
	local ui = W.UI.state
	local function dragFrom(frac, px, what) -- the point: a fraction of the strip's width plus pixels, read fresh (a drag moves the window)
		local r = H.rect(ui.top)
		local x, y = r.l + r.w * frac + px, r.b + r.h / 2
		local f = a:frameAt(x, y)
		eq(f == ui.top, true, what .. ": the strip takes the mouse at x " .. x .. " (found " .. name(f) .. ")")
		local l0 = H.rect(ui.win).l
		a:drag(f, 40, -30) w:advance(1)
		ok(H.rect(ui.win).l ~= l0, what .. ": the window moved with the drag")
	end
	dragFrom(0.5, 0, "no page, middle")
	dragFrom(0, 8, "no page, far left")
	W.UI.OpenSettings() w:advance(2)
	eq(W.UI.SettingsShown(), true, "control: Settings shows")
	dragFrom(0.5, 0, "Settings up, middle")
	W.UI.CloseSettings() w:advance(2)
	dragFrom(0, 8, "after Settings, far left again")	T.clean(w)
end)


-- (#36 review) the strip's hit rect must hold while a page is still sliding in: a control far right (not yet drawn in the
-- window) must not push the inset past the window. At every step the header, right of the arrows, still starts a drag.
local function stripDrags(w, a, ui, W, what)
	local r = H.rect(ui.top)
	local s = r.w / (ui.top:GetWidth() or r.w)
	local x, y = r.l + r.w - W.UI.HeadRoom() * s - 30, r.b + r.h / 2
	if ui.win:GetWidth() > 361 then x = r.l + 120 * s end -- wide: the buttons stand over the side pane, far to the right
	local f = a:frameAt(x, y)
	eq(f == ui.top, true, what .. ": the strip takes the mouse right of the arrows at x " .. x .. " (found " .. name(f) .. ")")
	if f == ui.top then
		local l0 = H.rect(ui.win).l
		a:drag(f, 10, -10)
		ok(H.rect(ui.win).l ~= l0, what .. ": the window moved with the drag")
	end
end

for _, step in ipairs({ 0.05, 0.5 }) do
	test("#36 strip while a page slides in: Drive/customers, steps of " .. step .. " s, the header still drags", function()
		local w, a, W = world()
		local ui = W.UI.state
		W.UI.SelectTab("Drive") w:advance(2)
		W.Driver.ShowScreen("customers")
		local t = 0
		while t < 1.2 do
			w:advance(step) t = t + step
			stripDrags(w, a, ui, W, "customers slide, t=" .. t)
		end
		realBack(w, a, "Drive/customers once the slide ended")
		T.clean(w)
	end)

	test("#36 strip while a page slides in: Ride/confirm, steps of " .. step .. " s, the header still drags", function()
		local w = T.newWorld()
		local c = T.rider(w, T.TESTCHAR, { screenW = 1920, screenH = 1080 })
		w:advance(15)
		local UI = c.W.UI
		UI.Toggle(true) w:advance(3)
		local key = "Mia Runner-Test"
		c.W.drivers = c.W.drivers or {}
		c.W.drivers[key] = { name = "Mia Runner", key = key, dest = "Undercity", price = 5000, state = "open", team = 3, service = "Mia's Rides", heard = c.env.GetTime() }
		UI.Show("confirm", key)
		local t = 0
		while t < 1.2 do
			w:advance(step) t = t + step
			stripDrags(w, c, UI.state, c.W, "confirm slide, t=" .. t)
		end
		realBack(w, c, "Ride/confirm once the slide ended")
		T.clean(w)
	end)
end

-- guard: the window unfolds (Customers goes wide): the arrows and the switch still take real clicks and the header still drags
test("#36 wide window: the Drive switch and the back arrow take real clicks, the header drags", function()
	local w = T.newWorld()
	local d = T.driver(w, T.ANITA, { spot = "Undercity", screenW = 1920, screenH = 1080, wide = true })
	d.wide = true
	w:advance(15)
	T.goOnline(d, { price = 5000 })
	d.W.db.pos = { "TOPLEFT", "TOPLEFT", 200, -60 } -- a saved place: the wide window needs no room beside the chat
	T.openDrive(d)
	local W, ui = d.W, d.W.UI.state
	local bar = W.Driver.ui.console.modeBar
	W.Driver.ShowScreen("customers") w:advance(3)
	ok(W.UI.Fold.IsUnfolded() and ui.win:GetWidth() > 361, "control: Customers made the window wide (" .. tostring(ui.win:GetWidth()) .. ")")
	stripDrags(w, d, ui, W, "wide, Customers up")
	realBack(w, d, "wide Customers")
	w:advance(3)
	if not W.UI.Fold.IsUnfolded() then W.UI.Fold.Toggle() w:advance(3) end
	ok(W.UI.Fold.IsUnfolded() and ui.win:GetWidth() > 361, "control: the fold button made the window wide (" .. tostring(ui.win:GetWidth()) .. ")")
	eq(bar:IsShown(), true, "control: the switch shows in the wide window")
	for _, word in ipairs({ "Raid summons", "Sell summons" }) do
		local label
		for _, b in ipairs(bar.buttons) do if b.label:GetText() == word then label = b.label end end
		local hit = d:clickOn(label) w:advance(1)
		eq(hit == label:GetParent(), true, "wide: " .. word .. ": the real click landed on " .. name(hit))
	end
	local r, br = H.rect(ui.top), H.rect(bar)
	local hit = d:frameAt(br.l + br.w + 12, r.b + r.h / 2)
	eq(hit == ui.top, true, "wide: the strip takes the mouse just right of the switch (found " .. name(hit) .. ")")
	T.clean(w)
end)

-- guard: the switch in a narrow window: wherever it stands (in the header zone or dropped to its own row) a real click reaches it
test("#36 narrow window: the Drive Sell / Raid switch takes a real click (header zone or its own row)", function()
	local w = T.newWorld()
	local d = T.driver(w, T.ANITA, { spot = "Undercity", screenW = 1920, screenH = 1080 })
	w:advance(15)
	T.goOnline(d, { price = 5000 })
	T.openDrive(d)
	local W, ui = d.W, d.W.UI.state
	W.UI.WindowWide(false) w:advance(3)
	ok(ui.win:GetWidth() < 361, "control: the window is narrow")
	local bar = W.Driver.ui.console.modeBar
	eq(bar:IsShown(), true, "control: the switch shows")
	for _, word in ipairs({ "Raid summons", "Sell summons" }) do
		local label
		for _, b in ipairs(bar.buttons) do if b.label:GetText() == word then label = b.label end end
		local hit = d:clickOn(label) w:advance(1)
		eq(hit == label:GetParent(), true, "narrow: " .. word .. ": the real click landed on " .. name(hit))
		eq(bar.value, word == "Raid summons" and "raid" or "sell", word .. ": the switch changed")
	end
	T.clean(w)
end)
