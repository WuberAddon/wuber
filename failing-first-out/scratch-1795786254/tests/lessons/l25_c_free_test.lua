-- Job 2525 group C and job 2607: tools/check.lua fails a player string that calls Wuber ITSELF free (marketing), passes
-- "free" used inside the addon (the author 23 Nov 19:08), and warns on tests that assign a harness field at file load (C3, L6).
local T = ...
local test, eq, ok, CHECK = T.test, T.eq, T.ok, T.CHECK

-- guard: infra, replaces the l25 c free-scan test (the old scan failed every use of the word)
test("free rule: check.lua fails a string calling Wuber free and passes in-addon uses", function()
	local bad = { "Wuber is free", "Get the free addon", "Use it for free", "Wuber is totally free to use" }
	local good = { "You gave them a free ride on ", "Free for your raid", "Install the free OpenMap addon (on CurseForge)",
		"Your raid · free summons", "Free", "One free summon later" }
	for _, s in ipairs(bad) do
		eq(#CHECK.scanFree("local a = \"" .. s .. "\"\n"), 1, "must fail: " .. s)
	end
	for _, s in ipairs(good) do
		eq(#CHECK.scanFree("local a = \"" .. s .. "\"\n"), 0, "must pass: " .. s)
	end
	eq(#CHECK.scanFree("-- Wuber is free\n"), 0, "a comment is no player text")
end)

-- guard: infra, the shipped tree has no string that calls Wuber free
test("free rule: the real tree passes check.lua check 12", function()
	local res = CHECK.check({ root = T.dir .. "/..", testFiles = false })
	local all = table.concat(res.fails, "\n")
	ok(not all:find("calls Wuber itself free", 1, true), "no marketing free in the shipped tree, in:\n" .. all)
end)

-- guard: infra, failed before because tools/check.lua had no free scan and no H.* load lint
test("l25 c: check.lua warns on a test file that assigns an H.* field at file load", function()
	local src = "local H = ...\nH.fake = 1\nH.x==2\nlocal function f()\n\tH.inner = 2\nend\nif H.y == 1 then end\n"
	eq(#CHECK.scanHarnessAssign(src), 1, "only the indent-zero assignment counts")
	local res = CHECK.check({ files = { "Net/A.lua" }, read = function() return "local _, W = ...\nlocal Mod = W.Module(\"Net.A\")\n" end,
		globals = { read = {}, write = {} }, owner = {}, legacy = {}, allow = {}, freeKnown = {},
		testFiles = { "tests/x_test.lua" }, testRead = function() return src end })
	local all = table.concat(res.warns, "\n")
	ok(all:find("HARNESS FIELDS ASSIGNED AT FILE LOAD", 1, true) and all:find("1 line(s)", 1, true), "the warning, in:\n" .. all)
	eq(#res.fails, 0, "a warning, not a failure")
end)
