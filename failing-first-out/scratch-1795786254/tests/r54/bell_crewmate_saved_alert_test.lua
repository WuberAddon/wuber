-- #81 (a bad hunt check, not an addon bug): the promise bell.crewmate_refused (tests/promises/driver2.lua) failed
-- with "Wuber accepts it" whenever an alert character was already saved from before (the acct3 fixture keeps one),
-- although Wuber refused the crew mate and kept the old one. The check must fail only when the crew mate itself is saved.
-- Runs the hunt's sweep on one situation and one promise (tools/hunt/sweep.lua --one) and reads its verdict line.
local T = ...
local test, ok = T.test, T.ok
local root = T.dir .. "/.."

local function lua() return (arg and arg[-1]) or "lua5.1" end
local function sh(cmd)
	local p = io.popen(cmd .. " 2>&1")
	local out = p and p:read("*a") or ""
	if p then p:close() end
	return out
end
local function sweep(sit, addon)
	local cmd = ("cd %s && \"%s\" tools/hunt/sweep.lua --one \"%s\" --promise bell.crewmate_refused --verbose --no-shrink"):format(root, lua():gsub("\\", "/"), sit)
	if addon then cmd = cmd .. " --addon \"" .. addon .. "\"" end
	return sh(cmd)
end
local function verdict(out)
	return out:match("\n(%a+)%s+bell%.crewmate_refused") or out:match("^(%a+)%s+bell%.crewmate_refused")
end

test("bell.crewmate_refused passes when an alert character was saved from before (#81)", function()
	local out = sweep("role=friend,saved=acct3_rider")
	ok(verdict(out) == "pass", "the promise passes (it said: " .. tostring(verdict(out)) .. "): " .. out:sub(-700))
end)

test("bell.crewmate_refused still fails when Wuber really saves the crew mate (#81)", function()
	-- a scratch copy of the addon whose BellSet no longer refuses a crew mate (the old behaviour the promise guards)
	local dir = root .. "/tests/out/scratch81"
	-- copied OVER the scratch folder (nothing is deleted); a file the real addon no longer has may linger there,
	-- which is fine. Bell.lua is copied fresh every run, so a patched one from an earlier run never survives.
	local isWin = package.config:sub(1, 1) == "\\"
	if isWin then sh(("xcopy /E /I /Y /Q \"%s\\Wuber\" \"%s\\Wuber\""):format(root:gsub("/", "\\"), dir:gsub("/", "\\")))
	else sh(("mkdir -p '%s/Wuber' && cp -R '%s/Wuber/.' '%s/Wuber/'"):format(dir, root, dir)) end
	local path = dir .. "/Wuber/Drive/Bell.lua"
	local f = io.open(path, "rb")
	ok(f, "the scratch copy has Bell.lua")
	local src = f:read("*a"); f:close()
	local n
	src, n = src:gsub("if key ~= myKey%(%) and isCrewKey%(key%) then", "if false then")
	ok(n == 1, "the crew refusal line was found once in the scratch copy")
	f = io.open(path, "wb"); f:write(src); f:close()
	local out = sweep("role=friend,saved=acct3_rider", dir .. "/Wuber")
	ok(verdict(out) == "fail", "the promise fails against the old behaviour (it said: " .. tostring(verdict(out)) .. "): " .. out:sub(-700))
	ok(out:find("accepts it", 1, true), "it says Wuber accepts the crew mate")
end)
