-- Final home: tests/ui/driver/crew_test.lua; add it to the per-module list in tests/run.lua.
-- Pins:
--   the captain's screen (add by name, setup again; no Leave) and the member's (Leave; no adding, no split);
--   Leave takes two clicks, the first turns the label to "Click again to leave" and wears off after 4 s;
--   Remove on a member's card takes them out of the crew on both windows, with a toast;
--   a member card's line: captain / no Wuber / not heard lately / not in your group / shards; the role words go
--   when there is news; Fair split only for a captain with Advanced on; the caster's part only with By clicks.
-- Why it matters to a player: a member who leaves by one stray click, a captain who cannot remove a member, or a
--   card that hides "no Wuber" or "not in your group" makes the crew call the wrong people to the portal.
local T = ...
local H, test, eq, ok = T.H, T.test, T.eq, T.ok

local function key(name) return (name:lower():gsub("[%s%-]+", " ")) end -- same as W.Key for these names (checked below)
local function screen(c) return c.W.Mod("UI.Driver.Screens").st.screens.crew end
local function shown(f) return f ~= nil and f:IsShown() and true or false end

-- every toast a window shows (as tests/au24/proof_g_test.lua does)
local function toasts(c)
	local seen = {}
	local orig = c.W.UI.Toast
	c.W.UI.Toast = function(text, kind, onClick)
		seen[#seen + 1] = tostring(text)
		return orig(text, kind, onClick)
	end
	return seen
end
local function said(seen, text)
	for _, t in ipairs(seen) do if t:find(text, 1, true) then return true end end
	return false
end

-- Ana (captain) and Bea (member) in one party, both with the Drive window on the Crew screen.
local function crew()
	local w = T.newWorld()
	local ana = w:addClient(T.ANA, { spot = "Orgrimmar", class = "WARLOCK" })
	local bea = w:addClient(T.BEA, { spot = "Orgrimmar", class = "WARLOCK" })
	w:group({ T.ANA, T.BEA })
	T.settle(w)
	ok(ana.W.Drive.OfferCrew(T.BEA), "setup: the crew offer")
	w:advance(3)
	bea.W.Drive.AnswerOffer(T.ANA, true)
	w:advance(5)
	ok(bea.W.Drive.char().captain ~= "", "setup: Bea is in Ana's crew")
	for _, c in ipairs({ ana, bea }) do
		T.openDrive(c)
		c.W.Driver.ShowScreen("crew")
	end
	w:advance(2)
	return w, ana, bea
end

-- a driver alone whose crew is what the test says (as tests/r31/r31_e_crewsub_test.lua does)
local function stubbed(list)
	local w = T.newWorld()
	local a = T.driver(w, T.ANITA, { spot = "Undercity" })
	w:advance(15)
	local W, DR = a.W, a.W.Drive
	DR.IsOpen = function() return true end
	DR.Crew = function()
		local out = { { name = a.player.name, key = W.myKey, role = "lock", app = true, me = true, here = true } }
		for _, m in ipairs(list or {}) do out[#out + 1] = m end
		return out
	end
	T.openDrive(a)
	W.Driver.ShowScreen("crew")
	w:advance(2)
	return w, a, W
end

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.driver.crew: contract (registered, deps = Screens + Wizard, header, D.screens.crew)", function()
	local W, w, r, Mod = T.contract("UI.Driver.Crew", "tests/ui/driver/crew_test.lua", {
		["D.screens.crew"] = "function",
	})
	ok(Mod, "W.Mod(\"UI.Driver.Crew\")")
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.driver.crew: a member card says what matters (captain, no Wuber, not heard, not in group, shards); never me", function()
	local w, a, W = stubbed({
		{ name = "Dru Oak", key = "dru oak", role = "helper", app = false, captain = true, here = true },
		{ name = "Fay Moss", key = "fay moss", role = "lock", app = true, here = true, shards = 1 },
		{ name = "Cal Brown", key = "cal brown", role = "helper", app = true, here = true },
		{ name = "Wick Lock", key = "wick lock", role = "lock", app = true, silent = true, here = false },
		{ name = "Ola Hart", key = "ola hart", role = "lock", app = false, silent = true, here = true },
	})
	local s = screen(a)
	ok(s, "the Crew screen was built")
	local rows = s.members.list
	eq(rows[1].sub:GetText(), "captain \194\183 no Wuber", "a captain without Wuber: the role words go") -- Crew.lua: #bits > 1
	eq(rows[2].sub:GetText(), "1 shard", "a Warlock's shards (plural of 1)")
	eq(rows[3].sub:GetText(), "Clicks the portal", "no news: the role words stay (Wizard.lua ROLE_TEXT)")
	eq(rows[4].sub:GetText(), "not heard lately \194\183 not in your group", "a silent Warlock out of the group")
	eq(rows[5].sub:GetText(), "no Wuber", "no Wuber wins over not heard lately") -- Crew.lua: elseif m.silent
	for i = 1, 5 do
		ok(rows[i].person and rows[i].person.key ~= W.myKey, "row " .. i .. " is not me")
	end
	ok(not (rows[6] and rows[6]:IsShown()), "five cards, no sixth")
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.driver.crew: the captain's screen adds and runs the setup; the member's screen only leaves", function()
	local w, ana, bea = crew()
	local sa, sb = screen(ana), screen(bea)
	eq(sa.intro:GetText(), "Your crew. Warlocks cast and click; others click the portal. Each says yes once.", "the captain's intro")
	ok(shown(sa.adder), "the captain can add by name")
	ok(shown(sa.wizard), "the captain can run the setup again")
	ok(not shown(sa.leave), "a captain has no Leave")
	local intro = sb.intro:GetText() or ""
	ok(intro:find("^You're in ") and intro:find("'s crew: you get the call to click the portal, and their invites are accepted for you.", 1, true),
		"the member's intro: " .. intro)
	ok(intro:find("Ana", 1, true), "it names the captain: " .. intro)
	ok(shown(sb.leave), "a member can leave")
	eq(sb.leave.label:GetText(), "Leave this crew", "the Leave label")
	ok(not shown(sb.adder), "a member adds nobody")
	ok(not shown(sb.wizard), "a member has no setup")
	ok(not shown(sb.cutRuleRow), "a member has no Fair split")
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.driver.crew: Leave takes two clicks; the first wears off after 4 s; the second leaves with a toast", function()
	local w, ana, bea = crew()
	local sb = screen(bea)
	local seen = toasts(bea)
	bea:clickOn(sb.leave)
	w:advance(0.5)
	eq(sb.leave.label:GetText(), "Click again to leave", "the first click only asks")
	ok(bea.W.Drive.char().captain ~= "", "still in the crew after one click")
	w:advance(5) -- Crew.lua: W.After(4, ...) forgets the first click
	eq(sb.leave.label:GetText(), "Leave this crew", "the question wore off")
	bea:clickOn(sb.leave)
	w:advance(0.5)
	ok(bea.W.Drive.char().captain ~= "", "a click after the question wore off only asks again")
	bea:clickOn(sb.leave)
	w:advance(3)
	eq(bea.W.Drive.char().captain, "", "two clicks: Bea left")
	ok(said(seen, "You left the crew"), "the toast says so")
	eq(ana.W.Drive.CrewEntry(ana.W.Key(T.BEA)), nil, "Ana's window lets her go (TL)")
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.driver.crew: Remove on a member's card takes her out on both windows", function()
	local w, ana, bea = crew()
	local sa = screen(ana)
	sa.update()
	local row
	for _, r in ipairs(sa.members.list) do
		if r:IsShown() and r.person and ana.W.Key(r.person.name) == key(T.BEA) then row = r end
	end
	ok(row and row.btn and row.btn:IsShown(), "Bea's card has a Remove button")
	local seen = toasts(ana)
	ana:clickOn(row.btn)
	w:advance(3)
	eq(ana.W.Drive.CrewEntry(ana.W.Key(T.BEA)), nil, "Bea is out of Ana's crew")
	ok(said(seen, "is out of your crew"), "the toast says so")
	eq(bea.W.Drive.char().captain, "", "Bea's window was told (TL)")
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.driver.crew: Fair split shows only with Advanced on; the caster's part only with By clicks; an unknown rule is By clicks", function()
	local w, a, W = stubbed({ { name = "Cal Brown", key = "cal brown", role = "helper", app = true, here = true } })
	W.db.advanced = false -- the harness starts clients in Advanced (harness.lua:6228)
	W.Fire("SETTINGS", "advanced")
	w:advance(0.5)
	local s = screen(a)
	ok(not shown(s.cutRuleRow), "Advanced off: no Fair split")
	ok(not shown(s.splitHead), "no heading either")
	W.db.advanced = true -- (Core/Base.lua W.Advanced)
	W.Fire("SETTINGS", "advanced")
	w:advance(0.5)
	ok(shown(s.cutRuleRow), "Advanced on: the rule")
	ok(shown(s.cutCasterRow), "By clicks (the default): the caster's part")
	eq(s.cutSeg.value, "clicks", "By clicks is chosen")
	W.Drive.opts().cutRule = "equal"
	W.Fire("SETTINGS", "drive.cutRule")
	w:advance(0.5)
	ok(shown(s.cutRuleRow), "still the rule")
	ok(not shown(s.cutCasterRow), "Equal: no caster's part")
	eq(s.cutSeg.value, "equal", "Equal is chosen")
	W.Drive.opts().cutRule = "bogus"
	W.Fire("SETTINGS", "drive.cutRule")
	w:advance(0.5)
	eq(s.cutSeg.value, "clicks", "an unknown rule reads as By clicks")
	ok(shown(s.cutCasterRow), "with the caster's part")
	T.clean(w)
end)
