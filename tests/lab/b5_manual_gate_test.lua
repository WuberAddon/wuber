-- Gate test for L.AUTO_MANUAL (hand-only Lab steps):
--   1. Every entry in L.AUTO_MANUAL has a reason of at least one sentence.
--   2. Any Auto check id (a_*) or Lab file (Auto*.lua) named in a reason exists.
--   3. No entry in L.AUTO_MANUAL already has an automatic row in L.AutoScreens() (stale entry).
--   4. Prints the list of hand-only steps with their reasons.
--   5. Proves each gate rule catches its corresponding mutant.
local T = ...
local H, test, eq, ok = T.H, T.test, T.eq, T.ok
local newWorld, settle, clean = T.newWorld, T.settle, T.clean

local LAB_DIR = os.getenv("WUBER_LAB_DIR") or (H.root .. "/lab/WuberLab")
if not H.exists(LAB_DIR .. "/AutoLayout.lua") then
	test("b5 manual gate: AutoLayout.lua not found (skipped)", function() end)
	return
end
H.ADDONS.WuberLab = LAB_DIR

local function loadLab(rewrite)
	local w = newWorld()
	local c = w:addClient("Anita Lift", { spot = "Undercity", class = "WARLOCK", money = 100000, addons = { "Wuber", "WuberLab" },
		allowMissing = not T.HAVE_UI, screenW = 1920, screenH = 1080, rewrite = rewrite })
	settle(w)
	return w, c, c.ns.WuberLab
end

local function checkManual(L)
	local errs = {}
	local manual = L.AUTO_MANUAL
	if type(manual) ~= "table" then
		return { "L.AUTO_MANUAL is missing" }, {}
	end

	local autoIds = {}
	for _, s in ipairs(L.AutoScreens()) do
		if s.id then autoIds[s.id] = true end
	end

	local keys = {}
	for id in pairs(manual) do keys[#keys + 1] = id end
	table.sort(keys)

	if #keys == 0 then
		errs[#errs + 1] = "L.AUTO_MANUAL is empty"
	end

	for _, id in ipairs(keys) do
		local reason = manual[id]
		if type(reason) ~= "string" then
			errs[#errs + 1] = id .. ": reason is not a string"
		else
			local trimmed = reason:gsub("^%s+", ""):gsub("%s+$", "")
			local wordCount = 0
			for _ in trimmed:gmatch("%S+") do wordCount = wordCount + 1 end
			if #trimmed < 15 or wordCount < 3 or not trimmed:find("[%.!?]") then
				errs[#errs + 1] = id .. ": reason is not at least one sentence (" .. trimmed .. ")"
			end
			for checkId in trimmed:gmatch("%f[%w_](a_[%w_]+)%f[^%w_]") do
				if not autoIds[checkId] then
					errs[#errs + 1] = id .. ": reason references unknown check " .. checkId
				end
			end
			for fname in trimmed:gmatch("([%w_]+%.lua)") do
				if not H.exists(LAB_DIR .. "/" .. fname) then
					errs[#errs + 1] = id .. ": reason references missing file " .. fname
				end
			end
		end
		if autoIds[id] then
			errs[#errs + 1] = id .. ": stale hand-only entry (already has an automatic row in L.AutoScreens())"
		end
	end

	return errs, keys
end

test("b5 manual gate: every L.AUTO_MANUAL entry has a valid sentence reason, existing refs, and no auto row", function()
	local w, _, L = loadLab()
	local errs, keys = checkManual(L)
	eq(#errs, 0, table.concat(errs, "; "))
	ok(#keys >= 2, "at least 2 hand-only steps recorded")
	print(("b5 manual gate: %d hand-only step(s) left:"):format(#keys))
	for _, id in ipairs(keys) do
		print(("  - %s: %s"):format(id, L.AUTO_MANUAL[id]))
	end
	clean(w)
end)

test("b5 manual gate: fails when a hand-only step has no sentence reason", function()
	local hit = false
	local function rewrite(addon, f, text)
		if addon ~= "WuberLab" or not f:gsub("\\", "/"):find("AutoLayout.lua", 1, true) then return text end
		local find = 'MANUAL.login_paused = "'
		local s = text:find(find, 1, true)
		if not s then error("MANUAL.login_paused not found") end
		hit = true
		return text .. '\nL.AUTO_MANUAL.login_paused = "by hand"\n'
	end
	local w, _, L = loadLab(rewrite)
	ok(hit, "mutant applied")
	local errs = checkManual(L)
	ok(#errs >= 1 and errs[1]:find("not at least one sentence", 1, true), "caught short reason: " .. table.concat(errs, "; "))
	clean(w)
end)

test("b5 manual gate: fails when a reason points at a check that does not exist", function()
	local hit = false
	local function rewrite(addon, f, text)
		if addon ~= "WuberLab" or not f:gsub("\\", "/"):find("AutoLayout.lua", 1, true) then return text end
		local find = "a_font"
		local s, e = text:find(find, 1, true)
		if not s then error("a_font not found in AutoLayout.lua") end
		hit = true
		return text:sub(1, s - 1) .. "a_missing_check_xyz" .. text:sub(e + 1)
	end
	local w, _, L = loadLab(rewrite)
	ok(hit, "mutant applied")
	local errs = checkManual(L)
	ok(#errs >= 1 and errs[1]:find("unknown check a_missing_check_xyz", 1, true), "caught missing check: " .. table.concat(errs, "; "))
	clean(w)
end)

test("b5 manual gate: fails when a hand-only step already has an automatic row", function()
	local hit = false
	local function rewrite(addon, f, text)
		if addon ~= "WuberLab" or not f:gsub("\\", "/"):find("AutoLayout.lua", 1, true) then return text end
		hit = true
		return text .. '\nL.AUTO_MANUAL.home = "Added as a stale hand-only entry for testing."\n'
	end
	local w, _, L = loadLab(rewrite)
	ok(hit, "mutant applied")
	local errs = checkManual(L)
	local found = false
	for _, e in ipairs(errs) do
		if e:find("stale hand-only entry", 1, true) then found = true end
	end
	ok(found, "caught stale hand-only entry: " .. table.concat(errs, "; "))
	clean(w)
end)
