-- Module: UI.Toasts
-- Purpose: UI.Toast and the toast queue (one at a time, slides from the top). UI.ChatBox and
--   UI.ClearOfChat: where the game's chat frame is now, and a spot for a Wuber frame clear of it.
--   UI.HudBoxes and UI.ClearOfHud: the shown action bars, micro menu, bags, status bars and party frames
--   (the game's and Daylight UI's), and a spot clear of them and the chat, with room to breathe.
-- API: UI.ToastPlace, UI.Toast, UI.ToastShowing, UI.UndoToast, UI.UndoPending, UI.ChatBox, UI.ClearOfChat, UI.HudBoxes, UI.ClearOfHud
--   (decisions N) UI.UndoToast(text, undo): a toast with an Undo button that stays 10 s; what was reset is kept only
--   in the undo function, which is dropped when the toast goes.
-- Internals: (none)
-- Uses: UI.Kit
-- Later: (none)
-- Events: listens (none); fires (none)
-- Standalone: no
-- Test: tests/ui/toasts_test.lua
-- From: UI.lua 422-612 (Wuber 2.2.1)
--
local _, W = ...
local Mod = W.Module("UI.Toasts", { "UI.Kit" })
local KitMod = W.Mod("UI.Kit")
local N = KitMod.N
local S = KitMod.S
local now = KitMod.now
local safeScript = KitMod.safeScript
local ui = KitMod.ui
local T = W.Theme
local A = T.Animate
local Try = T.Try
local UI = W.UI

---------------------------------------------------------------------------
-- The chat frame: no Wuber frame is placed over it
---------------------------------------------------------------------------
-- the author (20 Nov): on a squarer game window the chat ended up under Wuber's frames. A UI pack may
-- have moved the chat, so its place is read live, never guessed. Boxes are { left, right,
-- bottom, top } in UIParent units.

local CHAT = { side = 4, top = 26, bottom = 4, gap = 8 } -- room for its tabs above it

local function boxOf(f, ue)
	if type(f) ~= "table" then return nil end
	local l, r = N(Try(f, "GetLeft")), N(Try(f, "GetRight"))
	local b, t = N(Try(f, "GetBottom")), N(Try(f, "GetTop"))
	local e = N(Try(f, "GetEffectiveScale"))
	if not (l and r and b and t and e) or r - l < 1 or t - b < 1 then return nil end
	local k = e / ue
	return { l * k, r * k, b * k, t * k }
end

-- (IsVisible may answer 1 on some clients: any true value counts)
local function seen(f) return type(f) == "table" and W.Plain(Try(f, "IsVisible")) and true or false end

-- The chat dock shows: the default chat frame itself, or (another of its docked tabs selected,
-- which hides it) the selected docked frame. The dock stands where the default frame stands.
local function dockShown(f)
	if seen(f) then return true end
	if not f.isDocked then return false end
	local cur = rawget(_G, "FCF_GetCurrentChatFrame")
	local sel = type(cur) == "function" and select(2, pcall(cur)) or nil
	if type(sel) ~= "table" then sel = rawget(_G, "SELECTED_CHAT_FRAME") end
	return type(sel) == "table" and sel ~= f and sel.isDocked and seen(sel) or false
end

-- ChatBox(edit): the default chat frame's box with its tab row, whichever docked tab is selected
-- (so a tab switch changes nothing), or nil when the chat is hidden or missing: then there is
-- nothing to keep clear of. edit: with its edit box while it shows (one-off places only, such
-- as a toast: it comes and goes with every line typed).
function UI.ChatBox(edit)
	local f = DEFAULT_CHAT_FRAME
	if type(f) ~= "table" or not dockShown(f) then return nil end
	local ue = N(Try(UIParent, "GetEffectiveScale"))
	if not ue or ue <= 0 then return nil end
	local c = boxOf(f, ue)
	if not c then return nil end
	c = { c[1] - CHAT.side, c[2] + CHAT.side, c[3] - CHAT.bottom, c[4] + CHAT.top }
	local eb = edit and type(f.editBox) == "table" and f.editBox or nil
	local e = eb and seen(eb) and boxOf(eb, ue)
	if e then c = { math.min(c[1], e[1]), math.max(c[2], e[2]), math.min(c[3], e[3]), math.max(c[4], e[4]) } end
	return c
end

