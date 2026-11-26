local T = ...
local test, ok = T.test, T.ok
local root = T.dir .. "/.."
-- #101 (four bad hunt promises, not addon bugs). Each promise is run on the situation that failed, through the hunt's own
-- tools (tools/hunt/sweep.lua --one, tools/hunt/seq_hunt.lua), and must now say pass or n/a.

local function lua() return (arg and arg[-1]) or "lua5.1" end
local function run(args)
	local cmd = ("cd %s && \"%s\" %s 2>&1"):format(root, lua():gsub("\\", "/"), args)
	local p = io.popen(cmd)
	local out = p and p:read("*a") or ""
	if p then p:close() end
	return out
end
local function shell(cmd)
	local p = io.popen(cmd .. " 2>&1")
	local out = p and p:read("*a") or ""
	if p then p:close() end
	return out
end
local function sweep(sit, promise, addon)
	local out = run(('tools/hunt/sweep.lua --one "%s" --promise %s --verbose --no-shrink'):format(sit, promise) .. (addon and (' --addon "' .. addon .. '"') or ""))
	local verdict = out:match("\n(%a+)%s+" .. promise:gsub("%p", "%%%0")) or out:match("^(%a+)%s+" .. promise:gsub("%p", "%%%0"))
	return verdict, out
end

test("customers.notes_reach_own_account: a friend window in a raid is invited into the group, so it is heard (#101)", function()
	local verdict, out = sweep("group=raid,role=friend", "customers.notes_reach_own_account")
	ok(verdict == "pass", "raid + friend window: the note reaches the other window (it said: " .. tostring(verdict) .. "): " .. out:sub(-600))
	local v2, out2 = sweep("group=solo,role=friend", "customers.notes_reach_own_account")
	ok(v2 == "pass", "friend window, no raid dial: the note reaches the other window (it said: " .. tostring(v2) .. "): " .. out2:sub(-600))
end)

test("reply.one_driver_answers: askers are spaced past the reply gap (#101)", function()
	local verdict, out = sweep("role=warlock", "reply.one_driver_answers")
	ok(verdict == "pass", "the promise passes on a gap-throttled turn (it said: " .. tostring(verdict) .. "): " .. out:sub(-600))
end)

test("trips.chips_only_with_data: the check reads Trips again when the login tip moved the phone (#101)", function()
	local verdict, out = sweep("phone=trips_direct,saved=acct3_rider", "trips.chips_only_with_data")
	ok(verdict == "pass" or verdict == "na", "the promise reads the Trips page, not the Ride page (it said: " .. tostring(verdict) .. "): " .. out:sub(-600))
end)

-- the sequence hunt, seed 2: random chain 2 asks again as a NEW ride after a take-off-list; the old take-off flag must not apply to it
local function seqScript(body)
	local path = root .. "/tests/out/a101_seq_run.lua"
	local f = io.open(path, "wb")
	if not f then os.execute(('mkdir "%s"'):format((root .. "/tests/out"):gsub("/", "\\"))) f = io.open(path, "wb") end
	f:write(body)
	f:close()
	local out = run("tests/out/a101_seq_run.lua")
	os.remove(path)
	return out
end

test("seq_hunt seed 2 random#2: a take-off flag does not outlive a rider who asks again (#101)", function()
	local out = seqScript([[
local S = dofile("tools/hunt/seq_hunt.lua")
local res = S.runRandom(2, 6, 5)
local r = res[2]
print("RESULT " .. tostring(r and r.id) .. " " .. tostring(r and r.status) .. " " .. tostring(r and r.failure))
]])
	local id, status, why = out:match("RESULT (%S+) (%S+) ([^\r\n]*)")
	ok(id == "random#2", "ran random#2: " .. out:sub(-500))
	ok(status == "pass", "random#2 passes (it said: " .. tostring(status) .. " " .. tostring(why) .. ")")
end)

test("seq_hunt: a driver who is not offered Remove after take-off-list is still caught (#101)", function()
	local out = seqScript([[
local S = dofile("tools/hunt/seq_hunt.lua")
local Hunt = S.Hunt
local build = Hunt.build
-- the real fault: the big button never offers Remove
Hunt.build = function(...)
	local ctx = build(...)
	ctx.W.Drive.Plan = function() return { title = "Open - waiting for riders" } end
	return ctx
end
local r = S.runChain({ id = "x", sit = { role = "warlock", ride = "arrived" }, steps = { "take_off_list" } }, 1)
print("RESULT " .. tostring(r.status) .. " " .. tostring(r.failure))
]])
	local status, why = out:match("RESULT (%S+) ([^\r\n]*)")
	ok(status == "fail" and tostring(why):find("item6", 1, true), "item 6 is still reported (" .. tostring(status) .. " " .. tostring(why) .. "): " .. out:sub(-400))
end)

