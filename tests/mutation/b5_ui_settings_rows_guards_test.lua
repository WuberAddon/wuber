local T = ...
local test, eq, ok = T.test, T.eq, T.ok

local function openDriving(w, d)
	d.W.db.coach = true
	d.W.UI.Toggle(true)
	w:advance(3)
	d.W.UI.OpenSettings("driving")
	w:advance(1)
	return d.W.UI.settings
end

local function findKeyCapture(set)
	for _, ch in ipairs({ set:GetParent():GetChildren() }) do
		if ch.GetScript and ch:GetScript("OnKeyDown") then
			return ch
		end
	end
end

local function scrollToControl(w, st, ctl)
	local wheel = st.clip and st.clip:GetScript("OnMouseWheel")
	if not wheel or not ctl or not ctl.GetTop or not st.clip.GetTop then return end
	for _ = 1, 40 do
		local ct, cb = st.clip:GetTop(), st.clip:GetBottom()
		local rt, rb = ctl:GetTop(), ctl:GetBottom()
		if rt and rb and ct and cb and rt <= ct and rb >= cb then return end
		if rt and ct and rt > ct then
			wheel(st.clip, 2)
		else
			wheel(st.clip, -2)
		end
		w:advance(1)
	end
end

-- guards Wuber/UI/Settings/Rows.lua:350 (and->or: C_CVar.GetCVar result overwritten by GetCVar)
-- guards Wuber/UI/Settings/Rows.lua:352 (r ~= nil -> r == nil: GetCVar fallback ignored)
-- guards Wuber/UI/Settings/Rows.lua:357 (s == "0" -> s ~= "0": "1" treated as off)
-- guards Wuber/UI/Settings/Rows.lua:359 (n == 1 -> n ~= 1: non-1 numeric CVar treated as on)
-- guards Wuber/UI/Settings/Rows.lua:361 (p == true -> p ~= true: non-boolean/non-1 string treated as on)
-- guards Wuber/UI/Settings/Rows.lua:367 (ok -> not ok: GetCVarBool fallback ignored)
-- guards Wuber/UI/Settings/Rows.lua:369 (p == true -> p ~= true: GetCVarBool inverted)
test("mutation b5 settings rows: friendlyPlatesOn handles C_CVar, GetCVar, numeric, string and GetCVarBool fallbacks", function()
	local w = T.newWorld()
	local d = T.driver(w, T.BOB)
	T.settle(w)
	local Rows = d.W.Mod("UI.Settings.Rows")
	local origCC, origGet, origBool = d.env.C_CVar, d.env.GetCVar, d.env.GetCVarBool

	-- C_CVar.GetCVar takes precedence over GetCVar
	d.env.C_CVar = { GetCVar = function(name) if name == "nameplateShowFriends" then return "1" end end }
	d.env.GetCVar = function(name) if name == "nameplateShowFriends" then return "0" end end
	d.env.GetCVarBool = nil
	eq(Rows.friendlyPlatesOn(), true, "C_CVar '1' wins over GetCVar '0'")

	-- GetCVar fallback when C_CVar is absent
	d.env.C_CVar = {}
	d.env.GetCVar = function(name) if name == "nameplateShowFriends" then return "1" end end
	eq(Rows.friendlyPlatesOn(), true, "GetCVar '1' returns true")

	d.env.GetCVar = function(name) if name == "nameplateShowFriends" then return "0" end end
	eq(Rows.friendlyPlatesOn(), false, "GetCVar '0' returns false")

	-- Numeric CVar other than 1 is false
	d.env.GetCVar = function(name) if name == "nameplateShowFriends" then return 2 end end
	eq(Rows.friendlyPlatesOn(), false, "numeric 2 is not 1")

	-- Non-numeric non-1 string is false; boolean true is true
	d.env.GetCVar = function(name) if name == "nameplateShowFriends" then return "yes" end end
	eq(Rows.friendlyPlatesOn(), false, "non-boolean string 'yes' is false")
	d.env.GetCVar = function(name) if name == "nameplateShowFriends" then return true end end
	eq(Rows.friendlyPlatesOn(), true, "boolean true is true")

	-- GetCVarBool fallback when both GetCVar functions return nil
	d.env.GetCVar = function() return nil end
	d.env.GetCVarBool = function(name) if name == "nameplateShowFriends" then return true end end
	eq(Rows.friendlyPlatesOn(), true, "GetCVarBool true returns true")

	d.env.GetCVarBool = function(name) if name == "nameplateShowFriends" then return false end end
	eq(Rows.friendlyPlatesOn(), false, "GetCVarBool false returns false")

	d.env.C_CVar, d.env.GetCVar, d.env.GetCVarBool = origCC, origGet, origBool
	T.clean(w)
end)

