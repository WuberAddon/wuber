-- Tests of the chat frame rule (BRIEF19 R6, the author 20 Nov 01:56: "on my squarer window the chat
-- ends up underneath"). No Wuber frame at its default place - the phone, the floating big button
-- and its console, toasts (the update notice is one), the crew offer - sits over the game's chat
-- frame, read where it is now (a UI pack may move it), on narrow, square and wide screens. A
-- place the player chose is never moved. Loaded by tests/run.lua with its helper table T.
local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H

-- { name, UIParent width, height (UI units), the physical window }
local SIZES = {
	{ "2662x2089", 979, 768, 2662, 2089 },
	{ "1920x1080", 1365, 768, 1920, 1080 },
	{ "3840x2160", 1365, 768, 3840, 2160 },
	{ "3840x2160 at a small UI scale", 1920, 1080, 3840, 2160 },
}
-- { name, point, x, y, w, h }
local CHATS = {
	{ "bottom left (the game's place)", "BOTTOMLEFT", 32, 95, 430, 120 },
	{ "bottom right (moved)", "BOTTOMRIGHT", -32, 60, 430, 160 },
	{ "top left (moved)", "TOPLEFT", 20, -90, 400, 200 },
	{ "top middle (moved)", "TOP", 0, -10, 460, 140 },
}

local function placeChat(d, c)
	local env = d.env
	local f = env.DEFAULT_CHAT_FRAME
	f:ClearAllPoints()
	f:SetPoint(c[2], env.UIParent, c[2], c[3], c[4])
	f:SetSize(c[5], c[6])
	f:Show()
end

-- boxes are { l, b, w, h } in screen units (UIParent's scale is 1 here)
local function box(f)
	if not (f and f:IsVisible()) then return nil end
	return H.rect(f)
end

local function hits(a, c)
	return a and c and a.l < c.l + c.w and a.l + a.w > c.l and a.b < c.b + c.h and a.b + a.h > c.b
end

local function union(a, b)
	if not a then return b end
	if not b then return a end
	local l, bt = math.min(a.l, b.l), math.min(a.b, b.b)
	return { l = l, b = bt, w = math.max(a.l + a.w, b.l + b.w) - l, h = math.max(a.b + a.h, b.b + b.h) - bt }
end

-- whether a w x h box fits anywhere on the screen clear of every block (a coarse scan)
local function possible(sw, sh, w, h, blocks)
	for x = 0, sw - w, 6 do
		for y = 0, sh - h, 6 do
			local fine = true
			for _, b in ipairs(blocks) do
				if hits({ l = x, b = y, w = w, h = h }, b) then fine = false break end
			end
			if fine then return x, y end
		end
	end
	return false
end

-- (the wide phone counts as the narrow one: unfolding is the Fold's choice, but where only the
-- narrow phone fits clear of the chat, the window stays narrow)
local NARROW = 376
local function clear(what, a, chat, sw, sh, blocks, scale)
	if not a then return end
	if not hits(a, chat) then
		ok(true, what)
		return
	end
	local all = { chat }
	for _, b in ipairs(blocks or {}) do all[#all + 1] = b end
	local fx = possible(sw, sh, scale and math.min(a.w, NARROW * scale + 1) or a.w, math.max(a.h, a.tall or 0), all)
	ok(not fx, ("%s: over the chat frame (%.0f,%.0f %.0fx%.0f; chat %.0f,%.0f %.0fx%.0f) with a clear place on the screen")
		:format(what, a.l, a.b, a.w, a.h, chat.l, chat.b, chat.w, chat.h))
end

local function setup(size)
	local w = T.newWorld()
	local d = T.driver(w, T.ANITA, { spot = "Orgrimmar" })
	T.settle(w)
	local W = d.W
	W.db.coach = true
	W.Char().wizard = true
	H.state[d.env.UIParent].w, H.state[d.env.UIParent].h = size[2], size[3]
	d.physW, d.physH = size[4], size[5]
	d.wide = true
	d:fire("DISPLAY_SIZE_CHANGED")
	W.Driver.SetOnline(true)
	w:advance(2)
	return w, d, W
end

local function phoneBox(W)
	local st = W.UI.state
	return box(st.phone) or box(st.win)
end

-- the button and its console; tall: the box the console can grow to (4 rows, about 300 at the
-- button's scale), which is what has to fit for a place to count as clear
local function buttonBox(d)
	local env = d.env
	local b = env.WuberDriveButton
	if not (b and b:IsVisible()) then return nil end
	local r = union(box(b), box(env.WuberDriveMini))
	local br = H.rect(b)
	r.tall = br.h + 300 * b:GetEffectiveScale()
	return r
end

-- the toast's box where the next one goes (UI.ToastPlace: x from the centre, top from the top)
local function toastBox(W, sw, sh)
	local x, top = W.UI.ToastPlace()
	return { l = sw / 2 + x - 160, b = sh + top - 56, w = 320, h = 56 }
end

for _, size in ipairs(SIZES) do
	test("UI chat clear R6: " .. size[1] .. ": the phone, big button, console, toasts and crew offer keep off the chat frame", function()
		local w, d, W = setup(size)
		local sw, sh = size[2], size[3]
		for _, c in ipairs(CHATS) do
			local where = size[1] .. ", chat " .. c[1]
			placeChat(d, c)
			local chat = H.rect(d.env.DEFAULT_CHAT_FRAME)
			-- the window closed: the floating button and its console, a toast, the update notice, the crew offer
			if W.UI.IsShown() then W.UI.Toggle(false) end
			w:advance(1.5)
			clear(where .. ", window closed: the big button and its console", buttonBox(d), chat, sw, sh)
			clear(where .. ", window closed: a toast", toastBox(W, sw, sh), chat, sw, sh)
			W.UI.Toast("Wuber 9.9.9 is out", "update")
			w:advance(0.5)
			clear(where .. ": the update notice", toastBox(W, sw, sh), chat, sw, sh)
			W.UI.CrewOffer("Vexember-Realm", "Vex's portals")
			w:advance(0.5)
			clear(where .. ": the crew offer", box(d.env.WuberCrewOffer), chat, sw, sh)
			d.env.WuberCrewOffer:Hide()
			-- the window open at its default place (Ride: the button floats beside it)
			W.UI.Toggle(true)
			w:advance(1.5)
			local ph = phoneBox(W)
			ok(ph ~= nil, where .. ": the phone shows")
			clear(where .. ", window open: the phone", ph, chat, sw, sh, nil, W.UI.state.win:GetEffectiveScale())
			clear(where .. ", window open: the big button and its console", buttonBox(d), chat, sw, sh, { ph })
			clear(where .. ", window open: a toast", toastBox(W, sw, sh), chat, sw, sh, { ph })
			W.UI.Toggle(false)
			w:advance(1)
		end
		T.clean(w)
	end)
end

test("UI chat clear R6: the default place moves only as far as it must; a hidden chat frame changes nothing", function()
	local w, d, W = setup(SIZES[1])
	local env = d.env
	env.DEFAULT_CHAT_FRAME:Hide()
	W.UI.Toggle(true)
	w:advance(3)
	W.UI.Toggle(false)
	w:advance(1)
	W.UI.Toggle(true)
	w:advance(1)
	local p, _, rp, x, y = W.UI.state.win:GetPoint(1)
	ok(p == "CENTER" or p == "TOPLEFT", "anchored")
	local free = H.rect(W.UI.state.win)
	W.UI.Toggle(false)
	w:advance(1)
	-- a chat frame far away: the window stays where it was. (BRIEF20 B4 review) out of the wide
	-- phone's way too (the far left): it unfolds again as before. The default place is no longer
	-- saved when the unfold slides it, so a chat the wide phone would cover keeps it narrow and
	-- centred, which is another place.
	placeChat(d, { "", "BOTTOMLEFT", 2, 2, 100, 60 })
	W.UI.Toggle(true)
	w:advance(1)
	local r = H.rect(W.UI.state.win)
	eq(math.floor(r.l + 0.5), math.floor(free.l + 0.5), "a chat frame out of the way: the same place")
	W.UI.Toggle(false)
	w:advance(1)
	T.clean(w)
end)

test("UI chat clear R6: a place the player chose is never moved, for the window or the big button", function()
	local w, d, W = setup(SIZES[1])
	local env = d.env
	placeChat(d, CHATS[1])
	-- the player dragged both over the chat frame
	W.db.pos = { "BOTTOMLEFT", "BOTTOMLEFT", 40, 20 }
	W.UI.Toggle(true)
	w:advance(1)
	local _, _, _, x, y = W.UI.state.win:GetPoint(1)
	eq(x, 40, "the window's own place (x)")
	eq(y, 20, "the window's own place (y)")
	W.UI.Toggle(false)
	w:advance(1)
	-- the button dragged onto the chat (its saved place, in its own units)
	local b = env.WuberDriveButton
	W.db.drive.button.pos = { "BOTTOMLEFT", "BOTTOMLEFT", 40, 400 / b:GetScale() }
	W.Drive.Button.Place()
	w:advance(2)
	local p, _, _, bx = b:GetPoint(1)
	eq(p, "BOTTOMLEFT", "the button's own anchor")
	eq(bx, 40, "the button's own place (x)")
	T.clean(w)
end)

test("UI chat clear R6: the chat frame moves under the floating button: it moves away within a second or two", function()
	local w, d, W = setup(SIZES[2])
	local env = d.env
	local b = env.WuberDriveButton
	w:advance(1)
	local bb = buttonBox(d)
	ok(bb ~= nil, "the button floats")
	-- a UI pack puts the chat right where the button is
	local f = env.DEFAULT_CHAT_FRAME
	f:ClearAllPoints()
	f:SetPoint("BOTTOMLEFT", env.UIParent, "BOTTOMLEFT", bb.l, bb.b)
	f:SetSize(300, 160)
	f:Show()
	w:advance(2)
	local chat = H.rect(f)
	clear("after the chat moved under it", buttonBox(d), chat, 1365, 768)
	eq(#(w.violations or {}), 0, "no secure frame changed in combat")
	T.clean(w)
end)

-- (review 3, 4, 9) the box the big button keeps clear of is steady: another docked chat tab
-- selected (it hides the default frame), or the edit box shown and hidden for every line typed,
-- change nothing and never re-place the secure button; a client whose IsVisible answers 1 counts
local function countPlaces(b)
	local n = { 0 }
	local orig = b.ClearAllPoints
	b.ClearAllPoints = function(self, ...)
		n[1] = n[1] + 1
		return orig(self, ...)
	end
	return n
end

local function sameBox(a, b)
	if not (a and b) then return a == b end
	for i = 1, 4 do if math.abs(a[i] - b[i]) > 0.01 then return false end end
	return true
end

test("UI chat clear R6 review: another docked tab selected: the chat box stays (the window keeps off it), the button is not re-placed", function()
	local w, d, W = setup(SIZES[1])
	local env = d.env
	placeChat(d, CHATS[1])
	local cf1, cf2 = env.DEFAULT_CHAT_FRAME, env.ChatFrame2
	cf1.isDocked, cf2.isDocked = 1, 1
	cf2:ClearAllPoints()
	cf2:SetAllPoints(cf1)
	cf2:Hide()
	env.SELECTED_CHAT_FRAME = cf1
	w:advance(2)
	local before = W.UI.ChatBox()
	ok(before ~= nil, "the chat box is seen")
	local n = countPlaces(env.WuberDriveButton)
	-- the Combat Log tab: the default frame hides, the other docked one shows in its place
	for _ = 1, 3 do
		cf1:Hide()
		cf2:Show()
		env.SELECTED_CHAT_FRAME = cf2
		w:advance(1)
		ok(sameBox(W.UI.ChatBox(), before), "another tab selected: the same chat box")
		cf2:Hide()
		cf1:Show()
		env.SELECTED_CHAT_FRAME = cf1
		w:advance(1)
	end
	eq(n[1], 0, "the big button was not re-placed by the tab switches")
	-- the window opened with the other tab selected still keeps off the chat
	cf1:Hide()
	cf2:Show()
	env.SELECTED_CHAT_FRAME = cf2
	W.UI.Toggle(true)
	w:advance(1.5)
	clear("window opened on another chat tab: the phone", phoneBox(W), H.rect(cf1), SIZES[1][2], SIZES[1][3], nil, W.UI.state.win:GetEffectiveScale())
	-- the whole chat hidden (not docked any more): nothing to keep clear of
	cf2:Hide()
	cf1.isDocked = nil
	ok(W.UI.ChatBox() == nil, "the chat hidden: no box")
	T.clean(w)
end)

test("UI chat clear R6 review: the edit box shown and hidden for each line typed never re-places the big button", function()
	local w, d, W = setup(SIZES[2])
	local env = d.env
	local f = env.DEFAULT_CHAT_FRAME
	placeChat(d, CHATS[1])
	local eb = env.ChatFrame1EditBox
	f.editBox = eb
	eb:ClearAllPoints()
	eb:SetPoint("TOPLEFT", f, "BOTTOMLEFT", -5, -2)
	eb:SetPoint("TOPRIGHT", f, "BOTTOMRIGHT", 5, -2)
	eb:SetHeight(32)
	eb:Hide()
	w:advance(2)
	local before = W.UI.ChatBox()
	local n = countPlaces(env.WuberDriveButton)
	for _ = 1, 4 do
		eb:Show()
		w:advance(0.6)
		ok(sameBox(W.UI.ChatBox(), before), "typing: the box the button keeps clear of is the same")
		ok(W.UI.ChatBox(true)[3] < before[3] - 1, "a one-off place (a toast) sees the edit box")
		eb:Hide()
		w:advance(0.6)
	end
	eq(n[1], 0, "the big button was not re-placed while typing")
	T.clean(w)
end)

test("UI chat clear R6 review: a client whose IsVisible answers 1 still has a chat box", function()
	local w, d, W = setup(SIZES[1])
	local env = d.env
	placeChat(d, CHATS[1])
	local f = env.DEFAULT_CHAT_FRAME
	f.IsVisible = function() return 1 end
	ok(W.UI.ChatBox() ~= nil, "IsVisible 1: the chat box is seen")
	W.UI.Toggle(true)
	w:advance(1.5)
	clear("IsVisible 1: the phone", phoneBox(W), H.rect(f), SIZES[1][2], SIZES[1][3], nil, W.UI.state.win:GetEffectiveScale())
	T.clean(w)
end)

test("UI chat clear R6 review: the fold button says the window is kept narrow for the chat box, not that the screen is small", function()
	local w, d, W = setup(SIZES[1])
	placeChat(d, CHATS[1])
	W.UI.Toggle(true)
	w:advance(1.5)
	local fits, why = W.UI.Fold.Fits()
	ok(not fits, "no wide window over the chat at the default place")
	eq(why, "chat", "why: the chat box")
	T.clean(w)
end)

-- (round 19 auto-review: 39_customers_unfolded, 99_chat_home_unfolded) at 2662x2089 (UI scale 0.74:
-- 1331 x 1044 units) the floating big button and its console never sit over or under the open
-- unfolded phone: beside it with its console when there is room, else the button alone (no
-- console) above or below it, and off the chat; seen at once after the unfold
local SQUARE = { "2662x2089 at UI scale 0.74", 1331, 1044, 2662, 2089 }

local function overPhone(d, W)
	local ph = phoneBox(W)
	local b = d.env.WuberDriveButton
	if not (ph and b and b:IsVisible()) then return nil end
	local r = H.rect(b)
	if hits(r, ph) then return ("the button (%.0f,%.0f %.0fx%.0f) on the phone (%.0f..%.0f)"):format(r.l, r.b, r.w, r.h, ph.l, ph.l + ph.w) end
	local m = box(d.env.WuberDriveMini)
	if m and hits(m, ph) then return ("its console (%.0f,%.0f %.0fx%.0f) on the phone (%.0f..%.0f)"):format(m.l, m.b, m.w, m.h, ph.l, ph.l + ph.w) end
	return nil
end

test("UI chat clear R6 review: 2662x2089, the unfolded Customers page (window centred, no room beside it): the button alone, off the phone", function()
	local w, d, W = setup(SQUARE)
	placeChat(d, CHATS[1])
	-- the window where the photo tour puts it: the wide phone centred (a place of its own)
	W.db.pos = { "TOPLEFT", "TOPLEFT", math.floor((1331 / 1.15 - 720) / 2 + 0.5), -60 }
	W.UI.Toggle(true)
	w:advance(1)
	W.UI.SelectTab("Drive")
	w:advance(0.5)
	W.Driver.ShowScreen("customers")
	w:advance(0.1)
	ok(W.UI.Fold.IsUnfolded(), "the Customers page unfolds")
	ok(W.Drive.Button.Floating(), "the big button floats (no slot on Customers)")
	local why = overPhone(d, W)
	ok(why == nil, "at once: " .. tostring(why))
	w:advance(2)
	why = overPhone(d, W)
	ok(why == nil, "settled: " .. tostring(why))
	ok(d.env.WuberDriveButton:IsVisible(), "the button is seen")
	clear("Customers unfolded: the button", buttonBox(d), H.rect(d.env.DEFAULT_CHAT_FRAME), 1331, 1044)
	T.clean(w)
end)

test("UI chat clear R6 review: 2662x2089, the unfolded Home page at the default place: button and console beside it, off the chat, at once", function()
	local w, d, W = setup(SQUARE)
	placeChat(d, CHATS[1])
	W.UI.Toggle(true)
	w:advance(3)
	W.UI.Toggle(false)
	w:advance(1)
	W.UI.Toggle(true)
	w:advance(0.1)
	ok(W.UI.Fold.IsUnfolded(), "Home unfolds (clear of the chat)")
	local why = overPhone(d, W)
	ok(why == nil, "right after the unfold: " .. tostring(why))
	w:advance(2)
	why = overPhone(d, W)
	ok(why == nil, "settled: " .. tostring(why))
	ok(d.env.WuberDriveMini and d.env.WuberDriveMini:IsVisible(), "its console shows (there is room)")
	clear("Home unfolded: the button and its console", buttonBox(d), H.rect(d.env.DEFAULT_CHAT_FRAME), 1331, 1044, { phoneBox(W) })
	T.clean(w)
end)

-- (BRIEF20 B4, the real tour: shots 1, 19, 89 and 39) the default places keep clear of the action
-- bars as well as the chat, with room to breathe: the phone's default place covered the C and S bars
-- on the square window, and the big button the open phone pushed off its own place landed on the
-- General chat. The HUD here is the author's Daylight UI layout read off shot 89 (UIParent units at
-- 2662x2089, 1372 x 1077): four bars over the bottom middle, the micro menu bottom right, the party
-- frames on the left, the chat box bottom left; at the other sizes the same frames at the same
-- anchors (WoW keeps UI units, so a smaller screen in units has less room).
local HUD_SIZES = {
	{ "2662x2089 (a large test screen, UIParent 1372 x 1077)", 1372, 1077, 2662, 2089 },
	{ "2662x2089 at the default UI scale", 979, 768, 2662, 2089 },
	{ "1920x1080", 1365, 768, 1920, 1080 },
	{ "3840x2160", 1365, 768, 3840, 2160 },
	{ "3840x2160 at a small UI scale", 1920, 1080, 3840, 2160 },
}
-- { global name, point, x, y, w, h } (anchored to UIParent, as Daylight UI's movers place them)
local HUD_FRAMES = {
	{ "DaylightUIBar1", "BOTTOM", 147, 82, 453, 34 },
	{ "DaylightUIBar2", "BOTTOM", 147, 119, 453, 35 },
	{ "DaylightUIBar3", "BOTTOM", 147, 157, 453, 32 },
	{ "DaylightUIBar5", "BOTTOM", 89, 191, 178, 24 },
	{ "MicroMenuContainer", "BOTTOMRIGHT", -7, 6, 312, 52 },
	{ "DaylightUIPartyHeader", "LEFT", 38, 92, 199, 199 },
	{ "DaylightUIChatPanel", "BOTTOMLEFT", 0, 0, 590, 294 },
}
local HUD_CHAT = { "", "BOTTOMLEFT", 6, 8, 572, 252 }

local function placeHud(d)
	local env = d.env
	local out = {}
	for _, f in ipairs(HUD_FRAMES) do
		local fr = env[f[1]] or env.CreateFrame("Frame", f[1], env.UIParent)
		fr:ClearAllPoints()
		fr:SetPoint(f[2], env.UIParent, f[2], f[3], f[4])
		fr:SetSize(f[5], f[6])
		fr:Show()
		out[#out + 1] = H.rect(fr)
	end
	placeChat(d, HUD_CHAT)
	local c = H.rect(env.DEFAULT_CHAT_FRAME)
	out[#out + 1] = { l = c.l, b = c.b, w = c.w, h = c.h + 26 } -- with its tab row
	return out
end

-- a box grown by m all round (room to breathe)
local function grow(a, m)
	return { l = a.l - m, b = a.b - m, w = a.w + 2 * m, h = a.h + 2 * m }
end

-- area of a covered by the blocks
local function coverOf(a, blocks)
	local sum = 0
	for _, k in ipairs(blocks) do
		local cw = math.min(a.l + a.w, k.l + k.w) - math.max(a.l, k.l)
		local ch = math.min(a.b + a.h, k.b + k.h) - math.max(a.b, k.b)
		if cw > 0 and ch > 0 then sum = sum + cw * ch end
	end
	return sum
end

-- clear of every block by 6 or more, unless no place on the screen is clear of them all (then it
-- covers no more than it would in the middle of the screen); avoid: hard (the open phone)
local function clearHud(what, a, blocks, sw, sh, avoid, middle)
	if not a then return end
	local near = {}
	for _, k in ipairs(blocks) do near[#near + 1] = grow(k, 6) end
	for _, k in ipairs(avoid or {}) do
		ok(not hits(a, k), ("%s: on the phone (%.0f,%.0f %.0fx%.0f)"):format(what, a.l, a.b, a.w, a.h))
	end
	local hit
	for _, k in ipairs(near) do if hits(a, k) then hit = k break end end
	if not hit then
		ok(true, what)
		return
	end
	local all = {}
	for _, k in ipairs(blocks) do all[#all + 1] = k end
	for _, k in ipairs(avoid or {}) do all[#all + 1] = k end
	local fx = possible(sw, sh, a.w, math.max(a.h, a.tall or 0), all)
	ok(not fx, ("%s: over the bars or chat (%.0f,%.0f %.0fx%.0f; %.0f,%.0f %.0fx%.0f) with a clear place on the screen at %s")
		:format(what, a.l, a.b, a.w, a.h, hit.l, hit.b, hit.w, hit.h, tostring(fx)))
	if middle then
		ok(coverOf(a, blocks) <= coverOf(middle, blocks) + 1, what .. ": covers no more than the middle of the screen would")
	end
end

for _, size in ipairs(HUD_SIZES) do
	test("UI HUD clear B4: " .. size[1] .. ": the phone, big button, console, toasts and crew offer keep off the action bars and chat", function()
		local w, d, W = setup(size)
		local sw, sh = size[2], size[3]
		local hud = placeHud(d)
		w:advance(1)
		-- the window closed: the big button and its console (off the party frames too), a toast, the crew offer
		if W.UI.IsShown() then W.UI.Toggle(false) end
		w:advance(1.5)
		clearHud(size[1] .. ", window closed: the big button and its console", buttonBox(d), hud, sw, sh)
		W.UI.Toast("Wuber 9.9.9 is out", "update")
		w:advance(0.5)
		clearHud(size[1] .. ": a toast", toastBox(W, sw, sh), hud, sw, sh)
		W.UI.CrewOffer("Vexember-Realm", "Vex's portals")
		w:advance(0.5)
		clearHud(size[1] .. ": the crew offer", box(d.env.WuberCrewOffer), hud, sw, sh)
		d.env.WuberCrewOffer:Hide()
		-- the window open at its default place
		W.UI.Toggle(true)
		w:advance(1.5)
		local ph = phoneBox(W)
		ok(ph ~= nil, size[1] .. ": the phone shows")
		local mid = ph and { l = sw / 2 - ph.w / 2, b = sh / 2 - ph.h / 2, w = ph.w, h = ph.h }		clearHud(size[1] .. ", window open: the phone", ph, hud, sw, sh, nil, mid)
		clearHud(size[1] .. ", window open: the big button and its console", buttonBox(d), hud, sw, sh, { ph })
		T.clean(w)
	end)
end

test("UI HUD clear B4: shot 89, 2662x2089: the phone's default place is clear of the C and S bars and the chat box, not hugging it", function()
	local size = HUD_SIZES[1]
	local w, d, W = setup(size)
	local hud = placeHud(d)
	W.UI.Toggle(true)
	w:advance(2)
	local ph = phoneBox(W)
	ok(ph ~= nil, "the phone shows")
	for i, k in ipairs(hud) do
		local name = HUD_FRAMES[i] and HUD_FRAMES[i][1] or "the chat"
		ok(not hits(ph, grow(k, 8)), ("the phone (%.0f,%.0f %.0fx%.0f) at least 8 clear of %s (%.0f,%.0f %.0fx%.0f)")
			:format(ph.l, ph.b, ph.w, ph.h, name, k.l, k.b, k.w, k.h))
	end
	ok(ph.b + ph.h <= size[3], "on the screen (top)")
	T.clean(w)
end)

test("UI HUD clear B4: shot 39, the unfolded Customers page at the tour's place: the button pushed off the phone keeps off the chat and the bars", function()
	local size = HUD_SIZES[1]
	local w, d, W = setup(size)
	local env = d.env
	local hud = placeHud(d)
	-- the author's own button place, which the unfolded phone covers
	local b = env.WuberDriveButton
	W.db.drive.button.pos = { "CENTER", "CENTER", 0, 0 }
	W.Drive.Button.Place()
	-- the tour's place: the wide phone centred
	W.db.pos = { "TOPLEFT", "TOPLEFT", math.floor((1372 / 1.15 - 720) / 2 + 0.5), -130 }
	W.UI.Toggle(true)
	w:advance(1)
	W.UI.SelectTab("Drive")
	w:advance(0.5)
	W.Driver.ShowScreen("customers")
	w:advance(2.5)
	ok(W.UI.Fold.IsUnfolded(), "the Customers page unfolds")
	local ph = phoneBox(W)
	ok(W.Drive.Button.Floating(), "the big button floats")
	ok(b:IsVisible(), "the button is seen")
	local r = H.rect(b)
	ok(not hits(r, ph), ("the button (%.0f,%.0f %.0fx%.0f) off the phone"):format(r.l, r.b, r.w, r.h))
	for i, k in ipairs(hud) do
		local name = HUD_FRAMES[i] and HUD_FRAMES[i][1] or "the chat"
		ok(not hits(r, k), ("the button (%.0f,%.0f %.0fx%.0f) off %s (%.0f,%.0f %.0fx%.0f)"):format(r.l, r.b, r.w, r.h, name, k.l, k.b, k.w, k.h))
	end
	local m = box(env.WuberDriveMini)
	if m then
		for _, k in ipairs(hud) do ok(not hits(m, k), "its console off the bars and chat") end
		ok(not hits(m, ph), "its console off the phone")
	end
	T.clean(w)
end)

test("UI HUD clear B4: places the player chose are never moved, even over the bars", function()
	local size = HUD_SIZES[1]
	local w, d, W = setup(size)
	local env = d.env
	placeHud(d)
	W.db.pos = { "BOTTOM", "BOTTOM", 120, 40 }
	W.UI.Toggle(true)
	w:advance(1)
	local p, _, rp, x, y = W.UI.state.win:GetPoint(1)
	eq(p .. "/" .. rp .. "/" .. x .. "/" .. y, "BOTTOM/BOTTOM/120/40", "the window's own place over the bars")
	W.UI.Toggle(false)
	w:advance(1)
	-- the button's own place on the bars, the window shut: it stays
	local b = env.WuberDriveButton
	-- (its console hangs under it, so high enough for that to stay on the screen)
	W.db.drive.button.pos = { "BOTTOMLEFT", "BOTTOMLEFT", 700 / b:GetScale(), 450 / b:GetScale() }
	W.Drive.Button.Place()
	w:advance(2)
	local bp, _, _, bx, by = b:GetPoint(1)
	eq(bp, "BOTTOMLEFT", "the button's own anchor")
	eq(math.floor(bx * b:GetScale() + 0.5), 700, "the button's own place (x)")
	eq(math.floor(by * b:GetScale() + 0.5), 450, "the button's own place (y)")
	T.clean(w)
end)

test("UI HUD clear B4: hidden bars do not count, faded-out ones do (alpha never changes the key); a bar shown later re-places the big button at its default place", function()
	local size = HUD_SIZES[3]
	local w, d, W = setup(size)
	local env = d.env
	local hud = placeHud(d)
	local n = #W.UI.HudBoxes()
	ok(n >= 6, "the shown bars are read (" .. n .. ")")
	env.DaylightUIBar5:Hide()
	eq(#W.UI.HudBoxes(), n - 1, "a hidden bar does not count")
	env.DaylightUIBar5:Show()
	-- (review) Daylight UI fades bars by alpha (mouseover, out of combat): they still count, and a
	-- fade never re-places the big button
	w:advance(2)
	local before = W.UI.HudBoxes()
	local b = env.WuberDriveButton
	local moves = { 0 }
	local orig = b.ClearAllPoints
	b.ClearAllPoints = function(self, ...) moves[1] = moves[1] + 1 return orig(self, ...) end
	for _, a in ipairs({ 0, 0.4, 0, 1 }) do
		env.DaylightUIBar5:SetAlpha(a)
		w:advance(1)
		eq(#W.UI.HudBoxes(), n, "a bar at alpha " .. a .. " counts")
		local now = W.UI.HudBoxes()
		for i = 1, n do ok(sameBox(now[i], before[i]), "the same boxes at alpha " .. a) end
	end
	eq(moves[1], 0, "fading a bar never re-placed the big button")
	b.ClearAllPoints = orig
	-- a pet bar shows where the button and its console stand
	local bb = buttonBox(d)
	local pet = env.DaylightUIPetBar or env.CreateFrame("Frame", "DaylightUIPetBar", env.UIParent)
	pet:ClearAllPoints()
	pet:SetPoint("BOTTOMLEFT", env.UIParent, "BOTTOMLEFT", bb.l + 10, bb.b + 10)
	pet:SetSize(200, 30)
	pet:Show()
	w:advance(2.5)
	hud[#hud + 1] = H.rect(pet)
	clearHud("after the pet bar showed", buttonBox(d), hud, size[2], size[3])
	eq(#(w.violations or {}), 0, "no secure frame changed in combat")
	T.clean(w)
end)

test("UI HUD clear B4 review: the default place is never saved: unfolding there (sliding left off the screen's edge) leaves WuberDB.pos unset", function()
	for _, size in ipairs({ SQUARE, HUD_SIZES[1], HUD_SIZES[5] }) do
		local w, d, W = setup(size)
		if size ~= SQUARE then placeHud(d) else placeChat(d, CHATS[1]) end
		W.UI.Toggle(true)
		w:advance(3)
		W.UI.Toggle(false)
		w:advance(1)
		W.UI.Toggle(true)
		w:advance(2)
		W.UI.SelectTab("Drive")
		w:advance(0.5)
		W.Driver.ShowScreen("customers")
		w:advance(2)
		W.UI.SelectTab("Ride")
		w:advance(2)
		ok(W.db.pos == nil, size[1] .. ": the default place was not saved as the player's own (" .. tostring(W.db.pos and table.concat(W.db.pos, ",")) .. ")")
		T.clean(w)
	end
end)
