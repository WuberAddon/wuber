-- Module: Drive.Button
-- Purpose: The secure WuberDriveButton: size, place, key binding, dock/float, paint, clicks, skin,
--   DR.BuildButton, Skip, start-up.
-- API: DR.AutoScale, DR.Scale, DR.SetScale, DR.ResetPosition, DR.ApplyBinding, DR.SetKey, B.Place,
--   B.Dock, B.Floating, B.Docked, B.Solo, B.MiniRows, B.SetShown, B.SetLocked, B.KeepClosed, B.Refresh, B.Clicked,
--   DR.BuildButton, DR.SkipTarget, DR.Skip
-- Internals: (none). the ticker's watch: a wanted floating button that is hidden, faded,
--   off the screen or under the window is re-placed; one that cannot clear the window goes above it,
--   alone (round 31: B.Solo, its console would cover the phone), at the screen's least covering corner.
--   at its default place (none saved) it keeps clear of the chat frame too (W.UI.ClearOfChat,
--   UI.Toasts, at run time) and is re-placed when the chat frame moves. and of the action bars
--   and party frames (W.UI.ClearOfHud), also where the open phone pushes it off a place the player chose. (round 19 review) never over
--   or under the open phone: with no room for its console beside it, a shorter console (round 31: fewer
--   rows, B.MiniRows), then the button alone (B.Solo; the console waits); re-placed at once when the window folds or unfolds (FOLD). (BRIEF22 L3-L5) no clear place
--   beside the open phone at the chosen size: a smaller button that fits beside it (fitBeside, not under
--   FIT_MIN), the chosen size again once the phone shuts; its top never leaves the screen (the console's room is
--   what the screen has, or the console as it is now on a short screen, with only the rows that fit: B.MiniRows); at its default place off the minimap
--   and its button (minimapBox, an avoid box that gives way to the chat), the watch re-placing when they move.
--   Over the open phone it lies above the window's own sheet layers too (OVER_LEVEL).
-- Uses: Drive.Cast, Drive.Plan
-- Later: (none)
-- Events: listens On PLAYER_REGEN_DISABLED, On PLAYER_REGEN_ENABLED, login, Listen DRIVE, Listen
--   DRIVE_CREW, Listen PROVIDER, Listen FOLD, login; fires -
-- Standalone: no
-- Test: tests/drive/button_test.lua
-- From: Drive_Button.lua 1019-1615 (Wuber 2.2.1)
--
local ADDON, W = ...
local Mod = W.Module("Drive.Button", { "Drive.Cast", "Drive.Plan" })
local CastMod = W.Mod("Drive.Cast")
local PlanMod = W.Mod("Drive.Plan")
local COLORS, HEIGHT, WIDTH, btnDB = CastMod.COLORS, CastMod.HEIGHT, CastMod.WIDTH, CastMod.btnDB
local call, calls, isLeader, mode = CastMod.call, CastMod.calls, CastMod.isLeader, CastMod.mode
local now, raidTold, sorted, state = CastMod.now, CastMod.raidTold, CastMod.sorted, CastMod.state
local units = CastMod.units
local hook = PlanMod.hook
local DR = W.Drive

local plain, num, str = W.Plain, W.Num, W.Str

local B = DR.Button

local skinButton, skin -- (the look, below)

