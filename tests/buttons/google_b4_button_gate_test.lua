-- tests/buttons/google_b4_button_gate_test.lua: gate ensuring every tour-screen control
-- has either a probe row in tests/buttons/probes/*.lua or a line in tests/buttons/probes/TODO.lua,
-- and that no probe row points to a control that is gone.
local T = ...
local H = T.H
local Lib = assert(loadfile(T.dir .. "/buttons/lib.lua"))(T)

local function isSettingsControl(screen, id)
	if not (screen:match("^settings") or screen:match("^simple_settings")) then
		return false
	end
	return id:match("@Rows%.lua$") ~= nil
		or id:match("@Panel%.lua$") ~= nil
		or id:match("@Find%.lua$") ~= nil
end

local function loadProbes(probesDir)
	local probed, rows = {}, {}
	for _, path in ipairs(H.listFiles(probesDir, "lua")) do
		if not path:match("[/\\]TODO%.lua$") then
			local list = assert(loadfile(path))()
			local file = path:match("([^/\\]+)$")
			if type(list) == "table" then
				for _, row in ipairs(list) do
					if type(row) == "table" and row.id and row.on then
						probed[row.on] = probed[row.on] or {}
						probed[row.on][row.id] = true
						rows[#rows + 1] = { id = row.id, on = row.on, file = file }
					end
				end
			end
		end
	end
	return probed, rows
end

T.test("b4 button gate: every tour control has a probe row or TODO line and no probe row is stale", function()
	local probesDir = T.dir .. "/buttons/probes"
	local todo = assert(loadfile(probesDir .. "/TODO.lua"))()
	T.ok(type(todo.settingsGate) == "string" and todo.settingsGate ~= "", "TODO.lua points to settingsGate")
	local sg = io.open(T.dir .. "/../" .. todo.settingsGate, "r")
	T.ok(sg ~= nil, "settingsGate exists: " .. tostring(todo.settingsGate))
	if sg then sg:close() end

	local inTodo = {}
	for _, entry in ipairs(todo) do
		if type(entry) == "table" and entry.id and entry.screen then
			inTodo[entry.screen] = inTodo[entry.screen] or {}
			inTodo[entry.screen][entry.id] = true
		end
	end

	local probed, probeRows = loadProbes(probesDir)
	local ctx = Lib.newWorld()
	local shownScreens, skippedScreens, seenOnScreen = {}, {}, {}
	local missing = {}

	for _, s in ipairs(Lib.screens(ctx)) do
		local okShow = Lib.show(ctx, s)
		if not okShow then
			skippedScreens[s.id] = true
		else
			shownScreens[s.id] = true
			local seen = {}
			seenOnScreen[s.id] = seen
			for _, ctl in ipairs(Lib.controls(ctx)) do
				if not seen[ctl.id] then
					seen[ctl.id] = true
					if not isSettingsControl(s.id, ctl.id) then
						local hasProbe = probed[s.id] and probed[s.id][ctl.id]
						local hasTodo = inTodo[s.id] and inTodo[s.id][ctl.id]
						if not hasProbe and not hasTodo then
							missing[#missing + 1] = ctl.id .. " (on " .. s.id .. ")"
						end
					end
				end
			end
		end
	end

	local gone = {}
	for _, row in ipairs(probeRows) do
		if not skippedScreens[row.on] then
			if not (shownScreens[row.on] and seenOnScreen[row.on] and seenOnScreen[row.on][row.id]) then
				gone[#gone + 1] = row.id .. " (on " .. row.on .. ", in " .. row.file .. "): control gone"
			end
		end
	end

	local nowProbed = 0
	for _, entry in ipairs(todo) do
		if type(entry) == "table" and entry.id and entry.screen then
			if probed[entry.screen] and probed[entry.screen][entry.id] then
				nowProbed = nowProbed + 1
			end
		end
	end
	if nowProbed > 0 then
		print(nowProbed .. " TODO lines are now probed, remove them")
	end

	table.sort(missing)
	table.sort(gone)
	T.ok(#missing == 0, #missing .. " control(s) with neither a probe row nor a TODO.lua line:\n  " .. table.concat(missing, "\n  "))
	T.ok(#gone == 0, #gone .. " probe row(s) with control gone:\n  " .. table.concat(gone, "\n  "))
	T.eq(#ctx.w.errors, 0, "no Lua errors during b4 button gate walk")
end)
