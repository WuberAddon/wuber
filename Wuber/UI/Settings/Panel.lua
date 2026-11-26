-- Module: UI.Settings.Panel
-- Purpose: Settings panel build, layout and update (UI.BuildSettings/OpenSettings/CloseSettings) and the
--   "How Wuber finds drivers" help page.
-- Options page: at login one plain frame "WuberOptionsPage" (a line and an "Open Wuber settings" button) goes into the
--   game's Options > AddOns list (Settings.RegisterCanvasLayoutCategory, else InterfaceOptions_AddCategory, else nothing).
--   The button opens Wuber's own settings beside the game's window; it never closes or hooks the game's window, and in
--   combat it only says so. Mod.optionsFrame() returns the page (nil when the client has no such list).
-- API: UI.LayoutSettings, UI.UpdateSettings, UI.BuildSettings, UI.OpenSettings, UI.CloseSettings,
--   UI.SettingsShown, UI.HelpShown, UI.OpenHelp, UI.CloseHelp,
--   UI.ScrollHelp, UI.HasOpenMap
-- Internals: SECTIONS, sectionRanges, wideLayout, buildNav, foldLayout, helpWide, helpLayout, viewLayout, search,
--   openSection, openResult, back, selectSection, sectionMove
-- (design 2, N) Folded, Settings and Help are pages pushed in from the right (A.Push) and popped by their back
-- chevron (A.PopPage), inside st.pages (a frame the size of the window that cuts them off); a section is pushed
-- over the Settings home the same way. In combat the swap is at once (opts.secure). Unfolded, or when the call
-- itself opens the window, they keep the short slide. A move ends first on a fold, a close, a new open.
-- Unfolded (SPEC7 2.8): the search box and a narrow section list on the left (in the panel), the
-- chosen section's rows on the right (the scroll area shows only that section's range); a search
-- shows its matches on the right instead. Help unfolded (H24-07): the page takes the whole pane and wraps again; (older: contents list left, the text right);
-- the part being read is lit in the list as you scroll or click (2.3.2, I31).
-- Folded (round 9, G1): a Settings home (the search box and a card per section, each with what
-- it is set to); a tap opens just that section, with the back arrow to the home. st.view is
-- "home" | "results" | "section"; st.query what is typed. UI.OpenSettings(where): where = a
-- section key ("riding", "driving", "map", "sound", "window"; "drive" and "bell" = Driving)
-- opens that section, else the home.
-- Uses: UI.Settings.Rows, UI.Settings.Find, UI.Settings.Pages, UI.Kit
-- Later: UI.Tips (ShowAgain, else ShowNow: Help's "Show a tip" row), UI.Fold (Register, IsUnfolded: the unfolded layout, SPEC7 2.8 "settings"), FX.Emblem (W.Emblem.Active,
--   W.Emblem.Mine, W.Emblem.Sweep: the Pioneer emblem rows), UI.Bug (UI.Bug.Open: the "Report a bug" rows)
-- Events: listens Listen SETTINGS (advanced); fires SETTINGS, PAGE (open, close, help)
-- Standalone: no
-- Test: tests/ui/settings/panel_test.lua
-- From: UI_Settings.lua 583-1259 (Wuber 2.2.1)
--
local _, W = ...
local Mod = W.Module("UI.Settings.Panel", { "UI.Settings.Rows", "UI.Settings.Find", "UI.Settings.Pages", "UI.Kit" })
local PagesMod = W.Mod("UI.Settings.Pages")
local RowsMod = W.Mod("UI.Settings.Rows")
local FindMod = W.Mod("UI.Settings.Find")
local KitMod = W.Mod("UI.Kit")
local INNER = RowsMod.INNER
local N = RowsMod.N
local PAD = RowsMod.PAD
local S = RowsMod.S
local TOP_H = RowsMod.TOP_H
local WIN_W = RowsMod.WIN_W
local btn = RowsMod.btn
local buildDriving = RowsMod.buildDriving
local buildDriving2 = RowsMod.buildDriving2
local buildDriving3 = RowsMod.buildDriving3
local keyRow = RowsMod.keyRow
local optToggle = RowsMod.optToggle
local buildRiding8 = RowsMod.buildRiding8
local buildWindow8 = RowsMod.buildWindow8
local sync8 = RowsMod.sync8
local buttonRow = RowsMod.buttonRow
local call = RowsMod.call
local db = RowsMod.db
local dopts = RowsMod.dopts
local hiddenCount = RowsMod.hiddenCount
local inCombat = RowsMod.inCombat
local isWarlock = RowsMod.isWarlock
local row = RowsMod.row
local runCheck = RowsMod.runCheck
local safeScript = RowsMod.safeScript
local section = RowsMod.section
local set = RowsMod.set
local st = RowsMod.st
local toggleRow = RowsMod.toggleRow
local turnOnPlates = RowsMod.turnOnPlates
local creditsText = PagesMod.creditsText
local badgeMotion = PagesMod.badgeMotion
local coverSoon = PagesMod.coverSoon
local coverTab = PagesMod.coverTab
local paragraph = PagesMod.paragraph
local placePara = PagesMod.placePara
local mayTravel = PagesMod.mayTravel
local pagesOf = PagesMod.pagesOf
local panelMove = PagesMod.panelMove
local scaleNow = PagesMod.scaleNow
local sectionMove = PagesMod.sectionMove
local timeFormat = PagesMod.timeFormat
local T = W.Theme
local A = T.Animate
local Try = T.Try
local UI = W.UI

---------------------------------------------------------------------------
-- Building
---------------------------------------------------------------------------

Mod.sectionMove = sectionMove
Mod.optionsFrame = PagesMod.optionsFrame

