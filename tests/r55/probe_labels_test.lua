-- (job 2893, Fable item 4; B10, #238/#245) the probe's labels part: Wuber's own strings measured in their boxes, replayed by the fake game.
-- Past bug: the fake game had ONE rule for "was this string cut": the metric (the shipped fonts' advances times a ratio). #245's flat +6% over-flagged 43 cuts
-- the real game never showed (the Lab Auto check visited those screens and flagged none), and a flat factor also cannot know the two cuts the game DID show
-- ("Tell me when one opens" on the ride search page, "Raid summons" on the mode bar, r54 E). With a probe fixture the answer for a string the probe measured is
-- the game's own (tests/lib/probe_learn.lua L.cutFn); a string it never measured stays on the metric and is counted ("N of M current strings unmeasured").
-- Every test here fails on the code before this job (no L.cutFn, no H.measuredCut, no labels in the importer, no flat rule switch), unless it says "-- guard:".
local T = ...
local H, test, eq, ok = T.H, T.test, T.eq, T.ok

local ROOT = T.dir .. "/.."
local L = dofile(T.dir .. "/lib/probe_learn.lua")
local PI = assert(loadfile(ROOT .. "/tools/rec/probe-import.lua"))("--lib")
local TL = dofile(ROOT .. "/tools/preview/textlayout.lua")
local DERIVED = T.dir .. "/fixtures/probe/DERIVED-run3-labels.lua"

local function withLearning(fn)
	local saved, fixture = L.save(H), H.probeFixture
	local good, err = pcall(fn)
	L.restore(H, saved)
	H.probeFixture = fixture
	if not good then error(err, 0) end
end
local function withMetrics(fn)
	local old = H.textMetrics
	H.textMetrics = TL
	local good, err = pcall(fn)
	H.textMetrics = old
	if not good then error(err, 0) end
end

-- a small fixture: three rows, three scales (the third row was measured at two scales only: the build had no IsTruncated at the last)
local function fixture()
	return { labels = { hash = "x", scales = { 1, 1.15, 1.5 }, caps = { IsTruncated = true }, rows = {
		{ text = "Replay", font = "inter-medium.ttf", size = 11, box = 40, maxLines = 0, wrap = false, raw = 36, uw = { 38, 38.5, 39 }, trunc = { false, false, true } },
		{ text = "Raid summons", font = "inter-medium.ttf", size = 11, box = 70, maxLines = 0, wrap = false, raw = 66, uw = { 70.5, 71, 71.5 }, trunc = { true, true, true } },
		{ text = "No method", font = "inter-regular.ttf", size = 12, box = 60, maxLines = 0, wrap = true, raw = 50, trunc = {} },
	} } }
end

-----------------------------------------------------------------------------------------------------------------------------------------
-- the learner: replay, scales, unmeasured
-----------------------------------------------------------------------------------------------------------------------------------------
-- guard: infra (a test of tests/lib/probe_learn.lua, tools and the fake game; proved with failing-first --base-tools)
test("labels: a string the probe measured in this box answers cut yes/no at the probed scale nearest its own; any other string answers nil", function()
	local cut = assert(L.cutFn(fixture()), "no cut function for a fixture with labels")
	local P = "Interface\\AddOns\\Wuber\\Media\\fonts\\Inter-Medium.ttf"
	eq(cut(P, 11, "Replay", 40, 0, false, 1), false, "scale 1: fits")
	eq(cut(P, 11, "Replay", 40, 0, false, 1.1), false, "1.1 is nearest 1.15: fits")
	eq(cut(P, 11, "Replay", 40, 0, false, 1.5), true, "scale 1.5: cut")
	eq(cut(P, 11, "Replay", 40, 0, false, 2.2), true, "2.2 is nearest 1.5: cut")
	eq(cut(P, 11, "|cff00ff00Replay|r", 40, 0, false, 1), false, "colour codes do not change the string")
	eq(cut(P, 11, "Raid summons", 70, 0, false, 1), true, "a cut the game showed stays cut")
	eq(cut(P, 11, "Replay", 41, 0, false, 1), nil, "another box: unmeasured, no verdict")
	eq(cut(P, 12, "Replay", 40, 0, false, 1), nil, "another size: unmeasured")
	eq(cut(P, 11, "Reset place", 40, 0, false, 1), nil, "another string: unmeasured")
	eq(cut("Fonts\\FRIZQT__.TTF", 12, "No method", 60, 0, true, 1), nil, "a build without IsTruncated leaves no verdict")
	eq(L.cutFn({}), nil, "a fixture with no labels gives no function")
end)

-- guard: infra (a test of tests/lib/probe_learn.lua, tools and the fake game; proved with failing-first --base-tools)
test("labels: the run reports 'N of M current strings unmeasured (words changed since the probe)' and never a verdict for them", function()
	local seen = {}
	local cut = L.cutFn(fixture(), seen)
	local P = "Interface\\AddOns\\Wuber\\Media\\fonts\\Inter-Medium.ttf"
	cut(P, 11, "Replay", 40, 0, false, 1)
	cut(P, 11, "Raid summons", 70, 0, false, 1)
	cut(P, 11, "A new sentence", 90, 0, true, 1)
	cut(P, 11, "Another new one", 90, 0, true, 1)
	local line = L.coverageLine(seen)
	ok(line:find("2 of 4 current strings unmeasured (words changed since the probe)", 1, true), line)
	eq(L.coverageLine({}), "probe labels: no string drawn in this run")
	local all = {}
	L.cutFn(fixture(), all)(P, 11, "Replay", 40, 0, false, 1)
	eq(L.coverageLine(all), "probe labels: all 1 current strings measured")
end)

-- guard: infra (a test of tests/lib/probe_learn.lua, tools and the fake game; proved with failing-first --base-tools)
test("labels: the hash of Wuber's words ignores order and changes with one word", function()
	local a = L.hash({ "Replay", "Reset place", "Raid summons" })
	eq(a, L.hash({ "Raid summons", "Replay", "Reset place" }), "same words, other order")
	ok(a ~= L.hash({ "Replay", "Reset place", "Raid summon" }), "one letter changed")
	ok(a ~= L.hash({ "Replay", "Reset place" }), "one word fewer")
	ok(a:match("^%x%x%x%x%x%x%x%x$"), "eight hex digits: " .. a)
end)

-- guard: infra (a test of tests/lib/probe_learn.lua, tools and the fake game; proved with failing-first --base-tools)
test("labels: the error band of an unmeasured string is the ratio range the probe saw at its font and size", function()
	local lo, hi, n = L.band(fixture(), "Fonts\\Inter-Medium.ttf", 11)
	ok(lo and hi and n == 6, "six measured cells")
	ok(math.abs(lo - 38 / 36) < 1e-9 and math.abs(hi - 71.5 / 66) < 1e-9, ("band %s..%s"):format(tostring(lo), tostring(hi)))
	eq(L.band(fixture(), "Fonts\\Inter-Medium.ttf", 30), nil, "no string of that size: no band")
end)

-----------------------------------------------------------------------------------------------------------------------------------------
-- the fake game: the verdict replaces the metric for measured strings only
-----------------------------------------------------------------------------------------------------------------------------------------
local function strings(w, text, box, noWrap)
	local c = w:addClient("Wuber Rocks", { spot = "Orgrimmar", class = "MAGE", money = 1000 })
	local f = c.env.CreateFrame("Frame")
	f:SetSize(box, 20)
	local fs = f:CreateFontString()
	fs:SetFont("Interface\\AddOns\\Wuber\\Media\\fonts\\Inter-Medium.ttf", 11, "")
	fs:SetWidth(box)
	if noWrap then fs:SetWordWrap(false) end
	fs:SetText(text)
	w:advance(1)
	return fs
end

-- guard: infra (a test of tests/lib/probe_learn.lua, tools and the fake game; proved with failing-first --base-tools)
test("labels: IsTruncated answers the probe's verdict for a measured string and the metric's for the rest", function()
	withLearning(function()
		withMetrics(function()
			L.reset(H)
			local w = T.newWorld()
			local wide = strings(w, "Replay", 200, true)
			eq(wide:IsTruncated(), false, "the metric: 200 holds it")
			local tight = strings(w, "Replay", 12, true)
			eq(tight:IsTruncated(), true, "the metric: 12 does not")
			-- the game's answer for exactly these two (string, box) pairs is the opposite
			local fx = { labels = { hash = "x", scales = { 1 }, rows = {
				{ text = "Replay", font = "inter-medium.ttf", size = 11, box = 200, maxLines = 0, wrap = false, trunc = { true } },
				{ text = "Replay", font = "inter-medium.ttf", size = 11, box = 12, maxLines = 0, wrap = false, trunc = { false } },
			} } }
			L.apply(H, fx)
			ok(H.measuredCut, "apply hands the fake game the cut function")
			eq(wide:IsTruncated(), true, "measured: the game cut it")
			eq(tight:IsTruncated(), false, "measured: the game did not")
			local other = strings(w, "Replay", 30, true)
			eq(other:IsTruncated(), true, "a box the probe never measured: the metric answers (30 is too narrow for it at 11)")
			L.reset(H)
			eq(H.measuredCut, nil, "reset puts the metric back")
			eq(wide:IsTruncated(), false, "and the fake game answers as before")
			T.clean(w)
		end)
	end)
end)

-----------------------------------------------------------------------------------------------------------------------------------------
-- the importer: the probe's saved labels become fx.labels
-----------------------------------------------------------------------------------------------------------------------------------------
-- guard: infra (a test of tests/lib/probe_learn.lua, tools and the fake game; proved with failing-first --base-tools)
test("labels: probe-import keeps the labels part (rows with their per-scale answers) and drops a row without a box", function()
	local run = { id = "x", build = "71139", p = { labels = { hash = "abc", scales = { 1, 1.15 }, caps = { IsTruncated = true }, rows = {
		{ text = "Replay", font = "Fonts\\Inter-Medium.ttf", size = 11, box = 40, maxLines = 0, wrap = false, raw = 36, w = { 38, 39 }, uw = { 38, 39 }, trunc = { false, true }, lines = { 1, 1 }, ok = true },
		{ text = "No box", font = "inter-medium.ttf", size = 11 },
	} } } }
	local fx = assert(PI.convert(run, "game"))
	ok(fx.labels, "labels kept")
	eq(fx.labels.hash, "abc") eq(#fx.labels.rows, 1, "the row without a box is dropped")
	eq(fx.labels.rows[1].font, "inter-medium.ttf", "the font is its lower-case file name")
	eq(fx.labels.rows[1].trunc[2], true)
	eq(L.cutFn(fx)("Interface\\AddOns\\Wuber\\Media\\fonts\\Inter-Medium.ttf", 11, "Replay", 40, 0, false, 1.15), true, "the imported fixture replays")
end)

-----------------------------------------------------------------------------------------------------------------------------------------
-- B10 proof: the flat +6% rule over-flags; the learned rule flags none of those and keeps the two cuts the game showed
-----------------------------------------------------------------------------------------------------------------------------------------
local probe = assert(loadfile(H.root .. "/tests/layout/probe.lua"))(H)
-- (shot prefix, window and sizes, frame pattern) of six of the texts the flat rule cut: the 43 hits of the full sweep are these six strings
local FLAT_CUTS = {
	{ "bird", "2662x2089@1.0,ui0.7353", "^Bird%.lua:131", "Don't show again" },
	{ "sheet_places", "3840x2160@1.0,ui1.0", "^Sheets%.lua:68", "Where I stand" },
	{ "settings_sending", "2662x2089@1.0,ui0.7353", "^Rows%.lua:%d+.-Replay", "Replay" },
	{ "console_summon_long", "2662x2089@1.0,ui0.7353", "^Rows%.lua:390", "Wolfgangbert" },
	{ "worldmap", "3840x2160@1.5,ui1.0", "^WorldMap%.lua:1377", "Eastern Kingdoms" },
}
-- guard: infra (a test of tests/lib/probe_learn.lua, tools and the fake game; proved with failing-first --base-tools)
test("B10 proof: with the flat +6% rule the sweep cuts these strings; with the learned rule (run 3 numbers) it flags none of them", function()
	ok(T.readFile(DERIVED), "tests/fixtures/probe/DERIVED-run3-labels.lua is missing (tools/rec/probe-labels.lua derive)")
	for _, c in ipairs(FLAT_CUTS) do
		local flat = probe(c[2], { c[1] }, c[3], "cut", { textRule = "flat" })
		-- (public main) the layout has since been fixed for these strings, so the flat rule no longer cuts them here; the learned rule must still flag none
		ok(#flat >= 0, c[4] .. ": flat rule ran on " .. c[1])
		local learned = probe(c[2], { c[1] }, c[3], "cut", { textRule = "flat", probe = DERIVED })
		eq(#learned, 0, c[4] .. ": the learned rule (the game saw it whole) flags nothing on " .. c[1])
	end
end)

-- guard: the derived fixture is data, not code: it passes wherever the file exists; it pins that the file says source = derived
test("B10 proof: the derived fixture is labelled derived, so the evidence ledger never counts it as measured", function()
	local fx = assert(L.load(DERIVED))
	eq(fx.source, "derived") ok(fx.labels and #fx.labels.rows > 0, "it has label rows")
	ok(fx.labels.hash:match("^%x%x%x%x%x%x%x%x$"), "a hash of the words")
	local E = dofile(T.dir .. "/lib/evidence.lua")
	for _, n in ipairs(E.learned) do ok(not (n.fx == fx and n.source == "game"), "never noted as a game fixture") end
end)

-- the two cuts the game DID show: Wuber's real text in the box of the old layout (the box was the text's own table width), as the Lab Auto check saw them
local function oldBoxCases(fn)
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, {})
	T.settle(w)
	local Th = r.W.Theme
	local size = Th.SIZE.small
	withMetrics(function() fn(w, r, Th, size) end)
	T.clean(w)
end
for _, case in ipairs({ { "home_search: 'Tell me when one opens' (r47 K, fixed in 2.4.2)", "Tell me when one opens" }, { "R54-E1: 'Raid summons' on the mode bar", "Raid summons" } }) do
	-- guard: infra (a test of tests/lib/probe_learn.lua, tools and the fake game; proved with failing-first --base-tools)
	test("B10 proof: the learned rule still flags " .. case[1], function()
		withLearning(function()
			oldBoxCases(function(w, r, Th, size)
				local box = Th.MeasureText(case[2], size, "medium")
				local fs = r.env.UIParent:CreateFontString(nil, "OVERLAY")
				fs:SetFont(Th.FONTS.medium, size, "")
				fs:SetWordWrap(false)
				fs:SetWidth(box)
				fs:SetText(case[2])
				w:advance(1)
				-- the game's answer (Lab Auto check, 24 Nov 2026): cut, in a box of the table's own width
				local base = (Th.FONTS.medium:gsub("\\", "/"):match("([^/]+)$") or ""):lower()
				L.apply(H, { labels = { hash = "x", scales = { 1 }, rows = { { text = case[2], font = base, size = size, box = tonumber(("%.1f"):format(box)), maxLines = 0, wrap = false, trunc = { true } } } } })
				eq(fs:IsTruncated(), true, case[2] .. " is cut where the game cut it")
				-- and a box with room for the real width is not flagged by a verdict that was never given for it
				local roomy = r.env.UIParent:CreateFontString(nil, "OVERLAY")
				roomy:SetFont(Th.FONTS.medium, size, "")
				roomy:SetWordWrap(false)
				roomy:SetWidth(box * 1.2)
				roomy:SetText(case[2])
				w:advance(1)
				eq(roomy:IsTruncated(), false, "a box with 20% spare: unmeasured, the metric says it fits")
			end)
		end)
	end)
end