local function overlaps(a, l, b, w, h)
	return a ~= nil and l < a[2] and l + w > a[1] and b < a[4] and b + h > a[3]
end

-- ClearOfChat(l, b, w, h, avoid, edit): a w x h box whose bottom left is at l, b (UIParent units).
-- Returns where it goes: where it is when that is clear of the chat frame (or there is none),
-- else the nearest place beside, under or over the chat that is on the screen and clear of the
-- chat and of every box in avoid (say the open phone); none of those: where it is. A third
-- value is true when it moved. edit: the chat's edit box counts too, while it shows (UI.ChatBox).
function UI.ClearOfChat(l, b, w, h, avoid, edit)
	local c = UI.ChatBox(edit)
	if not (c and l and b and w and h) or not overlaps(c, l, b, w, h) then return l, b, false end
	local sw, sh = N(Try(UIParent, "GetWidth")), N(Try(UIParent, "GetHeight"))
	if not (sw and sh) then return l, b, false end
	local g = CHAT.gap
	local best, bx, by
	for _, p in ipairs({ { c[2] + g, b }, { c[1] - g - w, b }, { l, c[3] - g - h }, { l, c[4] + g } }) do
		local x = math.max(0, math.min(sw - w, p[1]))
		local y = math.max(0, math.min(sh - h, p[2]))
		local fine = x + w <= sw + 0.5 and y + h <= sh + 0.5 and not overlaps(c, x, y, w, h)
		for _, a in ipairs(fine and avoid or {}) do
			if overlaps(a, x, y, w, h) then fine = false end
		end
		local d = math.abs(x - l) + math.abs(y - b)
		if fine and (not best or d < best) then best, bx, by = d, x, y end
	end
	if not best then return l, b, false end
	return bx, by, true
end

---------------------------------------------------------------------------
-- The action bars, micro menu, bags bar, status bars and party frames: no Wuber
-- frame at its default place is put over them either
---------------------------------------------------------------------------
-- the author (20 Nov): on the square window the phone's default place covered the action bars,
-- and the big button pushed off the phone landed on the chat. The game's frames and Daylight UI's
-- (its bars are DaylightUIBar1..8 and friends, its party frames DaylightUIPartyHeader) are read
-- live: only the shown ones, where they are now, at their own scale. Daylight UI's chat box (its
-- panel) counts as the chat.
local HUD = { gap = 10, chat = 14, big = 0.4, names = {
	"MainMenuBar", "MainActionBar", "MultiBarBottomLeft", "MultiBarBottomRight", "MultiBarLeft", "MultiBarRight",
	"MultiBar5", "MultiBar6", "MultiBar7", "StanceBar", "StanceBarFrame", "PetActionBar", "PetActionBarFrame",
	"PossessActionBar", "PossessBarFrame", "MicroMenuContainer", "MicroButtonAndBagsBar", "BagsBar",
	"MainStatusTrackingBarContainer", "SecondaryStatusTrackingBarContainer", "PartyFrame", "CompactPartyFrame",
	"PartyMemberFrame1", "PartyMemberFrame2", "PartyMemberFrame3", "PartyMemberFrame4",
	"DaylightUIBar1", "DaylightUIBar2", "DaylightUIBar3", "DaylightUIBar4", "DaylightUIBar5", "DaylightUIBar6",
	"DaylightUIBar7", "DaylightUIBar8", "DaylightUIStanceBar", "DaylightUIPetBar", "DaylightUIPossessBar",
	"DaylightUITotemBar", "DaylightUIPartyHeader", "DaylightUIReputationBar", "DaylightUIChatPanel",
	"DaylightUIChatSidePanel", "DaylightUIDataBar", "DaylightUIInfoPanel",
} }