-- guards Wuber/UI/Settings/Rows.lua:384 (r ~= nil -> r == nil: soundInBgOff ignores GetCVar "0")
test("mutation b5 settings rows: Alert character tooltip warns when Sound in Background is off", function()
	local w = T.newWorld()
	local d = T.driver(w, T.BOB)
	T.settle(w)
	local origCC, origGet = d.env.C_CVar, d.env.GetCVar
	d.env.C_CVar = nil
	d.env.GetCVar = function(name)
		if name == "Sound_EnableSoundWhenGameIsInBG" then return "0" end
	end
	local st = openDriving(w, d)
	local field = st.controls["drive.bell"]
	ok(field and field.edit and field.edit.wuberTip, "drive.bell edit has wuberTip")
	local tipText = field.edit.wuberTip.text(field.edit)
	ok(tipText:find("Sound in Background is off", 1, true) ~= nil, "tooltip mentions Sound in Background is off")
	d.env.C_CVar, d.env.GetCVar = origCC, origGet
	T.clean(w)
end)

-- guards Wuber/UI/Settings/Rows.lua:593 (and -> or: captain treated as crewWindow)
test("mutation b5 settings rows: captain window can toggle Show ride passphrase", function()
	local w = T.newWorld()
	local d = T.driver(w, T.BOB)
	T.settle(w)
	d.W.Drive.IsCaptain = function() return true end
	d.W.Drive.opts().showPass = false
	local st = openDriving(w, d)
	local t = st.controls["drive.showPass"]
	ok(t, "drive.showPass toggle")
	scrollToControl(w, st, t)
	d:clickOn(t)
	w:advance(0.5)
	eq(d.W.Drive.opts().showPass, true, "captain click enables showPass")
	T.clean(w)
end)

-- guards Wuber/UI/Settings/Rows.lua:712 (fr == set -> fr ~= set: GLOBAL_MOUSE_DOWN on Set cancels capture)
-- guards Wuber/UI/Settings/Rows.lua:714 (drop statement: GLOBAL_MOUSE_DOWN elsewhere leaves capture active)
-- guards Wuber/UI/Settings/Rows.lua:728 (drop statement: st.capturing not cleared after binding a key)
-- guards Wuber/UI/Settings/Rows.lua:731 (key == "ESCAPE" -> key ~= "ESCAPE": Escape binds or blocks normal key)
test("mutation b5 settings rows: key capture starts disabled, ignores Esc, cancels on outside click, and stops after one key", function()
	local w = T.newWorld()
	local d = T.driver(w, T.BOB)
	T.settle(w)
	local st = openDriving(w, d)
	local set = st.controls["drive.key"]
	ok(set, "drive.key Set button")
	local cap = findKeyCapture(set)
	ok(cap, "key capture frame")
	eq(cap:IsKeyboardEnabled(), false, "keyboard disabled before clicking Set")

	local origFoci = d.env.GetMouseFoci
	-- Click Set, then GLOBAL_MOUSE_DOWN on Set keeps capture alive
	d:clickOn(set)
	d.env.GetMouseFoci = function() return { set } end
	cap:GetScript("OnEvent")(cap, "GLOBAL_MOUSE_DOWN")
	cap:GetScript("OnKeyDown")(cap, "F8")
	eq(d.W.db.drive.button.key, "F8", "F8 bound while capture kept alive on Set")

	-- Pressing another key after capture finished does not overwrite keybind
	cap:GetScript("OnKeyDown")(cap, "F9")
	eq(d.W.db.drive.button.key, "F8", "subsequent key does not overwrite F8")

	-- Escape cancels without changing keybind
	d:clickOn(set)
	cap:GetScript("OnKeyDown")(cap, "ESCAPE")
	eq(d.W.db.drive.button.key, "F8", "Escape does not overwrite F8")

	-- GLOBAL_MOUSE_DOWN outside Set cancels capture
	d:clickOn(set)
	d.env.GetMouseFoci = function() return {} end
	cap:GetScript("OnEvent")(cap, "GLOBAL_MOUSE_DOWN")
	cap:GetScript("OnKeyDown")(cap, "F10")
	eq(d.W.db.drive.button.key, "F8", "outside click cancelled capture")

	d.env.GetMouseFoci = origFoci
	T.clean(w)
end)

