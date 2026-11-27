-- Adopted from the fable-2411 draft in r52 (job 2706).
-- Final home: tests/ui/driver/wizard_test.lua; add it to the per-module list in tests/run.lua.
-- Pins: step 1 words for a Warlock and for any other class ("Who casts?", "Just me" is greyed and refused with its tip, a stale solo pick is cleared).
-- Pins: which choice is preselected when the wizard opens (solo / friends / none), Next with no choice, Just me skipping the crew step, the back route.
-- Pins: Done saves wizard = true, the summoners and a plain caster, leaves for the console; a non-Warlock may finish with nobody ticked and is warned.
-- Pins: step 2 rows (role line, ticked by default), Send offers goes only to ticked people, nobody ticked toasts, Add-by-name rejects empty and bad names.
-- Pins: step 3 order (ticks, arrows, saved at once, main caster / casts second words), Whoever clicks first, D.SaveSummoners copies its list.
-- Pins: a person row's words and button by offer state (waiting, no answer, said no, joined) and mode (add, member).
-- Why it matters to a player: this is the first thing a new driver does. If it broke they could not get past "Who summons with you?", offers would go to
-- people they unticked, the wrong Warlock would cast first, or the setup would never be marked done and the welcome would keep coming back.
local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H

local function plain(t) return (tostring(t or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end
local function has(c, text) return #c:findText(text, false, true) > 0 end -- a visible text holding it (plain)

-- a Warlock driver at Ratchet; opts.bots = { { name, class }, ... } are grouped with it; opts.fresh: the wizard never done
local function setup(opts)
	opts = opts or {}
	local w = T.newWorld()
	local d = T.driver(w, T.ANITA, { spot = "Ratchet" })
	local names = { T.ANITA }
	for _, b in ipairs(opts.bots or {}) do
		w:addBot(b[1], { spot = "Ratchet", class = b[2] })
		names[#names + 1] = b[1]
	end
	if #names > 1 then w:group(names) end
	T.settle(w)
	T.openDrive(d)
	local W = d.W
	if opts.fresh then W.Char().wizard = nil end
	return w, d, W, W.Driver, W.Drive
end

-- opens the wizard page (step 1, or step 3 straight with arg 3) and returns its screen table
local function wiz(w, d, arg)
	d.W.Driver.ShowScreen("wizard", arg) w:advance(1)
	return d.W.Driver.ui.subs.wizard
end

local function rowIn(list, pat)
	for _, r in ipairs(list) do
		if r:IsShown() and r.person and tostring(r.person.name):find(pat, 1, true) then return r end
	end
end

local function summonerRow(wz, key)
	for _, r in ipairs(wz.summoners.list) do
		if r:IsShown() and r.p and r.p.key == key then return r end
	end
end

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.driver.wizard: contract; classRole, ROLE_TEXT and indexOf", function()
	local W, w, r, Mod = T.contract("UI.Driver.Wizard", "tests/ui/driver/wizard_test.lua", {
		["D.SaveSummoners"] = "function", ["D.screens.wizard"] = "function",
		["Mod.classRole"] = "function", ["Mod.indexOf"] = "function", ["Mod.saveOrder"] = "function", ["Mod.offer"] = "function",
		["Mod.rosterNotCrew"] = "function", ["Mod.paintPerson"] = "function", ["Mod.personRow"] = "function",
		["Mod.addByName"] = "function", ["Mod.isWarlock"] = "function", ["Mod.ROLE_TEXT"] = "table",
	})
	eq(Mod.classRole("WARLOCK"), "lock", "a Warlock summons and clicks") -- Wizard.lua:63
	eq(Mod.classRole("MAGE"), "helper", "any other class clicks")
	eq(Mod.classRole(nil), "helper", "an unknown class is a helper")
	eq(Mod.ROLE_TEXT.lock, "Summons and clicks", "the Warlock's line") -- Wizard.lua:67
	eq(Mod.ROLE_TEXT.helper, "Clicks the portal", "the helper's line")
	eq(Mod.indexOf({ "a", "b", "c" }, "c"), 3, "found at its place")
	eq(Mod.indexOf({ "a" }, "z"), nil, "missing is nil")
	eq(Mod.indexOf({}, "a"), nil, "empty list")
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.driver.wizard: step 1 asks who summons, in three cards", function()
	local w, d = setup()
	local wz = wiz(w, d)
	eq(wz.step, 1, "opens on step one") -- Wizard.lua:860
	ok(has(d, "Who summons with you?"), "the Warlock's question: " .. T.list(d:visibleTexts()):sub(1, 300))
	for _, t in ipairs({ "Just me", "My friends help", "My other characters" }) do ok(has(d, t), t .. " card") end
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.driver.wizard: the card ticked when it opens: Just me for a set-up Warlock alone, My friends help with a crew, none when never set up", function()
	local w, d, W, D, DR = setup()
	local wz = wiz(w, d)
	eq(wz.choice, "solo", "set up and alone: Just me") -- Wizard.lua:867
	D.ShowScreen("console") w:advance(1.5)
	W.Char().wizard = nil
	wz = wiz(w, d)
	eq(wz.choice, nil, "never set up: nothing is ticked, Next waits")
	D.ShowScreen("console") w:advance(1.5)
	ok(DR.AddPlainHelper("Mia Mage", nil), "control: a helper joined the crew")
	wz = wiz(w, d)
	eq(wz.choice, "friends", "someone in the crew: My friends help") -- Wizard.lua:867 (n > 0)
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.driver.wizard: Next with nothing picked asks to pick; Just me skips the crew step; back from step 3 after Just me goes to step 1", function()
	local w, d, W = setup({ fresh = true })
	local wz = wiz(w, d)
	eq(wz.choice, nil, "control: nothing picked")
	wz.next:GetScript("OnClick")(wz.next) w:advance(0.5)
	eq(wz.step, 1, "still on step one") -- Wizard.lua:783
	ok(has(d, "Pick one of the three first"), "the toast tells why: " .. T.list(d:visibleTexts()):sub(-200))
	d:clickText("Just me") w:advance(0.5)
	eq(wz.choice, "solo", "Just me picked")
	d:clickText("^Next$", { pattern = true }) w:advance(1)
	eq(wz.step, 3, "alone: straight to who summons, no crew step") -- Wizard.lua:784
	eq(wz.order[1], W.myKey, "a Warlock alone is the caster") -- Wizard.lua:745
	eq(wz.onBack(), true, "the chevron goes back")
	eq(wz.step, 1, "back from step 3 after Just me lands on step 1, not on the crew step") -- Wizard.lua:775
	w:advance(1)
	eq(wz.onBack(), false, "nothing before step one: the chevron leaves the wizard") -- Wizard.lua:778
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.driver.wizard: Done marks the wizard done, saves me as the summoner with no named caster, and goes back to the console", function()
	local w, d, W, D, DR = setup({ fresh = true })
	local wz = wiz(w, d)
	d:clickText("Just me") w:advance(0.5)
	d:clickText("^Next$", { pattern = true }) w:advance(1)
	ok(has(d, "Who summons?"), "step 3 asks who summons")
	W.Char().wizard = nil
	d:clickText("^Done$", { pattern = true }) w:advance(1)
	eq(W.Char().wizard, true, "set up is saved") -- Wizard.lua:789
	eq(D.CurrentScreen(), "console", "back on the console") -- Wizard.lua:796
	ok(has(d, "You're set up. Press Open when you're ready."), "the toast says so")
	eq(W.Char().caster, "", "Just me: no named caster") -- Wizard.lua:790 dr("SetCaster", "")
	eq(DR.Summoners()[1], W.myKey, "I am the summoner")
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.driver.wizard: a non-Warlock is asked who casts; Just me is refused with its reason; a stale solo pick is cleared", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR) -- a Mage
	w:advance(15)
	T.openDrive(r)
	local D = r.W.Driver
	D.ShowScreen("wizard") w:advance(1)
	local wz = D.ui.subs.wizard
	ok(has(r, "Who casts?"), "the question for a class that cannot summon") -- Wizard.lua:276
	ok(has(r, "A Warlock friend") and has(r, "My other account"), "the cards name a Warlock")
	r:clickText("Just me") w:advance(0.5)
	eq(wz.choice, nil, "Just me is not an answer without a Warlock") -- Wizard.lua:259
	ok(has(r, "You need a Warlock to cast: pick one in the next step."), "its reason is shown")
	eq(wz.step, 1, "still on step one")
	wz.choice = "solo"
	wz.paint()
	eq(wz.choice, nil, "a solo choice left from before is dropped") -- Wizard.lua:296
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.driver.wizard: step 2 lists the group with their roles, ticked; Send offers goes only to the ticked", function()
	local w, d, W, D, DR = setup({ bots = { { "Mia Mage", "MAGE" }, { "Wanda Lock", "WARLOCK" } } })
	local wz = wiz(w, d)
	d:clickText("My friends help") w:advance(0.5)
	d:clickText("^Next$", { pattern = true }) w:advance(1)
	eq(wz.step, 2, "the crew step")
	local mia, wanda = rowIn(wz.people.list, "Mia"), rowIn(wz.people.list, "Wanda")
	ok(mia and wanda, "both group members are listed: " .. T.list(d:visibleTexts()):sub(1, 300))
	eq(plain(wanda.sub:GetText()), "Summons and clicks", "a Warlock's line") -- Wizard.lua:67,159
	eq(plain(mia.sub:GetText()), "Clicks the portal", "any other class")
	ok(wanda.toggle:IsShown() and wanda.picked == true and mia.picked == true, "everyone is ticked to start with") -- Wizard.lua:177
	d:clickOn(mia.toggle) w:advance(0.3)
	eq(mia.picked, false, "Mia unticked")
	d:clickText("^Send offers$", { pattern = true }) w:advance(1)
	ok(DR.offers[wanda.person.key], "Wanda got an offer") -- Wizard.lua:326-332
	eq(DR.offers[mia.person.key], nil, "Mia did not")
	ok(has(d, "Crew offer sent to Wanda"), "the toast names her")
	ok(has(d, "Send offers again"), "the button now offers to send again") -- Wizard.lua:419
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.driver.wizard: Send offers with nobody ticked says so and sends nothing", function()
	local w, d, W, D, DR = setup({ bots = { { "Mia Mage", "MAGE" } } })
	local wz = wiz(w, d)
	d:clickText("My friends help") w:advance(0.5)
	d:clickText("^Next$", { pattern = true }) w:advance(1)
	local mia = rowIn(wz.people.list, "Mia")
	ok(mia, "Mia is listed")
	d:clickOn(mia.toggle) w:advance(0.3)
	d:clickText("^Send offers$", { pattern = true }) w:advance(0.5)
	ok(has(d, "Pick someone first, or add a name"), "the toast tells what to do") -- Wizard.lua:342
	eq(DR.offers[mia.person.key], nil, "no offer went out")
	ok(not wz.sent, "the step still says Send offers, not 'again'")
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.driver.wizard: Add by name refuses an empty field and a name that is not a player's", function()
	local w, d, W, D, DR = setup()
	local wz = wiz(w, d)
	d:clickText("My friends help") w:advance(0.5)
	d:clickText("^Next$", { pattern = true }) w:advance(1)
	d:clickOn(wz.adder.add) w:advance(0.3)
	ok(has(d, "Type a name first"), "empty: asks for a name") -- Wizard.lua:201
	d:type(wz.adder.field.edit, "x", false)
	d:clickOn(wz.adder.add) w:advance(0.3)
	ok(has(d, "That isn't a player's name. Type the name as the game shows it (each part 2 to 12 letters), with -Realm for another realm."), "one letter is not a name") -- Wizard.lua:203, Team.lua:ValidName
	eq(next(DR.offers), nil, "no offer was sent")
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.driver.wizard: step 3 order: ticks and arrows reorder the summoners, saved at once, with the main caster named", function()
	local w, d, W, D, DR = setup()
	ok(DR.AddPlainHelper("Zed Lock", "lock"), "control: a Warlock without Wuber joined the crew")
	local zk = W.Key("Zed Lock")
	D.SaveSummoners({ W.myKey, zk })
	eq(DR.Summoners()[1], W.myKey, "saved order: me first")
	eq(DR.Summoners()[2], zk, "then Zed")
	local wz = wiz(w, d, 3)
	eq(wz.step, 3, "ShowScreen('wizard', 3) opens straight on who summons") -- Wizard.lua:868
	eq(wz.order[1], W.myKey, "the page starts from the saved order")
	eq(wz.order[2], zk, "both ticked")
	local me, zed = summonerRow(wz, W.myKey), summonerRow(wz, zk)
	ok(me and zed, "both Warlocks are rows")
	ok(plain(me.sub:GetText()):find("main caster", 1, true), "I am the main caster: " .. plain(me.sub:GetText())) -- Wizard.lua:640
	eq(plain(zed.sub:GetText()), "casts second · no Wuber", "Zed casts second, and nobody sees his shards") -- Wizard.lua:640-644
	ok(not me.up:IsShown() and me.down:IsShown(), "the first has only Down") -- Wizard.lua:649-650
	ok(zed.up:IsShown() and not zed.down:IsShown(), "the last has only Up")
	d:clickOn(zed.up) w:advance(0.5)
	eq(DR.Summoners()[1], zk, "Up: Zed is saved as the main caster at once") -- Wizard.lua:547-548
	eq(DR.Summoners()[2], W.myKey, "and I am second")
	zed = summonerRow(wz, zk)
	ok(plain(zed.sub:GetText()):find("main caster", 1, true), "his row says so")
	d:clickOn(zed.toggle) w:advance(0.5)
	eq(#DR.Summoners(), 1, "unticked: only one summoner left") -- Wizard.lua:540
	eq(DR.Summoners()[1], W.myKey, "me")
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.driver.wizard: 'Whoever clicks first' shows with two ticked Warlocks and toggles the caster", function()
	local w, d, W, D, DR = setup()
	ok(DR.AddPlainHelper("Zed Lock", "lock"), "control: a second Warlock")
	D.SaveSummoners({ W.myKey, W.Key("Zed Lock") })
	local wz = wiz(w, d, 3)
	ok(wz.any:IsShown(), "two ticked: the row shows") -- Wizard.lua:671
	d:clickOn(wz.any) w:advance(0.5)
	eq(W.Char().caster, "-", "no main caster: whoever clicks first") -- Wizard.lua:562
	d:clickOn(wz.any) w:advance(0.5)
	eq(W.Char().caster, "", "clicked again: back to the order, and the first is me so no name") -- Wizard.lua:560
	local zed = summonerRow(wz, W.Key("Zed Lock"))
	d:clickOn(zed.toggle) w:advance(0.5)
	ok(not wz.any:IsShown(), "one ticked: the row is gone") -- Wizard.lua:679
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.driver.wizard: a non-Warlock with no Warlock in the crew is warned on step 3 and may still finish", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR)
	w:advance(15)
	T.openDrive(r)
	local W, D = r.W, r.W.Driver
	W.Char().wizard = nil
	D.ShowScreen("wizard", 3) w:advance(1)
	local wz = D.ui.subs.wizard
	eq(wz.step, 3, "straight to who summons")
	ok(has(r, "No Warlock in your crew yet. Go Back and add your Warlock friend (or your own Warlock), then tick them here."), "the warning: " .. T.list(r:visibleTexts()):sub(1, 300)) -- Wizard.lua:662
	r:clickText("^Done$", { pattern = true }) w:advance(1)
	eq(W.Char().wizard, true, "Done still saves") -- Wizard.lua:789
	eq(#W.Drive.Summoners(), 0, "with nobody to summon")
	eq(D.CurrentScreen(), "console", "and leaves")
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.driver.wizard: SaveSummoners keeps a copy of the list it is given", function()
	local w, d, W, D, DR = setup()
	local order = { W.myKey }
	D.SaveSummoners(order)
	order[1] = "someone else"
	order[2] = "another"
	eq(#DR.Summoners(), 1, "the saved order has one") -- Wizard.lua:457-459
	eq(DR.Summoners()[1], W.myKey, "and it is still me")
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.driver.wizard: a person row says what the offer is doing and offers the right button", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR)
	w:advance(15)
	local W = r.W
	local Mod, DR = W.Mod("UI.Driver.Wizard"), W.Drive
	local row = Mod.personRow(r.env.UIParent)
	local key = W.Key("Wanda Lock")
	local p = { name = "Wanda Lock", key = key, role = "lock" }
	local function paint(mode) Mod.paintPerson(row, p, mode, {}) return plain(row.sub:GetText()), plain(row.btn.label:GetText()) end
	DR.offers[key] = nil
	local sub, btn = paint("add")
	eq(sub, "Summons and clicks", "no offer: the role line") -- Wizard.lua:159
	eq(btn, "Add", "and Add") -- Wizard.lua:182
	DR.offers[key] = { name = "Wanda Lock", at = r.env.GetTime(), state = "waiting" }
	sub, btn = paint("add")
	eq(sub, "Waiting for Wanda to tap Yes", "waiting") -- Wizard.lua:108
	eq(btn, "Ask again", "Ask again")
	DR.offers[key].state = "noapp"
	sub, btn = paint("add")
	eq(sub, "No answer: Wanda may not have Wuber", "no answer") -- Wizard.lua:106
	eq(btn, "Add anyway", "Add anyway")
	DR.offers[key].state = "no"
	sub = paint("add")
	eq(sub, "Wanda said no", "said no") -- Wizard.lua:105
	DR.offers[key].state = "yes"
	sub = paint("add")
	eq(sub, "Wanda joined", "joined") -- Wizard.lua:107
	DR.offers[key] = nil
	sub, btn = paint("member")
	eq(btn, "Remove", "a crew member's row offers Remove") -- Wizard.lua:185
	paint("pick")
	ok(row.toggle:IsShown() and not row.btn:IsShown(), "a pick row has the tick, not a button") -- Wizard.lua:176-179
	eq(row.picked, true, "ticked by default")
	DR.offers[key] = { name = "Wanda Lock", at = r.env.GetTime(), state = "waiting" }
	paint("pick")
	ok(not row.toggle:IsShown() and not row.btn:IsShown(), "while waiting there is neither a tick nor a button") -- Wizard.lua:170-174
	DR.offers[key] = nil
	T.clean(w)
end)