-- HudBoxes(): the boxes of those that show now ({ left, right, bottom, top }, UIParent units).
-- A frame faded out still counts (Daylight UI fades its bars by alpha, on mouseover or out of
-- combat, and they come back in a fight when nothing secure can move), and its alpha never
-- changes the boxes. One that would cover most of the screen (a holder, not a bar) does not count.
function UI.HudBoxes()
	local out = {}
	local ue = N(Try(UIParent, "GetEffectiveScale"))
	local sw, sh = N(Try(UIParent, "GetWidth")), N(Try(UIParent, "GetHeight"))
	if not (ue and ue > 0 and sw and sh) then return out end
	for _, name in ipairs(HUD.names) do
		local f = rawget(_G, name)
		local c = seen(f) and boxOf(f, ue)
		if c and (c[2] - c[1]) * (c[4] - c[3]) <= HUD.big * sw * sh then out[#out + 1] = c end
	end
	return out
end

-- the chat (its gap) and the HUD (theirs) as boxes to keep out of; avoid boxes keep a gap of 8
local function blocks(avoid, edit)
	local list = {}
	local c = UI.ChatBox(edit)
	if c then list[1] = { c[1] - HUD.chat, c[2] + HUD.chat, c[3] - HUD.chat, c[4] + HUD.chat, 2 } end
	for _, h in ipairs(UI.HudBoxes()) do
		list[#list + 1] = { h[1] - HUD.gap, h[2] + HUD.gap, h[3] - HUD.gap, h[4] + HUD.gap, 1 }
	end
	local soft = #list
	for _, a in ipairs(avoid or {}) do
		if type(a) == "table" and a[4] then list[#list + 1] = { a[1] - 8, a[2] + 8, a[3] - 8, a[4] + 8, 0 } end
	end
	return list, soft
end

-- how much of the chat and the HUD a w x h box at x, y covers (the chat counts double); nil when
-- it touches an avoid box (the open phone)
local function covered(list, soft, x, y, w, h)
	local sum = 0
	for i, k in ipairs(list) do
		local cw = math.min(x + w, k[2]) - math.max(x, k[1])
		local ch = math.min(y + h, k[4]) - math.max(y, k[3])
		if cw > 0.01 and ch > 0.01 then
			if i > soft then return nil end
			sum = sum + cw * ch * k[5]
		end
	end
	return sum
end

-- ClearOfHud(l, b, w, h, avoid, edit): like UI.ClearOfChat, but clear of the action bars, micro
-- menu, bags bar, status bars and party frames as well (UI.HudBoxes), with room to breathe round
-- each. Where it is when that is clear, else the nearest place on the screen clear of all of them
-- and of every box in avoid; none: the place that covers the least of them (never one over an
-- avoid box). Returns l, b, moved, clear (false: it still covers some of them).
function UI.ClearOfHud(l, b, w, h, avoid, edit)
	if not (l and b and w and h) then return l, b, false, true end
	local sw, sh = N(Try(UIParent, "GetWidth")), N(Try(UIParent, "GetHeight"))
	local list, soft = blocks(avoid, edit)
	local here = covered(list, soft, l, b, w, h)
	if not (sw and sh) or here == 0 then return l, b, false, here == 0 end
	local xs, ys = { l, 0, sw - w }, { b, 0, sh - h }
	for _, k in ipairs(list) do
		xs[#xs + 1], xs[#xs + 2] = k[2], k[1] - w
		ys[#ys + 1], ys[#ys + 2] = k[4], k[3] - h
	end
	local best, bc, bx, by
	for _, px in ipairs(xs) do
		local x = math.max(0, math.min(sw - w, px))
		for _, py in ipairs(ys) do
			local y = math.max(0, math.min(sh - h, py))
			local c = covered(list, soft, x, y, w, h)
			local d = math.abs(x - l) + math.abs(y - b)
			if c and (not bc or c < bc - 0.5 or (c <= bc + 0.5 and d < best)) then best, bc, bx, by = d, c, x, y end
		end
	end
	if not bc or (here and bc >= here - 0.5) then return l, b, false, false end
	return bx, by, true, bc == 0
end

---------------------------------------------------------------------------
-- Toasts: slide down from the top centre, one at a time (a new one replaces it), gone after
-- 4 s (favourite and watch toasts stay 6 s)
---------------------------------------------------------------------------

do -- the toasts (a block: its locals stay out of the file's top level)
local toasts, toastPool = {}, {}
local toastHost
local TOAST_W, TOAST_H, TOAST_GAP, TOAST_TOP = 320, 56, 8, -18
local TOAST_KIND = {
	found = { colour = "glow", glyph = "check", sound = "found" },
	summon = { colour = "magenta", glyph = "summon", sound = "alert" },
	request = { colour = "glow", glyph = "summon", sound = "found" },
	info = { colour = "accent", glyph = "ride" },
	fav = { colour = "magenta", glyph = "heart", sound = "found", stay = 6 },
	watch = { colour = "glow", glyph = "bell", sound = "found", stay = 6 },
	warn = { colour = "red", text = "!" },
	error = { colour = "red", text = "!" },
	-- the driver's alerts (DRIVE_ALERT kinds; UI_Drive.lua plays the sound)
	portal = { colour = "red", glyph = "summon", stay = 8, sticky = true },
	shards = { colour = "red", text = "!" },
	advert = { colour = "glow", glyph = "bell", stay = 6 },
	nonpayer = { colour = "red", glyph = "lock", stay = 10 },
	blocked = { colour = "red", glyph = "lock", stay = 10 },
	paid = { colour = "gold", glyph = "coin" },
	away = { colour = "muted", glyph = "clock", stay = 8 },
	offer = { colour = "glow", glyph = "summon", stay = 6 },
	-- (2.3) a rider asks the driver for a raincheck (UI.Driver.Mini; a click opens
	-- "Give raincheck"): 10 s, so there is time to click; not sticky, no sound of its own
	raincheck = { colour = "glow", glyph = "clock", stay = 10 },
	-- (round 11) "Wuber 2.3.1 is out" (Net.Update): once per session, quiet, 8 s to read it
	update = { colour = "accent", glyph = "star", stay = 8 },
	-- (decisions N) "3 settings reset." with its Undo button (UI.UndoToast): 10 s to change your mind
	undo = { colour = "accent", glyph = "check", stay = 10 },
}
-- glyphs on light circles are drawn in ink, on dark ones in white
local LIGHT = { glow = true, accent = true, gold = true, amber = true, magenta = true, muted = true } -- (design 1) accent is the one violet: ink on it

-- Where toasts go (x offset from the screen's centre, y of the first one from its top): at the
-- top of the screen, but never over the open window's tabs - then just above the phone, else
-- beside it, else under it (the author, 18 Nov: toasts landed on Ride / Trips / Drive).
local toastX, toastTop = 0, TOAST_TOP
-- the widest toast now up: a toast widens when a word of its text is wider than the text's room (toastWiden below)
local function toastW()
	local w = TOAST_W
	for _, t in ipairs(toasts) do if (t.w or 0) > w then w = t.w end end
	return w
end
-- the height of the toasts up, stacked (a taller toast, or two, needs more room than TOAST_H)
local function toastStackH()
	local h = 0
	for i, t in ipairs(toasts) do h = h + (t.h or TOAST_H) + (i > 1 and TOAST_GAP or 0) end
	return math.max(h, TOAST_H)
end
-- (returns the open phone's box, for the chat check below)
local function phonePlace()
	toastX, toastTop = 0, TOAST_TOP
	local ph = ui.phone or ui.win
	-- (IsVisible, not IsShown: the phone stays shown inside a window that is closed)
	if not (ph and W.Plain(Try(ph, "IsVisible"))) then return nil end
	local ue = N(Try(UIParent, "GetEffectiveScale")) or 1
	local pe = N(Try(ph, "GetEffectiveScale")) or ue
	local l, r, t, b = N(Try(ph, "GetLeft")), N(Try(ph, "GetRight")), N(Try(ph, "GetTop")), N(Try(ph, "GetBottom"))
	local sw, sh = N(Try(UIParent, "GetWidth")), N(Try(UIParent, "GetHeight"))
	if not (l and r and t and b and sw and sh) or ue <= 0 then return nil end
	local k = pe / ue
	l, r, t, b = l * k, r * k, t * k, b * k
	local box = { l, r, b, t }
	local tw, th = toastW(), toastStackH()
	-- the screen-top toast clears the window: nothing to move
	if sh + TOAST_TOP - th > t + 4 or r < sw / 2 - tw / 2 or l > sw / 2 + tw / 2 then return box end
	-- above or under: centred on the primary pane (the left one when the window unfolds)
	local cx = l + ((ph == ui.phone and KitMod.BEZEL or 0) + KitMod.WIN_W / 2) * k - sw / 2
	if sh - t >= th + 16 then
		toastX, toastTop = cx, (t + 10 + th) - sh
	elseif sw - r >= tw + 16 then
		toastX, toastTop = r + 12 + tw / 2 - sw / 2, t - 40 - sh
	elseif l >= tw + 16 then
		toastX, toastTop = l - 12 - tw / 2 - sw / 2, t - 40 - sh
	elseif b >= th + 16 then
		toastX, toastTop = cx, (b - 10) - sh
	end
	return box
end

-- and never over the chat frame (a squarer game window, or a UI pack that moved it);
-- nor an action bar or the party frames; (decisions N2) nor the What's new card (WuberNewsCard)
local function toastPlace()
	local box = phonePlace()
	local sw, sh = N(Try(UIParent, "GetWidth")), N(Try(UIParent, "GetHeight"))
	if not (sw and sh) then return end
	local th = toastStackH()
	local tw = toastW()
	local l, b = sw / 2 + toastX - tw / 2, sh + toastTop - th
	-- (decisions N2) nor over the What's new card while it is up: it stands beside the phone, where a toast goes too
	local avoid = box and { box } or nil
	local news = rawget(_G, "WuberNewsCard")
	local ue = N(Try(UIParent, "GetEffectiveScale"))
	local card = ue and ue > 0 and seen(news) and boxOf(news, ue)
	if card then
		avoid = avoid or {}
		avoid[#avoid + 1] = card
	end
	local nl, nb, moved = UI.ClearOfHud(l, b, tw, th, avoid, true)
	if moved then toastX, toastTop = nl + tw / 2 - sw / 2, nb + th - sh end
	-- a wide toast centred on a phone near the screen's edge would hang off it: keep it inside, with a margin of 12
	if tw <= sw - 24 then
		toastX = math.max(12 + tw / 2 - sw / 2, math.min(sw / 2 - 12 - tw / 2, toastX))
	end
end
UI.ToastPlace = function() toastPlace() return toastX, toastTop end

-- (round 11) whether a toast is on screen (Net.Update waits for it to go before its own)
function UI.ToastShowing() return #toasts > 0 end

-- a toast grows taller to hold its whole text (never cut): a 2 line toast is TOAST_H, each line more adds TOAST_LINE
local TOAST_LINE, TOAST_ROOM = 17, 251 -- the text's width: TOAST_W less the icon (13 + 30 + 12) and the right margin 14
local UNDO = { w = 66, h = 28, right = 12, gap = 10, tip = "Puts back what was just reset." } -- (decisions N) the Undo button
local function toastHeight(t)
	local fs = t.text
	local need = W.Num(fs.GetUnboundedStringWidth and fs:GetUnboundedStringWidth()) or 0
	if need <= 0 then need = #(W.Str(fs:GetText()) or "") * 7 end
	local lines = math.max(1, math.ceil(need * 1.08 / ((t.room or TOAST_ROOM) + (t.extra or 0))))
	local h = TOAST_H + TOAST_LINE * math.max(0, lines - 2)
	-- the text's own height as the game lays it out (a larger text size makes the lines taller than TOAST_LINE): 11 above and below
	local drawn = W.Num(Try(fs, "GetStringHeight")) or 0
	return math.max(h, math.ceil(drawn + 22))
end

-- The game never breaks a word across lines: a word wider than the text's room is cut with "...". So the toast gets
-- wider, by what that word needs, up to the screen less a margin (the same 1.08 spare as the height above). When even
-- that is not enough (a word wider than the screen) the text stays as it is: nothing else keeps the characters whole.
local function toastWiden(t)
	local probe = t.probe
	if not probe then
		probe = T.Text(t.card, "body", "white", "LEFT", "medium")
		Try(probe, "SetWordWrap", false)
		probe:SetAlpha(0)
		t.probe = probe
	end
	local widest = 0
	for word in (W.Str(t.text:GetText()) or ""):gmatch("%S+") do
		probe:SetText(word)
		widest = math.max(widest, W.Num(T.TextWidth(probe, word)) or 0)
	end
	local sw = N(Try(UIParent, "GetWidth")) or 0
	local extra = math.max(0, math.ceil(widest * 1.08 - (t.room or TOAST_ROOM)))
	if sw > 0 then extra = math.min(extra, math.max(0, sw - 24 - TOAST_W)) end
	t.extra, t.w = extra, TOAST_W + extra
	t:SetWidth(t.w)
end

local function toastY(i)
	local y = toastTop
	for j = 1, i - 1 do y = y - ((toasts[j] and toasts[j].h) or TOAST_H) - TOAST_GAP end
	return y
end

local function layoutToasts()
	for i, t in ipairs(toasts) do t.targetY = toastY(i) end
	if toastHost then toastHost:Show() end
end

local function removeToast(t, quick)
	for i, x in ipairs(toasts) do
		if x == t then
			table.remove(toasts, i)
			break
		end
	end
	t.token = (t.token or 0) + 1
	A.FadeOut(t, quick and 0.1 or 0.22, function()
		t:Hide()
		if t.undoFn then t.undoFn, t.onClick = nil, nil end -- (decisions N) the reset is final: what it removed is forgotten
		toastPool[#toastPool + 1] = t
	end)
	layoutToasts()
end

local function buildToast()
	local t = CreateFrame("Button", nil, UIParent)
	t:SetSize(TOAST_W, TOAST_H)
	t:SetFrameStrata("FULLSCREEN_DIALOG")
	t.card = T.Card(t, TOAST_W, TOAST_H, { colour = { 0.086, 0.086, 0.157, 0.97 }, radius = 18, border = "line" })
	t.card:SetAllPoints(t)
	t.icon = T.Circle(t.card, 30, "white", "ARTWORK")
	t.icon:SetPoint("LEFT", t.card, "LEFT", 13, 0)
	t.glyph = T.Icon(t.card, "check", 16, "ink", "OVERLAY")
	t.glyph:SetPoint("CENTER", t.icon, "CENTER")
	t.mark = T.Text(t.card, "heading", "ink", "CENTER", "bold")
	t.mark:SetPoint("CENTER", t.icon, "CENTER", 0, 0)
	t.text = T.Text(t.card, "body", "white", "LEFT", "medium")
	t.text:SetPoint("LEFT", t.icon, "RIGHT", 12, 0)
	t.text:SetPoint("RIGHT", t.card, "RIGHT", -14, 0)
	Try(t.text, "SetWordWrap", true)
	Try(t.text, "SetMaxLines", 0)
	t:RegisterForClicks("LeftButtonUp")
	safeScript(t, "OnClick", function(self)
		local fn = self.onClick
		removeToast(self, true)
		if fn then fn() else UI.Toggle(true) end
	end)
	T.Tip(t, "Wuber", function(self)
		if self.tip then return self.tip end
		if self.onClick then return "Click to see this driver and book a ride." end
		return "Click to open Wuber."
	end)
	return t
end

local function buildToastHost()
	toastHost = CreateFrame("Frame", nil, UIParent)
	toastHost:SetSize(1, 1)
	toastHost:SetPoint("TOP", UIParent, "TOP", 0, 0)
	toastHost:Hide()
	safeScript(toastHost, "OnUpdate", function(self, elapsed)
		local moving = false
		-- the window opened, closed or moved while a toast is up: find its place again (4 times a second)
		self.acc = (self.acc or 0) + (elapsed or 0)
		if self.acc >= 0.25 and #toasts > 0 then
			self.acc = 0
			local ox, oy = toastX, toastTop
			toastPlace()
			if ox ~= toastX or oy ~= toastTop then
				for i, t in ipairs(toasts) do t.targetY = toastY(i) end
			end
		end
		local k = math.min(1, (elapsed or 0) * 12)
		for _, t in ipairs(toasts) do
			local y = t.curY or t.targetY
			if t.targetY and math.abs(y - t.targetY) > 0.5 then
				y = y + (t.targetY - y) * k
				moving = true
			else
				y = t.targetY or y
			end
			if y ~= t.curY or t.curX ~= toastX then
				t.curY, t.curX = y, toastX
				t:ClearAllPoints()
				t:SetPoint("TOP", UIParent, "TOP", toastX, y)
			end
		end
		if not moving and #toasts == 0 then self:Hide() end
	end)
end

-- Toast(text, kind, onClick): kind "found", "summon", "request", "info", "fav", "watch", "warn",
-- "error", or a driver alert kind (portal, shards, advert, nonpayer, blocked, paid, away, offer,
-- raincheck), or "update" (a newer Wuber is out); an unknown kind looks like "info". onClick (optional) runs when the toast is
-- clicked (default: open the window).
function UI.Toast(text, kind, onClick)
	text = S(text)
	if not text then return nil end
	local spec = TOAST_KIND[kind or "info"] or TOAST_KIND.info
	local t0 = now()
	for _, x in ipairs(toasts) do
		if x.message == text and t0 - (x.at or 0) < 2 then return x end -- no repeats
	end
	if not toastHost then buildToastHost() end
	-- "CLICK THE PORTAL" jumps the queue and is not pushed off by a lesser toast while it stays
	-- (prep-242 AU24-24) an Undo toast is never lost: it stacks under the portal toast instead of being dropped
	local cur = toasts[1]
	local stack = false
	if cur and TOAST_KIND[cur.kind or ""] and TOAST_KIND[cur.kind].sticky and not spec.sticky
		and t0 - (cur.at or 0) < (TOAST_KIND[cur.kind].stay or 4) then
		if kind ~= "undo" then return nil end
		stack = true
	end
	if not stack then
		while #toasts >= 1 do removeToast(toasts[1], true) end
	end
	local t = table.remove(toastPool) or buildToast()
	t.message, t.at, t.onClick, t.kind, t.tip = text, t0, onClick, kind or "info", nil
	t.undoFn, t.room, t.extra, t.w = nil, nil, 0, TOAST_W
	if t.undo then -- (decisions N) a toast that had the Undo button: a plain one again
		t.undo:Hide()
		t.text:SetPoint("RIGHT", t.card, "RIGHT", -14, 0)
	end
	t.text:SetText(text)
	toastWiden(t)
	t.h = toastHeight(t)
	t:SetHeight(t.h)
	t.icon:SetVertexColor(T.RGB(spec.colour))
	if spec.glyph then
		t.glyph:SetTexture(T.MEDIA .. spec.glyph)
		t.glyph:SetVertexColor(T.RGB(LIGHT[spec.colour] and "ink" or "white"))
		t.glyph:Show()
		t.mark:Hide()
	else
		t.glyph:Hide()
		t.mark:SetText(spec.text or "")
		t.mark:SetTextColor(T.RGB(LIGHT[spec.colour] and "ink" or "white"))
		t.mark:Show()
	end
	toasts[#toasts + 1] = t
	toastPlace()
	t.targetY = toastY(#toasts)
	t.curY = t.targetY + (toastX == 0 and toastTop == TOAST_TOP and 70 or 24) -- starts a little above, slides down
	t:ClearAllPoints()
	t:SetPoint("TOP", UIParent, "TOP", toastX, t.curY)
	t.curX = toastX
	A.FadeIn(t, 0.22)
	layoutToasts()
	if spec.sound then W.Sound(spec.sound) end
	local token = (t.token or 0) + 1
	t.token = token
	W.After(spec.stay or 4, function()
		if t.token == token then removeToast(t) end
	end)
	return t
end

-- (decisions N) Undo after a reset. UndoToast(text, undo): the toast with an "Undo" button at its right, for 10 s. A
-- click on the button (or on the toast) runs undo() once and takes the toast away; when the toast goes by itself, or
-- another toast replaces it, undo is dropped and the reset is final. Returns the toast (nil when none could show).
local function runUndo(t)
	local fn = t.undoFn
	if not fn then return end
	t.undoFn, t.onClick = nil, nil
	for _, x in ipairs(toasts) do
		if x == t then removeToast(t, true) break end
	end
	fn()
end

function UI.UndoToast(text, undo)
	local t = UI.Toast(text, "undo")
	if type(t) ~= "table" or type(undo) ~= "function" or not t.card then return t end
	if not t.undo then
		t.undo = T.Pill(t.card, "Undo", "dark", UNDO.w, UNDO.h) -- the second button kind: gold is only for a price and the one main button
		t.undo:SetPoint("RIGHT", t.card, "RIGHT", -UNDO.right, 0)
		safeScript(t.undo, "OnClick", function() runUndo(t) end)
		T.Tip(t.undo, "Undo", UNDO.tip)
	end
	t.undo:Show()
	t.text:SetPoint("RIGHT", t.card, "RIGHT", -UNDO.right - UNDO.w - UNDO.gap, 0)
	t.room = TOAST_ROOM + 14 - UNDO.right - UNDO.w - UNDO.gap
	t.undoFn, t.tip = undo, UNDO.tip
	t.onClick = function() runUndo(t) end
	toastWiden(t)
	t.h = toastHeight(t)
	t:SetHeight(t.h)
	toastPlace()
	layoutToasts()
	return t
end

-- whether a toast with a live Undo is up (a second, empty reset then says nothing, so the Undo stays)
function UI.UndoPending()
	for _, x in ipairs(toasts) do
		if x.undoFn then return true end
	end
	return false
end
end -- the toasts

