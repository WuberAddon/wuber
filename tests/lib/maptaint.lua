-- tests/lib/maptaint.lua: three world-map taint rules of the fake game (decisions round, group J; Polestar ideas 2 and 11).
-- In the real game the world map is the game's own window: addon code that makes frames under it, puts click scripts
-- on its children or opens it with the game's Lua runs inside the map's code and can leave it "tainted" (a blocked
-- open in a fight, lost quest pins, "AddOn blocked" with the gamepad interface). The fake game holds Wuber to:
--   (a) frame   no frame is created with a parent under WorldMapFrame, except the lines listed in
--               tests/fixtures/map-taint-known.txt (what Wuber's map pins do today; rewriting them is another job);
--   (b) click   no OnClick / OnMouseDown / OnMouseUp script (SetScript, HookScript) on a frame under the map, except
--               the listed lines;
--   (c) open    the map is opened or moved only through the game's safe opener C_Map.OpenWorldMap (Wuber: W.Map.Open).
--               ShowUIPanel(WorldMapFrame), OpenWorldMap(), ToggleWorldMap(), WorldMapFrame:Show() and
--               WorldMapFrame:SetMapID() from Wuber's code raise, like a call on tools/forbidden.lua. Allowed only
--               when the client has no C_Map.OpenWorldMap at all (Wuber's fallback). The safe opener in combat is a
--               violation too (Wuber refuses first).
-- A case of (a) or (b) is named by its file and the text of its source line (not the line number, so edits above it
-- do not matter). A case not on the list is a violation that fails the test, cleaned or not (H.forbiddenLeft).
-- Only code in the shipped Wuber folder is judged: tests, the harness and other addons may do as they like, and so
-- may a client that replays old code (client.rewrite).
-- WUBER_MAPTAINT_LOG=<file>: every case seen is appended there ("known" or "NEW"), to mend the list after a real change.
return function(H, isUnder)
	local MT = { known = {}, seen = {}, safe = 0 }
	MT.MARK = " (world-map taint rule, tests/lib/maptaint.lua)"
	MT.CLICKS = { OnClick = true, OnMouseDown = true, OnMouseUp = true }
	local harnessDir, root
	do
		local src = debug.getinfo(1, "S").source:gsub("^@", ""):gsub("\\", "/")
		harnessDir = src:match("^(.*)/lib/[^/]*$") or "tests"
		root = harnessDir:match("^(.*)/[^/]*$") or "."
	end
	MT.file = harnessDir .. "/fixtures/map-taint-known.txt"

	local function trim(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end
	function MT.load(path)
		local out = {}
		local f = io.open(path or MT.file, "r")
		if not f then return out end
		for line in f:lines() do
			line = trim(line)
			if line ~= "" and line:sub(1, 1) ~= "#" then out[line] = true end
		end
		f:close()
		return out
	end
	MT.known = MT.load()

	-- Wuber's file and line now running, skipping C functions and the harness; nil when a test, the harness itself
	-- or another addon is the first code found.
	local lines = {}
	function MT.caller()
		local dir = H.ADDONS and H.ADDONS.Wuber
		if not dir then return nil end
		dir = dir:gsub("\\", "/")
		for level = 3, 60 do
			local info = debug.getinfo(level, "Sl")
			if not info then return nil end
			if info.what ~= "C" and info.what ~= "tail" then
				local src = (info.source or ""):gsub("\\", "/")
				local at = src:find(dir, 1, true)
				local before = at and src:sub(at - 1, at - 1) or ""
				if at and (at <= 2 or before == "/" or before == "@") then
					return src:sub(at + #dir + 1), info.currentline, src:gsub("^@", "")
				end
				if not (src:find("harness[%w_]*%.lua$") or src:find("tests/lib/", 1, true)) then return nil end
			end
		end
		return nil
	end
	local function lineText(path, n)
		local t = lines[path]
		if not t then
			t = {}
			local f = io.open(path, "r")
			if f then for l in f:lines() do t[#t + 1] = l end f:close() end
			lines[path] = t
		end
		return t[n] and trim(t[n]) or ("line " .. tostring(n))
	end
	MT.dropSources = function() lines = {} end

	local function judged(client)
		return client and client.world and not client.rewrite
	end
	local function note(client, kind)
		if not judged(client) then return end
		local file, line, path = MT.caller()
		if not file then return end
		local key = kind .. " | " .. file .. " | " .. lineText(path, line)
		local w = client.world
		w.mapTaint = w.mapTaint or {}
		w.mapTaint[key] = (w.mapTaint[key] or 0) + 1
		local first = not MT.seen[key]
		MT.seen[key] = true
		local known = MT.known[key]
		if first then
			local log = os.getenv("WUBER_MAPTAINT_LOG")
			if log and log ~= "" then
				local f = io.open(log, "a")
				if f then f:write((known and "known " or "NEW   ") .. key .. "\n") f:close() end
			end
		end
		if not known then
			local what = kind == "frame" and "a frame created with a parent under the world map"
				or "a click script on a frame under the world map"
			w.violations[#w.violations + 1] = client.player.name .. ": " .. what .. ", not on the known list (" .. file .. ":"
				.. tostring(line) .. "; " .. key .. ")" .. MT.MARK
		end
	end

	-- (a) from H.createFrame
	function MT.created(client, parent)
		local map = client.env and client.env.WorldMapFrame
		if not map or not (parent == map or isUnder(parent, map)) then return end
		note(client, "frame")
	end
	-- (b) from Frame:SetScript / Frame:HookScript
	function MT.script(client, frame, name)
		if not MT.CLICKS[name] then return end
		local map = client and client.env and client.env.WorldMapFrame
		if not map or frame == map or not isUnder(frame, map) then return end
		note(client, "click")
	end
	-- (c) from the fake's Lua openers; raises when Wuber's code is the caller and the game has the safe opener
	function MT.opener(client, what)
		if MT.safe > 0 or not judged(client) then return end
		local file, line = MT.caller()
		if not file then return end
		local cmap = client.env.C_Map
		if not (type(cmap) == "table" and type(cmap.OpenWorldMap) == "function") then return end
		local w = client.world
		w.violations[#w.violations + 1] = client.player.name .. ": " .. what .. " from addon code (" .. file .. ":" .. tostring(line)
			.. "): the world map is opened only through C_Map.OpenWorldMap (W.Map.Open)" .. MT.MARK
		error("map taint: " .. what .. " from addon code; open the world map through C_Map.OpenWorldMap (W.Map.Open)", 3)
	end
	-- the fake C_Map.OpenWorldMap: fn runs as the game's own code
	function MT.safeOpen(client, fn, ...)
		if client.player.combat and judged(client) and MT.caller() then
			local w = client.world
			w.violations[#w.violations + 1] = client.player.name .. ": C_Map.OpenWorldMap() in combat" .. MT.MARK
			client:fire("ADDON_ACTION_BLOCKED", "Wuber", "C_Map.OpenWorldMap()")
			return
		end
		MT.safe = MT.safe + 1
		local ok, err = pcall(fn, ...)
		MT.safe = MT.safe - 1
		if not ok then error(err, 0) end
	end
	-- every case of this run's known list whose source line is gone (the list is stale): for the test
	function MT.stale(known)
		local out = {}
		local dir = H.ADDONS.Wuber
		for key in pairs(known or MT.known) do
			local kind, file, text = key:match("^(%S+) | (%S+) | (.*)$")
			local found = false
			local f = file and io.open(dir .. "/" .. file, "r")
			if f then
				for l in f:lines() do if trim(l) == text then found = true break end end
				f:close()
			end
			if not found then out[#out + 1] = key end
		end
		table.sort(out)
		return out
	end
	return MT
end
