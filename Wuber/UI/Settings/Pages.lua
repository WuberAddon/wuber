-- Module: UI.Settings.Pages
-- Purpose: The pages frame that Settings and Help are pushed into, the moves of a page and of a section, and the
--   small helpers split out of UI.Settings.Panel (a pure move, no change in what anything does).
-- API: UI.HELP_TITLE, UI.HELP, UI.HELP_FOOTER (the text of the Help page)
-- Internals: Mod.SECTIONS, Mod.sectionRanges, Mod.paragraph, Mod.placePara, Mod.creditsText, Mod.pagesOf, Mod.mayTravel, Mod.coverTab, Mod.pushedShown, Mod.coverSoon, Mod.panelMove, Mod.sectionMove,
--   Mod.timeFormat, Mod.scaleNow, Mod.badgeMotion, Mod.linesFor, Mod.optionsFrame, buildOptionsPage
-- Pages (design 2, N): st.pages is one frame the size of the window that cuts its children off; Settings, Help and
--   a section are pushed into it (A.Push) and popped (A.PopPage). In combat the swap is at once (opts.secure).
-- Options page: at login one plain frame "WuberOptionsPage" goes into the game's Options > AddOns list when the client
--   has such a list; its button opens Wuber's own settings. Mod.optionsFrame() returns the page (nil without a list).
-- Uses: UI.Settings.Rows
-- Later: UI.Settings.Panel (UI.OpenSettings is called through UI at run time), UI.Fold (IsUnfolded)
-- Events: listens OnLogin (the options page); fires (none)
-- Standalone: no
-- Test: tests/ui/settings/pages_test.lua
-- From: UI.Settings.Panel (Wuber 2.4.2)
--
local _, W = ...
local Mod = W.Module("UI.Settings.Pages", { "UI.Settings.Rows" })
local RowsMod = W.Mod("UI.Settings.Rows")
local N = RowsMod.N
local WIN_W = RowsMod.WIN_W
local db = RowsMod.db
local safeScript = RowsMod.safeScript
local st = RowsMod.st
local T = W.Theme
local A = T.Animate
local Try = T.Try
local UI = W.UI

function Mod.timeFormat(copper)
	return math.floor(copper / 10000 + 0.5) .. "g / hour"
end

function Mod.scaleNow()
	local s = N(db().scale)
	if s then return s end
	local win = UI.state and UI.state.win
	return win and N(win:GetScale()) or 1
end

-- (round 13, I2) a badge in the picker turns only when chosen or under the mouse; else face-on, still
function Mod.badgeMotion(b)
	local p = b and b.preview
	if p and type(p.SetStill) == "function" then pcall(p.SetStill, p, not (b.chosen or b.hover)) end
end

-- (design 2, N) Settings and Help are pages pushed over the window's tab: they live in one frame the size of the
-- window that cuts its children off (a page on its way in from the right is never drawn outside the phone).
-- st.under is an empty stand-in for "the tab underneath": A.Push dims it (the black cover) and hides IT at the end,
-- so the real tab body is never hidden or moved by Settings.
function Mod.pagesOf(win)
	local c = st.pages
	if not c then
		c = CreateFrame("Frame", nil, win)
		c:SetAllPoints(win)
		c:SetFrameLevel(win:GetFrameLevel() + 1)
		Try(c, "SetClipsChildren", true)
		c.noEdgeFade = "the pages' frame, not a list"
		st.pages = c
		local u = CreateFrame("Frame", nil, c)
		u:SetPoint("TOPLEFT", c, "TOPLEFT", 0, 0)
		u:SetPoint("BOTTOMRIGHT", c, "BOTTOMRIGHT", 0, 0)
		u:Hide()
		st.under = u
	end
	return c
end

-- Whether a panel may travel now: only in the folded window that was already open (unfolded, Settings and Help
-- are two panes wide: they keep the short slide they had).
function Mod.mayTravel(ui, wasShown)
	if not wasShown or st.wide then return false end
	if (N(ui.win:GetWidth()) or WIN_W) > WIN_W + 1 then return false end
	local F = UI.Fold
	if type(F) == "table" and type(F.IsUnfolded) == "function" and F.IsUnfolded() then return false end
	return true
end

-- The panel comes in from the right (push) or leaves that way (pop). opts.secure: the tab underneath may hold a
-- secure overlay, so in combat the swap is at once; the overlays are laid again when the move ends.
-- (run 1, a) the open tab's own page is hidden while a pushed page (Settings, Help) is in place (Window.lua
-- UI.CoverTab): its frames could draw over the page (screenshot 164940: Trips over the Settings rows)
function Mod.coverTab(on)
	if type(UI.CoverTab) == "function" then W.Safe("cover tab", UI.CoverTab, on) end
end
function Mod.pushedShown()
	return (st.panel ~= nil and st.panel:IsShown()) or UI.HelpShown()
end
-- covered once the page has arrived; a timer as well, for a move that never finished
function Mod.coverSoon(ui)
	if W.After then W.After(T.MOTION.page + 0.1, function() if ui.settingsOpen and Mod.pushedShown() then Mod.coverTab(true) end end) end
