-- #202 Lab Auto check BACK-REAL (lab/WuberLab/AutoSteps7.lua): on Settings (from Ride and from the Drive cog) and on Your crew the topmost
-- mouse-enabled Wuber frame at the back arrow's centre must BE the arrow; the OnClick of that frame must put the page away.
-- Run in the fake game, whose GetTexture() gives file ids like the real client. Wuber Lab is never shipped.
local T = ...
local H, test, eq, ok = T.H, T.test, T.eq, T.ok
local newWorld, settle, clean = T.newWorld, T.settle, T.clean

local LAB_DIR = os.getenv("WUBER_LAB_DIR") or (H.root .. "/lab/WuberLab")
if not H.exists(LAB_DIR .. "/AutoSteps7.lua") then
	test("lab backreal: AutoSteps7.lua not found (skipped)", function() end)
	return
end
H.ADDONS.WuberLab = LAB_DIR

local SCREENS = { "a_backreal_ride", "a_backreal_drive", "a_backreal_crew", "a_backreal_last" }

local function autoRun(rewrite)
	local w = newWorld()
	w:addClient("Mia Runner", { spot = "Undercity", class = "WARLOCK" })
	local c = w:addClient("Anita Lift", { spot = "Undercity", class = "WARLOCK", money = 100000, addons = { "Wuber", "WuberLab" },
		allowMissing = not T.HAVE_UI, screenW = 1920, screenH = 1080, rewrite = rewrite })
	settle(w)
	local L, W = c.ns.WuberLab, c.W
	c.env.IsInGuild = function() return true end
	c.env.Screenshot = function() c.env.C_Timer.After(0.2, function() c:fire("SCREENSHOT_SUCCEEDED") end) end
	W.UI.Toggle(true)
	w:advance(2)
	local started, why = L.AutoStart({ words = SCREENS })
	ok(started, "the Auto check started: " .. tostring(why))
	for _ = 1, 3000 do
		if not L.AutoRunning() then break end
		w:advance(1)
	end
	ok(not L.AutoRunning(), "the Auto check reached its end")
	return L.lastAuto or {}, c, w
end

local function rows(last)
	local out = {}
	for _, r in ipairs(last.results or {}) do
		if r.steps and (","  .. r.steps .. ","):find(",BACK-REAL,", 1, true) then out[#out + 1] = r.status .. " " .. tostring(r.kind) .. ": " .. tostring(r.detail) end
	end
	return table.concat(out, " | ")
end

-- guard: tests a new Lab Auto check (BACK-REAL) that the base does not have; failing-first copies no lab/ files, so it skips on the base
test("lab backreal: BACK-REAL passes on Settings from Ride, Settings from Drive and Your crew", function()
	local last, c, w = autoRun()
	eq(last.reason, nil, "the Auto check ended by itself")
	eq((last.steps or {})["BACK-REAL"], "pass", "BACK-REAL passes: " .. rows(last))
	-- (the Settings screens run folded and unfolded: two rows each)
	for _, page in ipairs({ "Settings from Ride", "Settings from the Drive cog", "Your crew" }) do
		ok(rows(last):find("pass verify back arrow, real click: Drive > " .. page, 1, true) or rows(last):find("pass verify back arrow, real click: " .. page, 1, true), page .. " passed: " .. rows(last))
	end
	eq(#w.errors, 0, "Lua errors: " .. table.concat(w.errors, "; "))
	clean(w)
end)

-- guard: tests a new Lab Auto check (BACK-REAL) that the base does not have; failing-first copies no lab/ files, so it skips on the base
test("lab backreal: BACK-REAL says look when the header strip covers the arrow again (the hit rect fix undone)", function()
	local find, repl = "top:SetHitRectInsets(inset, 0, 0, 0)", "top:SetHitRectInsets(0, 0, 0, 0)"
	local hit = false
	local function rewrite(addon, f, text)
		if addon ~= "Wuber" or not f:gsub("\\", "/"):find("UI/Window.lua", 1, true) then return text end
		local s, e = text:find(find, 1, true)
		if not s then error("the broken copy's text is not in Window.lua") end
		hit = true
		return text:sub(1, s - 1) .. repl .. text:sub(e + 1)
	end
	local last, c, w = autoRun(rewrite)
	ok(hit, "the broken copy was made")
	eq((last.steps or {})["BACK-REAL"], "look", "BACK-REAL looks on the broken copy: " .. rows(last))
	clean(w)
end)
