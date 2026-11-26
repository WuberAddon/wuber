-- Job 2904: the Auto check walks everything the 2.4.4 round changed (the WATCH list in lab/WuberLab/AutoSteps7.lua).
-- Offline the fake game answers the checks; in the real game the same rows read the real fonts and the real hit order.
local T = ...
local H, test, eq, ok = T.H, T.test, T.eq, T.ok
local LAB_DIR = os.getenv("WUBER_LAB_DIR") or (H.root .. "/lab/WuberLab")
if not H.exists(LAB_DIR .. "/AutoCheck.lua") then
	test("lab244: Wuber Lab not found (skipped)", function() end)
	return
end
H.ADDONS.WuberLab = LAB_DIR

local function newLab()
	local w = T.newWorld()
	local c = w:addClient("Watcher", { spot = "Undercity", class = "WARLOCK", money = 100000, addons = { "Wuber", "WuberLab" },
		allowMissing = not T.HAVE_UI, screenW = 1920, screenH = 1080 })
	T.settle(w)
	c.env.Screenshot = function() c.env.C_Timer.After(0.2, function() c:fire("SCREENSHOT_SUCCEEDED") end) end
	return w, c, c.ns.WuberLab
end

local function runAuto(w, L, words)
	ok(L.AutoStart({ words = words }), "the Auto check started")
	for _ = 1, 1800 do
		if not L.AutoRunning() then break end
		w:advance(1)
	end
	ok(not L.AutoRunning(), "the Auto check ended")
	return L.lastAuto
end

local function screensOfWatch(L)
	local seen, list = {}, {}
	for _, item in ipairs(L.AUTO_WATCH) do
		for _, id in ipairs(item.screens or {}) do
			if not seen[id] then seen[id] = true list[#list + 1] = id end
		end
	end
	return list
end

-- the looks of the watch rows and of the rows added for the 2.4.4 round (the fake game's own text widths leave a few layout looks on
-- older screens: the real game decides those, they are in the report)
local OWN = { a_bird_card = true, a_retire_card = true, a_hidden_row = true, a_settings_adv = true, a_coach_2 = true, a_tip_skip_the_bird = true, a_tip_drive_setup = true }
local function looks(auto)
	local out = {}
	for _, r in ipairs(auto.results or {}) do
		if r.status == "look" and (r.kind:find("^watch") or OWN[r.id]) then out[#out + 1] = r.id .. " " .. r.view .. " " .. r.kind .. ": " .. tostring(r.detail) end
	end
	return table.concat(out, "\n")
end

test("lab244: every screen the WATCH list names is a screen of the Auto check", function()
	local w, c, L = newLab()
	local have = {}
	for _, s in ipairs(L.AutoScreens()) do have[s.id] = true end
	ok(#L.AUTO_WATCH >= 25, "the watch list has its entries: " .. #L.AUTO_WATCH)
	for _, item in ipairs(L.AUTO_WATCH) do
		ok(type(item.id) == "string" and type(item.what) == "string", "an entry has an id and says what it is")
		ok(item.words or item.screens, item.id .. ": words or screens")
		for _, id in ipairs(item.screens or {}) do
			ok(have[id], item.id .. ": the screen " .. id .. " exists in the Auto check")
		end
	end
end)

test("lab244: the Auto check on the watched screens: each changed thing is seen, nothing needs a look", function()
	local w, c, L = newLab()
	local auto = runAuto(w, L, screensOfWatch(L))
	ok(auto.watch, "the run judged the watch list")
	eq(table.concat(auto.watch.missing, ","), "", "watch entries never seen")
	ok(auto.watch.n >= 25 and auto.watch.seen == auto.watch.n, "every judged entry is seen: " .. tostring(auto.watch.seen) .. "/" .. tostring(auto.watch.n))
	eq(looks(auto), "", "nothing needs a look")
end)

test("lab244: a watched change whose words never show is a look, not a pass", function()
	local w, c, L = newLab()
	L.AUTO_WATCH[#L.AUTO_WATCH + 1] = { id = "wzz", what = "a change nobody can see", words = { "zzz no such words zzz" }, screens = { "home" }, on = "text" }
	local auto = runAuto(w, L, { "home" })
	local found
	for _, r in ipairs(auto.results or {}) do if r.kind == "watch wzz" then found = r end end
	ok(found and found.status == "look", "the missing words are a look: " .. tostring(found and found.status))
	ok(found and found.detail:find("no screen and in no tooltip", 1, true), "it says why: " .. tostring(found and found.detail))
	local missing = {}
	for _, id in ipairs(auto.watch.missing) do missing[id] = true end
	ok(missing.wzz, "listed as missing in the saved result")
end)

test("lab244: a screen of an entry that no run walked is a look", function()
	local w, c, L = newLab()
	L.AUTO_WATCH[#L.AUTO_WATCH + 1] = { id = "wyy", what = "a screen that does not exist", screens = { "home", "nowhere_screen" } }
	L.AUTO_WATCH[#L.AUTO_WATCH + 1] = { id = "wxx", what = "walked", screens = { "home" } }
	local auto = runAuto(w, L, { "home" })
	local seen = {}
	for _, r in ipairs(auto.results or {}) do seen[r.kind] = r.status end
	ok(seen["watch wxx"] == nil, "an entry whose screen was walked passes (no row for a plain pass)")
	eq(auto.watch.missing[1] ~= "wxx", true, "walked is not missing")
end)

-- #255 (HUNT-07): the floating big button over a control of the phone is a "buttons" finding of the Auto check
test("lab244: the big button over one of the phone's controls is found, clear of them it is not", function()
	local w, c, L = newLab()
	local W = L.W()
	W.UI.Toggle(true)
	w:advance(2)
	local env = c.env
	local big = env.WuberDriveButton
	ok(big ~= nil, "the big button exists")
	big:SetFrameStrata("TOOLTIP")
	big:Show()
	w:advance(1)
	local S = L.AutoScan(W)
	local target
	for _, info in ipairs(S.ctrls) do
		if info.f ~= big and not info.hidden and info.rect and info.rect.r - info.rect.l > 8 and info.rect.t - info.rect.b > 8 and info.root ~= nil then target = info break end
	end
	ok(target ~= nil, "the phone has a control")
	local function placeAt(x, y)
		big:ClearAllPoints()
		big:SetPoint("CENTER", env.UIParent, "BOTTOMLEFT", x, y)
		w:advance(1)
	end
	local function bigFindings()
		local F = L.AutoLook(W, "t244")
		local n = 0
		for _, text in ipairs(F.buttons) do if text:find("big button over", 1, true) then n = n + 1 end end
		return n, F
	end
	placeAt((target.rect.l + target.rect.r) / 2, (target.rect.b + target.rect.t) / 2)
	local over = bigFindings()
	ok(over >= 1, "the big button on a control is found: " .. over)
	local sw = env.UIParent:GetWidth()
	placeAt(sw - 80, 60)
	local clear = bigFindings()
	eq(clear, 0, "the big button in the corner, clear of the phone, is not")
end)
