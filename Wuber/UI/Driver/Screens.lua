-- Module: UI.Driver.Screens
-- Purpose: Shared kit for the driver's other screens: helpers, UI.drive state, Screen/label/para/Pool
--   builders.
-- API: W.Drive, W.Driver, D.screens, UI.drive
-- Internals: Char, INNER, PAD, Pool, Screen, WIDTH, call, dr, inCombat, money, nameOf, now, opts, para,
--   plural, safeScript, setShown, short, st, toast
-- Uses: (none)
-- Later: (none)
-- Events: (none)
-- Standalone: no
-- Test: tests/ui/driver/screens_test.lua
-- From: UI_Drive.lua 1-163 (Wuber 2.2.1)
--
-- Wuber: the driver's other screens (2.0), shown over the Drive tab's console (Driver.lua):
--   the crew wizard (three steps, clicks only), the Crew screen, the Messages editor (live
--   preview exactly as DR.Text writes it), the Blocked list, the Earnings screen (tiles, a
--   24-hour bar chart, best hours, the 7 x 24 heatmap), the price and place sheet, the row menu,
--   the old summoning addon's retire card, the end-of-shift card, the crew-offer consent card, and the floating mini console under the big
--   button. Plus the driver's toasts (DRIVE_ALERT, DRIVE_BLOCKED, DRIVE_PAID).
-- Everything reads DR.* nil-guarded; nothing is secure; nothing scales text.
--
-- UI.ShowDrive(screen, arg)  "console", "wizard", "crew", "messages", "blocked", "earnings", "sheet"
-- UI.CrewOffer(fromName, service)   the consent card (also on DRIVE_OFFER)
-- UI.DriveSlot()             the big button's slot while the console shows, else nil
-- UI.DriveSummary()          one line for the minimap tooltip
-- UI.DriveWantsClick()       the big button has a click for you

local _, W = ...
local Mod = W.Module("UI.Driver.Screens", {})
local T = W.Theme
local function wrapH(n, size) return n * T.DrawnSize(size) + (n - 1) * T.Spacing(size) end -- n wrapped lines, spacing between them
local A = T.Animate
local Try = T.Try
local UI = W.UI

W.Drive = W.Drive or {}
local DR = W.Drive
local D = W.Driver or {}
W.Driver = D
D.screens = D.screens or {}

local K = D.kit or {}
local WIDTH, PAD = 360, 10
local INNER = WIDTH - PAD * 2
local TOP_H = 56
local SLICE_CAP = 126 -- (2.3) UI.Kit's 3-slice caps (window units)

local S, N = W.Str, W.Num

local function call(fn, ...)
	if type(fn) ~= "function" then return nil end
	local ok, a, b, c, d = pcall(fn, ...)
	if not ok then
		W.Error("drive screens", a)
		return nil
	end
	return a, b, c, d
end
local function dr(name, ...) return call(DR[name], ...) end
local function now() return N(call(GetTime)) or 0 end
local function money(c) return W.Money(N(c) or 0) end
local function short(n) return W.Short(S(n) or "?") end
local function setShown(f, on) if on then f:Show() else f:Hide() end end
local function inCombat() return call(W.InCombat) == true end
local function toast(text, kind, onClick)
	if UI and type(UI.Toast) == "function" then return call(UI.Toast, text, kind, onClick) end
end
local function safeScript(frame, script, fn)
	frame:SetScript(script, function(...)
		local ok, err = pcall(fn, ...)
		if not ok then W.Error("drive " .. script, err) end
	end)
end
local function Char()
	if not W.myKey or type(W.Char) ~= "function" then return nil end
	local ok, c = pcall(W.Char)
	if ok and type(c) == "table" then return c end
	return nil
end
local function plural(n, one, many) return n == 1 and ("1 " .. one) or (n .. " " .. (many or (one .. "s"))) end
local function opts()
	local o = dr("opts")
	return type(o) == "table" and o or {}
