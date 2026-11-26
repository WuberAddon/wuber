local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H

test("r47 d6: C56r-2 Wizard Step 2 'Add anyway' on a Warlock saves a helper, so Step 3 cannot list him", function()
	local w = T.newWorld()
	local d = T.driver(w, T.ANITA, { spot = "Ratchet" })
	w:addBot("Wanda Lock", { spot = "Ratchet", class = "WARLOCK" })
	w:group({ T.ANITA, "Wanda Lock" })
	T.settle(w)
	T.openDrive(d)
	d.W.Driver.ShowScreen("wizard") w:advance(1)
	d:clickText("My friends help") w:advance(0.5)
	d:clickText("^Next$", { pattern = true }) w:advance(1)
	ok(#d:findText("Summons and clicks") > 0, "control: the row says Wanda summons and clicks (a Warlock)")
	d:clickText("^Send offers$", { pattern = true }) w:advance(26)
	ok(#d:findText("Add anyway") > 0, "control: Add anyway is offered")
	d:clickText("^Add anyway$", { pattern = true }) w:advance(1)
	local DR = d.W.Drive
	local m
	for _, c in ipairs(DR.Crew()) do if not c.me then m = c end end
	ok(m, "control: Wanda is in the crew")
	d:clickText("^Next$", { pattern = true }) w:advance(1)
	ok(#d:findText("Who summons%?") > 0, "control: Step 3 is open")
	eq(m.role, "lock", "Wanda is a Warlock added anyway: she is saved as a summoner, not a helper")
	ok(#d:findText("no Wuber") > 0, "Step 3 lists Wanda as a summoner without Wuber: " .. T.list(d:visibleTexts()):sub(-250))
	T.clean(w)
end)

test("r47 d6: C56r-3 Crew screen 'Add anyway' on a Warlock saves a helper, so she cannot be a summoner", function()
	local w = T.newWorld()
	local d = T.driver(w, T.ANITA, { spot = "Ratchet" })
	w:addBot("Wanda Lock", { spot = "Ratchet", class = "WARLOCK" })
	w:group({ T.ANITA, "Wanda Lock" })
	T.settle(w)
	T.openDrive(d)
	d.W.Driver.ShowScreen("crew") w:advance(1)
	ok(#d:findText("In your group") > 0, "control: Wanda is listed under IN YOUR GROUP: " .. T.list(d:visibleTexts()):sub(-200))
	local function topmost(pat)
		local best
		for _, fs in ipairs(d:findText(pat, true)) do
			if H.visible(fs) and (not best or fs:GetTop() > best:GetTop()) then best = fs end
		end
		return best
	end
	d:clickOn(topmost("^Add$")) w:advance(26)
	ok(#d:findText("Add anyway") > 0, "control: after no answer Add anyway is offered: " .. T.list(d:visibleTexts()):sub(-200))
	d:clickText("^Add anyway$", { pattern = true }) w:advance(1)
	local DR = d.W.Drive
	local m
	for _, c in ipairs(DR.Crew()) do if not c.me then m = c end end
	ok(m, "control: Wanda is in the crew")
	eq(m.role, "lock", "Wanda is a Warlock added anyway: the crew keeps her as a helper, not a summoner")
	T.clean(w)
end)

test("r47 d6: C56r-8 Step 2 toggle choice sticks to the row frame, so a player the captain unticked turns ON when another accepts", function()
	local w = T.newWorld()
	local d = T.driver(w, T.ANITA, { spot = "Ratchet" })
	w:addBot("Alder Mage", { spot = "Ratchet", class = "MAGE" })
	local birch = w:addClient("Birch Lock", { spot = "Ratchet", class = "WARLOCK", shards = 10, money = 100000 })
	w:addBot("Cedar Mage", { spot = "Ratchet", class = "MAGE" })
	w:group({ T.ANITA, "Alder Mage", "Birch Lock", "Cedar Mage" })
	T.settle(w)
	T.openDrive(d)
	d.W.Driver.ShowScreen("wizard") w:advance(1)
	d:clickText("My friends help") w:advance(0.5)
	d:clickText("^Next$", { pattern = true }) w:advance(1)
	local pool = d.W.Driver.ui.subs.wizard.people
	local function rowOf(name)
		for _, r in ipairs(pool.list) do if r:IsShown() and r.person and r.person.name == name then return r end end
	end
	local alder = rowOf("Alder Mage")
	ok(alder and alder.toggle:IsShown() and alder.toggle.on == true, "control: everybody starts ticked")
	d:click(alder.toggle) w:advance(0.5) -- the captain does NOT want Alder
	ok(rowOf("Alder Mage").toggle.on == false, "control: Alder is now unticked")
	d:clickText("^Send offers$", { pattern = true }) w:advance(3) -- offers go to Birch and Cedar only
	birch.W.Drive.AnswerOffer(T.ANITA, true) w:advance(4) -- Birch says Yes and moves to the top of the list
	local a2 = rowOf("Alder Mage")
	ok(a2 and a2.toggle:IsShown(), "control: Alder still waits to be picked, with his toggle showing")
	ok(a2.toggle.on == false, "the captain unticked Alder, but after Birch joined Alder's toggle is ON again (and 'Send offers again' would send him a crew card)")
	T.clean(w)
end)

test("r47 d6: C56r-9 typing your own name in Step 2 'Add by name' lists you as someone to invite", function()
	local w = T.newWorld()
	local d = T.driver(w, T.ANITA, { spot = "Ratchet" })
	w:addBot("Mia Mage", { spot = "Ratchet", class = "MAGE" })
	w:group({ T.ANITA, "Mia Mage" })
	T.settle(w)
	T.openDrive(d)
	d.W.Driver.ShowScreen("wizard") w:advance(1)
	d:clickText("My friends help") w:advance(0.5)
	d:clickText("^Next$", { pattern = true }) w:advance(1)
	local sc = d.W.Driver.ui.subs.wizard
	local function listed(name)
		for _, r in ipairs(sc.people.list) do if r:IsShown() and r.person and r.person.name == name then return r end end
	end
	ok(listed("Mia Mage"), "control: the groupmate is listed")
	d:type(sc.adder.field.edit, T.ANITA, false) -- (a name is two words now, so it reaches the offer, which refuses it; one send: the click)
	d:click(sc.adder.add) w:advance(1)
	ok(#d:findText("Couldn't send the offer") + #d:findText("isn't a player's name") > 0, "control: the offer to yourself is refused (toast)")
	local me = listed(T.ANITA)
	ok(me == nil, "the player typed their own name: the refused offer still puts '" .. T.ANITA .. "' in the Pick your crew list" .. (me and (me.toggle:IsShown() and ", ticked for Send offers" or "") or ""))
	T.clean(w)
end)

test("r47 d6: C56r-10 Crew 'Add by name' keeps a junk or refused name in IN YOUR GROUP for good", function()
	local w = T.newWorld()
	local d = T.driver(w, T.ANITA, { spot = "Ratchet" })
	w:addBot("Mia Mage", { spot = "Ratchet", class = "MAGE" })
	w:group({ T.ANITA, "Mia Mage" })
	T.settle(w)
	T.openDrive(d)
	d.W.Driver.ShowScreen("crew") w:advance(1)
	local sc = d.W.Driver.ui.subs.crew
	ok(d.W.Key("Mia Mage") ~= nil, "control: a real name has a key")
	local function count()
		local n = 0
		for _, r in ipairs(sc.others.list) do if r:IsShown() and r.person then n = n + 1 end end
		return n
	end
	eq(count(), 1, "control: only the groupmate is under In your group")
	ok(d.W.Key("---") == nil, "control: the junk name '---' has no key")
	d:type(sc.adder.field.edit, "---")
	d:click(sc.adder.add) w:advance(1)
	ok(#d:findText("isn't a player's name") > 0, "control: the offer is refused (toast)")
	eq(count(), 1, "the player typed '---': the refused name now sits under IN YOUR GROUP as a second person (with an Add button) for the rest of the session")
	T.clean(w)
end)