end

function Mod.panelMove(ui, panel, push)
	-- the panel lies above the tab and has its own opaque fill: it travels over the tab, the cover dims the rest
	local opts = { clip = st.pages, width = WIN_W, secure = true, onDone = function()
		if push and ui.settingsOpen and panel:IsShown() then Mod.coverTab(true) end
		if ui.animUntil and ui.animUntil > (N(GetTime()) or 0) then ui.animUntil = N(GetTime()) or 0 end
		if UI.SyncSecure then UI.SyncSecure() end
	end }
	ui.animUntil = (N(GetTime()) or 0) + T.MOTION.page + 0.02
	if push then A.Push(panel, st.under, opts) else A.PopPage(panel, st.under, opts) end
end

-- (design 2, N) folded, a section comes in from the right in place of the Settings home; on the way back
-- (Mod.back) the home comes in from the left in place of the section.
function Mod.sectionMove(push)
	local home = st.find and st.find.home
	local ui = UI.state
	if st.wide or not (home and st.clip and st.pages and ui and ui.win and st.panel:IsVisible()) then return end
	-- the home and the section are siblings inside the panel: only one is on screen during the move (opts.single),
	-- over the panel's own fill; st.leaving stays nil, so a layout in the middle shows the current one only
	local opts = { clip = st.pages, width = WIN_W, secure = true, single = true, onDone = function()
		st.leaving = nil
		UI.LayoutSettings()
	end }
	if push then
		A.Push(st.clip, home, opts)
	else
		A.PopPage(st.clip, home, opts)
	end
end