-- Each fix must still catch the real fault. A scratch copy of the addon (copied OVER the scratch folder, nothing is deleted)
-- gets the one line broken, and the promise is run against it with --addon.
local function scratch(rel, pattern, replacement)
	-- one folder per broken file: shards run these tests at the same time (a shared folder let one copy mend another's break)
	local dir = root .. "/tests/out/scratch101/" .. rel:gsub("[^%w]", "_")
	local isWin = package.config:sub(1, 1) == "\\"
	if isWin then shell(("xcopy /E /I /Y /Q \"%s\\Wuber\" \"%s\\Wuber\""):format(root:gsub("/", "\\"), dir:gsub("/", "\\")))
	else shell(("mkdir -p '%s/Wuber' && cp -R '%s/Wuber/.' '%s/Wuber/'"):format(dir, root, dir)) end
	local path = dir .. "/Wuber/" .. rel
	local f = io.open(path, "rb")
	ok(f, "the scratch copy has " .. rel)
	local src = f:read("*a") f:close()
	local n
	src, n = src:gsub(pattern, replacement)
	ok(n == 1, "the line to break was found once in the scratch copy of " .. rel)
	f = io.open(path, "wb") f:write(src) f:close()
	return dir .. "/Wuber"
end

-- Shards of one suite run the tests below at the same time. Each broken copy must have its own folder: a copy made for one
-- test must not be copied over (and so mended) by another test's copy before its promise has run. This is the flake of
-- "reply.one_driver_answers still fails ..." (shard 15 only, under load).
test("scratch copies of the addon do not share a folder, so parallel shards cannot mend each other's break (#101)", function()
	local a = scratch("Drive/Book.lua", "(function DR%.BookPeers%(%)%s*local out = {})", "%1 if true then return out end")
	local b = scratch("Drive/AutoReply.lua", "DR%.REPLY_GAP = 8", "DR.REPLY_GAP = 1000")
	ok(a ~= b, "two breaks, two folders (both were " .. a .. ")")
	local f = io.open(a .. "/Drive/Book.lua", "rb")
	local src = f and f:read("*a") or ""
	if f then f:close() end
	ok(src:find("if true then return out end", 1, true), "the first break is still in its copy after the second copy was made")
end)

test("customers.notes_reach_own_account still fails when book sync reaches nobody (#101)", function()
	local addon = scratch("Drive/Book.lua", "(function DR%.BookPeers%(%)%s*local out = {})", "%1 if true then return out end")
	local verdict, out = sweep("group=raid,role=friend", "customers.notes_reach_own_account", addon)
	ok(verdict == "fail", "the promise fails (it said: " .. tostring(verdict) .. "): " .. out:sub(-600))
	ok(out:find("the other window has nil", 1, true), "it says the other window got no note")
end)

test("reply.one_driver_answers still fails when nobody answers a buyer (#101)", function()
	local addon = scratch("Drive/AutoReply.lua", "DR%.REPLY_GAP = 8", "DR.REPLY_GAP = 1000")
	local verdict, out = sweep("role=warlock", "reply.one_driver_answers", addon)
	ok(verdict == "fail", "the promise fails (it said: " .. tostring(verdict) .. "): " .. out:sub(-600))
	ok(out:find("0 whispers instead of one", 1, true), "it says no whisper went out")
end)

test("trips.chips_only_with_data still fails when Trips shows no chips (#101)", function()
	local addon = scratch("UI/Rider/Trips.lua", "(local out = {}%s*local favN, fav)", "local out = {} if true then return out end local favN, fav")
	local verdict, out = sweep("phone=trips_direct,saved=acct3_rider", "trips.chips_only_with_data", addon)
	ok(verdict == "fail", "the promise fails (it said: " .. tostring(verdict) .. "): " .. out:sub(-600))
	ok(out:find("no go-to chip", 1, true), "it says the go-to chip is missing")
end)