-- guards Wuber/UI/Settings/Rows.lua:748 (SetKey == "function" -> ~= "function": Clear button fails to clear keybind)
test("mutation b5 settings rows: Clear button removes the big button keybind", function()
	local w = T.newWorld()
	local d = T.driver(w, T.BOB)
	T.settle(w)
	d.W.Drive.SetKey("F8")
	eq(d.W.db.drive.button.key, "F8", "initial key F8")
	local st = openDriving(w, d)
	local set = st.controls["drive.key"]
	ok(set, "drive.key Set button")
	local clear
	for _, ch in ipairs({ set:GetParent():GetChildren() }) do
		if ch ~= set and ch.label and ch.label.GetText and ch.label:GetText() == "Clear" then
			clear = ch
			break
		end
	end
	ok(clear, "Clear button")
	local setKeyCalls = 0
	local origSetKey = d.W.Drive.SetKey
	d.W.Drive.SetKey = function(k)
		setKeyCalls = setKeyCalls + 1
		return origSetKey(k)
	end
	d:clickOn(clear)
	w:advance(0.2)
	d.W.Drive.SetKey = origSetKey
	eq(setKeyCalls, 1, "Clear calls Drive.SetKey")
	eq(d.W.db.drive.button.key, nil, "Clear removes saved keybind")
	T.clean(w)
end)

test("mutation b5 settings rows: Advert reminder clamps positive values below 15 to 15 and keeps 0", function()
	local w = T.newWorld()
	local d = T.driver(w, T.BOB)
	T.settle(w)
	local st = openDriving(w, d)
	local sl = st.controls["drive.adEvery"]
	ok(sl, "drive.adEvery slider")
	sl.onChange(5)
	eq(d.W.Drive.opts().adEvery, 15, "5 min clamped to 15")
	sl.onChange(0)
	eq(d.W.Drive.opts().adEvery, 0, "0 min stays 0")
	T.clean(w)
end)

-- guards Wuber/UI/Settings/Rows.lua:1001 (always sets shown=true and keepClosed=true)
-- guards Wuber/UI/Settings/Rows.lua:1004 (waiting sets shown=true and keepClosed=false)
-- guards Wuber/UI/Settings/Rows.lua:1007 (wuber sets shown=false)
test("mutation b5 settings rows: Big button on screen segmented control updates shown and keepClosed", function()
	local w = T.newWorld()
	local d = T.driver(w, T.BOB)
	T.settle(w)
	local st = openDriving(w, d)
	local seg = st.controls["drive.onScreen"]
	ok(seg, "drive.onScreen segmented control")
	scrollToControl(w, st, seg.buttons[3])
	d:clickOn(seg.buttons[3])
	eq(d.W.db.drive.button.shown, false, "Only in Wuber sets shown=false")
	d:clickOn(seg.buttons[1])
	eq(d.W.db.drive.button.shown, true, "Always sets shown=true")
	eq(d.W.db.drive.button.keepClosed, true, "Always sets keepClosed=true")
	d:clickOn(seg.buttons[3])
	d:clickOn(seg.buttons[2])
	eq(d.W.db.drive.button.shown, true, "When riders wait sets shown=true")
	eq(d.W.db.drive.button.keepClosed, false, "When riders wait sets keepClosed=false")
	T.clean(w)
end)

test("mutation b5 settings rows: enabling Flight offers clears midFlight flag", function()
	local w = T.newWorld()
	local d = T.driver(w, T.BOB)
	T.settle(w)
	d.W.db.flightOffers = false
	d.W.db.birdTip = false
	d.W.db.midFlight = true
	d.W.db.coach = true
	d.W.UI.Toggle(true)
	w:advance(3)
	d.W.UI.OpenSettings("riding")
	w:advance(1)
	local t = d.W.UI.settings.controls.flightOffers
	ok(t, "flightOffers toggle")
	d:clickOn(t)
	w:advance(0.2)
	eq(d.W.db.flightOffers, true, "flightOffers enabled")
	eq(d.W.db.midFlight, nil, "midFlight cleared when enabling flightOffers")
	T.clean(w)
end)

-- guards Wuber/UI/Settings/Rows.lua:1206 (newerVersion shown in aboutText on NEWER_VERSION)
test("mutation b5 settings rows: about footer updates when NEWER_VERSION fires", function()
	local w = T.newWorld()
	local d = T.driver(w, T.BOB)
	T.settle(w)
	d.W.db.coach = true
	d.W.UI.Toggle(true)
	w:advance(3)
	d.W.UI.OpenSettings("window")
	w:advance(1)
	local origNewer = d.W.NewerVersion
	d.W.NewerVersion = function() return "9.9.9" end
	d.W.Fire("NEWER_VERSION")
	local txt = d.W.UI.settings.about and d.W.UI.settings.about:GetText() or ""
	ok(txt:find("Wuber " .. tostring(d.W.VERSION), 1, true) ~= nil, "about footer shows current version")
	ok(txt:find("Wuber 9.9.9 is out", 1, true) ~= nil, "about footer shows newer version")
	d.W.NewerVersion = origNewer
	T.clean(w)
end)