-- How many lines `text` takes at px in `room` (the wider of Inter's measure and the game's).
function Mod.linesFor(fs, text, px, room)
	local n, cur = 1, ""
	local function width(t)
		local a = (type(T.MeasureText) == "function" and tonumber(T.MeasureText(t, px, "regular"))) or 0
		local b = 0
		if fs then
			local old = fs:GetText()
			fs:SetText(t)
			b = N(fs:GetStringWidth()) or 0
			fs:SetText(old)
		end
		return math.max(a, b) * 1.07 -- (#265) as T.ParaLines (Theme/Forms.lua)
	end
	for word in tostring(text):gmatch("%S+") do
		local try = cur == "" and word or (cur .. " " .. word)
		if cur ~= "" and width(try) > room then
			n, cur = n + 1, word
		else
			cur = try
		end
	end
	return n
end

-- The page in the game's Options > AddOns list: one line and one button that opens Wuber's own settings.
local optionsPage
function Mod.optionsFrame() return optionsPage end

local function buildOptionsPage()
	local f = CreateFrame("Frame", "WuberOptionsPage", UIParent)
	f.name = "Wuber"
	f:SetSize(600, 200)
	f:Hide() -- the game's list shows the page when its row is chosen; until then it must never be drawn on the screen itself
	f.wuberOptionsPage = true
	f.line = T.Text(f, "body", "white", "LEFT", "regular")
	f.line:SetPoint("TOPLEFT", f, "TOPLEFT", 16, -16)
	f.line:SetText("Wuber's settings are in Wuber's own window.")
	f.status = T.Text(f, "sub", "muted", "LEFT", "regular")
	f.status:SetPoint("TOPLEFT", f, "TOPLEFT", 16, -88)
	f.status:SetText("")
	f.openBtn = T.Pill(f, "Open Wuber settings", "dark", 180, 32)
	f.openBtn:SetPoint("TOPLEFT", f, "TOPLEFT", 16, -48)
	safeScript(f.openBtn, "OnClick", function()
		if InCombatLockdown and InCombatLockdown() then
			f.status:SetText("In combat. Try again when it ends.")
			return
		end
		f.status:SetText("")
		-- (run 1, a) the game's Options window stays open: Wuber comes up above it, on Settings (Window.lua raise())
		if UI.state then UI.state.overOptions = true end
		if UI.Raise then UI.Raise() end
		UI.OpenSettings()
	end)
	f:HookScript("OnShow", function() f.status:SetText("") end)
	T.Tip(f.openBtn, "Open Wuber settings", "Opens Wuber's own settings window.")
	return f
end

W.OnLogin(function()
	local api, oldAdd = _G["Settings"], _G["InterfaceOptions_AddCategory"]
	local hasNew = type(api) == "table" and type(api.RegisterCanvasLayoutCategory) == "function"
		and type(api.RegisterAddOnCategory) == "function"
	local hasOld = type(oldAdd) == "function"
	if optionsPage or not (hasNew or hasOld) then return end
	local f = buildOptionsPage()
	local done
	if hasNew then
		done = pcall(function()
			local cat = api.RegisterCanvasLayoutCategory(f, "Wuber")
			api.RegisterAddOnCategory(cat)
		end)
	else
		done = pcall(oldAdd, f)
	end
	if done then optionsPage = f else f:Hide() end
end)

-- Each paragraph: its font string, room, lines and the height it was given (for the tests'
-- measure check: nothing is cut off).
-- (H24-07) placePara puts a paragraph at y in room and measures it; Help runs it again when the pane's width changes.
function Mod.placePara(e, y, room)
	local fs, text, px = e.fs, e.text, e.pxName
	fs:ClearAllPoints()
	fs:SetPoint("TOPLEFT", e.parent, "TOPLEFT", e.x, -y)
	fs:SetWidth(room)
	Try(fs, "SetMaxLines", 0)
	local lines = Mod.linesFor(fs, text, px, room)
	local num = T.SIZE[px] or tonumber(px) or T.SIZE.body -- the number, for the height maths only
	-- (design 3, P) n lines are n x the drawn size + (n - 1) x the line gap tall (T.DrawnSize, T.Spacing), plus the 2 of padding
	-- and never under what the wrap helper's own line box (1.2 x the size a line) says, so one line is never clipped
	local h = math.max(lines * T.DrawnSize(px) + (lines - 1) * T.Spacing(px) + 2, math.ceil(lines * num * 1.2))
	fs:SetHeight(h)
	Try(fs, "SetMaxLines", lines + 1)
	e.px, e.room, e.lines, e.h = num, room, lines, h
	return y + h
end

function Mod.paragraph(parent, y, text, px, colour, weight, room, x)
	local fs = T.Text(parent, px, colour, "LEFT", weight)
	Try(fs, "SetWordWrap", true)
	Try(fs, "SetNonSpaceWrap", false)
	Try(fs, "SetJustifyV", "TOP")
	fs:SetText(text)
	local e = { fs = fs, parent = parent, x = x, text = text, pxName = px }
	local texts = st.help.texts
	texts[#texts + 1] = e
	return Mod.placePara(e, y, room), e
end

UI.HELP_TITLE = "How Wuber finds drivers"
UI.HELP = {
	{ icon = "pulse", title = "",
		text = "Wuber is a radio network. Drivers call out; every Wuber on your realm hears them." },
	{ icon = "signal", title = "",
		text = "It reaches every Wuber on your realm." },
	{ icon = "check", title = "",
		text = "Whispers are the backup, so a driver may show a few seconds late. A driver's price comes only from that driver's own character." },
	{ icon = "star", title = "",
		text = "More users, more drivers. Your list grows with every ride and favourite." },
	{ icon = "pin", title = "",
		text = "Drivers: Wuber adds the [Wuber] tag to your advert for you. Other players' Wuber reads it." },
	{ icon = "lock", title = "",
		text = "Each ruleset is its own world. You only see your own." },
	{ icon = "pin", title = "",
		text = "World map: best with the free OpenMap addon." },
	{ icon = "bell", title = "",
		text = "Nobody there? Wait a minute. Tap Ping drivers. Tap Tell me." },
}
UI.HELP_FOOTER = "Nothing here is shared outside the game, and Wuber never sends anything in chat without your click, except the short auto-reply to riders who ask in public and the Messages lines you switch on (Settings can turn the auto-reply off)."

-- (BRIEF15) the credits: "Thanks to our first riders and drivers", the Pioneers' short names
-- (W.PioneerNames: the shipped lists only); nil while both lists are empty
function Mod.creditsText()
	local n, lines = type(W.PioneerNames) == "function" and RowsMod.call(W.PioneerNames) or nil, {}
	if type(n) ~= "table" then return nil end
	if type(n.drivers) == "table" and #n.drivers > 0 then lines[#lines + 1] = "Drivers: " .. table.concat(n.drivers, ", ") end
	if type(n.riders) == "table" and #n.riders > 0 then lines[#lines + 1] = "Riders: " .. table.concat(n.riders, ", ") end
	return #lines > 0 and (T.Code("glow") .. "Thanks to our first riders and drivers|r\n" .. table.concat(lines, "\n")) or nil
end

-- the sections, top to bottom (Driving only while it shows): key, label, tip
Mod.SECTIONS = {
	{ "riding", "Riding", "Your time, invites, the flight master tip, hidden drivers." },
	{ "driving", "Driving", "For Warlocks and crews: badge, adverts, invites, trades, the shift's split." },
	{ "map", "Map", "Drivers on the world map, OpenMap, the minimap button." },
	{ "sound", "Sound and effects", "Pings, chimes and the summon alert; portals, sparkles, crowns and badges over heads." },
	{ "window", "This window", "Size, wide pages, position, tips, updates and Check my game." },
}
local SECTIONS = Mod.SECTIONS

-- each shown section's range in the scroll content: { key, top, bottom }
function Mod.sectionRanges()
	local byPage = {}
	for _, fr in ipairs(st.chain or {}) do
		if fr:IsShown() then
			local t = (st.frameTop and st.frameTop[fr]) or 0
			local b = t + (N(fr.baseH) or N(fr:GetHeight()) or 0)
			local r = byPage[fr.page]
			if not r then
				byPage[fr.page] = { key = fr.page, top = t, bottom = b }
			else
				if t < r.top then r.top = t end
				if b > r.bottom then r.bottom = b end
			end
		end
	end
	local list = {}
	for _, sec in ipairs(SECTIONS) do
		local r = byPage[sec[1]]
		if r then list[#list + 1] = r end
	end
	return list
end
