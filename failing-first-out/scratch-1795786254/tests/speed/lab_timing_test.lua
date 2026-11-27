-- tests/speed/lab_timing_test.lua (job 2749, step 4): Wuber Lab's Auto check has a TIMING PASS (lab/WuberLab/AutoSpeed.lua).
-- For each screen change it saves the Lua ms of the call, the worst frame in the next second and Wuber's memory before/after
-- in WuberLabDB.autoCheck.speed; tools/labreport.js prints them (lab/tools/test/labreport.test.js). It sends nothing and leaves WuberDB as it was.
local T = ...
local H, test, eq, ok = T.H, T.test, T.eq, T.ok

local LAB_DIR = os.getenv("WUBER_LAB_DIR") or (H.root .. "/lab/WuberLab")
if not H.exists(LAB_DIR .. "/WuberLab.toc") then
	test("speed lab: Wuber Lab not found (skipped)", function() end)
	return
end

-- the changes the brief lists, in the order the report prints them
local WANT = { "close0", "open1", "close1", "open2", "trips1", "ride1", "drive1", "earn1", "earn_back", "ride2", "settings1", "settings_back",
	"help1", "help_back", "confirm1", "confirm_home", "unfold", "fold" }

local function serialize(v, out)
	if type(v) ~= "table" then out[#out + 1] = tostring(v) return end
	local keys = {}
	for k in pairs(v) do keys[#keys + 1] = k end
	table.sort(keys, function(a, b)
		if type(a) == type(b) and (type(a) == "number" or type(a) == "string") then return a < b end
		return type(a) < type(b)
	end)
	out[#out + 1] = "{"
	for _, k in ipairs(keys) do
		out[#out + 1] = tostring(k) .. "="
		serialize(v[k], out)
		out[#out + 1] = ","
	end
	out[#out + 1] = "}"
end

local function sentBy(w, name)
	local n = 0
	for _, list in ipairs({ w.addonLog or {}, w.whispers or {}, w.chatPosts or {}, w.invites or {} }) do
		for _, e in ipairs(list) do if e.from == name then n = n + 1 end end
	end
	return n
end

local function labClient(w)
	local c = w:addClient("Anita Lift", { spot = "Undercity", class = "WARLOCK", money = 100000, addons = { "Wuber", "WuberLab" },
		screenW = 1920, screenH = 1080 })
	T.settle(w)
	-- the tour's camera: a shot is a quiet call, the game says it was saved a moment later
	c.env.Screenshot = function() c.env.C_Timer.After(0.2, function() c:fire("SCREENSHOT_SUCCEEDED") end) end
	return c
end

local function withLab(fn)
	local before = H.ADDONS.WuberLab
	H.ADDONS.WuberLab = LAB_DIR
	local good, err = pcall(fn)
	H.ADDONS.WuberLab = before
	if not good then error(err, 0) end
end

test("speed lab: the Auto check's timing pass saves a row per screen change (ms, worst frame, memory), sends nothing, leaves WuberDB as it was", function()
	withLab(function()
		local w = T.newWorld()
		w:addClient("Mia Runner", { spot = "Undercity", class = "WARLOCK" })
		local c = labClient(w)
		local L = c.ns.WuberLab
		local out = {}
		serialize(c.env.WuberDB, out)
		local dbBefore = table.concat(out)
		local sent = sentBy(w, "Anita Lift")
		local started, why = L.AutoStart({ words = { "a_speed" } })
		ok(started, "the Auto check started with the timing pass: " .. tostring(why))
		for _ = 1, 400 do
			if not L.AutoRunning() then break end
			w:advance(1)
		end
		ok(not L.AutoRunning(), "the Auto check ended")
		local saved = c.env.WuberLabDB.autoCheck
		ok(saved and saved.speed, "the run saved a speed table")
		local rows, byId = saved.speed.rows, {}
		for _, r in ipairs(rows) do byId[r.id] = r end
		eq(#rows, #WANT, "one row per change")
		for i, id in ipairs(WANT) do
			local r = byId[id]
			ok(r, "a row for " .. id)
			if r then
				eq(rows[i].id, id, "row " .. i .. " is " .. id)
				ok(type(r.ms) == "number" and r.ms >= 0, id .. ": ms is a number >= 0")
				ok(type(r.frame) == "number" and r.frame >= 0, id .. ": worst frame is a number >= 0")
				ok((r.frames or 0) >= 1, id .. ": at least one frame watched")
				ok(type(r.kb) == "number", id .. ": memory delta is a number")
				ok(type(r.label) == "string" and r.label ~= "", id .. " has its words")
				eq(r.note, nil, id .. ": no error")
			end
		end
		-- (review) each change happened: the window closes and opens, and unfold really unfolds (1920 wide: there is room)
		local function st(id) return byId[id] or {} end
		eq(st("close0").shown, false, "close0: the window is shut")
		eq(st("open1").shown, true, "open1: the window is open (a real open, not one already open)")
		eq(st("close1").shown, false, "close1: the window is shut")
		ok(st("unfold").fits, "control: the window has room to unfold here")
		eq(st("unfold").unfolded, true, "unfold (the fold button): the window is unfolded")
		eq(st("fold").unfolded, false, "fold (the fold button again): the window is folded")
		ok(type(saved.speed.startKB) == "number" and saved.speed.startKB >= 0, "Wuber's memory at the start")
		ok(type(saved.speed.endKB) == "number" and saved.speed.endKB >= 0, "Wuber's memory at the end")
		eq(sentBy(w, "Anita Lift") - sent, 0, "nothing sent: no chat, no addon message")
		out = {}
		serialize(c.env.WuberDB, out)
		eq(table.concat(out), dbBefore, "WuberDB after the timing pass")
		T.clean(w)
	end)
end)

-- guard: off by default outside the Auto check
test("speed lab: the timing pass is an Auto check screen only (the photo tour and a plain Auto subset never run it)", function()
	withLab(function()
		local w = T.newWorld()
		local c = labClient(w)
		local L = c.ns.WuberLab
		for _, s in ipairs(L.PHOTO_SCREENS) do ok(s.id ~= "a_speed", "the photo tour does not list a_speed") end
		local listed = false
		for _, s in ipairs(L.AutoScreens()) do if s.id == "a_speed" then listed = true end end
		ok(listed, "the Auto check lists a_speed")
		ok(L.TourStart({ only = { "home" } }), "a plain tour started")
		for _ = 1, 60 do
			if not L.Touring() then break end
			w:advance(1)
		end
		eq(L.speedRows, nil, "a plain tour times nothing")
		eq(c.env.WuberLabDB.autoCheck, nil, "a plain tour saves no Auto check")
		T.clean(w)
	end)
end)
