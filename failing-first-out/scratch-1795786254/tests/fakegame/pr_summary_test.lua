-- Fable item 7 (small form): tools/pr-summary.lua, the PR body block. Proven on the real history: Wuber 2.4.2 (9716c70, the commit that
-- has the old Sheets pill calling ReloadUI from addon code: blocked as tainted in the real client, #230) must show that line.
-- The diff is RECORDED in tests/fixtures/old/sheets_reloadui_2_4_2.diff (git diff -U0 of that commit for Sheets.lua, the hunk cut to
-- lines 655-672, so the test needs no git). Live: lua5.1 tools/pr-summary.lua ROOT 9716c70
local T = ...
local test, eq, ok = T.test, T.eq, T.ok
local P = dofile("tools/pr-summary.lua")
local forbidden = dofile("tools/forbidden.lua")
local function slurp(p) local f = assert(io.open(p, "rb")) local s = f:read("*a") f:close() return s end

test("pr summary: the recorded 2.4.2 Sheets diff lists the ReloadUI line as a forbidden name", function()
	local md, res = P.summarize(slurp("tests/fixtures/old/sheets_reloadui_2_4_2.diff"), { forbidden = forbidden, noBase = true, label = "ROOT 9716c70" })
	local hit
	for _, x in ipairs(res.forbidden) do if x.name == "ReloadUI" and x.path == "Wuber/UI/Driver/Sheets.lua" then hit = hit or x end end
	ok(hit, "ReloadUI is found in Wuber/UI/Driver/Sheets.lua")
	eq(hit.n, 664, "at line 664, where the pill calls it")
	ok(md:find("Sheets.lua:664 ReloadUI", 1, true), "the markdown block shows it: " .. md:sub(1, 400))
	ok(md:find("Not checked: taint propagation", 1, true), "the block says what it does not check")
end)

test("pr summary: a name in a comment is not a use; a changed test with a reasoned direct click is not new", function()
	local diff = table.concat({
		"+++ b/Wuber/X.lua", "@@ -1,0 +10,2 @@", "+-- ReloadUI is blocked, so we say /reload", "+local x = 1",
		"+++ b/tests/x/a_test.lua", "@@ -5,0 +20,3 @@",
		"+	b:Click() -- direct-click: the script itself is under test",
		"+	c:clickOn(b)",
		"+	b:GetScript(\"OnClick\")(b)", "" }, "\n") -- direct-click: sample diff text, nothing is clicked
	local _, res = P.summarize(diff, { forbidden = forbidden, noBase = true })
	eq(#res.forbidden, 0, "a comment does not count")
	eq(#res.clicks, 1, "only the unreasoned direct click counts")
	eq(res.clicks[1].n, 22, "at its new line number")
end)

-- guard: the apisurface branch. The file lands with PR #253; the tool takes it when it exists and says so when it does not.
test("pr summary: new API names carry apisurface flags when a surface is given, and say so when it is absent", function()
	local diff = table.concat({ "+++ b/Wuber/Y.lua", "@@ -1,0 +1,3 @@",
		"+	C_Club.SendInvitation(x)", "+	local ok = frame:IsEventRegistered(\"E\")", "+	DoThing(frame)", "" }, "\n")
	local surface = { meta = { build = "test" }, globals = {}, ns = { C_Club = { SendInvitation = { hr = true } } }, methods = { IsEventRegistered = { csa = true } } }
	local md = P.summarize(diff, { noBase = true, surface = surface })
	ok(md:find("C_Club.SendInvitation [hr]", 1, true), "the hardware-click flag shows: " .. md)
	ok(md:find("IsEventRegistered [csa]", 1, true), "the secret-accessor flag shows")
	ok(not md:find("DoThing [", 1, true), "an unknown helper is counted, not listed as flagged")
	local md2 = P.summarize(diff, { noBase = true })
	ok(md2:find("apisurface not available", 1, true), "without a surface it says so")
	ok(md2:find("SendInvitation", 1, true) and md2:find("DoThing", 1, true), "and lists the names")
end)