end
-- "dan rider" -> "Dan Rider" (blocked entries are keys)
local function nameOf(key)
	key = S(key) or "?"
	return (key:gsub("(%a)([%w']*)", function(a, b) return a:upper() .. b end))
end

local st = { screens = {} }
UI.drive = st

---------------------------------------------------------------------------
-- A screen over the console: back, title, a scroll area, an optional fixed bottom bar
---------------------------------------------------------------------------

-- opts.bigTitle (E3b-05): the title is the page's own heading, display size (28), drawn on the page under the
-- header bar's back chevron instead of beside it; the scroll area starts below it (s.scrollY is where). Other
-- screens keep the small title in the header bar.
local function Screen(parent, title, bottom, opts)
	local s = {}
	local big = type(opts) == "table" and opts.bigTitle == true
	s.scrollY = 50
	local f = CreateFrame("Frame", nil, parent)
	f:SetAllPoints(parent)
	f:EnableMouse(true)
	f.wuberNoTip = true -- the screen blocks clicks to the console under it; its parts have tips
	f.bg = T.Tex(f, "winbg", "BACKGROUND")
	f.bg:SetAllPoints(f)
	f.bg:SetTexCoord(0, 504 / 512, 0, (1 - TOP_H / 600) * (840 / 1024))
	-- (2.3) unfolded, the left pane's screen has no right edge (nothing reads as a divider): the
	-- window's left cap and its stretched middle, as UI.Kit's 3-slice draws them (s.Wide)
	f.bgMid = T.Tex(f, "winbg", "BACKGROUND")
	f.bgMid:Hide()
	if type(T.RegisterBackdrop) == "function" then
		T.RegisterBackdrop(f, {
			showArt = function(on)
				f.bg:SetShown(on)
				f.bgMid:SetShown(on and s.bgWide == true)
			end,
			layer = "BACKGROUND", sub = 0,
		})
	end
	function s.Wide(on)
		on = on == true
		if s.bgWide == on then return end
		s.bgWide = on
		local k, v0, v1 = (504 / 512) / WIDTH, 0, (1 - TOP_H / 600) * (840 / 1024)
		f.bg:ClearAllPoints()
		if on then
			f.bg:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
			f.bg:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, 0)
			f.bg:SetWidth(SLICE_CAP)
			f.bg:SetTexCoord(0, SLICE_CAP * k, v0, v1)
			f.bgMid:ClearAllPoints()
			f.bgMid:SetPoint("TOPLEFT", f.bg, "TOPRIGHT", 0, 0)
			f.bgMid:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0)
			f.bgMid:SetTexCoord(SLICE_CAP * k, (WIDTH - SLICE_CAP) * k, v0, v1)
			f.bgMid:SetShown(T.activeTheme == T.DEFAULT_THEME)
		else
			f.bg:SetAllPoints(f)
			f.bg:SetTexCoord(0, 504 / 512, v0, v1)
			f.bgMid:Hide()
		end
	end
	s.frame = f
	s.back = T.RoundButton(f, "back", 32, "card")
	-- (design 2, C) the screen starts at the top of the phone: the back chevron and the title are in the header
	-- zone, on the line of the window's x; the cog steps aside while a pushed screen shows (UI.HeadPush)
	s.back:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -12)
	if W.UI and W.UI.HeadPush then
		W.UI.HeadPush(f)
		f:HookScript("OnShow", function() call(W.UI.HeadPush) end)
		f:HookScript("OnHide", function() call(W.UI.HeadPush) end)
	end
	safeScript(s.back, "OnClick", function()
		if s.onBack and s.onBack() then return end
		D.ShowScreen("console")
	end)
	T.Tip(s.back, "Back", "Back to your driver console.")
	s.title = T.Text(f, big and "display" or "heading", "white", "LEFT", "bold")
	if big then
		local th = math.ceil(T.DrawnSize("display")) + 6
		s.title:SetPoint("TOPLEFT", f, "TOPLEFT", PAD + 4, -46)
		s.title:SetWidth(INNER - 8)
		s.title:SetHeight(th)
		s.scrollY = 46 + th + 2
	else
		s.title:SetPoint("LEFT", s.back, "RIGHT", 12, 0)
		s.title:SetWidth(196)
	end
	s.title:SetText(title or "")
	-- the small words that stood at the right of the back row (where the window's x now is) sit under the title,
	-- and the title goes up a little while there are any
	s.right = T.Text(f, "caption", "muted", "LEFT", "regular")
	s.right:SetPoint("TOPLEFT", s.back, "TOPRIGHT", 12, -20)
	s.right:SetWidth(196)
	local rightSet = s.right.SetText
	s.right.SetText = function(self, t)
		rightSet(self, t)
		if big then return end
		s.title:ClearAllPoints()
		s.title:SetPoint("LEFT", s.back, "RIGHT", 12, (S(t) or "") ~= "" and 7 or 0)
	end
	s.scroll = T.Scroll(f, { lift = 8 }) -- (design 2) a small lift: its soft edges and bar stay under Settings and Help when they open over this page
	s.scroll:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -s.scrollY)
	s.scroll:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, bottom or 6)
	s.content = s.scroll.content
	if bottom then
		s.bar = CreateFrame("Frame", nil, f)
		s.bar:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, 0)
		s.bar:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0)
		s.bar:SetHeight(bottom)
		local line = T.Line(s.bar, "line", 0.8)
		line:SetHeight(1)
		line:SetPoint("TOPLEFT", s.bar, "TOPLEFT", PAD, 0)
		line:SetPoint("TOPRIGHT", s.bar, "TOPRIGHT", -PAD, 0)
	end
	f:Hide()
	return s
