-- Decisions round, group J: Polestar ideas 2 and 11 (BUGS-NEXT PST-02, and the fake-game half of PST-01).
-- 1. Wuber opens the world map in ONE function, W.Map.Open, through the game's safe opener C_Map.OpenWorldMap.
-- 2. The fake game holds three taint rules (tests/lib/maptaint.lua): (a) no frame created under the world map,
--    (b) no click script on a frame under it, both except the cases of today listed in
--    tests/fixtures/map-taint-known.txt; (c) the map is opened only through the safe opener. tools/check.lua holds
--    (c) as plain text too (check 9).
-- Loaded by tests/run.lua with its helper table T.
local T = ...
local H, test, eq, ok = T.H, T.test, T.eq, T.ok
local MT = H.mapTaint

-- code that runs as if it stood in a shipped Wuber file (the rules judge only Wuber's own code)
local function asWuber(c, code, file)
	local chunk = assert(loadstring(code, "@" .. (file or (H.ADDONS.Wuber .. "/UI/Map/Probe.lua"))))
	setfenv(chunk, c.env)
	return chunk
end

local function taints(w)
	local out = {}
	for _, v in ipairs(w.violations) do
		if tostring(v):find(MT.MARK, 1, true) then out[#out + 1] = tostring(v) end
	end
	return out
end

local function mapWorld()
	local w = T.newWorld()
	local d = T.driver(w, T.BOB)
	local r = T.rider(w, T.TESTCHAR)
	T.settle(w)
	T.goOnline(d, { price = 5000 })
	w:advance(2)
	return w, r, d
end

-- counts the calls of an opener of the fake game, which still runs
local function spy(env, tbl, name)
	local t = tbl or env
	local old, n = t[name], { calls = 0 }
	t[name] = function(...) n.calls = n.calls + 1 n.last = (...) return old(...) end
	return n
end

test("dec j: show this driver on the map opens it through the game's safe opener, never through the map's own Lua", function()
	local w, r = mapWorld()
	local env = r.env
	local safe, panel = spy(env, env.C_Map, "OpenWorldMap"), spy(env, nil, "ShowUIPanel")
	ok(type(r.W.Map.Open) == "function", "W.Map.Open is there")
	ok(not env.WorldMapFrame:IsShown(), "the map starts shut")
	ok(r.W.Map.ShowDriver("bob stone"), "ShowDriver says yes")
	w:advance(0.2)
	ok(env.WorldMapFrame:IsShown(), "the map is open")
	ok(safe.calls >= 1, "through C_Map.OpenWorldMap")
	eq(panel.calls, 0, "ShowUIPanel is not used")
	local bob = r.W.drivers["bob stone"]
	eq(env.WorldMapFrame:GetMapID(), bob.mapID, "on the driver's map")
	eq(safe.last, bob.mapID, "the map was moved there by the safe opener too")
	eq(#taints(w), 0, "no taint rule broken: " .. table.concat(taints(w), "; "))
	-- W.Map.Open by itself: opens, and moves an open map
	env.WorldMapFrame:Hide()
	eq(r.W.Map.Open(), true, "Open() with no map opens the map")
	ok(env.WorldMapFrame:IsShown(), "open again")
	T.clean(w)
end)

test("dec j: the map is not opened in combat, and the safe opener is not even asked", function()
	local w, r = mapWorld()
	local env = r.env
	local safe = spy(env, env.C_Map, "OpenWorldMap")
	w:enterCombat(r)
	eq(r.W.Map.Open(1), false, "W.Map.Open refuses")
	eq(r.W.Map.ShowDriver("bob stone"), false, "ShowDriver refuses")
	eq(safe.calls, 0, "C_Map.OpenWorldMap was not called")
	ok(not env.WorldMapFrame:IsShown(), "the map stays shut")
	-- the fake game: the safe opener from Wuber's code in combat is a violation (the game blocks it)
	asWuber(r, "C_Map.OpenWorldMap()")()
	local left = taints(w)
	eq(#left, 1, "one violation")
	ok(left[1]:find("C_Map.OpenWorldMap() in combat", 1, true), left[1])
	ok(not env.WorldMapFrame:IsShown(), "and it did not open")
	w.violations = {}
	T.clean(w)
end)

test("dec j: a game without the safe opener still gets its map (the fallback), and the fake game allows that only then", function()
	local w, r = mapWorld()
	local env = r.env
	env.C_Map.OpenWorldMap = nil
	local panel = spy(env, nil, "ShowUIPanel")
	ok(r.W.Map.ShowDriver("bob stone"), "ShowDriver says yes")
	w:advance(0.2)
	ok(env.WorldMapFrame:IsShown(), "the map is open")
	eq(panel.calls, 1, "through ShowUIPanel, once")
	eq(env.WorldMapFrame:GetMapID(), r.W.drivers["bob stone"].mapID, "on the driver's map")
	eq(#taints(w), 0, "no violation: " .. table.concat(taints(w), "; "))
	T.clean(w)
end)

test("dec j: rule c seen red: each Lua way of opening the map raises from Wuber's code, and fails the test", function()
	local ways = {
		{ "ShowUIPanel(WorldMapFrame)", "ShowUIPanel(WorldMapFrame)" },
		{ "OpenWorldMap()", "OpenWorldMap()" },
		{ "ToggleWorldMap()", "ToggleWorldMap()" },
		{ "WorldMapFrame:Show()", "WorldMapFrame:Show()" },
		{ "WorldMapFrame:SetMapID(1411)", "WorldMapFrame:SetMapID()" },
	}
	for _, way in ipairs(ways) do
		local inner
		local passed, why = T.runOne(function()
			local w = T.newWorld()
			local c = T.rider(w, T.TESTCHAR)
			w:advance(1)
			inner = { w = w, c = c }
			-- under the addon's own pcall, as W.Safe would: swallowed, and still a failed test
			inner.okc, inner.err = pcall(asWuber(c, way[1]))
		end)
		eq(passed, false, way[1] .. ": the test fails")
		ok(tostring(why):find(way[2], 1, true), way[1] .. " named in the failure: " .. tostring(why))
		eq(inner.okc, false, way[1] .. " raised")
		ok(tostring(inner.err):find("map taint", 1, true), tostring(inner.err))
		ok(not inner.c.env.WorldMapFrame:IsShown(), way[1] .. ": the map did not open")
		inner.w.violations = {}
	end
	-- not Wuber's code: a test (the player pressing M) and the game's safe opener may
	local w = T.newWorld()
	local c = T.rider(w, T.TESTCHAR)
	w:advance(1)
	c.env.ShowUIPanel(c.env.WorldMapFrame)
	c.env.WorldMapFrame:Hide()
	c.env.ToggleWorldMap()
	c.env.WorldMapFrame:Hide()
	asWuber(c, "C_Map.OpenWorldMap(1411)")()
	ok(c.env.WorldMapFrame:IsShown(), "the safe opener opens the map")
	eq(c.env.WorldMapFrame:GetMapID(), 1411, "on the map asked for")
	eq(#taints(w), 0, "none of these is a violation: " .. table.concat(taints(w), "; "))
	T.clean(w)
end)

test("dec j: rule a seen red: a new frame created under the world map fails the test; made with no parent and then moved, it does not", function()
	local inner
	local passed, why = T.runOne(function()
		local w = T.newWorld()
		local c = T.rider(w, T.TESTCHAR)
		w:advance(1)
		inner = { w = w, c = c }
		asWuber(c, "WuberProbeA = CreateFrame('Frame', nil, WorldMapFrame.ScrollContainer.Child)")()
	end)
	eq(passed, false, "the test fails")
	ok(tostring(why):find("a frame created with a parent under the world map", 1, true), tostring(why))
	ok(tostring(why):find("UI/Map/Probe.lua:1", 1, true), "it names the file and line: " .. tostring(why))
	eq(#taints(inner.w), 1, "one violation")
	inner.w.violations = {}

	local w = T.newWorld()
	local c = T.rider(w, T.TESTCHAR)
	w:advance(1)
	asWuber(c, "local f = CreateFrame('Frame') f:SetParent(WorldMapFrame.ScrollContainer.Child) WuberProbeB = f")()
	eq(c.env.WuberProbeB:GetParent(), c.env.WorldMapFrame.ScrollContainer.Child, "the frame is under the map all the same")
	asWuber(c, "CreateFrame('Frame', nil, UIParent)")()
	c.env.CreateFrame("Frame", nil, c.env.WorldMapFrame) -- a test's own frame is not Wuber's
	asWuber(c, "CreateFrame('Frame', nil, WorldMapFrame)", H.root .. "/OtherAddon/Probe.lua")() -- nor another addon's
	eq(#taints(w), 0, "no violation: " .. table.concat(taints(w), "; "))
	-- the direct child of the map itself counts too
	asWuber(c, "CreateFrame('Frame', nil, WorldMapFrame)")()
	eq(#taints(w), 1, "a child of WorldMapFrame itself")
	w.violations = {}
	T.clean(w)
end)

test("dec j: rule b seen red: a new click script on a frame under the world map fails the test; a hover script does not", function()
	for _, code in ipairs({
		"WuberProbeB:SetScript('OnClick', function() end)",
		"WuberProbeB:SetScript('OnMouseDown', function() end)",
		"WuberProbeB:SetScript('OnMouseUp', function() end)",
		"WuberProbeB:HookScript('OnMouseUp', function() end)",
	}) do
		local inner
		local passed, why = T.runOne(function()
			local w = T.newWorld()
			local c = T.rider(w, T.TESTCHAR)
			w:advance(1)
			inner = { w = w, c = c }
			asWuber(c, "local f = CreateFrame('Button') f:SetParent(WorldMapFrame.ScrollContainer.Child) WuberProbeB = f")()
			asWuber(c, code)()
		end)
		eq(passed, false, code .. ": the test fails")
		ok(tostring(why):find("a click script on a frame under the world map", 1, true), tostring(why))
		eq(#taints(inner.w), 1, code .. ": one violation")
		inner.w.violations = {}
	end
	local w = T.newWorld()
	local c = T.rider(w, T.TESTCHAR)
	w:advance(1)
	asWuber(c, "local f = CreateFrame('Button') f:SetParent(WorldMapFrame.ScrollContainer.Child) WuberProbeB = f")()
	asWuber(c, "WuberProbeB:SetScript('OnEnter', function() end) WuberProbeB:SetScript('OnClick', nil)")()
	asWuber(c, "local f = CreateFrame('Button', nil, UIParent) f:SetScript('OnClick', function() end)")()
	asWuber(c, "WorldMapFrame:HookScript('OnShow', function() end)")()
	c.env.WuberProbeB:SetScript("OnClick", function() end) -- a test's own script is not Wuber's
	eq(#taints(w), 0, "no violation: " .. table.concat(taints(w), "; "))
	T.clean(w)
end)

test("dec j: the known list is what Wuber's map does today: no frame lines and 5 click lines, none stale, and a line off the list fails", function()
	local frames, clicks = 0, 0
	for key in pairs(MT.known) do
		if key:find("^frame | ") then frames = frames + 1 elseif key:find("^click | ") then clicks = clicks + 1
		else error("a line of the known list that is neither frame nor click: " .. key) end
	end
	eq(frames, 0, "frame lines on tests/fixtures/map-taint-known.txt (PST-01 part A: every map frame is made with no parent, then parented; a new line needs the author's yes)")
	eq(clicks, 5, "click lines on the list")
	eq(table.concat(MT.stale(), "\n"), "", "every listed line is still in the source (remove a line when its case is gone)")
	-- today's map, used for real: pins, tags, the route and the buttons all come from listed lines
	local w, r = mapWorld()
	ok(r.W.Map.ShowDriver("bob stone"), "the map opens on Bob")
	w:advance(1)
	local seenFrames, seenClicks = 0, 0
	for key in pairs(w.mapTaint or {}) do
		ok(MT.known[key], "seen and listed: " .. key)
		if key:find("^frame | ") then seenFrames = seenFrames + 1 else seenClicks = seenClicks + 1 end
	end
	eq(seenFrames, 0, "no Wuber map frame is made with a parent under the map")
	ok(seenClicks >= 3, "and its click scripts (" .. seenClicks .. " lines)")
	eq(#taints(w), 0, "nothing off the list: " .. table.concat(taints(w), "; "))
	T.clean(w)
	-- the same map with one line taken off the list: red
	local saved = MT.known
	local inner
	local passed, why = T.runOne(function()
		local short = {}
		for key in pairs(saved) do short[key] = true end
		short['click | UI/Map/Pins.lua | pin:SetScript("OnClick", function(self)'] = nil
		MT.known = short
		local w2, r2 = mapWorld()
		inner = w2
		r2.W.Map.ShowDriver("bob stone")
		w2:advance(1)
	end)
	MT.known = saved
	eq(passed, false, "the test fails")
	ok(tostring(why):find("pin:SetScript(\"OnClick\"", 1, true), "and names the line: " .. tostring(why))
	inner.violations = {}
end)

test("dec j: check.lua fails on a map opener anywhere but W.Map.Open", function()
	local scan = T.CHECK.scanMapOpen
	eq(scan("UI/Home.lua", "local x = 1\nShowUIPanel(WorldMapFrame)\n"), 2, "ShowUIPanel in another file fails, at the line")
	eq(scan("UI/Home.lua", "ToggleWorldMap()\n"), 1, "ToggleWorldMap")
	eq(scan("UI/Home.lua", "OpenWorldMap(12)\n"), 1, "the Lua OpenWorldMap")
	eq(scan("UI/Home.lua", "C_Map.OpenWorldMap(12)\n"), 1, "even the safe opener belongs in W.Map.Open only")
	eq(scan("UI/Home.lua", "WorldMapFrame:Show()\n"), 1, "WorldMapFrame:Show")
	eq(scan("UI/Home.lua", "WorldMapFrame:SetMapID(12)\n"), 1, "SetMapID")
	eq(scan("UI/Home.lua", "-- ShowUIPanel(WorldMapFrame) is never called here\nlocal shown = WorldMapFrame:IsShown()\n"), nil,
		"a comment is no call, and reading the map is fine")
	local one = "local open = C_Map.OpenWorldMap\npcall(ShowUIPanel, map)\ncall(map, \"SetMapID\", id)\n"
	eq(scan("UI/Map/Map.lua", one), nil, "W.Map.Open's file may name each once")
	eq(scan("UI\\Map\\Map.lua", one), nil, "Windows separators too")
	eq(scan("UI/Map/Map.lua", one .. "ShowUIPanel(map)\n"), 4, "a second ShowUIPanel line there fails")
	eq(scan("UI/Map/Map.lua", one .. "ToggleWorldMap()\n"), 4, "ToggleWorldMap is allowed nowhere")
	local n = 0
	for _ in pairs(T.CHECK.MAP_ALLOW) do n = n + 1 end
	eq(n, 1, "one file on the list")
	-- the shipped map files pass check 9, and a copy with the old opener does not
	local res = T.CHECK.check({ root = H.root, files = { "UI/Map/Map.lua", "UI/Map/Base.lua", "UI/Window.lua" }, globals = nil })
	for _, f in ipairs(res.fails) do ok(not f:find("W.Map.Open", 1, true), f) end
	local src = T.readFile(H.ADDONS.Wuber .. "/UI/Map/Map.lua")
	eq(scan("UI/Map/Map.lua", src), nil, "UI/Map/Map.lua as shipped")
	local line, name = scan("UI/Map/Map.lua", src .. "\nlocal function old(map) pcall(ShowUIPanel, map) end\n")
	ok(line, "the old opener added back fails")
	eq(name, "ShowUIPanel", "and is named")
end)
