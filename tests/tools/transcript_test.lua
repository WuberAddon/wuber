-- tests/tools/transcript_test.lua: the transcript's version normalisation (BRIEF21 S1). One baseline
-- serves master ("a.b.c-dev") and a stamped release tree ("a.b.c"): the build's -dev version is written
-- as <ver>, and a stamped tree's windows run as its -dev build. A fresh copy of tests/lib/transcript.lua
-- is loaded here (its own state), so the suite's recorder is not touched.
local T = ...
local test, eq, ok = T.test, T.eq, T.ok
local path = T.dir .. "/lib/transcript.lua"

test("transcript: the build's version is read from Core/Base.lua and agrees with the TOC", function()
	local TR = dofile(path)
	local ver = TR.buildVersion(T.dir .. "/..")
	ok(type(ver) == "string" and ver ~= "", "W.VERSION found")
	local toc = T.readFile(T.dir .. "/../Wuber/Wuber.toc")
	eq(toc:match("## Version: *([^\r\n]+)"), ver, "the TOC says the same")
end)

test("transcript: a.b.c-dev stays itself, a stamped a.b.c runs as a.b.c-dev, a test's rc is left alone", function()
	local TR = dofile(path)
	local dev = TR.versions("2.3.2-dev")
	eq(dev.dev, "2.3.2-dev") eq(dev.stamped, false)
	local rel = TR.versions("2.3.2")
	eq(rel.dev, "2.3.2-dev") eq(rel.stamped, true)
	eq(TR.versions("2.3.3-rc1").stamped, false)
	eq(TR.versions(nil), nil)
end)

test("transcript: the build's -dev version is written as <ver>, other versions as they are", function()
	local TR = dofile(path)
	TR.useVersion("2.3.2")
	eq(TR.str("D~1~Ratchet~H~2.3.2-dev~~0~1"), '"D~1~Ratchet~H~<ver>~~0~1"', "in a message")
	eq(TR.str("Wuber 2.3.2-dev, /wuber\n2.3.2-dev"), '"Wuber <ver>, /wuber\\n<ver>"', "in a text, every time")
	eq(TR.str("2.3.2"), '"2.3.2"', "a plain number a test sets is kept")
	eq(TR.str("2.3.0-dev"), '"2.3.0-dev"', "another -dev is kept")
	eq(TR.str("2x3x2-dev"), '"2x3x2-dev"', "dots are dots")
	eq(TR.str("12.3.2-dev 1.2.3.2-dev 2.3.2-dev2 2.3.2-dev.2"), '"12.3.2-dev 1.2.3.2-dev 2.3.2-dev2 2.3.2-dev.2"',
		"inside a longer number: kept")
	eq(TR.str("v2.3.2-dev. (2.3.2-dev)~2.3.2-dev"), '"v<ver>. (<ver>)~<ver>"', "a full stop, brackets, ~, ends")
	eq(TR.str("2.3.2-dev"), '"<ver>"', "the whole string")
	TR.useVersion("2.3.3-dev")
	eq(TR.str("2.3.2-dev"), '"2.3.2-dev"', "only this build's version")
	eq(TR.str("2.3.3-dev"), '"<ver>"')
end)

test("transcript: a stamped tree's windows run as -dev; a test's own version wins; opts are left as given", function()
	local TR = dofile(path)
	local seen = {}
	local World = { addClient = function(self, name, opts) seen[#seen + 1] = opts.version return { name = name } end }
	eq(TR.devWindows(World, "2.3.2-dev"), true)
	local opts = { spot = "x" }
	eq(World:addClient("a", opts).name, "a")
	eq(seen[1], "2.3.2-dev", "the -dev build")
	eq(opts.version, nil, "the caller's opts are as they were")
	World:addClient("b", { version = "2.3.0" })
	eq(seen[2], "2.3.0", "the test's own version")
	World:addClient("c")
	eq(seen[3], "2.3.2-dev", "no opts at all")
	eq(TR.devWindows({}, "x"), false, "no World.addClient: nothing to wrap")
end)

-- guard: the reset between tests is in tests/run.lua, which the gate keeps from the target, so the addon base cannot fail it; step 1 only sets the leak for step 2
test("transcript: H.textMetrics isolation (step 1: set without restoring)", function()
	T.H.textMetrics = { leaked = true }
end)

-- guard: the reset between tests is in tests/run.lua, which the gate keeps from the target, so the addon base cannot fail it; it keeps the runner restoring H.textMetrics
test("transcript: H.textMetrics isolation (step 2: next test sees nil)", function()
	eq(T.H.textMetrics, nil, "H.textMetrics must not leak from a prior test")
end)
