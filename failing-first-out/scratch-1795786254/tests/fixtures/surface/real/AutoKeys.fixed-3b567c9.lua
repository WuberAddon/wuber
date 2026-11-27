-- Wuber Lab (developer only, never shipped): the Auto check "KEYS-SETTINGS" (#203, T243-4).
-- With Settings open (from Ride and from Drive): a press on the search pill puts the keyboard in the box (the control), then a
-- press on the Settings background must give it back: GetCurrentKeyBoardFocus() is nil and no visible Wuber frame has
-- IsKeyboardEnabled() true while it does not pass keys on (SetPropagateKeyboardInput(false)).
-- (T243 round 2) Settings from Drive opens the DRIVE cog's page ("driving", where the "Key for the big button" row is), as the cog does,
-- and a visible Wuber frame that takes keys there while no key is being set is a look at once, with the frame named.
-- Every game value is read through plain(): a secret boolean cannot be compared (it broke the first run in game).
-- Local only: nothing is sent, no secure frame is touched, nothing runs in combat; the box focus and the tab are put back.
-- What it cannot do: press with a real mouse. The pill's own OnMouseDown runs for the first press; the second press is the game's
-- own GLOBAL_MOUSE_DOWN handlers of the Wuber frames run once with the mouse where the player left it (a result with the mouse
-- over the box says skip, since a press there is the player typing). A real press stays a hand step if this says look.
-- New file: needs a full game restart (a /reload does not find it). Same rules as AutoSteps.lua.

local _, L = ...

local K, P = L.PhotoKit, L.PhotoShotKit
local str = L.str
local fn = K.fn

local STEP = "KEYS-SETTINGS"
local NAME = "keys while Settings is open"

local function callm(o, name, ...)
	if type(o) ~= "table" or not fn(o, name) then return nil end
	local r = { pcall(o[name], o, ...) }
	if not r[1] then return nil end
	return unpack(r, 2)
end
local function isSecret(v)
	local g = rawget(_G, "issecretvalue")
	if type(g) ~= "function" then return false end
	local ok, r = pcall(g, v)
	return ok and r == true
end
local function plain(v)
	if isSecret(v) then return nil end
	return v
end
-- a game value that is true (a secret one is not known, so not true)
local function isTrue(o, name, ...)
	return plain(callm(o, name, ...)) == true
end
local function result(status, detail)
	return { name = NAME, status = status, detail = detail, steps = { STEP } }
end
local function data()
	local t = K.tour()
	if not t then return {} end
	t.autoData = t.autoData or {}
	return t.autoData
end

local function focusNow()
	local g = rawget(_G, "GetCurrentKeyBoardFocus")
	if type(g) ~= "function" then return nil, false end
	local ok, f = pcall(g)
	if not ok then return nil, false end
	return plain(f), true
end

-- a frame told apart for the player: its name, else its kind and the first name above it
local function describe(f)
	local nm = str(callm(f, "GetName"))
	if nm then return nm end
	local kind = str(callm(f, "GetObjectType")) or "frame"
	local p, d = callm(f, "GetParent"), 0
	while type(p) == "table" and d < 60 do
		local pn = str(callm(p, "GetName"))
		if pn then return ("an unnamed %s inside %s"):format(kind, pn) end
		p, d = callm(p, "GetParent"), d + 1
	end
	return "an unnamed Wuber " .. kind
end

-- every visible Wuber frame (the window and the frames named Wuber...) that takes keys and does not pass them on
local function swallowers(W)
	local out = {}
	local up = rawget(_G, "UIParent")
	local seen, n = {}, 0
	local win = type(W.UI) == "table" and type(W.UI.state) == "table" and W.UI.state.win
	local function ours(f)
		local p, d = f, 0
		while type(p) == "table" and d < 60 do
			if p == win then return true end
			local nm = str(callm(p, "GetName"))
			if nm and nm:find("^WuberLab") then return false end
			if nm and nm:find("^Wuber") then return true end
			p, d = callm(p, "GetParent"), d + 1
		end
		return false
	end
	local function walk(f, depth)
		if n > 30000 or depth > 40 then return end
		for _, c in ipairs({ callm(f, "GetChildren") }) do
			if type(c) == "table" and not seen[c] then
				seen[c] = true
				n = n + 1
				if isTrue(c, "IsKeyboardEnabled") and isTrue(c, "IsVisible")
					and not isTrue(c, "GetPropagateKeyboardInput") and ours(c) then
					out[#out + 1] = describe(c)
				end
				walk(c, depth + 1)
			end
		end
	end
	walk(up, 0)
	return out
end

local function overBox(box)
	local foci
	if type(GetMouseFoci) == "function" then
		local ok, list = pcall(GetMouseFoci)
		if ok and type(list) == "table" then foci = list end
	end
	for _, fr in ipairs(foci or {}) do
		local p, d = fr, 0
		while type(p) == "table" and d < 12 do
			if p == box or p == box.edit then return true end -- (tables compared with tables: no game value here)
			p, d = callm(p, "GetParent"), d + 1
		end
	end
	return false
end

-- the second press: every Wuber frame that listens for GLOBAL_MOUSE_DOWN gets the event once
-- -> how many frames hide from us whether they listen (a secret answer: that frame is not pressed)
local function pressElsewhere(W)
	local up = rawget(_G, "UIParent")
	local seen = {}
	local hidden = 0
	local function walk(f, depth)
		if depth > 40 then return end
		for _, c in ipairs({ callm(f, "GetChildren") }) do
			if type(c) == "table" and not seen[c] then
				seen[c] = true
				local reg = callm(c, "IsEventRegistered", "GLOBAL_MOUSE_DOWN")
				if isSecret(reg) then hidden = hidden + 1
				elseif reg == true then
					local ok, h = pcall(c.GetScript, c, "OnEvent")
					local nm = str(callm(c, "GetName"))
					if ok and type(h) == "function" and not (nm and nm:find("^WuberLab")) then pcall(h, c, "GLOBAL_MOUSE_DOWN", "LeftButton") end
				end
				walk(c, depth + 1)
			end
		end
	end
	walk(up, 0)
	return hidden
end

local function probe(W, origin)
	local UI = W.UI
	local out = { origin = origin }
	if plain(rawget(_G, "InCombatLockdown") and InCombatLockdown()) == true then out.combat = true return out end
	if type(UI.SelectTab) == "function" then pcall(UI.SelectTab, origin) end
	-- the Drive tab's cog opens the Driving page (Window.lua: OpenSettings("drive")); Ride's opens the home
	pcall(UI.OpenSettings, origin == "Drive" and "drive" or nil)
	local st = type(UI.settings) == "table" and UI.settings
	out.page = st and plain(st.view == "section" and st.sec or st.view) or nil
	-- the page as opened: no key is being set, so no visible Wuber frame may hold the keyboard
	if st and not st.capturing then out.pageSwallowers = swallowers(W) end
	-- the search pill is on the home page: the cog's page was read above, the press below starts from the home
	if origin == "Drive" then pcall(UI.OpenSettings) end
	local box = st and type(st.find) == "table" and st.find.box
	if type(box) ~= "table" or type(box.edit) ~= "table" then out.none = true return out end
	if not isTrue(box, "IsVisible") then out.hidden = true return out end
	local _, haveFocusFn = focusNow()
	if not haveFocusFn then out.nofn = true return out end
	if overBox(box) then out.mouseOver = true return out end
	local down = callm(box, "GetScript", "OnMouseDown")
	if type(down) == "function" then pcall(down, box, "LeftButton") end
	out.control = isTrue(box.edit, "HasFocus") and focusNow() == box.edit
	out.regHidden = pressElsewhere(W)
	out.focus = focusNow()
	out.swallowers = swallowers(W)
	pcall(box.edit.ClearFocus, box.edit) -- put back
	return out
end

L.AUTO_SCREENS[#L.AUTO_SCREENS + 1] = { id = "a_keys_settings", side = "settings", auto = true,
	title = "Settings: a press on the search pill, then on the Settings background, gives the keys back to the game",
	covers = { any = { verify = { STEP } } },
	run = function(W)
		return P.settings(W, function(UI) return true end)
	end,
	post = function(W)
		local d = data()
		d.keys = {}
		local ui = type(W.UI) == "table" and type(W.UI.state) == "table" and W.UI.state
		local was = ui and ui.tab
		for _, origin in ipairs({ "Ride", "Drive" }) do
			local ok, r = pcall(probe, W, origin)
			d.keys[origin] = ok and r or { broke = tostring(r):sub(1, 200) }
		end
		if type(W.UI.CloseSettings) == "function" then pcall(W.UI.CloseSettings, true) end
		if was and type(W.UI.SelectTab) == "function" then pcall(W.UI.SelectTab, was) end
		return true
	end,
	verify = function()
		local k = data().keys
		if not k then return "skip", "the Settings screen did not set up" end
		local out = {}
		for _, origin in ipairs({ "Ride", "Drive" }) do
			local r = k[origin] or {}
			local name = NAME .. " (Settings from " .. origin .. ")"
			local function add(status, detail) local x = result(status, detail) x.name = name out[#out + 1] = x end
			if r.broke then add("look", "the check itself broke: " .. r.broke)
			elseif r.combat then add("skip", "in combat: nothing was changed")
			elseif #(r.pageSwallowers or {}) > 0 then
				add("look", ("Settings is open on the %s page and no key is being set, yet a visible Wuber frame takes keys and does not pass them on (the player cannot move or jump): %s"):format(
					tostring(r.page or "?"), table.concat(r.pageSwallowers, ", ")))
			elseif origin == "Drive" and r.page ~= nil and r.page ~= "driving" then
				add("skip", "the Drive cog did not open the driving page here (it shows " .. tostring(r.page) .. "), so its keys were not looked at")
			elseif r.none then add("skip", "this Wuber has no Settings search box the check knows")
			elseif r.hidden then add("skip", "the search box is not shown on this page")
			elseif r.nofn then add("skip", "this game has no GetCurrentKeyBoardFocus")
			elseif r.mouseOver then add("skip", "the mouse is over the search box: a press there is the player typing; move it away and run again")
			elseif not r.control then add("skip", "a press on the pill did not put the keyboard in the box, so there is nothing to give back")
			elseif r.focus ~= nil and (r.regHidden or 0) > 0 then
				add("skip", "the game hides from the Lab whether Wuber's frames listen for a press elsewhere (secret answers), so that press could not be made")
			elseif r.focus ~= nil then add("look", "after a press on the Settings background the keyboard is still in a box: every key goes to it, none to the game")
			elseif #(r.swallowers or {}) > 0 then add("look", "a visible Wuber frame takes keys and does not pass them on: " .. table.concat(r.swallowers, ", "))
			else add("pass", "after a press on the pill and one on the Settings background the keys go to the game (no box focus, no frame holding the keyboard)") end
		end
		return out
	end }
