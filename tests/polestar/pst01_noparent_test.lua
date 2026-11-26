-- PST-01 part A (Polestar): with the game's Gamepad UI on, a frame CREATED with a parent that sits inside an open game
-- window (the world map) makes the game rebuild that window's navigation inside the addon's code and taints the map.
-- The cure: create the frame with NO parent, then SetParent. These tests prove the promise: no Wuber CreateFrame call is
-- given a parent that is the world map or under it, and every such frame still ends up where it was (same parent, same
-- level and strata). Also W.GamepadUI (Core.Runtime). Loaded by tests/run.lua with its helper table T.
local T = ...
local H, test, eq, ok = T.H, T.test, T.eq, T.ok

local function under(f, map)
	local n = 0
	while f and n < 60 do
		if f == map then return true end
		f = f.GetParent and f:GetParent() or nil
		n = n + 1
	end
	return false
end

-- wraps the client's CreateFrame: notes every call made from Wuber's own files (file and line, the parent given, the
-- frame made); a call whose parent is the map or under it goes in rec.bad
local function watch(r)
	local env = r.env
	local old = env.CreateFrame
	local rec = { calls = {}, bad = {}, made = {} }
	env.CreateFrame = function(ftype, name, parent, ...)
		local f = old(ftype, name, parent, ...)
		-- the Wuber line that asked, past the map helper that makes the frame
		local file, line
		local dir = (H.ADDONS.Wuber):gsub("\\", "/")
		for level = 2, 12 do
			local info = debug.getinfo(level, "Sl")
			if not info then break end
			local src = (info.source or ""):gsub("\\", "/"):gsub("^@", "")
			if src:sub(1, #dir + 1) == dir .. "/" and not src:find("/UI/Map/Base.lua", 1, true) then
				file, line = src:sub(#dir + 2), info.currentline
				break
			end
		end
		if file then
			local c = { file = file, line = line, parent = parent, frame = f, ftype = ftype }
			rec.calls[#rec.calls + 1] = c
			if parent ~= nil and under(parent, env.WorldMapFrame) then rec.bad[#rec.bad + 1] = c end
		end
		return f
	end
	return rec
end

local function drive()
	local w = T.newWorld()
	local d = T.driver(w, T.BOB)
	local c = T.driver(w, T.ANITA) -- the creator: the big crowned pin with the sparkle
	local r = T.rider(w, T.TESTCHAR)
	T.settle(w)
	local rec = watch(r)
	T.goOnline(d, { price = 5000 })
	T.goOnline(c, { price = 2000 })
	w:advance(2)
	r.W.db.mapOnly = true
	ok(r.W.Map.ShowDriver("bob stone"), "ShowDriver opens the map on Bob")
	w:advance(0.5)
	local map = r.env.WorldMapFrame
	local child = map.ScrollContainer.Child
	-- hover: the cursor over a place makes the tag and the corner button
	r.mouseOver = map.ScrollContainer
	local found
	for ix = 0, 100, 2 do
		for iy = 0, 100, 2 do
			r.mapCursorX, r.mapCursorY = ix / 100, iy / 100
			if not found and r.W.Map.PlaceUnderCursor(false) then found = true end
			if found then break end
		end
		if found then break end
	end
	w:advance(1)
	-- the route line on the canvas, and on a panel
	r.W.Map.RouteOnPanel(child, { 0.2, 0.2 }, { 0.8, 0.7 })
	w:advance(0.5)
	r.W.Map.Refresh()
	w:advance(0.5)
	return w, r, rec, map
end

test("pst01 noparent: no Wuber frame is created with a parent under the world map, and each still ends up under it", function()
	local w, r, rec, map = drive()
	local seen = {}
	for _, c in ipairs(rec.calls) do seen[c.file] = true end
	ok(seen["UI/Map/Pins.lua"] and seen["UI/Map/Map.lua"] and seen["UI/Map/Route.lua"], "the drive reached Pins, Map and Route")
	local lines = {}
	for _, c in ipairs(rec.bad) do lines[#lines + 1] = c.file .. ":" .. tostring(c.line) end
	eq(#rec.bad, 0, "CreateFrame was given a parent under the map at: " .. table.concat(lines, ", "))
	-- where they ended: the frames Wuber's map files made are under the map (or, for the one not shown, still parented)
	local made, bare = 0, {}
	for _, c in ipairs(rec.calls) do
		if c.file:find("^UI/Map/") then
			ok(c.frame:GetParent() ~= nil, c.file .. ":" .. tostring(c.line) .. " has a parent after the call")
			if under(c.frame, map) then made = made + 1 end
		end
	end
	ok(made >= 20, "frames of the map files sit under the world map: " .. made)
	-- the canvas children keep their frame level (one above the canvas) and strata
	local child = map.ScrollContainer.Child
	for _, f in ipairs({ child:GetChildren() }) do
		eq(f:GetFrameStrata(), child:GetFrameStrata(), "a pin keeps the canvas strata")
		ok(f:GetFrameLevel() >= child:GetFrameLevel(), "a pin is not below the canvas")
	end
	T.clean(w)
end)

test("pst01 noparent: a pin still takes a real click (it is the topmost frame at its centre) and opens Wuber on that driver", function()
	local w, r, rec, map = drive()
	local child = map.ScrollContainer.Child
	local pin
	for _, f in ipairs({ child:GetChildren() }) do
		if f.key == "bob stone" and H.visible(f) then pin = f end
	end
	ok(pin, "Bob's pin is on the map")
	local TM = dofile(H.root .. "/tests/lib/topmost.lua")
	TM.assertTopmost(H, r, pin, "Bob's pin")
	local shown = {}
	r.W.UI.Show = function(screen, arg) shown[#shown + 1] = tostring(screen) .. ":" .. tostring(arg) end
	r:clickOn(pin)
	w:advance(0.2)
	eq(shown[1], "confirm:bob stone", "the click opens Wuber on Confirm for that driver")
	T.clean(w)
end)

test("pst01 noparent: W.GamepadUI is true with the gamepad style, false with the mouse style and with no style call at all", function()
	-- the style is set before the addon loads, as in the game (UI/Commands.lua may read it at load)
	local function fresh(style, enumGamePad)
		local w = T.newWorld()
		local r = T.rider(w, T.TESTCHAR, { prepare = function(env)
			env.Enum = env.Enum or {}
			env.Enum.InputDeviceInterfaceType = enumGamePad and { MouseKeyboard = 0, GamePad = 1 } or nil
			env.C_InputInterfaceStyle = style and { GetCurrentStyle = function() return style end } or nil
		end })
		T.settle(w)
		return w, r
	end
	local w, r = fresh(1, true)
	ok(type(r.W.GamepadUI) == "function", "W.GamepadUI exists")
	eq(r.W.GamepadUI(), true, "gamepad style")
	r.env.C_InputInterfaceStyle = { GetCurrentStyle = function() error("asked twice") end }
	eq(r.W.GamepadUI(), true, "read once, then cached")
	T.clean(w)
	local w2, r2 = fresh(0, true)
	eq(r2.W.GamepadUI(), false, "mouse style")
	T.clean(w2)
	local w3, r3 = fresh(nil, true)
	eq(r3.W.GamepadUI(), false, "no C_InputInterfaceStyle")
	T.clean(w3)
	local w4, r4 = fresh(1, false)
	eq(r4.W.GamepadUI(), false, "no Enum")
	T.clean(w4)
	local w5, r5 = fresh(0, true)
	r5.env.C_InputInterfaceStyle = { GetCurrentStyle = function() error("boom") end }
	eq(r5.W.GamepadUI(), false, "a failing call is false")
	T.clean(w5)
end)