end

-- a section label ("PICK YOUR CREW") at y on parent; returns the next y
local function label(parent, y, text, colour)
	local h = T.Text(parent, "caption", colour or "glow", "LEFT", "bold")
	h:SetPoint("TOPLEFT", parent, "TOPLEFT", PAD + 4, -y)
	h:SetWidth(INNER - 8)
	h:SetText(text)
	return y + 20, h
end

-- a paragraph that wraps; its height follows the text it is given (nothing cut off)
local function para(parent, px, colour, width)
	local fs = T.Para(parent, px, colour or "muted", width)
	local plainSet = fs.SetText
	fs.SetText = function(self, t)
		-- (#267) a further 5% of room: this paragraph is laid out at small pixel sizes where the game's whole-pixel glyphs run wider still
		local n = T.ParaLines(t, px, "regular", width / 1.05)
		Try(self, "SetMaxLines", n + 1)
		-- one line as it was; each further line adds the label's own step (drawn size and spacing), as T.Para does
		local one = math.ceil((T.SIZE[px] or tonumber(px) or T.SIZE.body) * 1.32 + 1) + 2
		self.paraH = math.max(one + (n - 1) * (T.DrawnSize(px) + T.Spacing(px)), wrapH(n, px))
		self:SetHeight(self.paraH)
		plainSet(self, t)
	end
	return fs
end

-- rows reused from a pool: pool.get(i) -> row (made by maker(parent) the first time)
local function Pool(parent, maker)
	local p = { list = {} }
	function p.get(i)
		local r = p.list[i]
		if not r then
			r = maker(parent)
			p.list[i] = r
		end
		return r
	end
	function p.hideFrom(n)
		for i = n + 1, #p.list do p.list[i]:Hide() end
	end
	return p
end

-- for other modules (REFACTOR-MAP section 2): set at the end, when every local holds its final value
Mod.Char = Char
Mod.INNER = INNER
Mod.PAD = PAD
Mod.Pool = Pool
Mod.Screen = Screen
Mod.WIDTH = WIDTH
Mod.call = call
Mod.dr = dr
Mod.inCombat = inCombat
Mod.money = money
Mod.nameOf = nameOf
Mod.now = now
Mod.opts = opts
Mod.para = para
Mod.plural = plural
Mod.safeScript = safeScript
Mod.setShown = setShown
Mod.short = short
Mod.st = st
Mod.toast = toast
