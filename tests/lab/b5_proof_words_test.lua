-- Tests for lab/WuberLab/ProofWords.lua:
--   1. Runs all 5 ProofWords rows in the fake game through L.AutoStart.
--   2. Verifies all 5 pass, send nothing, have no Lua errors, and restore state.
--   3. Proves each check catches a regression when the underlying Wuber code is mutated (mutants killed).
local T = ...
local H, test, eq, ok = T.H, T.test, T.eq, T.ok
local newWorld, settle, clean = T.newWorld, T.settle, T.clean

local LAB_DIR = os.getenv("WUBER_LAB_DIR") or (H.root .. "/lab/WuberLab")
local PROOF_WORDS = LAB_DIR .. "/ProofWords.lua"
if not H.exists(PROOF_WORDS) then
	test("b5 proof words: ProofWords.lua not found (skipped)", function() end)
	return
end
H.ADDONS.WuberLab = LAB_DIR

local SCREENS = {
	"a_proof_words_openmap",
	"a_proof_words_drive_gear",
	"a_proof_words_share_notes",
	"a_proof_words_minimap_pause",
	"a_proof_words_crew_own",
}

local function runAuto(words, rewrite)
	local w = newWorld()
	w:addClient("Mia Runner", { spot = "Undercity", class = "WARLOCK" })
	local c = w:addClient("Anita Lift", { spot = "Undercity", class = "WARLOCK", money = 100000, addons = { "Wuber", "WuberLab" },
		allowMissing = not T.HAVE_UI, screenW = 1920, screenH = 1080, rewrite = rewrite })
	settle(w)
	local L, W = c.ns.WuberLab, c.W
	local chunk = assert(loadfile(PROOF_WORDS))
	setfenv(chunk, c.env)
	chunk("WuberLab", L)

	c.env.IsInGuild = function() return true end
	c.env.Screenshot = function() c.env.C_Timer.After(0.2, function() c:fire("SCREENSHOT_SUCCEEDED") end) end
	W.UI.Toggle(true)
	w:advance(2)

	local beforeSent = c.sent or 0
	local beforeWhispers = #(w.whispers or {})
	local beforeShare = W.Drive.opts().shareNotes
	local started, why = L.AutoStart({ words = words or SCREENS })
	ok(started, "AutoStart succeeded: " .. tostring(why))
	for _ = 1, 3000 do
		if not L.AutoRunning() then break end
		w:advance(1)
	end
	ok(not L.AutoRunning(), "Auto check finished")
	return L.lastAuto or {}, c, w, beforeSent, beforeWhispers, beforeShare
end

local function screenSeen(last, id)
	for _, s in ipairs(last.screens or {}) do
		if s.id == id then return true end
	end
	return false
end

local function hasLook(last, id)
	for _, r in ipairs(last.results or {}) do
		if r.id == id and type(r.kind) == "string" and r.kind:find("^verify") and r.status == "look" then
			return true, r.detail
		end
	end
	return false
end

test("b5 proof words: all 5 word checks pass in the fake game, send nothing, and restore state", function()
	local last, c, w, beforeSent, beforeWhispers, beforeShare = runAuto()
	eq(last.reason, nil, "Auto check ended cleanly")

	for _, id in ipairs(SCREENS) do
		ok(screenSeen(last, id), id .. " ran")
		local bad, detail = hasLook(last, id)
		ok(not bad, id .. " passed: " .. tostring(detail))
	end

	eq(c.W.Drive.opts().shareNotes, beforeShare, "shareNotes restored")
	eq(c.sent or 0, beforeSent, "no addon messages sent")
	eq(#(w.whispers or {}), beforeWhispers, "no whispers sent")
	eq(#(w.errors or {}), 0, "no Lua errors: " .. table.concat(w.errors or {}, "; "))
	clean(w)
end)

local MUTANTS = {
	{
		id = "a_proof_words_openmap",
		file = "UI/Settings/Panel.lua",
		find = "Best with OpenMap; works without it.",
		repl = "Needs the free OpenMap addon; glides the map.",
	},
	{
		id = "a_proof_words_drive_gear",
		file = "UI/Window.lua",
		find = 'UI.OpenSettings(UI.state and UI.state.tab == "Drive" and "drive" or nil)',
		repl = "UI.OpenSettings(nil)",
	},
	{
		id = "a_proof_words_share_notes",
		file = "Drive/Commands.lua",
		find = 'sharenotes = { key = "shareNotes", text = "Sharing notes with your own accounts" },',
		repl = 'sharenotes = { key = "shareNotes", text = "Sharing notes broken" },',
	},
	{
		id = "a_proof_words_minimap_pause",
		file = "UI/Minimap.lua",
		find = 'Shift-right-click',
		repl = "Right-click-disabled",
	},
	{
		id = "a_proof_words_crew_own",
		file = "UI/Driver/Customers.lua",
		find = 'and dr("BookShareOn") ~= false',
		repl = "",
	},
}

for _, m in ipairs(MUTANTS) do
	test("b5 proof words: " .. m.id .. " catches mutant in " .. m.file, function()
		local hit = false
		local function rewrite(addon, f, text)
			if addon ~= "Wuber" or not f:gsub("\\", "/"):find(m.file, 1, true) then return text end
			local s, e = text:find(m.find, 1, true)
			if not s then error("target not found in " .. m.file .. ": " .. m.find) end
			hit = true
			return text:sub(1, s - 1) .. m.repl .. text:sub(e + 1)
		end
		local last, _, w = runAuto({ m.id }, rewrite)
		ok(hit, "mutant applied to " .. m.file)
		local bad = hasLook(last, m.id)
		ok(bad, m.id .. " caught the mutant")
		clean(w)
	end)
end
