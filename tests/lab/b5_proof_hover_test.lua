-- Tests for lab/WuberLab/ProofHover.lua:
--   1. Runs a_proof_hover_raised and a_proof_hover_owncolour in the fake game through L.AutoStart.
--   2. Verifies both pass, nothing is sent, no Lua errors, and state is put back.
--   3. Proves each check catches the regression when the fix in Wuber/ is undone (mutants killed).
local T = ...
local H, test, eq, ok = T.H, T.test, T.eq, T.ok
local newWorld, settle, clean = T.newWorld, T.settle, T.clean

local LAB_DIR = os.getenv("WUBER_LAB_DIR") or (H.root .. "/lab/WuberLab")
local PROOF_HOVER = LAB_DIR .. "/ProofHover.lua"
if not H.exists(PROOF_HOVER) then
	test("b5 proof hover: ProofHover.lua not found (skipped)", function() end)
	return
end
H.ADDONS.WuberLab = LAB_DIR

local SCREENS = { "a_proof_hover_raised", "a_proof_hover_owncolour" }

local function runAuto(rewrite)
	local w = newWorld()
	w:addClient("Mia Runner", { spot = "Undercity", class = "WARLOCK" })
	local c = w:addClient("Anita Lift", { spot = "Undercity", class = "WARLOCK", money = 100000, addons = { "Wuber", "WuberLab" },
		allowMissing = not T.HAVE_UI, screenW = 1920, screenH = 1080, rewrite = rewrite })
	settle(w)
	local L, W = c.ns.WuberLab, c.W
	local chunk = assert(loadfile(PROOF_HOVER))
	setfenv(chunk, c.env)
	chunk("WuberLab", L)

	c.env.IsInGuild = function() return true end
	c.env.Screenshot = function() c.env.C_Timer.After(0.2, function() c:fire("SCREENSHOT_SUCCEEDED") end) end
	W.UI.Toggle(true)
	w:advance(2)

	local beforeSent = c.sent or 0
	local beforeWhispers = #(w.whispers or {})
	local beforeAdvanced = W.db and W.db.advanced
	local started, why = L.AutoStart({ words = SCREENS })
	ok(started, "AutoStart succeeded: " .. tostring(why))
	for _ = 1, 3000 do
		if not L.AutoRunning() then break end
		w:advance(1)
	end
	ok(not L.AutoRunning(), "Auto check finished")
	return L.lastAuto or {}, c, w, beforeSent, beforeWhispers, beforeAdvanced
end

local function screenSeen(last, id)
	for _, s in ipairs(last.screens or {}) do
		if s.id == id then return true end
	end
	return false
end

local function verifyRows(last, id)
	local out = {}
	for _, r in ipairs(last.results or {}) do
		if r.id == id and type(r.kind) == "string" and r.kind:find("^verify") then
			out[#out + 1] = r
		end
	end
	return out
end

test("b5 proof hover: both hover checks pass in the fake game, send nothing, and restore state", function()
	local last, c, w, beforeSent, beforeWhispers, beforeAdvanced = runAuto()
	eq(last.reason, nil, "Auto check ended cleanly")

	ok(screenSeen(last, "a_proof_hover_raised"), "a_proof_hover_raised ran")
	ok(screenSeen(last, "a_proof_hover_owncolour"), "a_proof_hover_owncolour ran")

	local r1 = verifyRows(last, "a_proof_hover_raised")
	for _, r in ipairs(r1) do
		eq(r.status, "pass", r.kind .. ": " .. tostring(r.detail))
	end

	local r2 = verifyRows(last, "a_proof_hover_owncolour")
	for _, r in ipairs(r2) do
		eq(r.status, "pass", r.kind .. ": " .. tostring(r.detail))
	end

	eq(c.W.db.advanced, beforeAdvanced, "W.db.advanced restored")
	eq(c.sent or 0, beforeSent, "no addon messages sent")
	eq(#(w.whispers or {}), beforeWhispers, "no whispers sent")
	eq(#(w.errors or {}), 0, "no Lua errors: " .. table.concat(w.errors or {}, "; "))
	clean(w)
end)

test("b5 proof hover: a_proof_hover_raised says look when OnLeave sets card fill instead of raised", function()
	local find = 'bellTest:HookScript("OnLeave", function(self) self.fill:SetColor("raised") end)'
	local hit = false
	local function rewrite(addon, f, text)
		if addon ~= "Wuber" or not f:gsub("\\", "/"):find("UI/Settings/Rows.lua", 1, true) then return text end
		local s, e = text:find(find, 1, true)
		if not s then error("target line not found in Rows.lua") end
		hit = true
		return text:sub(1, s - 1) .. 'bellTest:HookScript("OnLeave", function(self) self.fill:SetColor("card") end)' .. text:sub(e + 1)
	end
	local last, _, w = runAuto(rewrite)
	ok(hit, "mutant applied to Rows.lua")
	local r1 = verifyRows(last, "a_proof_hover_raised")
	local anyLook = false
	local diag = {}
	for _, r in ipairs(r1) do
		diag[#diag + 1] = tostring(r.kind) .. "=" .. tostring(r.status) .. "(" .. tostring(r.detail) .. ")"
		if r.status == "look" then anyLook = true end
	end
	ok(anyLook, "a_proof_hover_raised caught the mutant; reason=" .. tostring(last.reason) .. " rows=" .. table.concat(diag, " | "))
	clean(w)
end)

test("b5 proof hover: a_proof_hover_owncolour says look when pillPaint ownColour guard is undone", function()
	local find = "if b.ownColour and not b.inactive then"
	local hit = false
	local function rewrite(addon, f, text)
		if addon ~= "Wuber" or not f:gsub("\\", "/"):find("Theme/Widgets.lua", 1, true) then return text end
		local s, e = text:find(find, 1, true)
		if not s then error("target line not found in Widgets.lua") end
		hit = true
		return text:sub(1, s - 1) .. "if false and b.ownColour and not b.inactive then" .. text:sub(e + 1)
	end
	local last, _, w = runAuto(rewrite)
	ok(hit, "mutant applied to Widgets.lua")
	local r2 = verifyRows(last, "a_proof_hover_owncolour")
	eq(#r2, 1, "1 result for a_proof_hover_owncolour")
	eq(r2[1].status, "look", "a_proof_hover_owncolour caught the mutant: " .. tostring(r2[1].detail))
	clean(w)
end)
