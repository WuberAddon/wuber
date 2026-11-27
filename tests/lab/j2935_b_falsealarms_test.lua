-- Lab job 2935 (group B): four Auto check false alarms from in-game run 2 of 2.4.4-dev.
local T = ...
local H, test, eq, ok = T.H, T.test, T.eq, T.ok
local newWorld, settle = T.newWorld, T.settle

local LAB_DIR = os.getenv("WUBER_LAB_DIR") or (H.root .. "/lab/WuberLab")
if not H.exists(LAB_DIR .. "/AutoCheck.lua") then
	test("lab auto false alarms: AutoCheck.lua not found (skipped)", function() end)
	return
end
H.ADDONS.WuberLab = LAB_DIR

local function client(w)
	local c = w:addClient("Anita Lift", { spot = "Undercity", class = "WARLOCK", money = 100000, addons = { "Wuber", "WuberLab" },
		allowMissing = not T.HAVE_UI, screenW = 1920, screenH = 1080 })
	settle(w)
	return c
end


local function run(c, w, id)
	c.env.WuberLabBarSteps = { name = "STEPS-T", auto = { id } }
	c.env.Screenshot = function() c.env.C_Timer.After(0.2, function() c:fire("SCREENSHOT_SUCCEEDED") end) end
	c.W.UI.Toggle(true)
	w:advance(2)
	local L = c.ns.WuberLab
	ok(L.AutoStart({}), "the Auto check started")
	for i = 1, 6000 do
		if not L.AutoRunning() then break end
		w:advance(1)
	end
	return L.lastAuto or {}
end
local function verdict(last, id, kind)
	for _, r in ipairs(last.results or {}) do
		if r.id == id and r.kind == "verify " .. kind then return r end
	end
end

local function screenById(L, id)
	for _, s in ipairs(L.AUTO_SCREENS) do if s.id == id then return s end end
end

test("lab false alarm F5: the raid page's '+N more below' pill is allowed, other text under a button is not", function()
	local w = newWorld()
	local L = client(w).ns.WuberLab
	local function allowedFor(screen, text)
		for _, a in ipairs(L.AUTO_ALLOW) do
			if a.kind == "under" and screen:find(a.screen or "") and text:find(a.text or "") then return true end
		end
		return false
	end
	ok(allowedFor("raid+folded", 'Ride.lua:12 FontString "Messages" half under Raid.lua:200 Button "+3 more below"'), "the cue pill is allowed on the raid page")
	ok(not allowedFor("home+folded", 'FontString "Messages" half under Raid.lua:200 Button "+3 more below"'), "only on the raid page")
	ok(not allowedFor("raid+folded", 'FontString "Messages" half under Raid.lua:200 Button "Save"'), "another button is still a finding")
end)

test("lab false alarm F6: the key-binding screen waits past the big button's 2 s re-place before it samples", function()
	local w = newWorld()
	local c = client(w)
	local L = c.ns.WuberLab
	local s = screenById(L, "a_keybinding")
	ok(s, "the screen exists")
	local ready, first, doneAt = s.ready, nil, nil
	s.ready = function(W)
		first = first or L.Now()
		local r = ready(W)
		if r and not doneAt then doneAt = L.Now() end
		return r
	end
	local last = run(c, w, "a_keybinding")
	s.ready = ready
	ok(first and doneAt, "the screen was sampled")
	ok(doneAt - first >= 3.2, "the sample comes 2.6 s after the last toggle, not 0.7 s: " .. tostring(doneAt and first and doneAt - first))
	ok(s.maxWait >= 5, "its wait limit covers it: " .. tostring(s.maxWait))
end)

test("lab false alarm F8: Escape with the keyboard free passes while the report's sheet holds the Escape slot", function()
	local w = newWorld()
	local c = client(w)
	local last = run(c, w, "a_bug_report")
	local r = verdict(last, "a_bug_report", "Escape with the keyboard free")
	ok(r, "the check reports on Escape with the keyboard free")
	eq(r and r.status, "pass", "detail: " .. tostring(r and r.detail))
end)

-- guard (F7 is not reproducible offline, run-2 triage): it passes on the base too; it pins that a look still reports buttons after the change
test("lab false alarm F7: a look still reports its controls (buttons are compared on a fresh read)", function()
	local w = newWorld()
	local c = client(w)
	local L = c.ns.WuberLab
	c.W.UI.Toggle(true)
	w:advance(3)
	local F, meta = L.AutoLook(c.W, "home+folded")
	ok(type(F) == "table" and type(F.buttons) == "table", "the buttons list exists")
	ok(not meta.err, "no error: " .. tostring(meta.err))
	ok((meta.scans or 0) >= 1, "one look was made")
end)