local function build(win)
	st.controls = {}
	st.fields, st.sliders = {}, {}
	st.credits = nil
	st.chain, st.frameTop = {}, {}
	local p = CreateFrame("Frame", nil, pagesOf(win))
	-- (design 2, C) from the top of the screen down to the tab bar (as high as before): the back chevron and the
	-- title are in the header zone, left of the window's x
	p:SetPoint("TOPLEFT", win, "TOPLEFT", 0, 0)
	p:SetPoint("BOTTOMRIGHT", win, "BOTTOMRIGHT", 0, UI.TABBAR_H or TOP_H)
	p:SetFrameLevel(win:GetFrameLevel() + 40)
	p:EnableMouse(true)
	p.bg = T.Tex(p, "winbg", "BACKGROUND")
	p.bg:SetAllPoints(p)
	p.bg:SetTexCoord(0, 504 / 512, 0, (1 - TOP_H / 600) * (840 / 1024))
	-- 3-slice (SPEC7 2.5): unfolded the panel is 720 wide; folded it draws exactly as before
	p.slices = KitMod.threeSlice(p.bg, p, T.MEDIA .. "winbg", "BACKGROUND", 0, 504 / 512, 0, (1 - TOP_H / 600) * (840 / 1024), 0, 0)
	p:Hide()
	st.panel = p
	st.builtKey = W.myKey -- the name the name-based rows (founder crown, Pioneer switch) were built for

	local back = T.RoundButton(p, "back", 32, "card")
	back:SetPoint("TOPLEFT", p, "TOPLEFT", 16, -12) -- on the line of the window's x (the header zone's middle)
	safeScript(back, "OnClick", function() Mod.back() end)
	st.back = back
	if UI.HeadPush then
		UI.HeadPush(p)
		p:HookScript("OnShow", function() pcall(UI.HeadPush) end)
		p:HookScript("OnHide", function() pcall(UI.HeadPush) end)
	end
	T.Tip(back, "Back", function()
		if not st.wide and st.view ~= "home" then return "Back to Settings: every section and the search." end
		return "Close Settings. Changes are saved as you make them."
	end)
	local title = T.Text(p, "display", "white", "LEFT", "bold")
	title:SetPoint("TOPLEFT", p, "TOPLEFT", PAD, -48)
	title:SetText("Settings")
	st.title = title
	-- (E3b-05 / D3-10) root "Settings" sits large on the page below the header; the hint sits under it.
	-- Folded section sub-pages still show their section name in the header bar beside the back arrow.
	local hint = T.Text(p, "caption", "muted", "LEFT", "regular")
	hint:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -2)
	hint:SetText("Hover over anything for help")
	st.hint = hint
	function Mod.headTitle()
		local sub = not st.wide and st.view == "section"
		T.SetFont(title, sub and "heading" or "display", "bold")
		title:ClearAllPoints()
		if sub then
			title:SetPoint("LEFT", back, "RIGHT", 12, 0)
		else
			title:SetPoint("TOPLEFT", p, "TOPLEFT", PAD, -48)
		end
	end
	Mod.headTitle()

	-- the rows' scroll: one section's range at a time (folded and unfolded), soft edges (S6)
	local clip = CreateFrame("Frame", nil, p)
	-- one level for good, made before its rows: above the Fold's side pane (empty for Settings) when
	-- unfolded; never changed after, so rows that set their own levels (the sliders' knobs) stay on top
	clip:SetFrameLevel((N(p:GetFrameLevel()) or 0) + 10)
	clip:SetPoint("TOPLEFT", p, "TOPLEFT", 0, -48)
	clip:SetSize(WIN_W, KitMod.WIN_H - TOP_H - 48 - 6)
	Try(clip, "SetClipsChildren", true)
	clip:EnableMouseWheel(true)
	safeScript(clip, "OnMouseWheel", function(_, delta)
		st.scrollTarget = math.max(st.scrollMin or 0, math.min(st.scrollMax or 0, st.scrollTarget - (tonumber(delta) or 0) * 70))
	end)
	st.clip = clip
	local c = CreateFrame("Frame", nil, clip)
	c:SetSize(WIN_W, 900)
	c:SetPoint("TOPLEFT", clip, "TOPLEFT", 0, 0)
	st.content = c
	T.EdgeFade(clip, { content = c, source = function()
		local lo = st.scrollMin or 0
		return (st.scroll or 0) - lo, (st.scrollMax or 0) - lo
	end })
	safeScript(clip, "OnUpdate", function(_, elapsed)
		if st.scroll == st.scrollTarget then return end
		local k = math.min(1, (elapsed or 0) * 14)
		local y = st.scroll + (st.scrollTarget - st.scroll) * k
		if math.abs(y - st.scrollTarget) < 0.5 then y = st.scrollTarget end
		st.scroll = y
		c:ClearAllPoints()
		c:SetPoint("TOPLEFT", clip, "TOPLEFT", 0, y)
	end)

	local function makePage(page, adv)
		local f = CreateFrame("Frame", nil, c)
		f:SetSize(WIN_W, 10)
		f.page = page
		f.adv = adv and true or false
		st.chain[#st.chain + 1] = f
		return f
	end

	-- Riding: always shown
	local riding = makePage("riding", false)
	st.riding = riding
	st.secY = { riding = { riding, 0 } }
	local y = section(riding, 6, "Riding")
	y = buildRiding8(riding, y)
	local hiddenBtn, hiddenRowFrame
	y, hiddenBtn, hiddenRowFrame = buttonRow(riding, y, "hidden", "Hidden drivers", "Drivers you chose to hide.",
		"In Advanced mode, right-click a driver's card to hide them. This shows every hidden driver again.", "Show all", function()
			local n = 0
			if type(W.ShowAllDrivers) == "function" then
				n = N(call(W.ShowAllDrivers)) or 0
			else
				n = hiddenCount()
				set("hidden", {})
			end
			UI.Toast(n > 0 and (n == 1 and "1 driver is back" or (n .. " drivers are back")) or "No hidden drivers", "info")
			UI.UpdateSettings()
		end)
	st.hiddenRow = hiddenBtn
	st.hiddenRowFrame = hiddenRowFrame
	st.ridingGroup = hiddenRowFrame and hiddenRowFrame.group
	riding.baseH = y + 6

	-- Riding: Advanced (no heading)
	local ridingAdv = makePage("riding", true)
	y = 6
	y = toggleRow(ridingAdv, y, "autoAccept", "Auto-accept my driver's invite", "Only the driver you booked; nobody else.",
		"When the driver you booked invites you, Wuber joins their group for you. Invites from anyone else are left alone.",
		function() return db().autoAccept ~= false end, function(on) set("autoAccept", on) end)
	y = toggleRow(ridingAdv, y, "autoLeave", "Leave the group after the ride", "A few seconds after you've paid.",
		"Leaves the driver's group by itself a few seconds after you've paid (never in combat).",
		function() return db().autoLeave ~= false end, function(on) set("autoLeave", on) end)
	local r
	r, y = row(ridingAdv, y, "My time is worth", "for time saved",
		"Wuber shows how much flying each summon saves. This turns that time into gold, so you can see if a fare is worth it.", "slider")
	local worth = T.Slider(r, INNER - 28, {
		min = 10000, max = 1000000, step = 10000, value = N(db().timeValue) or 100000, format = timeFormat, labelW = 100,
		onChange = function(v) set("timeValue", v) end,
	})
	worth.holder:SetPoint("TOPLEFT", r.below, "TOPLEFT", 0, 0)
	T.Tip(worth, "My time is worth", "Drag to set how much an hour of your time is worth, from 1g to 100g.")
	st.controls.timeValue = worth
	y = RowsMod.sendingRow(ridingAdv, y) -- (decisions N) what Wuber sends, and how much
	ridingAdv.baseH = y + 6

	-- Driving (Warlocks only): always shown (no heading)
	local drive = makePage("driving", false)
	st.drive = drive
	st.secY.driving = { drive, 0 }
	local dy = 6
	dy = optToggle(drive, dy, "autoInvite", "Invite riders who whisper me", "Whispers and Wuber app requests.",
		"Invites whisperers and app requests, 1.5 s apart. A place you don't summon to waits in your list. Off: click a name to invite.")
	st.notes = st.notes or {}
	dy, st.notes.autoInvite = RowsMod.noteUnder(st.controls["drive.autoInvite"], dy, RowsMod.NOTES.inviteNote) -- (quick wins)
	dy = toggleRow(drive, dy, "advertOnline", "Post an advert when I go online", "One line in public chat, by the same click.",
		"Opening also posts one advert line in public chat. At most once every 15 minutes. Never in combat, never without your click. Change the words in Messages.",
		function() return db().advertOnline ~= false end, function(on) set("advertOnline", on) end)
	local br
	br, dy = row(drive, dy, "Your badge", "On your card, pin and over your head.",
		"A badge riders see next to your name. Pick one, or none. A founder has the crown in place of none: it shows on the card when no other badge is picked, and it can't be given to anyone else.", 94)
	st.badges = {}
	local badges = type(W.BADGES) == "table" and W.BADGES or {}
	local choices = { { id = "", name = "None" } }
	for _, b in ipairs(badges) do
		if type(b) == "table" and S(b.id) then choices[#choices + 1] = b end
	end
	-- (r54 B) a founder's crown is the automatic choice, picked by default: it replaces None (the crown shows
	-- unless a badge is picked, so None would be a lie). Picking it clears the saved badge ("").
	-- It comes from W.IsCreator on the player's own character; nobody else gets the tile.
	local mine = W.myKey or (W.UnitName and W.Key and W.Key(W.UnitName("player")))
	if type(W.IsCreator) == "function" and mine and W.IsCreator(mine) == true then
		choices[1] = { id = "", founder = true, name = "Founder (automatic)" }
		st.founderPick = true
	else
		st.founderPick = nil
	end
	st.badgeRow = br
	-- every badge whole: the last one's ring ends inside the row (wraps to a second row if needed)
	local size = 36
	local room = INNER - 28 - 4 -- the ring is 4 wider than the badge
	local perRow = math.max(1, math.min(#choices, math.floor((room - size) / (size + 6)) + 1))
	local gap = perRow > 1 and math.min(44, (room - size) / (perRow - 1)) or 0
	local rows = math.ceil(#choices / perRow)
	if rows > 1 then dy = dy + RowsMod.grow(br, (rows - 1) * (size + 8)) end
	-- (decisions H) the chosen badge's name, in words, under the badges (UI.UpdateSettings writes it)
	local nameH = 16
	dy = dy + RowsMod.grow(br, nameH)
	st.badgeName = T.Text(br, "caption", "muted", "LEFT", "regular")
	st.badgeName:SetPoint("BOTTOMLEFT", br, "BOTTOMLEFT", 16, 10)
	st.badgeName:SetWidth(INNER - 32)
	for i, b in ipairs(choices) do
		local bbtn = CreateFrame("Button", nil, br)
		bbtn:SetSize(size, size)
		local col, line = (i - 1) % perRow, math.floor((i - 1) / perRow)
		bbtn:SetPoint("BOTTOMLEFT", br, "BOTTOMLEFT", 16 + col * gap, 12 + nameH + (rows - 1 - line) * (size + 8))
		bbtn.bg = T.Circle(bbtn, size, "panel", "BACKGROUND")
		bbtn.bg:SetPoint("CENTER", bbtn, "CENTER")
		bbtn.ring = T.Tex(bbtn, "ring", "BORDER")
		bbtn.ring:SetSize(size + 4, size + 4)
		bbtn.ring:SetPoint("CENTER", bbtn, "CENTER")
		bbtn.ring:SetVertexColor(T.RGB("glow"))
		bbtn.ring:Hide()
		-- (BRIEF22 G1) the ring of a badge not chosen: its own texture, shown or hidden
		bbtn.ringOff = T.Tex(bbtn, "ring", "BORDER")
		bbtn.ringOff:SetSize(size + 4, size + 4)
		bbtn.ringOff:SetPoint("CENTER", bbtn, "CENTER")
		bbtn.ringOff:SetVertexColor(T.RGB("line", 0.6))
		if b.founder then
			-- the founder tile is always on, in its own dim gold (never the chosen ring)
			bbtn.ringOff:SetVertexColor(T.RGB("gold", 0.35))
			bbtn.founder = true
			bbtn.preview = T.Crown(bbtn, size - 6, "settings")
			bbtn.preview:SetPoint("CENTER", bbtn, "CENTER")
		elseif b.id == "" then
			bbtn.icon = T.Icon(bbtn, "close", 16, "muted", "ARTWORK")
			bbtn.icon:SetPoint("CENTER", bbtn, "CENTER")
		else
			bbtn.preview = T.DriverBadge(bbtn, b.id, size - 6)
			if bbtn.preview then
				bbtn.preview:SetPoint("CENTER", bbtn, "CENTER")
				-- (round 13, I2) face-on and still, so each can be told apart (spinning, they were caught
				-- edge-on as thin sticks); the chosen one turns, and one under the mouse (UI.UpdateSettings)
				if type(bbtn.preview.SetStill) == "function" then pcall(bbtn.preview.SetStill, bbtn.preview, true) end
			end
		end
		bbtn.id = b.founder and "\0founder" or b.id
		bbtn.badgeName = S(b.name) or b.id
		bbtn:RegisterForClicks("LeftButtonUp")
		safeScript(bbtn, "OnEnter", function(self) self.hover = true badgeMotion(self) end)
		safeScript(bbtn, "OnLeave", function(self) self.hover = nil badgeMotion(self) end)
		T.Press(bbtn)
		safeScript(bbtn, "OnClick", function(self)
			local ch = type(W.Char) == "function" and call(W.Char)
			if type(ch) ~= "table" then return end
			ch.badge = self.founder and "" or self.id -- the crown tile: no pick, the crown shows by itself
			W.Fire("SETTINGS", "badge")
			if type(W.SendBeacon) == "function" then call(W.SendBeacon) end
			A.Pop(self, 0.3)
			UI.UpdateSettings()
		end)
		if b.founder then
			T.Tip(bbtn, "Founder (automatic)", "Your founder's crown. It always shows on your pin and over your head. Pick it to show it on your card too, in place of another badge. It can't be given to anyone else.")
		else
			T.Tip(bbtn, S(b.name) or b.id, b.id == "" and "No badge." or ("Show the " .. (S(b.name) or b.id) .. " badge to riders."))
		end
		st.badges[#st.badges + 1] = bbtn
	end
	dy = keyRow(drive, dy)
	st.driveH = dy + 6
	drive.baseH = st.driveH
	pcall(drive.SetHeight, drive, st.driveH)

	-- Driving: Advanced
	local driveAdv = makePage("driving", true)
	st.driveAdv = driveAdv
	dy = 6
	dy = buildDriving(driveAdv, dy)
	dy = buildDriving2(driveAdv, dy)
	dy = buildDriving3(driveAdv, dy)
	driveAdv.baseH = dy + 6
	pcall(driveAdv.SetHeight, driveAdv, driveAdv.baseH)

	-- Map: always shown
	local map = makePage("map", false)
	st.secY.map = { map, 0 }
	y = section(map, 6, "Map")
	y = toggleRow(map, y, "mapPins", "Drivers on the world map",
		UI.HasOpenMap() and "Best with OpenMap: installed" or "Best with OpenMap: not installed",
		"Pins show drivers, prices and your route on the world map; click one to book. Best with OpenMap; works without it.",
		function() return db().mapPins ~= false end, function(on) set("mapPins", on) end)
	st.mapRow = st.rows[#st.rows]
	y = toggleRow(map, y, "minimap", "Minimap button", "The Wuber button by the minimap.",
		"Shows the Wuber button by the minimap. /wuber always opens the window too.",
		function() return not db().minimapHidden end, function(on) set("minimapHidden", not on) end)
	map.baseH = y + 6

	-- Map: Advanced (Pioneer only)
	local emblem = W.Emblem
	local emblemActive = type(emblem) == "table" and emblem.Active()
	if emblemActive and emblem.Mine() then
		local mapAdv = makePage("map", true)
		y = 6
		y = toggleRow(mapAdv, y, "myEmblem", "Show my Pioneer emblem", "Over your head, for you and others.",
			"You are one of Wuber's Pioneers, so others with Wuber see a spinning emblem over your head. Turn this off to hide it, for you and for them.",
			function() return db().myEmblem ~= false end, function(on) set("myEmblem", on) W.Safe("emblem", emblem.Sweep) end)
		mapAdv.baseH = y + 6
	end

	-- Sound and effects (no Advanced rows)
	local sound = makePage("sound", false)
	st.secY.sound = { sound, 0 }
	y = section(sound, 6, "Sound")
	y = toggleRow(sound, y, "sound", "Sounds", "Pings, chimes and the summon alert.",
		"Plays a sound when a driver accepts, when the summon is up, and on milestones.",
		function() return db().sound ~= false end, function(on) set("sound", on) end)
	y = section(sound, y + 4, "Effects")
	local er
	er, y = row(sound, y, "Effects", "Portals, sparkles and celebrations.",
		"Full: every effect. Light: no full-screen effects, still badges. Off: no effects at all. Only the minimap button still pulses, while your summon is up or the big button has a click for you.", 84)
	local fx = T.Segmented(er, {
		{ value = "full", label = "Full", tip = "Every effect, full screen portals included." },
		{ value = "light", label = "Light", tip = "Effects in the window only, still badges." },
		{ value = "off", label = "Off", tip = "No effects. Calm and quick." },
	}, T.FxLevel(), function(v) set("fx", v) end, INNER - 28, 30)
	fx:SetPoint("BOTTOMLEFT", er, "BOTTOMLEFT", 16, 12)
	st.controls.fx = fx
	-- (design 2) pages and sheets fade in place instead of sliding (Theme.Anim's T.ReduceMotion reads it)
	y = toggleRow(sound, y, "reduceMotion", "Reduce motion", "", "Pages and sheets fade in place instead of sliding.",
		function() return db().reduceMotion == true end, function(on) set("reduceMotion", on and true or false) end)
	local emblemsOn = type(W.Emblem) == "table" and type(W.Emblem.Active) == "function" and W.Emblem.Active() == true
	y = toggleRow(sound, y, "plates", "Badges over heads",
		emblemsOn and "Crowns, badges and Pioneer emblems over nameplates." or "Crowns and badges over nameplates.",
		emblemsOn and "Shows badges, crowns and Pioneer emblems (violet riders, teal drivers) over heads. Needs friendly nameplates on. Not in dungeons or raids."
		or "Shows driver badges (and the founders' crown) above players' heads. Needs friendly nameplates on.",
		function() return db().plates ~= false and db().emblems ~= false end, function(on)
			on = on and true or false
			set("plates", on)
			set("emblems", on)
			if type(W.Emblem) == "table" and type(W.Emblem.Sweep) == "function" then W.Safe("emblem", W.Emblem.Sweep) end
		end)
	st.sound = sound
	st.soundBaseY = y
	-- a full-width button: the game's friendly nameplates (needed for the badges over heads)
	local plates = T.Pill(sound, "Turn on friendly nameplates", "dark", INNER, 38)
	plates:SetPoint("TOPLEFT", sound, "TOPLEFT", PAD, -(y + 8))
	plates.fill:SetColor("raised")
	plates:HookScript("OnLeave", function(self) self.fill:SetColor("raised") end)
	safeScript(plates, "OnClick", turnOnPlates)
	T.Tip(plates, "Turn on friendly nameplates", "Turns on the game's nameplates for friendly players, so badges and crowns can show over their heads. Out of combat only.")
	RowsMod.index(plates, "Turn on friendly nameplates", "", "Turns on the game's nameplates for friendly players, so badges and crowns can show over their heads.")
	st.controls.nameplates = plates
	st.platesBtn = plates
	local showPlatesBtn = not RowsMod.friendlyPlatesOn()
	plates:SetShown(showPlatesBtn)
	sound.baseH = y + (showPlatesBtn and (8 + 38 + 8) or 0) + 6

	-- This window: always shown
	local winSec = makePage("window", false)
	st.winSec = winSec
	st.rest = winSec
	st.secY.window = { winSec, 0 }
	y = section(winSec, 6, "This window")
	y = toggleRow(winSec, y, "advanced", "Advanced mode", "Every setting, and Wuber's extra tools.",
		"Advanced mode shows every setting, the wide window, crews, statistics and the other extra tools. Turning it off hides them again and changes nothing you have set.",
		function() return type(W.Advanced) == "function" and W.Advanced() == true end,
		function(on)
			if type(W.SetAdvanced) == "function" then W.SetAdvanced(on) end
			UI.UpdateSettings()
		end)
	local wr
	wr, y = row(winSec, y, "Window size", "let go to apply",
		"Makes the Wuber window bigger or smaller.", "slider")
	y = y + RowsMod.grow(wr, 4)
	local resetW = 64
	local sizeSlider = T.Slider(wr, INNER - 28 - resetW - 10, {
		min = 0.6, max = 1.6, step = 0.05, value = scaleNow(),
		format = function(v) return math.floor(v * 100 + 0.5) .. "%" end,
		onChange = function(v) set("scale", v) end, live = false,
	})
	sizeSlider.holder:SetPoint("LEFT", wr.below, "LEFT", 0, 0)
	T.Tip(sizeSlider, "Window size", "Drag to make the window bigger or smaller.")
	st.controls.scale = sizeSlider
	local resetBtn = T.Pill(wr, "Reset", "dark", resetW, 26)
	resetBtn:SetPoint("RIGHT", wr.below, "RIGHT", 0, 0)
	resetBtn.fill:SetColor("raised")
	resetBtn:HookScript("OnLeave", function(self) self.fill:SetColor("raised") end)
	safeScript(resetBtn, "OnClick", function()
		local d = db()
		local pos0, scale0 = d.pos, d.scale -- (decisions N) kept only in the Undo
		d.pos, d.scale = nil, nil
		W.Fire("SETTINGS", "pos")
		W.Fire("SETTINGS", "scale")
		local function putBack()
			d.pos, d.scale = pos0, scale0
			W.Fire("SETTINGS", "pos")
			W.Fire("SETTINGS", "scale")
			st.controls.scale:Set(scaleNow())
			local function place()
				if UI.ApplyScale then UI.ApplyScale() end
				if UI.PlaceWindow then UI.PlaceWindow() end
			end
			if inCombat() and W.AfterCombat then W.AfterCombat(place) else place() end
		end
		local function moveBack()
			local wwin = UI.state and UI.state.win
			if wwin then
				if UI.ApplyScale then UI.ApplyScale() end
				-- (BRIEF19 R6) the default place keeps clear of the chat box, like a first open
				if not (UI.PlaceWindow and UI.PlaceWindow()) then
					wwin:ClearAllPoints()
					wwin:SetPoint("CENTER", UIParent, "CENTER", 0, 20)
				end
			end
			RowsMod.resetDone((pos0 ~= nil and 1 or 0) + (scale0 ~= nil and 1 or 0), putBack, "Window back in its usual place")
		end
		st.controls.scale:Set(scaleNow())
		if inCombat() then
			-- (HUNT-59) the window cannot move in a fight: move it after, and only then say it is back
			UI.Toast("Window moves after combat", "info")
			if W.AfterCombat then W.AfterCombat(moveBack) end
		else
			moveBack()
		end
	end)
	T.Tip(resetBtn, "Reset", "Puts the window back at its usual place and size: the middle of the screen, or beside the chat box when the middle would cover it.")
	st.controls.resetPos = resetBtn
	winSec.baseH = y + 6

	-- This window: Advanced (Wide pages), then Check my game and its results card in a frame of their own,
	-- so the check is the last row of the page in both modes, directly above the footer
	local winAdv = makePage("window", true)
	y = 6
	y = buildWindow8(winAdv, y)
	winAdv.baseH = y + 6

	local winChk = makePage("window", false)
	st.winChk = winChk
	y = 6
	st.checkRowY = y
	y = buttonRow(winChk, y, "check", "Check my game", "See what your game supports.",
		"Tests the game features Wuber uses (drawing, the map, the network, summons) and lists the results.", "Check", runCheck)
	y = y + 6 -- the results card sits clear of the last group
	st.checkY = y
	local res = T.Card(winChk, INNER, 60, { colour = "panel", radius = 12, shadow = false, border = "line" })
	res:SetPoint("TOPLEFT", winChk, "TOPLEFT", PAD, -y)
	res.head = T.Text(res, "caption", "white", "LEFT", "bold")
	res.head:SetPoint("TOPLEFT", res, "TOPLEFT", 14, -14)
	res.head:SetWidth(INNER - 28)
	Try(res.head, "SetWordWrap", true)
	res:Hide()
	st.results = res
	st.winBase = y
	winChk.baseH = y + 6

	-- This window: footer (About + Pioneers credits)
	local winFoot = makePage("window", false)
	st.winFoot = winFoot
	st.about = T.Text(winFoot, "caption", "muted", "CENTER", "regular")
	st.about:SetWidth(INNER)
	Try(st.about, "SetWordWrap", true)
	st.about:SetText(RowsMod.aboutText())
	winFoot.baseH = 60

	-- the search and the folded home (UI.Settings.Find); "How Wuber finds drivers" is the home's
	-- last card (unfolded: the list's Help link)
	FindMod.build(p)
	st.helpRow = st.find.help
	UI.LayoutSettings()
	-- the unfolded layout (SPEC7 2.8): registered with the window, built on the first unfold
	local F = UI.Fold
	if type(F) == "table" and type(F.Register) == "function" then
		F.Register("settings", { build = Mod.foldBuild, layout = Mod.foldLayout })
	end
end

-- Places the sections (Driving only for Warlocks; Advanced frames only in Advanced; the check's results grow the window section).
function UI.LayoutSettings()
	if not st.panel then return end
	local warlock = isWarlock()
	-- (HUNT-23) opened from the Drive tab's gear: Driving shows to anyone
	if st.showDriving then warlock = true end
	-- any class that runs a service (SPEC4 1.1) or helps in a crew
	local role = (not warlock and W.Drive and type(W.Drive.Role) == "function") and call(W.Drive.Role) or nil
	if role == "helper" or role == "driver" then warlock = true end
	local adv = type(W.Advanced) == "function" and W.Advanced() == true

	if st.hiddenRowFrame and st.ridingGroup and st.riding then
		st.hiddenRowFrame:SetShown(hiddenCount() > 0)
		local gh = N(st.ridingGroup:Layout()) or 0
		st.riding.baseH = (N(st.ridingGroup.topY) or 6) + gh + 6
	end
	if st.sound and st.platesBtn then
		local showBtn = not RowsMod.friendlyPlatesOn()
		st.platesBtn:SetShown(showBtn)
		st.sound.baseH = (st.soundBaseY or 0) + (showBtn and (8 + 38 + 8) or 0) + 6
	end
	if st.winChk then
		local wy = st.winBase or 0
		if st.results and st.results:IsShown() then wy = wy + (N(st.results:GetHeight()) or 60) + 8 end
		st.winChk.baseH = wy + 6
	end
	if st.winFoot then
		local fy = 0
		st.about:ClearAllPoints()
		st.about:SetPoint("TOP", st.winFoot, "TOP", 0, -8)
		-- (BRIEF15) the Pioneers' credits under the footer, made only when the lists have names
		local credits = creditsText()
		if credits and not st.credits then
			st.credits = T.Text(st.winFoot, "caption", "muted", "CENTER", "regular")
			st.credits:SetWidth(INNER)
			Try(st.credits, "SetWordWrap", true)
		end
		if st.credits then
			st.credits:SetText(credits or "")
			st.credits:SetShown(credits ~= nil)
			st.credits:ClearAllPoints()
			st.credits:SetPoint("TOP", st.about, "BOTTOM", 0, -10)
			local okh, h = pcall(st.credits.GetStringHeight, st.credits)
			if credits then fy = fy + 10 + math.max(N(okh and h) or 0, 13 * (1 + select(2, credits:gsub("\n", "")))) end
		end
		st.winFoot.baseH = fy + 60
	end

	local top = 0
	st.frameTop = {}
	for _, fr in ipairs(st.chain or {}) do
		local show = (fr.page ~= "driving" or warlock) and (not fr.adv or adv)
		if show then
			local h = N(fr.baseH) or 0
			fr:SetHeight(h)
			fr:ClearAllPoints()
			fr:SetPoint("TOPLEFT", st.content, "TOPLEFT", 0, -top)
			fr:Show()
			st.frameTop[fr] = top
			top = top + h
		else
			fr:Hide()
			st.frameTop[fr] = top
		end
	end
	st.driveTop = st.frameTop[st.drive] or 0
	st.restTop = st.frameTop[st.winChk] or 0
	st.content:SetHeight(top)
	st.contentH = top
	return Mod.viewLayout()
end

-- The controls show the saved values (something else may have changed them).
function UI.UpdateSettings()
	if not st.panel then return end
	local c = st.controls
	for _, key in ipairs({ "advanced", "mapPins", "plates", "myEmblem", "minimap", "sound", "autoAccept", "autoLeave", "advertOnline", "starter", "reduceMotion", "groupFinder" }) do
		local t = c[key]
		if t and t.get then
			local on = t.get() and true or false
			if t.on ~= on then t:SetOn(on) end
		end
	end
	if c.fx and c.fx.value ~= T.FxLevel() then c.fx:SetValue(T.FxLevel()) end
	if c.timeValue and not c.timeValue.pending then
		local v = N(db().timeValue) or 100000
		if c.timeValue.value ~= v then c.timeValue:Set(v) end
	end
	if c.scale and not c.scale.pending then
		local v = scaleNow()
		if math.abs((c.scale.value or 0) - v) > 0.001 then c.scale:Set(v) end
	end
	local n = hiddenCount()
	if st.hiddenRow then
		st.hiddenRow:SetActive(n > 0)
		st.hiddenRow:SetLabel(n > 0 and "Show all" or "None")
		local parent = st.hiddenRow:GetParent()
		if parent and parent.desc then
			parent.desc:SetText(n > 0 and (n == 1 and "1 driver is hidden." or (n .. " drivers are hidden.")) or "In Advanced mode, right-click a card to hide a driver.")
		end
	end
	-- the map row says whether OpenMap is installed
	local mr = st.mapRow
	if mr and mr.desc then
		local has = UI.HasOpenMap()
		mr.desc:SetText(has and "Best with OpenMap: installed" or "Best with OpenMap: not installed")
		mr.desc:SetTextColor(T.RGB("muted"))
	end
	-- Driving
	for _, key in ipairs({ "autoInvite", "autoReply", "autoPublic", "acceptUnder", "kickAfter" }) do
		local t = c["drive." .. key]
		if t and t.get then
			local on = t.get() and true or false
			if t.on ~= on then t:SetOn(on) end
		end
	end
	for _, key in ipairs({ "drive.locked" }) do
		local t = c[key]
		if t and t.get then
			local on = t.get() and true or false
			if t.on ~= on then t:SetOn(on) end
		end
	end
	for _, f in ipairs(st.fields or {}) do f:Sync() end
	FindMod.summaries()
	for _, sl in ipairs(st.sliders or {}) do
		if sl.get and not sl.pending then
			local v = N(call(sl.get))
			if v and sl.value ~= v then sl:Set(v) end
		end
	end
	local seg = c["drive.whisperMode"]
	if seg then
		local m = S(dopts().whisperMode) or "auto"
		if m == "macro" then m = "auto" end
		if seg.value ~= m then seg:SetValue(m) end
	end
	local lv = c["drive.leavers"]
	if lv then
		local o = dopts()
		local v = o.autoBlock ~= true and "off" or (o.tellBlocked == true and "tell" or "quiet")
		if lv.value ~= v then lv:SetValue(v) end
	end
	local onScr = c["drive.onScreen"]
	if onScr then
		local b = btn()
		local v = b.shown == false and "wuber" or (b.keepClosed == true and "always" or "waiting")
		if onScr.value ~= v then onScr:SetValue(v) end
	end
	if st.keyRow then
		local k = S(btn().key)
		st.keyRow.desc:SetText(k and ("On " .. k) or "None set")
	end
	sync8()
	local ch = type(W.Char) == "function" and call(W.Char)
	local badge = type(ch) == "table" and S(ch.badge) or ""
	local chosenName
	for _, b in ipairs(st.badges or {}) do
		local on = (b.founder and badge == "") or b.id == badge -- the crown tile (id "") is on while no badge is picked
		b.ring:SetShown(on)
		b.ringOff:SetShown(not on)
		b.bg:SetVertexColor(T.RGB(on and "raised" or "panel"))
		b.chosen = on
		if on then chosenName = b.badgeName end
		badgeMotion(b)
	end
	if st.badgeName then st.badgeName:SetText(chosenName or "") end
	if st.badgeRow and st.founderPick then
		st.badgeRow.desc:SetText(badge == "" and "Founder (automatic): the crown shows on your card."
			or "Your badge shows on your card. Pick the crown to show it again.")
	end
	UI.LayoutSettings()
end

W.Listen("SETTINGS", function(key)
	if key == "advanced" and st.panel then
		if (st.query or "") ~= "" and st.find then FindMod.paint(st.query) end
		UI.UpdateSettings()
	end
end)

function UI.BuildSettings(win)
	if st.panel or not PagesMod.pagesOf then return end -- no Pages.lua yet (a reload after an update): the restart notice covers it
	build(win)
end

function UI.OpenSettings(where)
	local ui = UI.state
	if not (ui and ui.win) then return false end
	-- built while the game gave no player name ("?"), and the name is known now: build again so the
	-- founder crown tile and the Pioneer switch are there (the old page stays hidden, unused)
	-- (not once the wide page's left list exists: the fold keeps that holder, and a new page would come up without it)
	if st.panel and st.builtKey == "?" and W.myKey and W.myKey ~= "?" and not st.nav then
		st.panel:Hide()
		st.panel, st.nav, st.index = nil, nil, {}
	end
	if not st.panel then build(ui.win) end
	-- Help sits above Settings: close it so the page asked for is the one shown
	if UI.HelpShown() then UI.CloseHelp(true) end
	-- (run 1, a) a window still zooming shut counts as shut: it opens again (else it goes, and Settings with it)
	local wasShown = ui.win:IsShown() and not ui.closing and true or false
	local wasOpen = st.panel:IsShown() and true or false
	A.StopPage(st.pages)
	if not wasShown and UI.Toggle then UI.Toggle(true) end
	ui.settingsOpen = true
	if UI.UpdateStatusBar then W.Safe("status bar", UI.UpdateStatusBar) end -- the ride pill's click now shows the ride
	if UI.PaintGear then UI.PaintGear(true) end -- (design 1, K) the cog is white, never gold
	-- a fresh start: no search, the home (or the section asked for)
	st.query = ""
	st.showDriving = (where == "drive" or where == "bell")
	if st.find then st.find.box:SetText("") FindMod.paint("") end
	st.view = "home"
	UI.UpdateSettings()
	-- "drive": the Driving section; "bell": its alert character row; a section key: that section
	local key = (where == "drive" or where == "bell") and "driving" or S(where)
	local shown = false
	for _, r in ipairs(Mod.sectionRanges()) do
		if r.key == key then shown = true end
	end
	if shown then
		Mod.openSection(key, true)
	end
	local function bellScroll()
		st.bellUntil = (N(GetTime()) or 0) + 5
		local y = (st.frameTop and st.frameTop[st.driveAdv] or st.driveTop or 0) + (st.bellY or 0)
		st.scrollTarget = math.max(st.scrollMin or 0, math.min(st.scrollMax or 0, y - 8))
		st.scroll = st.scrollTarget
		st.content:ClearAllPoints()
		st.content:SetPoint("TOPLEFT", st.clip, "TOPLEFT", 0, st.scroll)
	end
	if shown and where == "bell" then bellScroll() end
	ui.animUntil = (N(GetTime()) or 0) + 0.3
	if UI.SyncSecure then UI.SyncSecure() end
	W.Fire("PAGE")
	-- (design 2, N) folded, Settings is a page pushed in from the right; unfolded (the PAGE above unfolds the
	-- window) or with the window just opened it keeps its short slide
	if mayTravel(ui, wasShown) then
		if not wasOpen then panelMove(ui, st.panel, true) else coverTab(true) end
	else
		A.SlideIn(st.panel, 40, 0.24)
		coverTab(true)
	end
	coverSoon(ui)
	-- the page layout (wide window) puts the section back to its top: scroll to the row again
	UI.Refresh(true)
	if shown and where == "bell" then bellScroll() end
	return true
end

function UI.CloseSettings(instant)
	local ui = UI.state
	if ui and UI.HelpShown() then UI.CloseHelp(true) end
	if not (ui and st.panel) then return end
	-- the search box lets go of the keyboard
	local box = st.find and st.find.box
	if box and box.edit:HasFocus() then pcall(box.edit.ClearFocus, box.edit) end
	ui.settingsOpen = false
	if UI.UpdateStatusBar then W.Safe("status bar", UI.UpdateStatusBar) end -- the ride pill takes no click on the ride's own screen
	coverTab(false) -- (run 1, a) back to the page Settings came from: it shows under the page that leaves
	if UI.PaintGear then UI.PaintGear(false) end
	ui.animUntil = (N(GetTime()) or 0) + 0.25
	-- (design 2, N) the back chevron pops the page (folded); a move still running ends first
	A.StopPage(st.pages)
	if instant or not st.panel:IsShown() then
		st.panel:Hide()
	elseif mayTravel(ui, ui.win:IsShown()) then
		panelMove(ui, st.panel, false)
	else
		A.SlideOut(st.panel, 40, 0.18)
	end
	W.Fire("PAGE")
	UI.Refresh(true)
end

function UI.SettingsShown() return st.panel ~= nil and st.panel:IsShown() end

---------------------------------------------------------------------------
-- "How Wuber finds drivers": a page in plain words (from Settings, Home's empty state and
-- the status bar's signal bars), so a short or empty list never looks like a broken addon.
---------------------------------------------------------------------------

local HELP_PX, HELP_HEAD_PX = "caption", "body"
-- (design round 1) the headings carry no picture any more: the words start at the card's margin (14) and
-- run to the right margin; each card measures its text (paragraph) so its height follows
local HELP_X = 14
local HELP_TEXT_W = INNER - 28

local help = { scroll = 0, scrollTarget = 0 }
st.help = help

-- (2.3.2, R3) "Report a bug" (Settings and Help): UI.Bug's window
function Mod.openBug()
	local b = UI.Bug
	if type(b) == "table" and type(b.Open) == "function" then call(b.Open) end
end

local function buildHelp(win)
	help.texts = {}
	local p = CreateFrame("Frame", nil, pagesOf(win))
	p:SetPoint("TOPLEFT", win, "TOPLEFT", 0, 0) -- (design 2, C) as Settings: from the top down to the tab bar
	p:SetPoint("BOTTOMRIGHT", win, "BOTTOMRIGHT", 0, UI.TABBAR_H or TOP_H)
	p:SetFrameLevel(win:GetFrameLevel() + 60)
	p:EnableMouse(true)
	p.bg = T.Tex(p, "winbg", "BACKGROUND")
	p.bg:SetAllPoints(p)
	p.bg:SetTexCoord(0, 504 / 512, 0, (1 - TOP_H / 600) * (840 / 1024))
	p.slices = KitMod.threeSlice(p.bg, p, T.MEDIA .. "winbg", "BACKGROUND", 0, 504 / 512, 0, (1 - TOP_H / 600) * (840 / 1024), 0, 0)
	p:Hide()
	help.panel = p

	local back = T.RoundButton(p, "back", 32, "card")
	back:SetPoint("TOPLEFT", p, "TOPLEFT", 16, -12)
	safeScript(back, "OnClick", function() UI.CloseHelp() end)
	T.Tip(back, "Back", "Back to where you were.")
	help.back = back
	if UI.HeadPush then
		UI.HeadPush(p)
		p:HookScript("OnShow", function() pcall(UI.HeadPush) end)
		p:HookScript("OnHide", function() pcall(UI.HeadPush) end)
	end
	local title = T.Text(p, "heading", "white", "LEFT", "bold")
	title:SetPoint("LEFT", back, "RIGHT", 12, 0)
	-- (design 2, C) the title ends before the window's buttons (the fold button and the x): its words go on a
	-- second line when they do not fit beside them
	-- (r52 F013) all of the buttons' room, with no 40 given back: the words stop 8 before the fold button
	help.titleRoom = (UI.HeadRoom and N(UI.HeadRoom("most")) or 152)
	-- the right end follows the panel's real width (a window that stays narrow while Help believes it is unfolded
	-- would otherwise put the words under the buttons)
	title:SetPoint("RIGHT", p, "TOPRIGHT", -(help.titleRoom + 8), -28)
	Try(title, "SetWordWrap", true)
	Try(title, "SetMaxLines", 2)
	title:SetText(UI.HELP_TITLE)
	help.title = title

	local clip = CreateFrame("Frame", nil, p)
	clip:SetPoint("TOPLEFT", p, "TOPLEFT", 0, -48)
	clip:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", 0, 6)
	Try(clip, "SetClipsChildren", true)
	clip:EnableMouseWheel(true)
	safeScript(clip, "OnMouseWheel", function(_, delta)
		help.picked = nil
		help.scrollTarget = math.max(0, math.min(help.scrollMax or 0, help.scrollTarget - (tonumber(delta) or 0) * 70))
	end)
	help.clip = clip
	T.EdgeFade(clip, { source = function() return help.scroll or 0, help.scrollMax or 0 end }) -- S6
	local c = CreateFrame("Frame", nil, clip)
	c:SetSize(WIN_W, 900)
	c:SetPoint("TOPLEFT", clip, "TOPLEFT", 0, 0)
	help.content = c
	safeScript(clip, "OnUpdate", function(_, elapsed)
		if help.scroll == help.scrollTarget then return end
		local k = math.min(1, (elapsed or 0) * 14)
		local y = help.scroll + (help.scrollTarget - help.scroll) * k
		if math.abs(y - help.scrollTarget) < 0.5 then y = help.scrollTarget end
		help.scroll = y
		c:ClearAllPoints()
		c:SetPoint("TOPLEFT", clip, "TOPLEFT", 0, y)
	end)

	help.cards, help.heads, help.bodies = {}, {}, {}
	for i, sec in ipairs(UI.HELP) do
		local card = T.Card(c, INNER, 60, { colour = "card", radius = 12, shadow = false })
		help.cards[i] = card
		if sec.title and sec.title ~= "" then
			local _, e = paragraph(card, 12, i .. ". " .. sec.title, HELP_HEAD_PX, "white", "bold", HELP_TEXT_W, HELP_X)
			help.heads[i] = e
		end
		local _, e = paragraph(card, 12, sec.text, HELP_PX, "muted", "regular", HELP_TEXT_W, HELP_X)
		help.bodies[i] = e
	end
	local urlCard = T.Card(c, INNER, 60, { colour = "card", radius = 12, shadow = false })
	local _, urlHead = paragraph(urlCard, 12, "Where to get Wuber", HELP_HEAD_PX, "white", "bold", HELP_TEXT_W, HELP_X)
	help.urlHead = urlHead
	local url = S(W.UPDATE_URL) or ""
	local urlBox = T.Field(urlCard, INNER - 16, 30, {
		max = 120, size = "caption",
		get = function() return S(W.UPDATE_URL) or "" end,
	})
	urlBox:SetText(url)
	local ueb = urlBox.edit
	ueb:SetAutoFocus(false)
	ueb:ClearAllPoints()
	ueb:SetPoint("TOPLEFT", urlBox, "TOPLEFT", 10, 0)
	ueb:SetPoint("BOTTOMRIGHT", urlBox, "BOTTOMRIGHT", -10, 0)
	local function selectUrl(self)
		local u = S(W.UPDATE_URL) or ""
		if (S(self:GetText()) or "") ~= u then self:SetText(u) end
		Try(self, "HighlightText")
	end
	Try(ueb, "HookScript", "OnEditFocusGained", function(self) pcall(selectUrl, self) end)
	Try(ueb, "HookScript", "OnMouseUp", function(self) pcall(selectUrl, self) end)
	Try(urlBox, "HookScript", "OnMouseUp", function()
		Try(ueb, "SetFocus")
		pcall(selectUrl, ueb)
	end)
	Try(ueb, "HookScript", "OnTextChanged", function(self, userInput)
		if not userInput then return end
		local u = S(W.UPDATE_URL) or ""
		if (S(self:GetText()) or "") ~= u then
			self:SetText(u)
			Try(self, "HighlightText")
		end
	end)
	safeScript(ueb, "OnEscapePressed", function(self) Try(self, "ClearFocus") end)
	urlBox:EnableMouse(true)
	T.Tip(urlBox, "Where to get Wuber", "Click the box, then press Ctrl+C to copy the address.")
	T.Tip(ueb, "Where to get Wuber", "Click the box, then press Ctrl+C to copy the address.")
	-- the note that says a newer Wuber is out opens here: say how to turn it off (the typed command)
	local _, urlNote = paragraph(urlCard, 12, "To stop the note that says a newer Wuber is out, type /wuber updates off.", "caption", "muted", "regular", HELP_TEXT_W, HELP_X)
	help.urlNote = urlNote
	help.urlCard = urlCard
	help.urlBox = urlBox
	local _, footE = paragraph(c, 0, UI.HELP_FOOTER, "caption", "muted", "regular", INNER, PAD)
	help.footer = footE
	-- (round 26) a tip row: brings the Ride tab's tip card back (UI.Tips, loaded later)
	local tipRow = T.Card(c, INNER, 60, { colour = "card", radius = 12, shadow = false })
	local _, tipHead = paragraph(tipRow, 12, "Tips", HELP_HEAD_PX, "white", "bold", INNER - 140, 14)
	local _, tipBody = paragraph(tipRow, 12, "A short hint on the Ride tab.", HELP_PX, "muted", "regular", INNER - 140, 14)
	help.tipRow, help.tipHead, help.tipBody = tipRow, tipHead, tipBody
	local tipBtn = T.Pill(tipRow, "Show a tip", "dark", 112, 30)
	tipBtn:SetPoint("RIGHT", tipRow, "RIGHT", -10, 0)
	tipBtn.fill:SetColor("raised")
	tipBtn:HookScript("OnLeave", function(self) self.fill:SetColor("raised") end)
	safeScript(tipBtn, "OnClick", function() Mod.showTip() end)
	T.Tip(tipBtn, "Show a tip", "Shows a short Wuber tip again on the Ride tab.")
	help.tip = tipBtn
	-- (2.3.2, R3) the last row: Report a bug (UI.Bug)
	local bugRow = T.Card(c, INNER, 60, { colour = "card", radius = 12, shadow = false })
	local _, bugHead = paragraph(bugRow, 12, "Something not working?", HELP_HEAD_PX, "white", "bold", INNER - 140, 14)
	local _, bugBody = paragraph(bugRow, 12, "Make a report to copy. Nothing is sent.", HELP_PX, "muted", "regular", INNER - 140, 14)
	help.bugHead, help.bugBody = bugHead, bugBody
	local bugBtn = T.Pill(bugRow, "Report a bug", "dark", 112, 30)
	bugBtn:SetPoint("RIGHT", bugRow, "RIGHT", -10, 0)
	bugBtn.fill:SetColor("raised")
	bugBtn:HookScript("OnLeave", function(self) self.fill:SetColor("raised") end)
	safeScript(bugBtn, "OnClick", function() Mod.openBug() end)
	T.Tip(bugBtn, "Report a bug", "Opens a short report to copy. Other players' names are left out and nothing is sent: "
		.. "you paste it in the comments on Wuber's CurseForge page.")
	help.bug = bugBtn
	help.bugRow = bugRow
	Mod.helpLayout(WIN_W)
end

-- (H24-07) Help's page at a pane width w (folded 360, unfolded 720): the cards, their words, the address box and the end
-- rows run from the 16 margin to the 16 margin, the words wrap again to it, and the page height (so the scroll range)
-- follows. Run at the build and by helpWide; the same flow at 360 as the page always had.
function Mod.helpLayout(w)
	if not help.content then return end
	local inner = w - PAD * 2
	local tw, rw = inner - 28, inner - 140
	local c = help.content
	help.layoutW = w
	c:SetWidth(w)
	local y = 6
	help.tops = {}
	for i, card in ipairs(help.cards) do
		help.tops[i] = y
		card:SetWidth(inner)
		card:ClearAllPoints()
		card:SetPoint("TOPLEFT", c, "TOPLEFT", PAD, -y)
		local cy = 12
		if help.heads[i] then cy = placePara(help.heads[i], cy, tw) + 4 end
		cy = placePara(help.bodies[i], cy, tw)
		card:SetHeight(cy + 12)
		y = y + cy + 12 + 8
	end
	local urlCard = help.urlCard
	help.urlY = y
	urlCard:SetWidth(inner)
	urlCard:ClearAllPoints()
	urlCard:SetPoint("TOPLEFT", c, "TOPLEFT", PAD, -y)
	local uy = placePara(help.urlHead, 12, tw)
	help.urlBox:SetWidth(inner - 16)
	help.urlBox:ClearAllPoints()
	help.urlBox:SetPoint("TOPLEFT", urlCard, "TOPLEFT", 8, -(uy + 6))
	local noteY = placePara(help.urlNote, uy + 6 + 30 + 8, tw)
	urlCard:SetHeight(noteY + 12)
	y = y + noteY + 12 + 8
	y = placePara(help.footer, y + 4, inner) + 16
	local function row(card, head, body)
		card:SetWidth(inner)
		card:ClearAllPoints()
		card:SetPoint("TOPLEFT", c, "TOPLEFT", PAD, -y)
		local by = placePara(head, 12, rw)
		by = placePara(body, by + 2, rw)
		local h = math.max(56, by + 12)
		card:SetHeight(h)
		return h
	end
	y = y + row(help.tipRow, help.tipHead, help.tipBody) + 8
	help.tops[#help.cards + 1] = y -- (BRIEF20 B9) the bug row
	y = y + row(help.bugRow, help.bugHead, help.bugBody) + 16
	c:SetHeight(y)
	help.height = y
end

-- Help's "Show a tip": UI.Tips.ShowAgain, else ShowNow (both looked up at run time).
function Mod.showTip()
	local tips = W.Mod("UI.Tips")
	local fn = tips and (tips.ShowAgain or tips.ShowNow)
	if type(fn) ~= "function" then return false end
	local ok, shown, why = pcall(fn)
	if not ok then return false end
	if shown == false then
		-- same wording as /wuber tips (UI.Commands) for the general case
		local say = {
			combat = "No tip now: try again out of combat.",
			ride = "No tip now: try again after your ride.",
			none = "You have seen every tip.",
		}
		W.Print(say[why] or "Tips are on. The next one shows when you open Wuber.")
		return false, why
	end
	return true
end

local function helpScrollMax()
	local clipH = N(help.clip:GetHeight()) or 490
	help.scrollMax = math.max(0, (help.height or 0) - clipH)
	return help.scrollMax
end

function UI.HelpShown() return help.panel ~= nil and help.panel:IsShown() end

-- Opens the page (from "settings", "home" or "status"). Returns true when it shows.
-- Settings' scroll bar holder: hidden while Help covers Settings (its level is above Help's)
-- (decisions N2) The rows go too, once Help has come in (st.underHelp): Help covers the whole window, and a section taller
-- than the list would sit under it cut at the list's edge with no soft edge. They are back the moment Help closes.
function Mod.settingsBar(on)
	local fd = st.clip and st.clip.edgeFade
	if fd and fd.holder then fd.holder:SetShown(on and true or false) end
	st.helpToken = (st.helpToken or 0) + 1
	if on then
		if st.underHelp then
			st.underHelp = nil
			if st.clip and (st.wide == true or st.view == "section" or st.leaving == st.clip) then st.clip:Show() end
		end
	else
		local token = st.helpToken
		W.After(T.MOTION.page + 0.05, function()
			if st.helpToken ~= token or not (st.clip and UI.HelpShown()) then return end
			st.underHelp = true
			st.clip:Hide()
		end)
	end
	-- the search results' own scroll bar and soft edges (Find) sit above Help just the same
	local rs = st.find and st.find.results
	local rf = rs and rs.edgeFade
	if rf and rf.holder then rf.holder:SetShown(on and true or false) end
end

function UI.OpenHelp(from, where)
	if not PagesMod.pagesOf then return false end
	local ui = UI.state
	if not (ui and ui.win) then return false end
	if not help.panel then buildHelp(ui.win) end
	if help.urlBox then help.urlBox:Sync() end
	help.from = from
	help.scroll, help.scrollTarget, help.picked = 0, 0, nil
	help.content:ClearAllPoints()
	help.content:SetPoint("TOPLEFT", help.clip, "TOPLEFT", 0, 0)
	ui.helpOpen = true
	Mod.settingsBar(false) -- Settings' scroll bar would draw over Help (REV-r26-1)
	ui.settingsOpen = true -- the window's other screens and the secure buttons step aside
	local wasShown = ui.win:IsShown() and not ui.closing and true or false
	local wasOpen = help.panel:IsShown() and true or false
	A.StopPage(st.pages)
	if not wasShown and UI.Toggle then UI.Toggle(true) end
	Mod.helpWide(UI.Fold and UI.Fold.IsUnfolded and UI.Fold.IsUnfolded())
	helpScrollMax()
	-- where = "address": scrolled to "Where to get Wuber" (the newer-version note)
	if where == "address" and help.urlY then
		local y = math.max(0, math.min(help.scrollMax or 0, help.urlY - 6))
		help.scroll, help.scrollTarget = y, y
		help.content:ClearAllPoints()
		help.content:SetPoint("TOPLEFT", help.clip, "TOPLEFT", 0, y)
	end
	ui.animUntil = (N(GetTime()) or 0) + 0.3
	if UI.SyncSecure then UI.SyncSecure() end
	W.Fire("PAGE")
	-- (design 2, N) folded, Help is a page pushed in from the right (as Settings is)
	if mayTravel(ui, wasShown) then
		if not wasOpen then panelMove(ui, help.panel, true) else coverTab(true) end
	else
		A.SlideIn(help.panel, 40, 0.24)
		coverTab(true)
	end
	coverSoon(ui)
	UI.Refresh(true)
	return true
end

-- Back to where it was opened from (Settings stays open under it).
function UI.CloseHelp(instant)
	local ui = UI.state
	if not (ui and help.panel) then return end
	ui.helpOpen = false
	Mod.settingsBar(true)
	ui.animUntil = (N(GetTime()) or 0) + 0.25
	A.StopPage(st.pages) -- (design 2, N) a move still running ends first (Settings under it is then in its final state)
	ui.settingsOpen = st.panel ~= nil and st.panel:IsShown()
	if not ui.settingsOpen then coverTab(false) end -- (run 1, a) no Settings under Help: the tab shows again
	if instant or not help.panel:IsShown() then
		help.panel:Hide()
	elseif mayTravel(ui, ui.win:IsShown()) then
		panelMove(ui, help.panel, false)
	else
		A.SlideOut(help.panel, 40, 0.18)
	end
	W.Fire("PAGE")
	UI.Refresh(true)
end

-- Scrolls the page by `delta` wheel steps (tests and the mouse wheel).
function UI.ScrollHelp(delta)
	if not help.panel then return end
	help.picked = nil
	helpScrollMax()
	help.scrollTarget = math.max(0, math.min(help.scrollMax or 0, help.scrollTarget - (tonumber(delta) or 0) * 70))
end

---------------------------------------------------------------------------
-- Unfolded (SPEC7 2.8 "settings"): the sections left, the chosen section's rows right. The
-- scroll area moves into the Fold's side pane and shows only that section's range; folded it
-- goes back exactly as it was. Help unfolded: its contents list left, the text right.
---------------------------------------------------------------------------

-- S11 (round 9): the list is a narrow column (navW); the chosen section's rows sit centred in the
-- rest of the 720 (clipX), above the Fold's side pane
local WIDE = { top = 52, navTop = 144, rowH = 44, gap = 4, clipTop = 48, clipBottom = 6, paneH = KitMod.WIN_H - TOP_H,
	navW = 232, clipX = 296 }
local SECTIONS = PagesMod.SECTIONS
local sectionRanges = PagesMod.sectionRanges
Mod.SECTIONS = SECTIONS
Mod.sectionRanges = sectionRanges

local function showIf(f, on)
	if on then f:Show() else f:Hide() end
end

-- the list on the left: which section shows, the selected one with an accent bar
local function paintNav(list)
	local nav = st.nav
	if not nav then return end
	local shown = {}
	for _, r in ipairs(list) do shown[r.key] = true end
	local y = WIDE.navTop
	for _, b in ipairs(nav.rows) do
		local on = shown[b.key] == true
		showIf(b, on)
		if on then
			b:ClearAllPoints()
			b:SetPoint("TOPLEFT", st.panel, "TOPLEFT", PAD, -y)
			y = y + WIDE.rowH + WIDE.gap
			local sel = b.key == st.sec and st.view ~= "results"
			showIf(b.bar, sel)
			b.bg:SetColor(sel and "raised" or "card")
			b.label:SetTextColor(T.RGB(sel and "white" or "muted"))
		end
	end
	nav.help:ClearAllPoints()
	nav.help:SetPoint("TOPLEFT", st.panel, "TOPLEFT", PAD, -(y + 8))
	nav.bug:ClearAllPoints()
	nav.bug:SetPoint("TOPLEFT", st.panel, "TOPLEFT", PAD, -(y + 8 + WIDE.rowH + WIDE.gap))
end

-- the chosen section in the side pane: the scroll area's height and range are that section's
function Mod.wideLayout()
	local list = sectionRanges()
	local cur
	for _, r in ipairs(list) do
		if r.key == st.sec then cur = r end
	end
	cur = cur or list[1]
	paintNav(list)
	if not cur then return end
	st.sec = cur.key
	local room = WIDE.paneH - WIDE.clipTop - WIDE.clipBottom
	local h = math.max(10, math.min(cur.bottom - cur.top, room))
	st.clip:SetHeight(h)
	local prevMin = st.secMin
	st.scrollMin = cur.top
	st.scrollMax = math.max(cur.top, cur.bottom - h)
	if st.secShown ~= cur.key then
		st.secShown = cur.key
		st.secMin = cur.top
		st.scrollTarget, st.scroll = cur.top, cur.top
		st.content:ClearAllPoints()
		st.content:SetPoint("TOPLEFT", st.clip, "TOPLEFT", 0, st.scroll)
		-- the Alert character link asked for its row a moment ago: the window unfolding must not undo that
		if cur.key == "driving" and st.bellUntil and (N(GetTime()) or 0) <= st.bellUntil then
			local y = (st.frameTop and st.frameTop[st.driveAdv] or st.driveTop or 0) + (st.bellY or 0)
			st.scrollTarget = math.max(st.scrollMin, math.min(st.scrollMax, y - 8))
			st.scroll = st.scrollTarget
			st.content:ClearAllPoints()
			st.content:SetPoint("TOPLEFT", st.clip, "TOPLEFT", 0, st.scroll)
		end
		st.bellUntil = nil
	elseif prevMin and prevMin ~= cur.top then
		local d = cur.top - prevMin
		st.secMin = cur.top
		st.scrollTarget = math.max(st.scrollMin, math.min(st.scrollMax, (st.scrollTarget or cur.top) + d))
		st.scroll = math.max(st.scrollMin, math.min(st.scrollMax, (st.scroll or cur.top) + d))
		st.content:ClearAllPoints()
		st.content:SetPoint("TOPLEFT", st.clip, "TOPLEFT", 0, st.scroll)
	end
	st.scrollTarget = math.max(st.scrollMin, math.min(st.scrollMax, st.scrollTarget))
	if (st.scroll or 0) < st.scrollMin or (st.scroll or 0) > st.scrollMax then
		st.scroll = math.max(st.scrollMin, math.min(st.scrollMax, st.scroll or st.scrollMin))
		st.content:ClearAllPoints()
		st.content:SetPoint("TOPLEFT", st.clip, "TOPLEFT", 0, st.scroll)
	end
end

-- picks a section (the list's rows, tests)
function Mod.selectSection(key)
	st.sec = S(key) or st.sec
	st.view = "section"
	UI.LayoutSettings()
end

---------------------------------------------------------------------------
-- The views (G1): the home, a search's matches, one section
---------------------------------------------------------------------------

local function secLabel(key)
	for _, sec in ipairs(SECTIONS) do
		if sec[1] == key then return sec[2] end
	end
	return "Settings"
end

-- what shows for st.view: unfolded there is no home (the list is always there: a section shows)
function Mod.viewLayout()
	local wide = st.wide == true
	local view = st.view or "home"
	if wide and view == "home" then view = "section" end
	showIf(st.clip, (view == "section" or st.leaving == st.clip) and not st.underHelp) -- (decisions N2) not under Help
	FindMod.place(view, wide, WIDE)
	-- (design 2, N) the page on its way out stays shown until its move ends (a refresh must not take it away)
	if st.leaving and st.find and st.leaving == st.find.home then st.leaving:Show() end
	st.title:SetText((not wide and view == "section") and secLabel(st.sec) or "Settings")
	showIf(st.hint, wide or view == "home")
	Mod.headTitle()
	if wide or view == "section" then return Mod.wideLayout() end
	paintNav(sectionRanges())
end

-- what is typed in the search box (the box, its x, Esc, Clear, tests)
function Mod.search(text)
	local q = tostring(text or "")
	if not q:find("%S") then q = "" end
	st.query = q
	local box = st.find and st.find.box
	if box and box:Text() ~= q then box:SetText(q) end
	if q ~= "" then
		st.view = "results"
	elseif st.view == "results" then
		st.view = "home"
	end
	FindMod.paint(q)
	UI.LayoutSettings()
end

-- one section (a home card, the list, OpenSettings(where)), from its top
-- (design 2, N) quiet: no move (OpenSettings(where) and a search match open the section in place)
function Mod.openSection(key, quiet)
	local fromHome = st.view == "home"
	A.StopPage(st.pages)
	st.sec = S(key) or st.sec
	st.view = "section"
	st.secShown = nil
	UI.LayoutSettings()
	if fromHome and not quiet then sectionMove(true) end
end

-- a match: its section, scrolled to it, with a brief highlight
function Mod.openResult(m)
	if type(m) ~= "table" then return end
	local box = st.find and st.find.box
	if box and box.edit:HasFocus() then pcall(box.edit.ClearFocus, box.edit) end
	if m.adv then
		st.query = ""
		if box and box:Text() ~= "" then box:SetText("") end
		FindMod.paint("")
		if st.wide then
			Mod.openSection("window", true)
			local advCtl = st.controls and st.controls.advanced
			FindMod.flash(advCtl and advCtl.row)
		else
			st.view = "home"
			UI.LayoutSettings()
			if st.find and st.find.home then st.find.home:ScrollTo(0, true) end
			FindMod.flash(st.find and st.find.advQuick)
		end
		return
	end
	Mod.openSection(m.key, true)
	-- (2.3.2, S2) snapped at once, then once more a frame later, when the folded layout has its range
	local snapped
	local function snap()
		st.scrollTarget = math.max(st.scrollMin or 0, math.min(st.scrollMax or 0, (N(m.y) or 0) - 4))
		st.scroll = st.scrollTarget
		snapped = st.scrollTarget
		st.content:ClearAllPoints()
		st.content:SetPoint("TOPLEFT", st.clip, "TOPLEFT", 0, st.scroll)
	end
	snap()
	if W.After then W.After(0.05, function() if st.view == "section" and st.sec == m.key and (snapped == nil or st.scrollTarget == snapped) then snap() end end) end -- (BRIEF25 I) not over a scroll made since
	FindMod.flash(m.rec and m.rec.frame)
end

-- the back arrow: folded, a section goes back to the home (or the matches); else it closes
function Mod.back()
	if not st.wide and st.view == "section" then
		A.StopPage(st.pages)
		st.view = (st.query or "") ~= "" and "results" or "home"
		UI.LayoutSettings()
		if st.view == "home" then sectionMove(false) end -- (design 2, N) the section leaves to the right
	elseif not st.wide and st.view == "results" then
		Mod.search("")
	else
		UI.CloseSettings()
	end
end

local function navRow(parent, key, label, tip, w)
	w = w or INNER
	local b = CreateFrame("Button", nil, parent)
	b:SetSize(w, WIDE.rowH)
	b:RegisterForClicks("LeftButtonUp")
	b.key = key
	b.bg = T.Rounded(b, "card", 12, "BACKGROUND", 0)
	b.bar = b:CreateTexture(nil, "ARTWORK")
	b.bar:SetColorTexture(T.RGB("accent"))
	b.bar:SetSize(3, WIDE.rowH - 16)
	b.bar:SetPoint("LEFT", b, "LEFT", 6, 0)
	b.label = T.Text(b, "body", "muted", "LEFT", "medium")
	b.label:SetPoint("LEFT", b, "LEFT", 18, 0)
	b.label:SetWidth(w - 36)
	b.label:SetText(label)
	T.Press(b, { fill = b.bg })
	T.Tip(b, label, tip)
	return b
end

-- the left list (made on the first unfold; parented to the panel, hidden while folded)
function Mod.foldBuild(holder)
	if not st.panel then return end
	local nav = CreateFrame("Frame", nil, st.panel)
	nav:SetAllPoints(st.panel)
	nav:Hide()
	nav.rows = {}
	for _, sec in ipairs(SECTIONS) do
		local b = navRow(nav, sec[1], sec[2], sec[3], WIDE.navW - PAD)
		safeScript(b, "OnClick", function(self)
			if (st.query or "") ~= "" then Mod.search("") end
			Mod.selectSection(self.key)
		end)
		nav.rows[#nav.rows + 1] = b
	end
	nav.help = navRow(nav, "help", "Help: finding drivers", "How Wuber finds drivers: why you might see few or none, and what helps.", WIDE.navW - PAD)
	-- a link, never styled as the chosen section (S11): no accent bar, a ? icon
	nav.help.label:SetTextColor(T.RGB("glow"))
	nav.help.bar:Hide()
	nav.help.mark = T.Text(nav.help, "body", "glow", "RIGHT", "bold")
	nav.help.mark:SetPoint("RIGHT", nav.help, "RIGHT", -14, 0)
	nav.help.mark:SetText("?")
	safeScript(nav.help, "OnClick", function() UI.OpenHelp("settings") end)
	-- (BRIEF20 B9) the bug report, a link under Help
	nav.bug = navRow(nav, "bug", "Report a bug", "Opens a short report to copy. Nothing is sent.", WIDE.navW - PAD)
	nav.bug.label:SetTextColor(T.RGB("glow"))
	nav.bug.bar:Hide()
	safeScript(nav.bug, "OnClick", function() Mod.openBug() end)
	st.nav = nav
	st.holder = holder
end

-- folded: the long scroll in the panel, as today; unfolded: the list left, the section right
function Mod.foldLayout(unfolded, holder)
	if not (st.panel and st.nav) then return end
	A.StopPage(st.pages) -- (design 2, N) a fold or unfold ends a page's move first
	st.wide = unfolded and true or false
	local clip = st.clip
	clip:ClearAllPoints()
	if st.wide then
		clip:SetParent(st.panel)
		clip:SetPoint("TOPLEFT", st.panel, "TOPLEFT", WIDE.clipX, -WIDE.clipTop)
		clip:SetWidth(WIN_W)
		st.secShown = nil
		st.nav:Show()
	else
		clip:SetParent(st.panel)
		clip:SetPoint("TOPLEFT", st.panel, "TOPLEFT", 0, -WIDE.clipTop)
		clip:SetWidth(WIN_W)
		st.nav:Hide()
		st.secShown = nil
	end
	UI.LayoutSettings()
	if UI.HelpShown() then Mod.helpWide(st.wide) end
end

-- (E3b-06, H24-07) Help unfolded: no contents list; Help takes the whole unfolded pane and lays itself out again.
function Mod.helpWide(on)
	local p = help.panel
	if not p then return end
	on = on and true or false
	if help.wide == on then return end
	help.wide = on
	local clip = help.clip
	clip:ClearAllPoints()
	clip:SetPoint("TOPLEFT", p, "TOPLEFT", 0, -WIDE.clipTop)
	local w = on and KitMod.WIDE_W or WIN_W
	if on then
		clip:SetSize(w, WIDE.paneH - WIDE.clipTop - WIDE.clipBottom)
	else
		clip:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", 0, WIDE.clipBottom)
	end
	-- (H24-07) the whole pane: the page, its cards and words, the title's room, then the scroll range
	Mod.helpLayout(w)
	help.scrollTarget = math.max(0, math.min(help.scrollMax or 0, help.scrollTarget or 0))
	helpScrollMax()
	help.scrollTarget = math.min(help.scrollTarget, help.scrollMax)
	if help.scroll > help.scrollMax then help.scroll = help.scrollMax end
	help.content:ClearAllPoints()
	help.content:SetPoint("TOPLEFT", clip, "TOPLEFT", 0, help.scroll)
end

-- Whether OpenMap is loaded (its API table is there).
function UI.HasOpenMap()
	return type(OpenMapAPI) == "table"
end
