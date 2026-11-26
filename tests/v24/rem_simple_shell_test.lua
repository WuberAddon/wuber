-- Wuber 2.4, Simple and Advanced shell: window size, tabs, minimap tooltip, tips, guide and one-time note. Loaded by tests/run.lua with its helper table T.
local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H

local function tipOf(c, f)
	local gt = c.env.GameTooltip
	H.state[gt].tipLines = {}
	H.state[f].scripts.OnEnter(f)
	local text = table.concat(H.state[gt].tipLines or {}, " | ")
	H.state[f].scripts.OnLeave(f)
	return text
end

local function tabButtons(ui)
	local out = {}
	for _, tab in ipairs(ui.tabs) do out[tab.name] = tab.button end
	return out
end

test("v24 simple shell: Mage in Simple hides Drive, splits Ride and Trips evenly, and shows Drive in Advanced", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, { simple = true })
	T.settle(w)
	local W = r.W
	W.db.coach = true
	W.UI.Toggle(true)
	w:advance(3)
	local ui = W.UI.state
	local btns = tabButtons(ui)
	eq(#r:findText("^Drive$"), 0, "no visible Drive tab in Simple")
	ok(btns.Ride:IsVisible() and btns.Trips:IsVisible(), "Ride and Trips visible")
	ok(not btns.Drive:IsVisible(), "Drive button hidden")
	ok(math.abs(btns.Ride:GetWidth() - 180) < 0.5, "Ride is half the bar wide")
	ok(math.abs(btns.Trips:GetWidth() - 180) < 0.5, "Trips is half the bar wide")
	eq(W.UI.Show("drive"), false, "UI.Show('drive') returns false when hidden")
	eq(ui.tab, "Ride", "Ride tab stays")
	eq(W.UI.SelectTab("Drive"), false, "UI.SelectTab('Drive') returns false when hidden")
	eq(ui.tab, "Ride", "Ride tab still stays")

	W.SetAdvanced(true)
	w:advance(0.5)
	ok(#r:findText("^Drive$") > 0 and btns.Drive:IsVisible(), "Drive tab shows in Advanced")
	ok(math.abs(btns.Ride:GetWidth() - 120) < 0.5, "Ride is a third wide")
	ok(math.abs(btns.Trips:GetWidth() - 120) < 0.5, "Trips is a third wide")
	ok(math.abs(btns.Drive:GetWidth() - 120) < 0.5, "Drive is a third wide")

	eq(W.UI.Show("drive"), true, "UI.Show('drive') succeeds in Advanced")
	eq(ui.tab, "Drive", "on Drive tab")
	W.SetAdvanced(false)
	w:advance(0.5)
	eq(ui.tab, "Ride", "switching to Simple moves off hidden Drive tab to Ride")
	ok(not btns.Drive:IsVisible(), "Drive tab hidden again")
	T.clean(w)
end)

test("v24 simple shell: Warlock in Simple sees the Drive tab", function()
	local w = T.newWorld()
	local d = T.driver(w, T.ANITA, { simple = true })
	T.settle(w)
	d.W.db.coach = true
	d.W.UI.Toggle(true)
	w:advance(3)
	ok(#d:findText("^Drive$") > 0, "Drive tab visible for Warlock in Simple")
	eq(d.W.UI.Show("drive"), true, "UI.Show('drive') opens Drive for Warlock in Simple")
	eq(d.W.UI.state.tab, "Drive", "on Drive tab")
	T.clean(w)
end)

test("v24 simple shell: Mage in Simple gets the Drive tab when a crew offer waits", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, { simple = true })
	T.settle(w)
	local W = r.W
	W.db.coach = true
	W.UI.Toggle(true)
	w:advance(3)
	eq(#r:findText("^Drive$"), 0, "Drive tab hidden before crew offer")

	W.Drive.pendingOffers = W.Drive.pendingOffers or {}
	local offer = {
		captain = T.ANITA,
		key = "anita lift",
		name = T.ANITA,
		cut = 25,
		at = r.env.GetTime(),
		expires = r.env.GetTime() + 60,
	}
	W.Drive.pendingOffers["anita lift"] = offer
	W.Fire("DRIVE_OFFER", "anita lift", offer)
	w:advance(0.5)
	ok(#r:findText("^Drive$") > 0, "Drive tab shows once a crew offer waits")
	eq(W.UI.Show("drive"), true, "UI.Show('drive') works while offer waits")
	eq(W.UI.state.tab, "Drive", "on Drive tab")

	W.Drive.pendingOffers["anita lift"] = nil
	W.Fire("DRIVE_OFFER", "anita lift")
	w:advance(0.5)
	eq(W.UI.state.tab, "Ride", "clearing the offer hides Drive and returns to Ride")
	eq(#r:findText("^Drive$"), 0, "Drive tab hidden again")
	T.clean(w)
end)

test("v24 simple shell: Simple stays phone-sized without Wide button and preserves WuberDB.fold", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, { simple = true })
	r.wide = true
	T.settle(w)
	local W = r.W
	W.db.coach = true
	W.UI.Toggle(true)
	w:advance(3)
	local wf = r.env.WuberFrame
	local foldBtn = W.UI.state.phone.fold
	eq(wf:GetWidth(), 360, "Simple window stays 360 wide on a wide screen")
	eq(W.UI.Fold.IsUnfolded(), false, "not unfolded in Simple")
	ok(not foldBtn:IsShown(), "Wide button hidden in Simple")
	eq(r.env.WuberDB.fold, nil, "WuberDB.fold stays nil in Simple")

	W.SetAdvanced(true)
	w:advance(1)
	eq(wf:GetWidth(), 720, "unfolds to 720 in Advanced")
	ok(foldBtn:IsVisible(), "Wide/Narrow button shows in Advanced")
	eq(r.env.WuberDB.fold, nil, "WuberDB.fold still nil after SetAdvanced(true)")

	W.db.fold = { v = 1, pages = { trips = "closed" }, narrow = false }
	W.SetAdvanced(false)
	w:advance(1)
	eq(wf:GetWidth(), 360, "folds back to 360 in Simple")
	ok(not foldBtn:IsShown(), "Wide button hidden again in Simple")
	eq(W.UI.WindowWide(), true, "saved Wide pages choice still reads true")
	eq(r.env.WuberDB.fold.narrow, false, "fold.narrow untouched after SetAdvanced(false)")
	eq(r.env.WuberDB.fold.pages.trips, "closed", "fold.pages untouched after SetAdvanced(false)")

	W.SetAdvanced(true)
	w:advance(1)
	eq(wf:GetWidth(), 720, "wide again after returning to Advanced")
	eq(r.env.WuberDB.fold.narrow, false, "fold.narrow untouched after returning to Advanced")
	eq(r.env.WuberDB.fold.pages.trips, "closed", "fold.pages untouched after returning to Advanced")
	T.clean(w)
end)

test("v24 simple shell: minimap tooltip hides Right-click in Simple and shows it in Advanced", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, { simple = true })
	T.settle(w)
	local btn = r.W.UI.state.minimap
	local simpleTip = tipOf(r, btn)
	ok(simpleTip:find("Left-click: open or close. Drag: move.", 1, true) ~= nil, "Simple tooltip has open/close and drag")
	eq(simpleTip:find("Right-click", 1, true), nil, "Simple tooltip has no Right-click")

	r.W.SetAdvanced(true)
	local advTip = tipOf(r, btn)
	ok(advTip:find("Right-click", 1, true) ~= nil, "Advanced tooltip has Right-click")
	T.clean(w)
end)

test("v24 simple shell: login tips leave out advanced tips in Simple and restore them in Advanced", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, { simple = true })
	T.settle(w)
	local Tips = r.W.UI.Tips or r.W.Mod("UI.Tips")
	local hidden = { world_view = true, bounty = true, passphrase = true, trips_wrapped = true }
	local simpleIds = {}
	for _, tip in ipairs(Tips.Eligible()) do
		simpleIds[tip.id] = true
		ok(not hidden[tip.id], "Simple Eligible excludes " .. tip.id)
	end
	ok(simpleIds.fly_or_summon, "Simple Eligible keeps fly_or_summon")

	r.W.SetAdvanced(true)
	local advIds = {}
	for _, tip in ipairs(Tips.Eligible()) do advIds[tip.id] = true end
	ok(advIds.bounty, "Advanced Eligible includes bounty again")
	ok(advIds.passphrase and advIds.trips_wrapped, "Advanced Eligible includes passphrase and trips_wrapped")
	T.clean(w)
end)

test("v24 simple shell: first-open guide in Simple for a Mage says of 4 and never of 5", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, { simple = true })
	T.settle(w)
	r.W.UI.Toggle(true)
	w:advance(5)
	ok(#r:findText("Tip 1 of 4") > 0, "first guide step says Tip 1 of 4")
	eq(#r:findText("of 5"), 0, "guide never says of 5")
	r:clickText("Next")
	w:advance(0.2)
	ok(#r:findText("Tip 2 of 4") > 0, "second step says Tip 2 of 4")
	r:clickText("Next")
	w:advance(0.2)
	ok(#r:findText("Tip 3 of 4") > 0, "third step says Tip 3 of 4")
	r:clickText("Next")
	w:advance(0.2)
	ok(#r:findText("Tip 4 of 4") > 0, "fourth step says Tip 4 of 4")
	ok(#r:findText("Got it") > 0, "last step button says Got it")
	eq(#r:findText("of 5"), 0, "still never says of 5")
	T.clean(w)
end)

test("v24 simple shell: simpleNote toast shows once on first open for returning players only", function()
	local note = "Wuber is simpler now. Everything else is in Settings: Advanced mode."
	local w1 = T.newWorld()
	local r1 = T.rider(w1, T.TESTCHAR, { simple = true, saved = { Wuber = { sound = false } } })
	T.settle(w1)
	eq(r1.env.WuberDB.simpleNote, true, "simpleNote waiting for returning player")
	r1.W.UI.Toggle(true)
	w1:advance(0.5)
	ok(#r1:findText(note, nil, true) > 0, "returning player sees simpleNote toast on first open")
	eq(r1.env.WuberDB.simpleNote, nil, "simpleNote cleared after showing")
	w1:advance(6)
	r1.W.UI.Toggle(false)
	w1:advance(1)
	r1.W.UI.Toggle(true)
	w1:advance(0.5)
	eq(#r1:findText(note, nil, true), 0, "no second toast on reopen")
	T.clean(w1)

	local w2 = T.newWorld()
	local r2 = T.rider(w2, T.TESTCHAR, { simple = true })
	T.settle(w2)
	r2.W.UI.Toggle(true)
	w2:advance(0.5)
	eq(#r2:findText(note, nil, true), 0, "new player never sees simpleNote toast")
	T.clean(w2)

	local w3 = T.newWorld()
	local r3 = T.rider(w3, T.TESTCHAR, { simple = true, saved = { Wuber = { sound = false } } })
	T.settle(w3)
	r3:slash("/wuber advanced")
	eq(r3.env.WuberDB.simpleNote, nil, "simpleNote cleared when /wuber advanced runs before open")
	r3.W.UI.Toggle(true)
	w3:advance(0.5)
	eq(#r3:findText(note, nil, true), 0, "no toast after /wuber advanced before opening")
	T.clean(w3)
end)
