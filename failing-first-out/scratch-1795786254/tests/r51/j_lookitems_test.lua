-- r51 group J: three Auto check "need a look" rows from run 1 (RUN1-8b). Each test drives the path the Lab probe drives.
local T = ...
local test, eq, ok = T.test, T.eq, T.ok

local function console()
	local w = T.newWorld()
	local a = T.driver(w, T.ANITA, { spot = "Ratchet" })
	w:addBot("Mia Mage", { spot = "Ratchet", class = "MAGE" })
	w:group({ T.ANITA, "Mia Mage" })
	T.settle(w)
	T.openDrive(a)
	return w, a
end

-- guard: run1 a_msg_callsum, Wuber shows it; the Lab probe AutoSteps.lua:650-671 looks for a "please summon" row in the
-- list, but since the word rule (35266769) the list rows show only the name and the "when" line, the message is in the
-- tooltip and the editor; the probe never opens the editor (runOf("messages")), so it can never find the text
-- guard: run1 a_msg_callsum, Wuber is right, the Lab probe is stale (see above)
test("r51 J: the Ask a summoner message previews in the editor with a name before the colon; the list row has no preview", function()
	local w, a = console()
	a.W.Driver.ShowScreen("messages") w:advance(1)
	local s = a.W.UI.drive.screens.messages
	local row
	for _, r in ipairs(s.rows) do if r.kind == "callsum" then row = r end end
	ok(row and row.title:GetText() == "Ask a summoner", "no Ask a summoner row")
	eq(#a:findText("please summon"), 0, "the list now shows a preview (the probe would then find it)")
	s.edit("callsum") w:advance(0.5)
	local p = s.editor.prev:GetText() or ""
	ok(p:find("^[^:]+: please summon"), "editor preview reads '" .. p .. "'")
	ok(not p:find("^%s*:"), "leading colon: " .. p)
	ok(#a:findText("please summon") > 0, "the editor preview is not visible text")
	T.clean(w)
end)

-- guard: run1 a_addbyname, Wuber shows it; the Lab probe AutoSteps2.lua:294-337 reads X.toasts() after both presses and
-- needs "Couldn't send the offer" twice, but "---" never reaches the offer: the name check refuses it first with its own note
-- guard: run1 a_addbyname, Wuber is right, the Lab probe is stale (see above)
test("r51 J: Crew Add by name says Couldn't send the offer once per refused name, no new row", function()
	local w, a = console()
	a.W.myName = "Anita" a.W.myKey = a.W.Key("Anita") -- the game's own name is one word; the test world's has a space
	a.W.Driver.ShowScreen("crew") w:advance(1)
	local sc = a.W.Driver.ui.subs.crew
	local function count()
		local n = 0
		for _, r in ipairs(sc.others.list) do if r:IsShown() and r.person then n = n + 1 end end
		return n
	end
	local before = count()
	for _, name in ipairs({ "Anita", "---" }) do
		a:type(sc.adder.field.edit, name, false)
		a:click(sc.adder.add) w:advance(0.2)
		if name == "---" then -- refused earlier, by the name check (Wizard.lua:204), with its own note
			ok(#a:findText("That isn't a player's name") > 0, "no name-check note for ---")
		else
			ok(#a:findText("Couldn't send the offer") > 0, "no 'Couldn't send the offer' for " .. name)
		end
	end
	eq(count(), before, "a refused name was listed")
	eq(#(sc.extra or {}), 0, "a refused name is in s.extra")
	T.clean(w)
end)

-- guard: run1 a_wizard_friends, Wuber shows it; the Lab probe AutoSteps.lua:690-704 is stale: since Design 1 (795f6d14)
-- a picked card is "glow" (violet), not "hover"/"gold", and b.edge is a no-op glow (Widgets.lua:238, T.EdgeGlow) whose
-- every field reads as a function, which is the "function value" the probe printed
-- guard: run1 a_wizard_friends, Wuber is right, the Lab probe is stale (see above)
test("r51 J: the picked Step 1 card keeps its picked background after the mouse leaves, the others stay plain", function()
	local w, a = console()
	a.W.Driver.ShowScreen("wizard") w:advance(1)
	local sc = a.W.Driver.ui.subs.wizard
	a:clickText("My friends help") w:advance(0.5)
	local b, other
	for _, c in ipairs(sc.choices) do if c.id == "friends" then b = c elseif not other then other = c end end
	ok(b and sc.choice == "friends", "card not picked")
	b:GetScript("OnEnter")(b)
	b:GetScript("OnLeave")(b)
	eq(b.bg.colour, "glow", "picked card after leave")
	ok(b.tick:IsShown(), "tick gone")
	eq(other.bg.colour, "card", "unpicked card")
	other:GetScript("OnEnter")(other)
	other:GetScript("OnLeave")(other)
	eq(other.bg.colour, "card", "unpicked card after leave")
	T.clean(w)
end)
