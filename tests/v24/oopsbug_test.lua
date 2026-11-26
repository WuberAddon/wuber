-- Wuber 2.4, oops bug report and tool: proves UI.Bug lists wrong invites anonymised and pull-oops collects and escapes them. Loaded by tests/run.lua with its helper table T.
local T = ...
local test, eq, ok = T.test, T.eq, T.ok

local function has(text, part) return type(text) == "string" and text:find(part, 1, true) ~= nil end

local function sent(w)
	return #w.addonLog + #w.whispers + #(w.chatPosts or {})
end

test("v24 oopsbug: bug report leaves out wrong invites and keeps intro unchanged when empty", function()
	local w = T.newWorld()
	local d = T.driver(w, T.ANITA)
	T.settle(w)
	T.goOnline(d)
	w:advance(2)
	local W = d.W
	local beforeReport = W.UI.Bug.Report("")
	W.SlashCommand("bug")
	local f = W.UI.Bug.frame
	local beforeIntro = f.how:GetText()
	ok(not has(beforeReport, "Wrong invites"), "no heading when no learned lines")
	ok(not has(beforeIntro, "It includes the chat lines you marked as wrong invites, with names removed."), "no new intro sentence when no learned lines")
	-- (Design 2) the report opens the window first, so its Window line now says open
	eq(f.copy:Text(), (beforeReport:gsub("Window: closed", "Window: open")), "copy box holds unchanged report")
	W.UI.Bug.Close()
	-- empty oops table still leaves the report byte for byte identical
	W.db.drive.oops = { players = {}, lines = {}, log = {} }
	eq(W.UI.Bug.Report(""), (beforeReport:gsub("Window: closed", "Window: open")), "empty oops log leaves report byte for byte identical")
	T.clean(w)
end)

test("v24 oopsbug: bug report includes last wrong invites with names removed and updated intro", function()
	local w = T.newWorld()
	local d = T.driver(w, T.ANITA)
	T.settle(w)
	T.goOnline(d)
	w:advance(2)
	local W = d.W
	local beforeSent = sent(w)
	local beforeReport = W.UI.Bug.Report("")
	ok(not has(beforeReport, "Wrong invites"), "baseline has no wrong invites")

	w:addBot(T.BOB, {})
	w:botWhisper(T.BOB, d, "summon me pls")
	w:advance(2)
	local bob = W.Drive.customers["bob stone"]
	ok(bob and W.Drive.Oops(bob), "first wrong invite learned")

	W.Drive.customers["cal brown"] = { key = "cal brown", name = T.CAL, state = "invited", auto = "whisper", autoMsg = "summon Cal please" }
	ok(W.Drive.Oops(W.Drive.customers["cal brown"]), "second wrong invite learned")

	beforeSent = sent(w) -- (lead) counted from here: the invite above sent its own messages
	W.SlashCommand("bug")
	local f = W.UI.Bug.frame
	local report = f.copy:Text()
	local intro = f.how:GetText()
	ok(has(report, "Wrong invites (last 10)"), "report holds heading:\n" .. report)
	ok(has(report, "summon me pls"), "report holds first learned line:\n" .. report)
	ok(has(report, "summon player 1 please"), "report replaces known player's name with player 1:\n" .. report)
	ok(not has(report, "Cal"), "known player's name appears nowhere in report:\n" .. report) -- (lead) "UI scale" holds "cal": look for the name as written
	ok(has(intro, "It includes the chat lines you marked as wrong invites, with names removed."), "intro holds new sentence:\n" .. intro)
	ok(#d:findText("It includes the chat lines you marked as wrong invites, with names removed.", true, true) > 0, "new intro sentence is visible")
	eq(sent(w), beforeSent, "nothing is sent when opening the report")
	W.UI.Bug.Close()
	T.clean(w)
end)

test("v24 oopsbug: pull-oops library collects nested oops logs and escapes JSON", function()
	local lib = assert(loadfile(T.dir .. "/../tools/gauntlet/pull-oops.lua"))("library")
	ok(type(lib) == "table" and type(lib.collect) == "function" and type(lib.json) == "function", "library returns collect and json")
	local cycle = {}
	cycle.self = cycle
	local db = {
		chars = {
			anita = {
				oops = {
					log = {
						{ text = "summon me pls", at = 1 },
						{ text = "", at = 2 },
						{ text = "   ", at = 3 },
						{ text = "summon me pls", at = 4 },
						{ text = "inv ratchet pls", at = 5 },
					},
				},
				cycle = cycle,
			},
		},
	}
	local got = lib.collect(db)
	eq(#got, 2, "skips empty and duplicate texts")
	eq(got[1], "summon me pls", "first collected text")
	eq(got[2], "inv ratchet pls", "second collected text")
	eq(lib.json('a"b\\c\td'), '"a\\"b\\\\c\\td"', "json escapes quote, backslash and tab")
end)
