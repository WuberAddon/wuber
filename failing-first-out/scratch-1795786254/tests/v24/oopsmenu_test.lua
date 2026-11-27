-- Wuber 2.4, p3: row menu item for the oops button. Loaded by tests/run.lua with its helper table T.
local T = ...
local test, eq, ok = T.test, T.eq, T.ok

local DAN, EVE = "Dan Miller", "Eve Stone"

local function key(name) return (name:lower():gsub("[%s%-]+", " ")) end

local function openDriver()
	local w = T.newWorld()
	local a = T.driver(w, T.ANITA, { spot = "Orgrimmar", shards = 10 })
	T.settle(w)
	local W = a.W
	if W.UI.WindowWide then W.UI.WindowWide(false) end
	T.openDrive(a)
	W.UI.ShowDrive("console")
	W.Drive.opts().autoInvite = true
	ok(W.Drive.SetOpen(true), "driver open in Orgrimmar")
	w:advance(3)
	return w, a, W, W.Drive, W.Driver
end

local function checkMenuInsideSheet(a, W, label)
	local menu = W.UI and W.UI.drive and (W.UI.drive.menu or (W.UI.drive.screens and W.UI.drive.screens.menu))
	ok(menu and menu.frame and menu.frame.card, label .. ": menu sheet exists")
	local card = menu.frame.card
	local top, bottom, left, right = card:GetTop(), card:GetBottom(), card:GetLeft(), card:GetRight()
	ok(top and bottom and left and right and top > bottom and right > left, label .. ": sheet card has bounds")
	local shown = 0
	for id, r in pairs(menu.items) do
		if r:IsShown() then
			shown = shown + 1
			ok(r:GetTop() <= top and r:GetBottom() >= bottom,
				label .. ": item " .. tostring(id) .. " vertical bounds inside sheet")
			ok(r:GetLeft() >= left and r:GetRight() <= right,
				label .. ": item " .. tostring(id) .. " horizontal bounds inside sheet")
			if type(r.label) == "table" and type(r.label.IsShown) == "function" and r.label:IsShown() then
				ok(r.label:GetTop() <= top and r.label:GetBottom() >= bottom
					and r.label:GetLeft() >= left and r.label:GetRight() <= right,
					label .. ": item " .. tostring(id) .. " label inside sheet")
			end
			if type(r.sub) == "table" and type(r.sub.IsShown) == "function" and r.sub:IsShown() then
				ok(r.sub:GetTop() <= top and r.sub:GetBottom() >= bottom
					and r.sub:GetLeft() >= left and r.sub:GetRight() <= right,
					label .. ": item " .. tostring(id) .. " subtext inside sheet")
			end
		end
	end
	ok(shown > 0, label .. ": at least one item shown")
	for _, txt in ipairs({
		"Oops, wrong invite", "Says sorry and removes them",
		"Take off the list", "Nothing is said (right-click)",
		"Mark as paid", "They paid some other way (Ctrl-click)",
		"Not a rider (a helper)", "They came to click the portal: never billed",
		"Block...", "Never serve them again (shift-right-click)",
	}) do
		for _, fs in ipairs(a:findText(txt, false, true)) do
			ok(fs:GetTop() <= top and fs:GetBottom() >= bottom
				and fs:GetLeft() >= left and fs:GetRight() <= right,
				label .. ": text '" .. txt .. "' inside sheet")
		end
	end
	return menu
end

test("v24 oopsmenu: Oops, wrong invite shows above Take off the list for auto-invited row, hides for clicked lead, arms button and hides after use", function()
	local w, a, W, DR, D = openDriver()
	w:addBot(DAN, { spot = "Ratchet", acceptsInvites = false })
	w:addBot(EVE, { spot = "Ratchet", acceptsInvites = false })
	w:advance(1)

	-- clear whisper -> Wuber auto-invites Dan
	w:botWhisper(DAN, a, "summon pls")
	w:advance(3)
	local dan = DR.customers[key(DAN)]
	eq(dan and dan.state, "invited", "Dan auto-invited")
	eq(DR.CanOops(dan), true, "CanOops true for Dan")

	-- unclear whisper -> Eve is a lead; clicking the lead invites her (not auto-invited)
	w:botWhisper(EVE, a, "LF sleeping bag summons")
	w:advance(3)
	local eveLead = DR.customers[key(EVE)]
	eq(eveLead and eveLead.state, "lead", "Eve is a lead")
	D.RowClick(eveLead, "LeftButton")
	w:advance(3)
	local eve = DR.customers[key(EVE)]
	ok(eve and eve.state ~= "lead", "clicked lead Eve becomes an invited rider")
	eq(DR.CanOops(eve), false, "CanOops false for clicked lead Eve")

	-- Dan's menu shows "Oops, wrong invite" above "Take off the list", and all text fits inside the sheet
	ok(D.OpenMenu(dan), "open Dan's row menu")
	w:advance(1)
	local oopsFs = a:findText("Oops, wrong invite", false, true)
	local dropFs = a:findText("Take off the list", false, true)
	ok(#oopsFs > 0, "Oops, wrong invite is shown for auto-invited Dan")
	ok(#dropFs > 0, "Take off the list is shown for Dan")
	ok(oopsFs[1]:GetBottom() > dropFs[1]:GetTop(), "Oops, wrong invite sits above Take off the list")
	local menu = checkMenuInsideSheet(a, W, "Dan menu")
	menu.frame:Close(true)
	w:advance(1)

	-- Eve's menu (clicked lead) does NOT show "Oops, wrong invite", and all text fits inside the sheet
	ok(D.OpenMenu(eve), "open Eve's row menu")
	w:advance(1)
	eq(#a:findText("Oops, wrong invite", false, true), 0, "Oops, wrong invite is hidden for clicked lead Eve")
	ok(#a:findText("Take off the list", false, true) > 0, "Take off the list is shown for Eve")
	checkMenuInsideSheet(a, W, "Eve menu")
	menu.frame:Close(true)
	w:advance(1)

	-- open Dan's menu again and choose "Oops, wrong invite"
	ok(D.OpenMenu(dan), "reopen Dan's row menu")
	w:advance(1)
	a:clickText("Oops, wrong invite")
	w:advance(1)

	eq(dan.oops, true, "Dan row marked c.oops == true")
	ok(#a:findText("Oops: remove Dan", false, true) > 0, "big button armed with Oops: remove Dan after 1s")

	-- second open of Dan's menu no longer shows the item
	ok(D.OpenMenu(dan), "second open of Dan's row menu")
	w:advance(1)
	eq(#a:findText("Oops, wrong invite", false, true), 0, "Oops, wrong invite no longer shown after use")
	ok(#a:findText("Take off the list", false, true) > 0, "Take off the list still shown on second open")
	checkMenuInsideSheet(a, W, "Dan second menu")

	T.clean(w)
end)
