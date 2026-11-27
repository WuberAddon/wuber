-- Wuber Lab (developer only, never shipped): the Auto check "KEYS-SETTINGS" (#203, T243-4).
-- With Settings open (from Ride and from Drive): a press on the search pill puts the keyboard in the box (the control), then a
-- press on the Settings background must give it back: GetCurrentKeyBoardFocus() is nil and no visible Wuber frame has
-- IsKeyboardEnabled() true while it does not pass keys on (SetPropagateKeyboardInput(false)).
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
local function plain(v)
	if type(issecretvalue) == "function" and issecretvalue(v) then return nil end
	return v
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
	return f, true
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
				if plain(callm(c, "IsKeyboardEnabled")) == true and plain(callm(c, "IsVisible")) == true
					and plain(callm(c, "GetPropagateKeyboardInput")) ~= true and ours(c) then
					out[#out + 1] = str(callm(c, "GetName")) or "an unnamed Wuber frame"
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
			if p == box or p == box.edit then return true end
			p, d = callm(p, "GetParent"), d + 1
		end
	end
	return false
end

-- the second press: every Wuber frame that listens for GLOBAL_MOUSE_DOWN gets the event once
local function pressElsewhere(W)
	local up = rawget(_G, "UIParent")
	local seen = {}
	local function walk(f, depth)
		if depth > 40 then return end
		for _, c in ipairs({ callm(f, "GetChildren") }) do
			if type(c) == "table" and not seen[c] then
				seen[c] = true
				if callm(c, "IsEventRegistered", "GLOBAL_MOUSE_DOWN") == true then
					local ok, h = pcall(c.GetScript, c, "OnEvent")
					local nm = str(callm(c, "GetName"))
					if ok and type(h) == "function" and not (nm and nm:find("^WuberLab")) then pcall(h, c, "GLOBAL_MOUSE_DOWN", "LeftButton") end
				end
				walk(c, depth + 1)
			end
		end
	end
	walk(up, 0)
end

local function probe(W, origin)
	local UI = W.UI
	local out = { origin = origin }
	if plain(rawget(_G, "InCombatLockdown") and InCombatLockdown()) == true then out.combat = true return out end
	if type(UI.SelectTab) == "function" then pcall(UI.SelectTab, origin) end
	pcall(UI.OpenSettings)
	local st = type(UI.settings) == "table" and UI.settings
	local box = st and type(st.find) == "table" and st.find.box
	if type(box) ~= "table" or type(box.edit) ~= "table" then out.none = true return out end
	if callm(box, "IsVisible") ~= true then out.hidden = true return out end
	local _, haveFocusFn = focusNow()
	if not haveFocusFn then out.nofn = true return out end
	if overBox(box) then out.mouseOver = true return out end
	local down = callm(box, "GetScript", "OnMouseDown")
	if type(down) == "function" then pcall(down, box, "LeftButton") end
	out.control = callm(box.edit, "HasFocus") == true and focusNow() == box.edit
	pressElsewhere(W)
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
			elseif r.none then add("skip", "this Wuber has no Settings search box the check knows")
			elseif r.hidden then add("skip", "the search box is not shown on this page")
			elseif r.nofn then add("skip", "this game has no GetCurrentKeyBoardFocus")
			elseif r.mouseOver then add("skip", "the mouse is over the search box: a press there is the player typing; move it away and run again")
			elseif not r.control then add("skip", "a press on the pill did not put the keyboard in the box, so there is nothing to give back")
			elseif r.focus ~= nil then add("look", "after a press on the Settings background the keyboard is still in a box: every key goes to it, none to the game")
			elseif #(r.swallowers or {}) > 0 then add("look", "a visible Wuber frame takes keys and does not pass them on: " .. table.concat(r.swallowers, ", "))
			else add("pass", "after a press on the pill and one on the Settings background the keys go to the game (no box focus, no frame holding the keyboard)") end
		end
		return out
	end }