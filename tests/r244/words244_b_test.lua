local T = ...
local test, eq, ok = T.test, T.eq, T.ok

-- 2.4.4 words page, line 10: the Alert character tip gets one extra line, only while the game's Sound in Background is off.
local OLD = "A character you have logged in on another account: it flashes, beeps and shows a banner when one of your windows needs a click. Empty: off."
local LINE = "Sound in Background is off in the game's sound settings, so the bell is silent while another window is in front"

local function tipText(setup)
	local w = T.newWorld()
	local d = T.driver(w, T.BOB)
	T.settle(w)
	d.W.db.coach = true
	d.W.UI.Toggle(true)
	w:advance(3)
	d.W.UI.OpenSettings("driving")
	w:advance(1)
	local f = d.W.UI.settings.controls["drive.bell"]
	ok(f and f.edit and f.edit.wuberTip, "the Alert character field has a tip")
	setup(d, w)
	local t = f.edit.wuberTip.text
	if type(t) == "function" then t = t(f.edit) end
	return t
end

local function cvar(v)
	return function(d, w)
		d.env.GetCVar = function(k) if k == "Sound_EnableSoundWhenGameIsInBG" then return v end end
	end
end

test("words244 b: Sound in Background off adds the extra line to the Alert character tip", function()
	local t = tipText(cvar("0"))
	ok(t:find(OLD, 1, true), "the old tooltip words are kept")
	ok(t:find(LINE, 1, true), "the extra line is there")
end)

test("words244 b: Sound in Background on leaves the Alert character tip exactly as before", function()
	eq(tipText(cvar("1")), OLD, "tip with the setting on")
end)

test("words244 b: Sound in Background unknown leaves the Alert character tip exactly as before", function()
	eq(tipText(cvar(nil)), OLD, "tip with the setting unknown")
end)

test("words244 b: the tip is read when shown, not cached", function()
	local state = "1"
	local d0
	local t1 = tipText(function(d) d0 = d; d.env.GetCVar = function() return state end end)
	eq(t1, OLD, "on at first")
	state = "0"
	local f = d0.W.UI.settings.controls["drive.bell"]
	ok(f.edit.wuberTip.text(f.edit):find(LINE, 1, true), "the same tip shows the line once the setting is off")
end)
