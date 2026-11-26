-- #203 (T243-4): the Lab's Auto check "KEYS-SETTINGS" (lab/WuberLab/AutoKeys.lua) in the fake game.
-- On the current Wuber it passes (Settings from Ride and from Drive); on a Wuber copy with the press-elsewhere release undone it says look.
-- Skipped with one passing note when the Lab isn't there. Wuber Lab is never shipped.
local T = ...
local H, test, eq, ok = T.H, T.test, T.eq, T.ok
local newWorld, settle, clean = T.newWorld, T.settle, T.clean

local LAB_DIR = os.getenv("WUBER_LAB_DIR") or (H.root .. "/lab/WuberLab")
if not H.exists(LAB_DIR .. "/AutoKeys.lua") then
	test("lab keys: AutoKeys.lua not found (skipped)", function() end)
	return
end
H.ADDONS.WuberLab = LAB_DIR

local function autoRun(rewrite)
	local w = newWorld()
	w:addClient("Mia Runner", { spot = "Undercity", class = "WARLOCK" })
	local c = w:addClient("Anita Lift", { spot = "Undercity", class = "WARLOCK", money = 100000, addons = { "Wuber", "WuberLab" },
		allowMissing = not T.HAVE_UI, screenW = 1920, screenH = 1080, rewrite = rewrite })
	settle(w)
	local L, W = c.ns.WuberLab, c.W
	c.env.IsInGuild = function() return true end
	c.env.C_AddOns = { GetNumAddOns = function() return 2 end, GetAddOnInfo = function(i) return ({ "Wuber", "WuberLab" })[i] end,
		IsAddOnLoaded = function() return true end }
	c.env.Screenshot = function() c.env.C_Timer.After(0.2, function() c:fire("SCREENSHOT_SUCCEEDED") end) end
	-- the fake game has no GetCurrentKeyBoardFocus: the visible EditBox that has the keyboard, else nil
	c.env.GetCurrentKeyBoardFocus = function()
		for _, f in ipairs(c.frames) do
			local okT, ot = pcall(f.GetObjectType, f)
			if okT and ot == "EditBox" and f:HasFocus() and f:IsVisible() then return f end
		end
		return nil
	end
	W.UI.Toggle(true)
	w:advance(2)
	local started, why = L.AutoStart({ words = { "a_keys_settings" } })
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
		if r.steps and (","  .. r.steps .. ","):find(",KEYS-SETTINGS,", 1, true) then out[#out + 1] = r.status .. " " .. tostring(r.detail) end
	end
	return out
end

test("lab keys: KEYS-SETTINGS passes on the current Wuber, from Ride and from Drive", function()
	local last, c, w = autoRun()
	local r = rows(last)
	eq(#r, 2, "one result per origin: " .. table.concat(r, " | "))
	for _, line in ipairs(r) do ok(line:find("^pass"), "passes: " .. line) end
	eq((last.steps or {})["KEYS-SETTINGS"], "pass", "the step passes")
	eq(#w.errors, 0, "Lua errors: " .. table.concat(w.errors, "; "))
	clean(w)
end)

test("lab keys: KEYS-SETTINGS says look when a press outside the box no longer lets go", function()
	local hit = false
	local function rewrite(addon, f, text)
		if addon ~= "Wuber" or not f:gsub("\\", "/"):find("UI/Settings/Find.lua", 1, true) then return text end
		local find = "if eb:HasFocus() and not pressedInside() then release() end"
		local s, e = text:find(find, 1, true)
		if not s then error("the broken copy's text is not in Find.lua") end
		hit = true
		return text:sub(1, s - 1) .. "if false then end" .. text:sub(e + 1)
	end
	local last, c, w = autoRun(rewrite)
	ok(hit, "the broken copy was made")
	eq((last.steps or {})["KEYS-SETTINGS"], "look", "the step looks: " .. table.concat(rows(last), " | "))
	clean(w)
end)