-- The words are fitted when they are set, to the room they have then. The button gets
-- its size (the slot's docked, WIDTH floating) and its anchors only when it is placed, which is
-- after the first paint at login and after the words change on docking, so a new place fits them
-- again (cheap: two labels, only when the place really changed).
local function refit(b)
	local T = W.Theme
	if not (T and T.Fit) then return end
	if b.title then pcall(T.Fit, b.title) end
	if b.sub then pcall(T.Fit, b.sub) end
end

-- (round 33, HUNT-117) A title that is still too wide at the smallest size (three jobs owed: "Thank Elm,
-- Wuber tip for Birch, Remove Elm") wraps onto a second line at that size, growing upward from its
-- bottom anchor (the subtitle sits under it), instead of losing its last job to "...". A title that
-- fits keeps its single big line.
local function fitTitle(b)
	local T, t = W.Theme, b.title
	if not (T and T.Fit and T.MeasureText and T.SetFont and t and t.wuberBase) then return end
	local min = t.wuberMin or T.SIZE.body
	local text = t.wuberText or ""
	-- (ING-01) the game gives NO value for a label it has not placed yet: take one value of each, then a number
	local l, r = t:GetLeft(), t:GetRight()
	l, r = W.Num(l), W.Num(r)
	local room = l and r and r > l and r - l or nil
	local base = t.wuberBig or t.wuberBase
	t.wuberBig = base
	local function wrapFor(on)
		if on then
			t.wuberLines = 2
			pcall(T.SetFont, t, min, t.wuberWeight)
		else
			t.wuberLines = nil
			pcall(T.SetFont, t, base, t.wuberWeight)
		end
		pcall(T.Fit, t)
	end
	wrapFor(false)
	local tooWide = t.wuberPx and t.wuberPx <= min and pcall(t.IsTruncated, t) and t:IsTruncated() == true
	if not tooWide and room then
		tooWide = T.MeasureText(text, min, t.wuberWeight) * (t.wuberSpare or 1) > room
	end
	if tooWide then wrapFor(true) end
end

---------------------------------------------------------------------------
-- Size, place, key
---------------------------------------------------------------------------

-- Until a size is chosen, a small game window gets a bigger button: the game shrinks
-- everything with the window, so a window half as tall as a 4K screen draws it at ~1.7.
function DR.AutoScale()
	if type(GetPhysicalScreenSize) ~= "function" then return 1 end
	local ok, _, h = pcall(GetPhysicalScreenSize)
	h = ok and num(h) or nil
	if not h or h <= 0 then return 1 end
	return math.max(1, math.min(2.2, math.floor(1800 / h * 10 + 0.5) / 10))
end

function DR.Scale()
	local b = btnDB()
	if b.sizeSet then return math.max(0.5, math.min(3, tonumber(b.scale) or 1)) end
	return DR.AutoScale()
end

-- A size chosen (0.5 to 3), or nil: back to fitting the window.
function DR.SetScale(n)
	local b = btnDB()
	n = tonumber(n)
	if n then
		b.scale, b.sizeSet = math.max(0.5, math.min(3, n)), true
	else
		b.sizeSet = false
	end
	B.Place()
	call("Changed")
	return DR.Scale()
end

function DR.ResetPosition()
	btnDB().pos = nil
	B.Place()
end

local function savePosition()
	local b = DR.button
	if not b then return end
	local point, _, relative, x, y = b:GetPoint(1)
	if point then
		-- (AUD-103) the offsets are in the button's own scale (shrunk beside the open phone); placeFloating
		-- reads them at the chosen size, so convert
		local k = (tonumber(plain(b:GetScale())) or 1) / DR.Scale()
		btnDB().pos = { point, relative or point, (tonumber(x) or 0) * k, (tonumber(y) or 0) * k }
	end
end

-- The key that presses the button. The key is account-wide, so it is bound only on a
-- character where Wuber's engine runs (no Ritual Rides or other provider driving, a Warlock or
-- a crew member): on any other character the key keeps its own action.
function DR.ApplyBinding()
	W.AfterCombat(function()
		local b = DR.button
		if not b or type(ClearOverrideBindings) ~= "function" then return end
		ClearOverrideBindings(b)
		local active = call("Lock") == nil and call("Active") == true
		state.bindActive = active
		if not active then return end
		local key = btnDB().key
		if type(key) == "string" and key ~= "" and type(SetOverrideBindingClick) == "function" then
			SetOverrideBindingClick(b, true, key, "WuberDriveButton", "LeftButton")
		end
	end)
end

-- A key for the button ("F5", "SHIFT-1"), or nil to clear it.
function DR.SetKey(key)
	key = str(key)
	if key then
		key = key:upper():gsub("%s+", "")
		if key == "" or key == "NONE" or key == "ESCAPE" then key = nil end
	end
	btnDB().key = key
	DR.ApplyBinding()
	call("Changed")
	return key
end

---------------------------------------------------------------------------
-- Showing, docking, floating
---------------------------------------------------------------------------

local function N(v)
	v = plain(v)
	return type(v) == "number" and v or nil
end

-- Whether the button belongs on screen at all, docked or floating.
local function wanted()
	if call("Lock") ~= nil then return false end
	if call("Active") ~= true then return false end
	local b = btnDB()
	if state.dockedNow then return true end -- (AUD-104) the slot is really in use, not just handed over
	if b.shown == false then return false end
	if not call("IsOpen") and not b.keepClosed then
		local n = 0
		for _ in pairs(DR.customers or {}) do n = n + 1 end
		if n == 0 then return false end
	end
	return true
end

local function placeDocked(b, slot)
	-- (issue 11) while the window is dragged out of combat the card is anchored to its slot, so it moves with
	-- the window every frame; nothing here moves it until the drag ends
	if state.following then return true end
	local l, bt = N(slot:GetLeft()), N(slot:GetBottom())
	local w, h = N(slot:GetWidth()), N(slot:GetHeight())
	local se = N(slot:GetEffectiveScale())
	local ue = N(UIParent:GetEffectiveScale())
	if not (l and bt and w and h and se and ue) or w <= 0 or h <= 0 or ue <= 0 then return false end
	local s = se / ue
	local win = WuberFrame
	-- (the author 18 Nov) a strata above the window, like its other secure overlays: WuberFrame is a
	-- toplevel frame, which the game raises above every frame of its own strata whenever it is
	-- shown or clicked, so in that strata the button ended under its slot and clicks fell on the
	-- slot. Frame levels stop at 10000.
	local strata = "FULLSCREEN_DIALOG"
	local level = math.min(10000, ((win and N(win:GetFrameLevel())) or 0) + 100)
	-- the open world map too: it is raised to the top of its layer when the game opens it, which may be after the
	-- button was placed (the Drive tab up, then the map): the button goes above it, and back when the map shuts
	local kit = W.Mod("UI.Kit")
	if kit and kit.OverMap then strata, level = kit.OverMap(strata, level) end
	local sig = ("D%.1f:%.1f:%.1f:%.1f:%.4f:%s:%d"):format(l, bt, w, h, s, tostring(strata), level)
	if state.sig ~= sig then
		b:SetFrameStrata(strata)
		b:SetFrameLevel(level)
		b:SetScale(s)
		b:ClearAllPoints()
		b:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", l, bt)
		b:SetSize(w, h)
		state.sig = sig
		refit(b)
	end
	return true
end

-- The floating button and the mini console under it (about MINI_H tall, at the
-- button's scale) must stay on screen and clear of the open phone. The handset hangs outside
-- WuberFrame (bezel at the sides, status bar on top, home strip below), so its box is the
-- window padded by UI.PHONE. In UIParent units; nil when the window is not shown.
local MINI_H = 300
-- (round 31, HUNT-94) the console's own measures (UI.Driver.Mini, its units): 8 above the rows, 48 a row, 16 the
-- "+N more" line and 38 the pills; at most four rows
local MINI = { rows = 4, row = 48, base = 62 }
local function windowBox()
	local win = WuberFrame
	if type(win) ~= "table" or type(win.IsShown) ~= "function" or not win:IsShown() then return nil end
	local l, r, bt, tp = N(win:GetLeft()), N(win:GetRight()), N(win:GetBottom()), N(win:GetTop())
	local we, ue = N(win:GetEffectiveScale()), N(UIParent:GetEffectiveScale())
	if not (l and r and bt and tp and we and ue) or ue <= 0 then return nil end
	local ph = (W.UI and W.UI.PHONE) or {}
	local bz = N(ph.bezel) or 8
	local top = bz + (N(ph.status) or 26)
	local bot = bz + (N(ph.home) or 15)
	return { (l - bz) * we / ue, (r + bz) * we / ue, (bt - bot) * we / ue, (tp + top) * we / ue }
end

-- (round 244, HUNT-07) the phone's clickable controls now (every shown, mouse-taking Button or CheckButton under the
-- window: its tabs, back arrows, the Me | Crew switch), in UIParent units { l, r, b, t }. Only asked for when no place is clear.
local function phoneControls()
	local out, win = {}, WuberFrame
	local ue = N(UIParent:GetEffectiveScale())
	if type(win) ~= "table" or not ue or ue <= 0 or type(win.GetChildren) ~= "function" then return out end
	local function walk(f, depth)
		if depth > 12 or type(f) ~= "table" then return end
		local ot = type(f.GetObjectType) == "function" and f:GetObjectType() or nil
		if (ot == "Button" or ot == "CheckButton") and f:IsVisible() and f:IsMouseEnabled() then
			local l, r, bt, tp, e = N(f:GetLeft()), N(f:GetRight()), N(f:GetBottom()), N(f:GetTop()), N(f:GetEffectiveScale())
			if l and r and bt and tp and e and r - l > 1 and tp - bt > 1 and (N(f:GetEffectiveAlpha()) or 1) > 0.05 then
				local k = e / ue
				out[#out + 1] = { l * k, r * k, bt * k, tp * k }
			end
		end
		if type(f.GetChildren) == "function" then
			for _, c in ipairs({ f:GetChildren() }) do walk(c, depth + 1) end
		end
	end
	walk(win, 0)
	return out
end

local function boxKey(bx)
	return bx and ("%.0f:%.0f:%.0f:%.0f"):format(bx[1], bx[2], bx[3], bx[4]) or "-"
end

-- After the normal anchor is set: when the button or its console would sit under the phone or
-- run off the screen, move the anchor (never the saved position) to the nearest clear place:
-- right of it, left of it, below it, above it. At its default place (free: none
-- saved) it keeps clear of the chat frame too; a place the player chose is theirs.
-- and the shown action bars and party frames (UI.HudBoxes): one moving re-places it
-- the minimap and Wuber's button on its rim, in UIParent units: { l, r, b, t } or nil. At its default
-- place the big button and its console keep off it (they sat on it at size 2.2).
local function minimapBox()
	local ue = N(UIParent:GetEffectiveScale())
	if not ue or ue <= 0 then return nil end
	local box
	for _, f in ipairs({ rawget(_G, "Minimap") or false, rawget(_G, "WuberMinimapButton") or false }) do
		if type(f) == "table" and type(f.IsVisible) == "function" and f:IsVisible() then
			local l, r, bt, tp, e = N(f:GetLeft()), N(f:GetRight()), N(f:GetBottom()), N(f:GetTop()), N(f:GetEffectiveScale())
			if l and r and bt and tp and e then
				local k = e / ue
				l, r, bt, tp = l * k, r * k, bt * k, tp * k
				box = box and { math.min(box[1], l), math.max(box[2], r), math.min(box[3], bt), math.max(box[4], tp) } or { l, r, bt, tp }
			end
		end
	end
	return box
end

-- the console's height now (its own units), or nil while it is hidden
local function miniHeight()
	local m = rawget(_G, "WuberDriveMini")
	return type(m) == "table" and type(m.IsShown) == "function" and m:IsShown() and N(m:GetHeight()) or nil
end

local function chatKey()
	local f, hud = W.UI and W.UI.ChatBox, W.UI and W.UI.HudBoxes
	local k = boxKey(type(f) == "function" and f() or nil) .. "|" .. boxKey(minimapBox()) -- the minimap too
	if type(hud) == "function" then
		for _, x in ipairs(hud()) do k = k .. "|" .. boxKey(x) end
	end
	return k
end

local function keepClear(b, s, free)
	local ue = N(UIParent:GetEffectiveScale())
	local sw, sh = N(UIParent:GetWidth()), N(UIParent:GetHeight())
	local l, bt = N(b:GetLeft()), N(b:GetBottom())
	local be = N(b:GetEffectiveScale())
	state.solo, state.miniRows = false, nil -- (no row cap left over when there is no geometry yet)
	if not (ue and ue > 0 and sw and sh and l and bt and be) then return end
	local k = be / ue
	l, bt = l * k, bt * k
	local gw = math.max(240, WIDTH) * s
	local bh = HEIGHT * s
	local bx = state.winBox
	-- clear of the action bars and party frames too (UI.ClearOfHud), and not only at
	-- the default place: a place the player chose that the open phone pushes it off is no longer
	-- theirs, so where it goes instead keeps off the chat and the bars as well
	local away = W.UI and (W.UI.ClearOfHud or W.UI.ClearOfChat)
	if type(away) ~= "function" then away = nil end
	local pushed = false
	-- at its default place: off the minimap too (an avoid box, as the phone)
	local mm = free and minimapBox() or nil
	local avoid = bx and { bx } or nil
	if mm then
		avoid = avoid or {}
		avoid[#avoid + 1] = mm
	end
	-- boxes gh tall whose top is the button's top (the console hangs under it)
	local function hits(px, py, gh)
		return bx and px < bx[2] and px + gw > bx[1] and py < bx[4] and py + gh > bx[3]
	end
	local function clamp(px, py, gh)
		return math.max(0, math.min(math.max(0, sw - gw), px)), math.max(0, math.min(math.max(0, sh - gh), py))
	end
	-- the nearest place clear of the phone (right of it, left, below, above), then off the chat
	-- where that keeps it clear of the phone; nil: none clear of the phone
	-- (third value: false when it still covers the chat or the bars)
	local function find(gh)
		local x, y = clamp(l, bt + bh - gh, gh)
		if hits(x, y, gh) then
			pushed = true
			for _, c in ipairs({ { bx[2] + 8, y }, { bx[1] - 8 - gw, y }, { x, bx[3] - 8 - gh }, { x, bx[4] + 8 } }) do
				local cx, cy = clamp(c[1], c[2], gh)
				if not hits(cx, cy, gh) then
					x, y = cx, cy
					break
				end
			end
			if hits(x, y, gh) then return nil end
		end
		local clear, onMap = true, false
		if away and (free or pushed) then
			local nx, ny, _, ok = away(x, y, gw, gh, avoid)
			-- the minimap gives way to the chat and the bars: only where a place clear of all of them exists
			-- (fourth value: true when it sits on the minimap for that)
			if ok == false and mm then
				local ax, ay, _, ok2 = away(x, y, gw, gh, bx and { bx } or nil)
				if ok2 ~= false then nx, ny, ok, onMap = ax, ay, ok2, true end
			end
			x, y = nx, ny
			clear = ok ~= false
		end
		return x, y, clear, onMap
	end
	-- the room kept for the console is what the screen has under the button: a big button on a
	-- short screen (2.2 on 768 units: 880 with the whole console) went off the top; now its top stays on it
	-- and when the whole console can't fit under it anyway, room for the console as it is now (so a short box
	-- can still keep off the chat and the minimap)
	local room = MINI_H * s
	local mh = miniHeight()
	local function asNow() state.miniKey = tostring(mh and math.floor(mh + 0.5) or "-") end -- the watch re-places when it changes
	local function rowsRoom(n) return (MINI.base + MINI.row * n) * s + 8 end
	state.miniKey, state.miniRows = nil, nil
	if bh + room > sh then
		-- (round 31, HUNT-94) and the console has only the rows that room holds (B.MiniRows; "+N more in Wuber's
		-- Drive tab" says where the rest are): a raid-sized list at 2.2 on 768 units hung 20 off the bottom
		local n = math.max(0, math.min(MINI.rows, math.floor(((sh - bh - 8) / s - MINI.base) / MINI.row)))
		if n < MINI.rows then state.miniRows = n end
		room = math.min(mh and (mh * s + 8) or rowsRoom(n), rowsRoom(n))
		asNow()
	end
	local gh = bh + math.max(0, math.min(room, sh - bh))
	local x, y, clear, onMap = find(gh)
	-- and where room for the whole console leaves no place clear of the chat, the bars and the
	-- minimap (a big button on the square screen): room for the console as it is now, if that has one
	if onMap or (x and not clear) then asNow() end -- (the console showing or growing may change this)
	if (onMap or (x and not clear)) and mh and bh + mh * s + 8 < gh - 0.5 then
		local g2 = bh + mh * s + 8
		local x2, y2, c2, m2 = find(g2)
		if x2 and c2 and not m2 then
			x, y, clear, onMap, gh = x2, y2, c2, m2, g2
			asNow()
		end
	end
	-- (round 19 review) no room for the console beside the open phone (the unfolded phone on a
	-- square window): the button alone, above or below it, and its console waits (B.Solo).
	-- also when the console's only place would cover the chat or the bars and the
	-- button alone has a clear one
	if bx and (not x or not clear) then
		-- (round 31) a shorter console first: fewer rows where that has a clear place
		for n = (state.miniRows or MINI.rows) - 1, 1, -1 do
			local g = bh + rowsRoom(n)
			local x2, y2, c2, m2 = find(g)
			if x2 and c2 and g < gh - 0.5 then
				x, y, clear, onMap, gh, state.miniRows = x2, y2, c2, m2, g, n
				break
			end
		end
	end
	if bx and (not x or not clear) then
		state.miniRows = nil
		local sx, sy, sclear = find(bh)
		if sx and (not x or sclear) then x, y, gh, state.solo = sx, sy, bh, true end
	end
	state.chatKey = (free or pushed) and chatKey() or nil
	-- no clear place on this screen (a small game window, a big button, the phone
	-- unfolded): the least covered of the four, and the caller lifts the button above the
	-- window. It stayed under it, where nobody could see it until the window moved.
	-- (round 31, HUNT-92) and the button alone (B.Solo): its console there lay over the middle of the phone.
	-- (HUNT-07) the corners of the screen are tried too: the least covered is then a corner, over the edge of
	-- the phone (its tab bar or its bottom tabs), never over the middle of a page (it sat on Earnings'
	-- Me | Crew switch, so a tap on Crew pressed the button)
	local over = false
	if not x then
		gh, state.solo = bh, true
		local function area(px, py)
			local w = math.min(px + gw, bx[2]) - math.max(px, bx[1])
			local h = math.min(py + gh, bx[4]) - math.max(py, bx[3])
			return (w > 0 and h > 0) and w * h or 0
		end
		-- (round 244, HUNT-07) what counts first is the phone's clickable controls covered (a tap on one must never
		-- reach the big button), then the phone's area: a place over the phone's art only beats one over its tabs
		local ctl = phoneControls()
		local function hitArea(px, py)
			local sum = 0
			for _, c in ipairs(ctl) do
				local w = math.min(px + gw, c[2]) - math.max(px, c[1])
				local h = math.min(py + gh, c[4]) - math.max(py, c[3])
				if w > 0 and h > 0 then sum = sum + w * h end
			end
			return sum
		end
		local function worse(a1, a2, b1, b2) return a1 < b1 - 0.5 or (a1 < b1 + 0.5 and a2 < b2 - 0.5) end
		x, y = clamp(l, bt + bh - gh, gh)
		local bestC = hitArea(x, y)
		local best = area(x, y)
		for _, c in ipairs({ { bx[2] + 8, y }, { bx[1] - 8 - gw, y }, { x, bx[3] - 8 - gh }, { x, bx[4] + 8 },
			{ 0, 0 }, { sw, 0 }, { 0, sh }, { sw, sh } }) do
			local cx, cy = clamp(c[1], c[2], gh)
			local a, ca = area(cx, cy), hitArea(cx, cy)
			if worse(ca, a, bestC, best) then x, y, best, bestC = cx, cy, a, ca end
		end
		-- (every place covers a control: a grid over the screen, the least control area, then the least phone area)
		if bestC > 0.5 and #ctl > 0 then
			local nx, ny = 48, 36
			for i = 0, nx do
				for j = 0, ny do
					local cx, cy = clamp((sw - gw) * i / nx, (sh - gh) * j / ny, gh)
					local ca = hitArea(cx, cy)
					if ca < bestC + 0.5 then
						local a = area(cx, cy)
						if worse(ca, a, bestC, best) then x, y, best, bestC = cx, cy, a, ca end
					end
				end
			end
		end
		over = best > 0
	end
	local nb = y + gh - bh -- the button's bottom
	if math.abs(x - l) < 0.5 and math.abs(nb - bt) < 0.5 then return over end
	b:ClearAllPoints()
	b:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", x / s, nb / s)
	return over
end

-- The window box the button has made room for. It follows the window only once the box has
-- changed and then held still for one tick, so a drag or a fold tween never churns the secure
-- button. True when it changed.
local function settleWindow(first)
	local live = windowBox()
	local k = boxKey(live)
	if state.winKey == nil and first then
		state.winBox, state.winKey = live, k
		return true
	end
	if k == state.winKey then
		state.winSeen = nil
		return false
	end
	if state.winSeen ~= k then
		state.winSeen = k
		return false
	end
	state.winBox, state.winKey, state.winSeen = live, k, nil
	return true
end

-- the largest size, below s and not under FIT_MIN, at which the button (with its console, or alone)
-- fits right or left of the open phone's box bx; nil: none
local FIT_MIN = 0.8
-- (prep-242 r3 H) the floating button that must lie over the open phone: above every layer the window raises
-- (sheet holders at 400 plus the sheet's 50, header buttons lifted to 700)
local OVER_LEVEL = 800
local function fitBeside(bx, s)
	local sw = N(UIParent:GetWidth())
	if not (bx and sw) then return nil end
	local room = math.max(bx[1] - 8, sw - bx[2] - 8) - 2
	local fit = math.floor(room / math.max(240, WIDTH) * 100) / 100
	if fit >= FIT_MIN and fit < s - 0.005 then return fit end
	return nil
end

local function placeFloating(b)
	local pos = btnDB().pos
	local s = DR.Scale()
	local free = not (type(pos) == "table" and type(pos[1]) == "string")
	local key = type(pos) == "table" and table.concat({ tostring(pos[1]), tostring(pos[2]), tostring(pos[3]), tostring(pos[4]) }, ":") or "centre"
	settleWindow(true)
	local kit = W.Mod("UI.Kit")
	local _, _, mapKey = kit and kit.OverMap and kit.OverMap("MEDIUM", 0)
	local sig = ("F%s:%.3f:%s:%s"):format(key, s, tostring(state.winKey), tostring(mapKey or ""))
	if state.sig == sig then return end
	b:SetFrameStrata("MEDIUM")
	-- (S1) only when the scale really changes: this re-places while the window folds
	local cur = N(b:GetScale())
	if not cur or math.abs(cur - s) > 0.0001 then b:SetScale(s) end
	b:SetSize(WIDTH, HEIGHT)
	b:ClearAllPoints()
	if not free then
		b:SetPoint(pos[1], UIParent, type(pos[2]) == "string" and pos[2] or pos[1], tonumber(pos[3]) or 0, tonumber(pos[4]) or 0)
	else
		b:SetPoint("CENTER", UIParent, "CENTER", 0, 200)
	end
	-- no clear place at the chosen size beside the open phone (1.5 or 2.2 on a 1365 or 1331 unit wide
	-- screen): a smaller button where it fits beside it, never under FIT_MIN; the chosen size again once the
	-- phone shuts or moves (a new window box re-places it). Out of combat, as every place.
	local over = keepClear(b, s, free)
	local fit = over and fitBeside(state.winBox, s)
	if fit then
		b:SetScale(fit)
		b:ClearAllPoints()
		if not free then
			b:SetPoint(pos[1], UIParent, type(pos[2]) == "string" and pos[2] or pos[1], (tonumber(pos[3]) or 0) * s / fit, (tonumber(pos[4]) or 0) * s / fit)
		else
			b:SetPoint("CENTER", UIParent, "CENTER", 0, 200 * s / fit)
		end
		over = keepClear(b, fit, free)
	end
	-- the window is HIGH: a floating button that has to overlap it goes above it,
	-- as the docked one does, never under it
	-- (prep-242 r3 H) and above the window's own FULLSCREEN_DIALOG layers too: the report sheet (UI.Bug, WuberBug at
	-- level 400) and the Raincheck sheet (UI.Moments, 400) lay over the button's foot (/wuber bug on the square screen,
	-- window at the bottom right), and the header buttons lifted over a sheet's dim (UI.Window, 700) would too
	if over then
		local win = WuberFrame
		local strata, level = "FULLSCREEN_DIALOG", math.min(10000, math.max(OVER_LEVEL, ((win and N(win:GetFrameLevel())) or 0) + 100))
		local kit = W.Mod("UI.Kit")
		if kit and kit.OverMap then strata, level = kit.OverMap(strata, level) end
		b:SetFrameStrata(strata)
		b:SetFrameLevel(level)
	end
	state.sig = sig
	refit(b)
end

-- The words under the title: docked in the Drive tab, plan.here; floating with its
-- console right under it, plan.below ("tap Open below"); alone (B.Solo), plan.sub.
local function subWords(plan)
	if state.dockedNow then return plan.here or plan.sub end
	if not state.solo then return plan.below or plan.sub end
	return plan.sub
end

-- Places and shows (or hides) the button as things stand. Out of combat only.
function B.Place()
	local b = DR.button
	if not b or W.InCombat() then return end
	local slot = state.docked
	if slot and not (slot.IsVisible and slot:IsVisible()) then slot = nil end
	if slot and not placeDocked(b, slot) then slot = nil end
	local was = state.dockedNow
	state.dockedNow = slot ~= nil
	-- leaving the slot: make room for the window as it is now (the box the ticker
	-- settled may be from before the window opened)
	if was and not slot then
		local live = windowBox()
		state.winBox, state.winKey, state.winSeen = live, boxKey(live), nil
	end
	if not slot then placeFloating(b) end
	-- (round 9) docked or floating changes the words under the title (plan.here / plan.sub);
	-- so does its console coming or going beside the open phone (plan.below)
	if type(b.plan) == "table" and b.sub then
		local words = subWords(b.plan) or ""
		if words ~= b.words then
			b.words = words
			b.sub:SetText(words)
		end
	end
	skin(b, state.dockedNow)
	if wanted() then
		if not b:IsShown() then b:Show() end
	elseif b:IsShown() then
		b:Hide()
	end
	if B.onPlace then pcall(B.onPlace, state.dockedNow) end
end

-- (issue 11) the window is being dragged (on = true) or was let go. Out of combat the docked card is
-- anchored to its slot for the drag, so it follows every frame; in combat nothing is moved or anchored (the
-- 0.25 s ticker stays the fallback and re-places it once the fight is over).
local function windowDrag(on)
	local b = DR.button
	-- (T243-2) in a fight the window moves away from the button, which cannot follow: its look is taken off at once (alpha and its
	-- own words only), and the 1 s dock check brings it back should the window be put back where it was
	if on and b and W.InCombat() then B.CombatView(false) return end
	if on then
		if not b or W.InCombat() or not state.dockedNow or not state.docked then return end
		local slot = state.docked
		if not (slot.IsVisible and slot:IsVisible()) then return end
		b:ClearAllPoints()
		b:SetPoint("BOTTOMLEFT", slot, "BOTTOMLEFT", 0, 0)
		state.following = true
		return
	end
	if not state.following then return end
	state.following = false
	state.sig = nil
	if W.InCombat() then
		W.AfterCombat(function() B.Place() end)
	else
		B.Place()
	end
end
W.Listen("WINDOW_DRAG", windowDrag)

-- C's console hands the slot while it shows (nil otherwise). Out of combat only: a fight
-- freezes the button where it is until it is over.
function B.Dock(slot)
	if slot ~= nil and type(slot) ~= "table" then slot = nil end
	state.docked = slot
	state.sig = nil
	if W.InCombat() then
		W.AfterCombat(function() B.Place() end)
		return
	end
	B.Place()
end

-- Whether the button floats on screen now (not docked in the Drive tab).
function B.Floating()
	local b = DR.button
	return b ~= nil and b:IsShown() and not state.dockedNow
end

function B.Docked() return state.dockedNow == true end

-- (round 19 review) floating without its console: no room for it beside the open phone
function B.Solo() return state.solo == true and not state.dockedNow end

-- (round 31) the rows its console has room for where it floats now (fewer than four), or nil: four
function B.MiniRows()
	if state.dockedNow or state.solo then return nil end
	return state.miniRows
end

function B.SetShown(on)
	btnDB().shown = on and true or false
	state.sig = nil
	W.AfterCombat(function() B.Place() end)
	call("Changed")
end

function B.SetLocked(on)
	btnDB().locked = on and true or false
end

function B.KeepClosed(on)
	btnDB().keepClosed = on and true or false
	W.AfterCombat(function() B.Place() end)
end

---------------------------------------------------------------------------
-- Painting and applying the plan
---------------------------------------------------------------------------

local function paint(b, plan, combat)
	local col = COLORS[plan.color] or COLORS.idle
	-- the accent along the bottom (round 7: the hero card's gold line); S3 (round 9): none while
	-- idle or off (closed, raid stopped), a clean full-width line while something is on
	local lit = plan.color ~= nil and plan.color ~= "idle" and plan.color ~= "off" and COLORS[plan.color] ~= nil
	for _, t in ipairs(b.accent or {}) do
		if t.isRing then t:SetVertexColor(col[1], col[2], col[3], 1) else t:SetColorTexture(col[1], col[2], col[3], 1) end
		t:SetShown(lit)
	end
	-- the face lights up for a click, dims while idle (only while it floats: docked, the
	-- console's hero card is the face)
	local look = b.fill and W.Driver and W.Driver.HERO_LOOK
	if look then
		local l = look[plan.color] or look.off
		pcall(b.fill.Paint, b.fill, l[5])
	end
	b.title:SetText(plan.title or "")
	fitTitle(b)
	-- (round 9) docked in the Drive tab: the words for there (never "in Wuber's Drive tab")
	local sub = subWords(plan) or ""
	b.words = sub
	b.sub:SetText(((combat and not plan.paused) and "|cffff8080in combat|r  " or "") .. sub)
	local pulse = (plan.type ~= nil) or plan.color == "alert" or plan.lead ~= nil
	local TH = W.Theme
	if TH and TH.ReduceMotion and TH.ReduceMotion() then pulse = false end -- (#305) Reduce motion: the accent stays lit, it does not breathe
	if b.pulse then
		if pulse and not b.pulse:IsPlaying() then
			for _, g in ipairs(b.pulses) do pcall(g.Play, g) end
		elseif not pulse and b.pulse:IsPlaying() then
			for _, g in ipairs(b.pulses) do pcall(g.Stop, g) end
			for _, t in ipairs(b.accent or {}) do t:SetAlpha(1) end
		end
	end
	-- the minimap icon flashes gold while a click is due here and the window is closed
	local win = WuberFrame
	local flash = pulse and not (win and win:IsShown())
	if flash ~= state.flashing and W.UI and W.UI.FlashMinimap then
		state.flashing = flash
		pcall(W.UI.FlashMinimap, flash, "gold")
	end
end

local function apply(b, plan)
	local was = b.applied or {}
	if was.type ~= plan.type or was.macrotext ~= plan.macrotext or was.clickbutton ~= plan.clickbutton then W.Crumb("secure attribute") end
	if was.type ~= plan.type then b:SetAttribute("type", plan.type) end
	if was.macrotext ~= plan.macrotext then b:SetAttribute("macrotext", plan.macrotext) end
	if was.clickbutton ~= plan.clickbutton then b:SetAttribute("clickbutton", plan.clickbutton) end
	b.applied = { type = plan.type, macrotext = plan.macrotext, clickbutton = plan.clickbutton }
	b.plan = plan
end

function B.Refresh()
	local b = DR.button
	if not b then return end
	local plan = DR.Plan()
	if W.InCombat() then
		-- the button cannot be changed now: it says what it holds, not the new plan
		if state.combatHidden then return end -- (#204) its look is off while its slot is gone
		paint(b, b.plan or plan, true)
		return
	end
	apply(b, plan)
	paint(b, plan, false)
	B.Place()
end

-- A fight begins. The game locks the button a moment after this event, and whatever it held
-- would then be repeated by every click: the same whispers again, a target that may have
-- become somebody else. So it is emptied while that is still allowed.
W.On("PLAYER_REGEN_DISABLED", function()
	local b = DR.button
	if not b or W.InCombat() then return end
	-- (T243-2) a fight begins in the middle of a window drag: the button is anchored to its slot for the drag, which would make the slot
	-- (and the window) protected: it goes back to its place on the screen now, while that is still allowed
	if state.following then
		state.following = false
		state.sig = nil
		B.Place()
	end
	local paused = { marks = {}, paused = true, color = "off", title = "Paused during combat", sub = "the button works again after the fight" }
	apply(b, paused)
	paint(b, paused, true)
end)

-- (#204) In a fight the button cannot be moved, hidden or docked, and it is docked over the Drive tab's slot. When
-- that slot goes away (another tab, Settings, a pushed page, the window closed or moved) the paused look would stay
-- drawn over whatever is there now. Allowed in combat: alpha and the button's own font strings. on == false hides the
-- look; true brings it back. Only a button that is docked at the moment (state.dockedNow) is touched: a floating one
-- keeps its look, it has its place on the screen. The mouse is not changeable here: a click on it does nothing (the
-- plan is the empty paused one) and the next PLAYER_REGEN_ENABLED restores everything.
function B.CombatView(on)
	local b = DR.button
	if not b or not W.InCombat() then return end
	if on == false then
		if not state.dockedNow or state.combatHidden then return end
		state.combatHidden = true
		b:SetAlpha(0)
		if b.title then b.title:SetText("") end
		if b.sub then b.sub:SetText("") end
		-- (T243-2) the button itself cannot be moved, hidden or made mouse-free now, and it still takes the clicks over the
		-- place it was left: the window (a plain frame) lifts itself above it, so its controls are on top there
		W.Fire("DRIVE_BUTTON_STALE", true)
	elseif state.combatHidden then
		state.combatHidden = nil
		W.Fire("DRIVE_BUTTON_STALE", false)
		b:SetAlpha(1)
		local plan = b.plan
		if type(plan) ~= "table" then plan = { marks = {}, paused = true, color = "off", title = "Paused during combat", sub = "the button works again after the fight" } end
		paint(b, plan, true)
	end
end

W.On("PLAYER_REGEN_ENABLED", function()
	if state.combatHidden then
		state.combatHidden = nil
		W.Fire("DRIVE_BUTTON_STALE", false)
		local b = DR.button
		if b then b:SetAlpha(1) end
	end
	state.sig = nil
	B.Refresh()
end)

-- After a click: what the macro just did is noted.
function B.Clicked()
	local b = DR.button
	local plan = b and b.plan
	if not plan then return end
	local t = now()
	if plan.type == "macro" then
		for _, m in ipairs(plan.marks or {}) do
			if m.kind == "cast" then
				-- noted before the click (PreClick); the game's own events tell the rest (in
				-- the test addon's test mode its hook stands in for the cast the macro left out)
				if m.sim then hook("cast", m.c.name, m.c) end
			elseif m.kind == "kick" then
				m.c.kickedAt = t
				m.c.kicks = (m.c.kicks or 0) + 1
			elseif m.kind == "oops" then
				call("Remove", m.c, "oops")
			elseif m.kind == "callsum" then
				-- the summoner was asked; in a raid the ask is their claim on the raider
				m.c.calledAt = t
				calls[m.summoner] = { name = m.c.name, at = t }
				if mode() == "raid" then call("Do", "CAST", m.c.name, m.summoner) end
			elseif m.kind == "raidsum" then
				raidTold[m.c.key or W.Key(m.c.name) or "?"] = t
			elseif DR.MarkSent then
				DR.MarkSent(m.c, m.kind)
			end
		end
	end
	if plan.box and DR.OpenBox then DR.OpenBox(plan.box.c, plan.box.kind) end
	-- what was noted is not noted twice, should a second click come before the next plan
	b.plan = { marks = {}, color = plan.color, title = plan.title, sub = plan.sub, type = plan.type, paused = plan.paused }
	call("Changed")
end

local function preClick(self)
	-- (2.4) out of combat the plan is made afresh for this click, after one more look at what the game says about
	-- each waiting rider's summon (DR.SummonLook): a rider who got a summon this second is not cast on. In combat
	-- the button was emptied when the fight began and nothing is changed here.
	if not W.InCombat() then
		call("SummonLook")
		B.Refresh()
	end
	-- What this click is about to do is noted before the game answers: the summon it casts,
	-- and the whispers whose echo ("To Dan: ...") is watched for.
	local plan = self.plan
	if plan and plan.lead and type(plan.lead.run) == "function" then
		-- the lead handover: this click is the hardware event PromoteToLeader needs
		local fix = plan.lead
		self.plan = { marks = {}, color = plan.color, title = plan.title, sub = plan.sub }
		local ok, err = pcall(fix.run)
		if not ok then W.Error("drive lead", err) end
		return
	end
	if not plan or plan.type ~= "macro" then return end
	local told = {}
	for _, m in ipairs(plan.marks or {}) do
		if m.kind == "cast" then
			DR.castIntent = { name = m.c.name, at = now() }
		elseif m.kind ~= "kick" and m.kind ~= "callsum" then
			told[#told + 1] = m.c -- a whisper: its echo is watched (a party/raid line has none)
		end
	end
	if #told > 0 and DR.WatchEcho then DR.WatchEcho(told) end
end

local function tooltip(self)
	-- (design 4) Wuber's own tip card (T.TipShow: not a secure frame, so it may show in combat); the words are
	-- as they were, a line's colour is a theme token
	local Th = W.Theme
	if not (type(Th) == "table" and type(Th.TipShow) == "function") then return end
	local plan = self.plan or {}
	local lines = {}
	if plan.say then
		lines[#lines + 1] = { "A click " .. plan.say .. ".", "white" }
	elseif plan.type == "click" then
		lines[#lines + 1] = { "A click presses Trade in the trade window.", "white" }
	else
		lines[#lines + 1] = { "Nothing to click right now: the button says what comes next.", "white" }
	end
	local key = btnDB().key
	lines[#lines + 1] = (key and ("Your key " .. key .. " clicks it too. ") or "") .. "Shift-drag moves it when it floats."
	if plan.macrotext then
		-- (round 13, I8) the macro as it runs, with what each /cast casts said plainly (whatever
		-- name the macro was built with)
		local shown = ("\n" .. tostring(plan.macrotext)):gsub("\n/cast[^\n]*", "\n/cast the summoning spell"):sub(2)
		lines[#lines + 1] = " "
		lines[#lines + 1] = shown
	end
	Th.TipShow(self, plan.title ~= "" and plan.title or "Wuber driving", lines, "ANCHOR_TOPLEFT")
end

-- (design round 3) sizes are T.SIZE names; without the theme the file font needs a number
local FALLBACK_PX = { display = 32, body = 14 }
local function text(parent, size, weight)
	local T = W.Theme
	if T and T.Text then
		local ok, fs = pcall(T.Text, parent, size, "white", "LEFT", weight)
		if ok and fs then
			-- (design round 1) the big button's words sit over the game world: they keep the soft shadow
			if T.WorldText then pcall(T.WorldText, fs) end
			return fs
		end
	end
	-- no theme: still Wuber's own font file (Arial Narrow under it, as T.SetFont does), never the game's serif
	local fs = parent:CreateFontString(nil, "OVERLAY")
	pcall(fs.SetFont, fs, "Fonts\\ARIALN.TTF", FALLBACK_PX[size] or size, "")
	pcall(fs.SetFont, fs, "Interface\\AddOns\\Wuber\\Media\\fonts\\Inter-" .. (weight == "bold" and "Bold" or "Regular") .. ".ttf", FALLBACK_PX[size] or size, "")
	pcall(fs.SetShadowOffset, fs, 1, -1)
	pcall(fs.SetShadowColor, fs, 0, 0, 0, 0.45)
	fs:SetJustifyH("LEFT")
	return fs
end

-- The look (round 7, the author's pick "06 v2"): a portal-violet card with a gold accent line along
-- the bottom (round 9, S3: the whole bottom between the corners, and only while something is
-- on; the old line up the right edge drew a half border), a big title and a two-line subtitle. Docked in the Drive
-- tab, the console's hero card draws the card itself (Skip sits in its top band), so the
-- button's own face hides and only its words and the accent show (B.Place, out of combat).
local function accentPiece(b, layer)
	local t = b:CreateTexture(nil, layer or "ARTWORK")
	t:SetColorTexture(COLORS.idle[1], COLORS.idle[2], COLORS.idle[3], 1)
	b.accent[#b.accent + 1] = t
	return t
end

skinButton = function(b)
	local T = W.Theme
	b.face = {}
	if T and T.Rounded and T.Tex then
		local ok, rim = pcall(T.Rounded, b, "glow", 17, "BACKGROUND", -2, 1.5)
		if ok and rim then rim:SetColor("glow", 0.85) b.face[#b.face + 1] = rim end
		local ok2, bg = pcall(T.Rounded, b, "hover", 16, "BACKGROUND", 0)
		if ok2 and bg then b.face[#b.face + 1] = bg end
		-- the filled portal-violet card, the same as the console's hero card (Driver.lua)
		local D = W.Driver
		if D and D.HeroFill then
			local ok3, fill = pcall(D.HeroFill, b, WIDTH, HEIGHT, 16, 1)
			if ok3 and fill then b.fill = fill b.face[#b.face + 1] = fill end
		end
	else
		local bg = b:CreateTexture(nil, "BACKGROUND")
		bg:SetAllPoints(b)
		bg:SetColorTexture(0.15, 0.14, 0.25, 0.95)
		b.face[1] = bg
	end
	-- the accent: the bottom edge between the rounded corners (S3); hidden until painted lit
	b.accent = {}
	b.bar = accentPiece(b)
	b.bar:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", 16, 0)
	b.bar:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -16, 0)
	b.bar:SetHeight(3)
	b.bar:Hide()
	-- the accent breathes while a click is due (alpha only)
	b.pulses = {}
	for _, t in ipairs(b.accent) do
		local okA, group = pcall(t.CreateAnimationGroup, t)
		if okA and group then
			local okL = pcall(group.SetLooping, group, "BOUNCE")
			local okF, fade = pcall(group.CreateAnimation, group, "Alpha")
			if okL and okF and fade then
				pcall(fade.SetFromAlpha, fade, 1)
				pcall(fade.SetToAlpha, fade, 0.35)
				pcall(fade.SetDuration, fade, 0.9)
				b.pulses[#b.pulses + 1] = group
			end
		end
	end
	b.pulse = b.pulses[1]
	local glow = b:CreateTexture(nil, "HIGHLIGHT")
	glow:SetAllPoints(b)
	glow:SetColorTexture(1, 1, 1, 0.06)

	-- the words: the title just above the middle, the subtitle under it (two lines at most)
	b.title = text(b, "display", "bold")
	b.title:SetPoint("BOTTOMLEFT", b, "LEFT", 20, 2)
	b.title:SetPoint("BOTTOMRIGHT", b, "RIGHT", -16, 2)
	-- (BRIEF18 3a) 14, not 16: two 12-letter names ("Bartholomewz summons Bartholomewz", crew turns)
	-- need it; every other state fits well above it
	b.title.wuberMin = T and T.SIZE and T.SIZE.body or nil
	b.title.wuberSpare = 1.06 -- (round 13, I18) fitted with spare: the game draws it a touch wider
	b.sub = text(b, "body", "regular")
	b.sub.wuberSpare = 1.06
	b.sub:SetPoint("TOPLEFT", b, "LEFT", 20, -6)
	b.sub:SetPoint("TOPRIGHT", b, "RIGHT", -16, -6)
	b.sub:SetTextColor(0.85, 0.82, 0.95)
	-- two lines at most: a longer text is cut by the game, so T.Fit's check of the game's
	-- answer (IsTruncated) shrinks it, instead of a third line running into the accent
	pcall(b.sub.SetMaxLines, b.sub, 2)
	if T and T.Lines then pcall(T.Lines, b.sub, 2) end
end

-- docked: the console's hero card is the face; floating: the button's own
skin = function(b, docked)
	if b.skinDocked == docked then return end
	b.skinDocked = docked
	for _, f in ipairs(b.face or {}) do
		if f.parts then
			f:SetShown(not docked)
		elseif docked then
			f:Hide()
		else
			f:Show()
		end
	end
end

function DR.BuildButton()
	if DR.button then return DR.button end
	if W.InCombat() then
		W.AfterCombat(DR.BuildButton)
		return nil
	end
	local b = CreateFrame("Button", "WuberDriveButton", UIParent, "SecureActionButtonTemplate")
	DR.button = b
	b:SetSize(WIDTH, HEIGHT)
	b:SetFrameStrata("MEDIUM")
	b:SetClampedToScreen(true)
	b:SetMovable(true)
	b:EnableMouse(true)
	b:RegisterForClicks("LeftButtonUp")
	b:RegisterForDrag("LeftButton")
	-- acts when the key or the mouse button comes up, whatever the action bars are set to
	b:SetAttribute("useOnKeyDown", false)

	skinButton(b)

	b:SetScript("OnDragStart", function(self)
		if btnDB().locked or W.InCombat() or state.dockedNow then return end
		if not (type(IsShiftKeyDown) == "function" and IsShiftKeyDown()) then return end
		self:StartMoving()
		self.moving = true
	end)
	b:SetScript("OnDragStop", function(self)
		if not self.moving then return end
		self.moving = nil
		-- a fight that began mid-drag: the button is let go when it is over
		W.AfterCombat(function()
			self:StopMovingOrSizing()
			savePosition()
			state.sig = nil
		end)
	end)
	b:SetScript("PreClick", function(self, _, down)
		if down then return end -- the action is on the way up (useOnKeyDown false)
		-- (Design 1) the big button answers with the same soft click as every control. It is a secure button: no
		-- mouse-down script is put on it, so the sound is here, in the script it always had (nothing on it is read)
		W.Sound("click")
		local ok, err = pcall(preClick, self)
		if not ok then W.Error("drive click", err) end
	end)
	b:SetScript("PostClick", function(_, _, down)
		if down then return end
		local ok, err = pcall(B.Clicked)
		if not ok then W.Error("drive click", err) end
	end)
	-- its own tooltip (what the click does, then the macro); marked like a T.Tip for the
	-- "every control has a tip" walk
	b.wuberTip = { title = "The big button", text = "Does what it says: one click, one step.", own = true }
	b:SetScript("OnEnter", function(self) W.Safe("drive tooltip", tooltip, self) end)
	b:SetScript("OnLeave", function(self)
		local Th = W.Theme
		if type(Th) == "table" and type(Th.TipHide) == "function" then Th.TipHide(self) end
	end)
	b:Hide()
	B.Refresh()
	DR.ApplyBinding()
	return b
end

---------------------------------------------------------------------------
-- Skip: the rider the big button is about to whisper or summon is dropped
---------------------------------------------------------------------------
-- For a name picked up by mistake. Click: off the list (nothing is said to them).
-- Shift-click: blocked as well. Not a secure button: it works in combat too.

-- The customer the next click is about, and what it would do to them.
function DR.SkipTarget()
	local b = DR.button
	local plan = (b and b.plan) or DR.Plan()
	for _, m in ipairs(plan and plan.marks or {}) do
		if m.c and m.kind ~= "kick" then return m.c, m.kind end
	end
	if plan and plan.box and plan.box.c then return plan.box.c, plan.box.kind end
	-- otherwise the next one waiting who has not been summoned yet (AUD-93: sell mode only; a raid
	-- console has its own queue, and a leftover sell customer is not on it)
	if mode() == "raid" then return nil end
	for _, c in ipairs(sorted()) do
		local s = c.state
		if s == "queued" or s == "invited" or s == "joined" or (s == "lead" and (c.wantsPrice or c.busy)) then return c, s end
	end
	return nil
end

function DR.Skip(block)
	local c, kind = DR.SkipTarget()
	if not c then return nil end
	if kind == "refuse" or kind == "moved" or kind == "mailpay" or (type(DR.refusals) == "table" and DR.refusals[c.key] == c)
		or (type(DR.moved) == "table" and DR.moved[c.key] == c) then
		c.told = true -- a blocked player (or one dropped for a place we left; or a rider who left owing, Drive.Mail): just not answered
		call("Changed")
		return c
	end
	if mode() == "raid" then
		-- a raider: off the raid queue (raids have no blocklist)
		call("RaidDrop", c.name, "skip")
		W.Print(c.name .. " is off the raid's summon list.")
		call("Changed")
		return c
	end
	if block then
		call("Blacklist", c.name, "skipped and blocked by hand")
		W.Print(c.name .. " is skipped and blocked.")
	else
		call("Do", "DROP", c.name)
		W.Print(c.name .. " is skipped" .. ((units()[c.key] and isLeader()) and ". They are still in the group: right-click their portrait to remove them." or "."))
	end
	call("Changed")
	return c
end

---------------------------------------------------------------------------
-- The watch: a floating button that is wanted is always seen
---------------------------------------------------------------------------
-- the author (20 Nov): "it randomly disappears; I can only see it if I wiggle the main menu". Only
-- a new window box re-placed the floating button, so whatever left it hidden, faded, off the
-- screen or under the window stayed so. The ticker now checks it; what holds for a tick is
-- put right (out of combat; the same fault at most every 2 s).

local RANK = { BACKGROUND = 1, LOW = 2, MEDIUM = 3, HIGH = 4, DIALOG = 5, FULLSCREEN = 6, FULLSCREEN_DIALOG = 7, TOOLTIP = 8 }

-- Why the floating button cannot be seen now, or nil.
local function unseen(b)
	if not b:IsShown() then return "hidden" end
	-- its own alpha: another addon fading UIParent is not ours to fix
	local a = type(b.GetAlpha) == "function" and N(b:GetAlpha()) or nil
	if a and a < 0.05 then return "faded" end
	local ue, be = N(UIParent:GetEffectiveScale()), N(b:GetEffectiveScale())
	local sw, sh = N(UIParent:GetWidth()), N(UIParent:GetHeight())
	local l, r, bt, tp = N(b:GetLeft()), N(b:GetRight()), N(b:GetBottom()), N(b:GetTop())
	if not (ue and ue > 0 and be and sw and sh and l and r and bt and tp) then return "lost" end
	local k = be / ue
	l, r, bt, tp = l * k, r * k, bt * k, tp * k
	-- a button with its console that is bigger than the screen cannot fit: not a fault to re-place
	local s = N(b:GetScale()) or 1
	local fits = math.max(240, WIDTH) * s <= sw + 1 and (HEIGHT + MINI_H) * s <= sh + 1
	if r - l < 1 or tp - bt < 1 or (fits and (l < -1 or bt < -1 or r > sw + 1 or tp > sh + 1)) then return "off screen" end
	local bx, win = windowBox(), WuberFrame
	if bx and l < bx[2] and r > bx[1] and bt < bx[4] and tp > bx[3] then
		local ws, bs = RANK[str(win:GetFrameStrata()) or ""] or 4, RANK[str(b:GetFrameStrata()) or ""] or 3
		if bs < ws or (bs == ws and (N(b:GetFrameLevel()) or 0) <= (N(win:GetFrameLevel()) or 0)) then return "under the window" end
	end
	return nil
end

local function watch(b)
	local why = wanted() and unseen(b) or nil
	-- at its default place: the chat frame moved (a UI pack, a drag)
	if not why and wanted() and state.chatKey and chatKey() ~= state.chatKey then why = "chat moved" end
	-- on a screen too short for the whole console: the console came, went or grew
	if not why and wanted() and state.miniKey then
		local mh = miniHeight()
		if tostring(mh and math.floor(mh + 0.5) or "-") ~= state.miniKey then why = "console" end
	end
	-- under a window that is still moving: the settled box re-places it
	if why == "under the window" and boxKey(windowBox()) ~= state.winKey then why = nil end
	if not why then
		state.watchSeen = nil
		return
	end
	if state.watchSeen ~= why then
		state.watchSeen = why
		return
	end
	local t = now()
	if why == state.watchWhy and state.watchAt and t - state.watchAt < 2 then return end
	state.watchAt, state.watchWhy, state.watchSeen = t, why, nil
	if why == "faded" then b:SetAlpha(1) end
	state.sig = nil
	B.Place()
end

---------------------------------------------------------------------------
-- Start
---------------------------------------------------------------------------

W.OnLogin(function()
	DR.BuildButton()
end)

W.Listen("DRIVE", function() B.Refresh() end)
W.Listen("DRIVE_CREW", function()
	state.sig = nil
	B.Refresh()
	-- joining or leaving a crew can turn the engine on or off here: the key follows
	if DR.button and state.bindActive ~= (call("Lock") == nil and call("Active") == true) then DR.ApplyBinding() end
end)
-- (round 19 review) the window folded or unfolded: room is made for its new box at once (the
-- ticker's settled box would leave the button under the wide phone for half a second)
W.Listen("FOLD", function()
	local b = DR.button
	if not b or W.InCombat() or state.dockedNow then return end
	local live = windowBox()
	state.winBox, state.winKey, state.winSeen = live, boxKey(live), nil
	state.sig = nil
	B.Place()
end)
W.Listen("PROVIDER", function()
	-- (AUD-92) another driver took over (or gave back): the button is re-placed, so it leaves the screen
	state.sig = nil
	B.Refresh()
	if DR.button and state.bindActive ~= (call("Lock") == nil and call("Active") == true) then DR.ApplyBinding() end
end)

-- the docked button follows its slot while the window moves or scrolls (cheap: a signature)
W.OnLogin(function()
	W.Every(0.25, function()
		local b = DR.button
		if not b or W.InCombat() then return end
		-- docked: follow the slot; floating: follow the window (S1) so the two never overlap.
		-- the box settles while docked too, so undocking never uses an old one
		local moved = settleWindow(false)
		if state.docked or (not state.dockedNow and moved) then
			B.Place()
		elseif not state.dockedNow then
			W.Safe("drive button watch", watch, b)
		end
	end)
end)
