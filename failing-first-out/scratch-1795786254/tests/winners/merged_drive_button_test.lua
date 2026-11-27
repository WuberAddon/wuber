-- Merged table-driven tests (test audit): each group below was several near-identical tests of tests/winners/drive_button_test.lua, the same body with different
-- literals. One body, one table of cases; every case keeps its own assertions and a failing case is named in the message.
local T = ...
local test, eq, ok = T.test, T.eq, T.ok

-- from tests/winners/drive_button_test.lua: line 432; line 448
test("breakit Drive.Button: the big button's tooltip shows the plan's own title (2 cases)", function()
	local failed = {}
	local cases = {
		{ "breakit Drive.Button: the big button's tooltip shows the plan's own title", "Trade with Dan", "Trade with Dan", "the tooltip shows the plan's title" },
		{ "breakit Drive.Button: a click plan's tooltip says it presses Trade", "Trade", "presses Trade in the trade window", "the tooltip explains the click" },
	}
	for _, case in ipairs(cases) do
		local C = { select(2, unpack(case)) }
		local good, err = pcall(function()
		local w = T.newWorld()
		local d = T.driver(w, T.ANA)
		T.settle(w)
		local b = d.env.WuberDriveButton
		ok(b, "the big button is built")
		b.plan = { title = C[1], type = "click" }
		local enter = b:GetScript("OnEnter")
		ok(type(enter) == "function", "the button has a tooltip handler")
		enter(b)
		w:advance(0.1)
		ok(#d:findText(C[2], false, true) > 0, C[3])
		T.clean(w)
		end)
		if not good then failed[#failed + 1] = case[1] .. ": " .. tostring(err) end
	end
	if #failed > 0 then error(#failed .. " of " .. #cases .. " cases failed:\n" .. table.concat(failed, "\n"), 0) end
end)

-- from tests/winners/drive_button_test.lua: line 1020; line 1053
test("breakit Drive.Button: a floating button overlapping the open phone is moved clear (2 cases)", function()
	local failed = {}
	local cases = {
		{ "breakit Drive.Button: a floating button overlapping the open phone is moved clear" },
		{ "breakit Drive.Button: a floating button tucked under the open phone is moved clear" },
	}
	for _, case in ipairs(cases) do
		local C = { select(2, unpack(case)) }
		local good, err = pcall(function()
	    local w = T.newWorld()
	    local d = T.driver(w, T.ANITA, { spot = "Orgrimmar" })
	    T.settle(w)
	    T.goOnline(d, { price = 5000 })
	    w:advance(2)
	    local b = d.env.WuberDriveButton
	    local win = d.env.WuberFrame
	    local U = d.env.UIParent
	    ok(b and T.H.visible(b) and d.W.Drive.Button.Floating(), "drive button is floating")
	    ok(win and U, "phone frame and parent exist")
	    d.W.Drive.SetScale(1)
	    w:advance(0.5)
	    win:SetSize(500, 600)
	    win:ClearAllPoints()
	    win:SetPoint("CENTER", U, "CENTER", 0, 0)
	    win:Show()
	    b:ClearAllPoints()
	    b:SetPoint("BOTTOMLEFT", U, "BOTTOMLEFT", 0, 0)
	    w:advance(2)
	    win:SetFrameStrata("MEDIUM")
	    b:SetFrameStrata("MEDIUM")
	    win:SetFrameLevel(50)
	    b:SetFrameLevel(10)
	    b:ClearAllPoints()
	    b:SetPoint("CENTER", U, "CENTER", 0, 0)
	    local x, y = b:GetLeft(), b:GetBottom()
	    w:advance(2)
	    ok(b:GetLeft() ~= x or b:GetBottom() ~= y, "the button is moved out from under the phone")
	    T.clean(w)
		end)
		if not good then failed[#failed + 1] = case[1] .. ": " .. tostring(err) end
	end
	if #failed > 0 then error(#failed .. " of " .. #cases .. " cases failed:\n" .. table.concat(failed, "\n"), 0) end
end)

-- from tests/winners/drive_button_test.lua: line 1881; line 1903
test("breakit Drive.Button: a kept-closed button appears as soon as the drive shuts with no riders (2 cases)", function()
	local failed = {}
	local cases = {
		{ "breakit Drive.Button: a kept-closed button appears as soon as the drive shuts with no riders", 'keeping the button closed puts it back at once' },
		{ "breakit Drive.Button: switching keep-closed on with no riders puts the big button back at once", 'the kept-closed button is shown right away' },
	}
	for _, case in ipairs(cases) do
		local C = { select(2, unpack(case)) }
		local good, err = pcall(function()
	 local w = T.newWorld()
	 local d = T.driver(w, T.ANA, { spot = 'Orgrimmar' })
	 T.settle(w)
	 local W = d.W
	 local DR = W.Drive
	 local b = d.env.WuberDriveButton
	 T.goOnline(d, { price = 5000 })
	 w:advance(1)
	 DR.Button.Dock(nil)
	 W.UI.Toggle(false)
	 w:advance(0.5)
	 ok(b and T.H.visible(b), 'the big button is on screen while the drive is on')
	 W.Driver.SetOnline(false)
	 w:advance(1)
	 ok(not T.H.visible(b), 'with no riders the closed drive hides the big button')
	 DR.Button.KeepClosed(true)
	 ok(T.H.visible(b), C[1])
	 T.clean(w)
		end)
		if not good then failed[#failed + 1] = case[1] .. ": " .. tostring(err) end
	end
	if #failed > 0 then error(#failed .. " of " .. #cases .. " cases failed:\n" .. table.concat(failed, "\n"), 0) end
end)

-- from tests/winners/drive_button_test.lua: line 2606; line 2683
test("breakit Drive.Button: dragging the big button saves its new place (2 cases)", function()
	local failed = {}
	local cases = {
		{ "breakit Drive.Button: dragging the big button saves its new place" },
		{ "breakit Drive.Button: letting go after dragging saves the button's place" },
	}
	for _, case in ipairs(cases) do
		local C = { select(2, unpack(case)) }
		local good, err = pcall(function()
	    local w = T.newWorld()
	    local d = T.driver(w, T.ANA)
	    T.settle(w)
	    T.goOnline(d, { price = 5000 })
	    w:advance(2)
	    local b = d.env.WuberDriveButton
	    ok(b, "drive button exists")
	    local wdb = d.env.WuberDB
	    ok(type(wdb) == "table" and type(wdb.drive) == "table" and type(wdb.drive.button) == "table", "drive button settings exist")
	    eq(wdb.drive.button.pos, nil, "no saved button position initially")
	    local start = b:GetScript("OnDragStart")
	    if type(start) == "function" then
	        d.env.IsShiftKeyDown = function() return true end
	        start(b)
	    end
	    local stop = b:GetScript("OnDragStop")
	    if type(stop) == "function" then stop(b) end
	    w:advance(1)
	    eq(type(wdb.drive.button.pos), "table", "button position saved after dragging")
	    T.clean(w)
		end)
		if not good then failed[#failed + 1] = case[1] .. ": " .. tostring(err) end
	end
	if #failed > 0 then error(#failed .. " of " .. #cases .. " cases failed:\n" .. table.concat(failed, "\n"), 0) end
end)

-- from tests/winners/drive_button_test.lua: line 2656; line 2739
test("breakit Drive.Button: shift-dragging the big button (2 cases)", function()
	local failed = {}
	local cases = {
		{ "breakit Drive.Button: shift-dragging the big button saves its new spot" },
		{ "breakit Drive.Button: shift-dragging the big button keeps the new spot after release" },
	}
	for _, case in ipairs(cases) do
		local C = { select(2, unpack(case)) }
		local good, err = pcall(function()
		local w = T.newWorld()
		local d = T.driver(w, T.ANA)
		T.settle(w)
		local b = d.W.Drive.BuildButton()
		ok(b, "the big button exists")
		d.W.Drive.Button.SetLocked(false)
		d.env.IsShiftKeyDown = function() return true end
		b.StartMoving = function(self) end
		b.StopMovingOrSizing = function(self) end
		b:ClearAllPoints()
		b:SetPoint("TOPLEFT", d.env.UIParent, "TOPLEFT", 111, -222)
		local wdb = d.env.WuberDB
		ok(type(wdb) == "table" and type(wdb.drive) == "table", "the drive settings exist")
		local bdb = wdb.drive.button
		eq(bdb and bdb.pos, nil, "no button position is saved before the drag")
		b:GetScript("OnDragStart")(b)
		b:GetScript("OnDragStop")(b)
		w:advance(1)
		bdb = wdb.drive.button
		ok(type(bdb) == "table" and type(bdb.pos) == "table", "the button position is saved after the drag")
		eq(bdb.pos[3], 111, "the saved x is the dragged place")
		eq(bdb.pos[4], -222, "the saved y is the dragged place")
		T.clean(w)
		end)
		if not good then failed[#failed + 1] = case[1] .. ": " .. tostring(err) end
	end
	if #failed > 0 then error(#failed .. " of " .. #cases .. " cases failed:\n" .. table.concat(failed, "\n"), 0) end
end)

-- from tests/winners/drive_button_test.lua: line 2837; line 3333
test("breakit Drive.Button: the big button tooltip is hidden when the pointer leaves (2 cases)", function()
	local failed = {}
	local cases = {
		{ "breakit Drive.Button: the big button tooltip is hidden when the pointer leaves" },
		{ "breakit Drive.Button: leaving the big button closes its tooltip" },
	}
	for _, case in ipairs(cases) do
		local C = { select(2, unpack(case)) }
		local good, err = pcall(function()
	    local w = T.newWorld()
	    local d = T.driver(w, T.ANA)
	    T.settle(w)
	    T.goOnline(d, { price = 5000 })
	    w:advance(2)
	    local b = d.env.WuberDriveButton
	    ok(b, 'the big button is built')
	    -- (design 4) the big button's tip is Wuber's own card now: shown by the button's OnEnter, not by showing the
	    -- game's tooltip by hand (which the button no longer touches); the fake game answers from the card
	    local tip = d.env.GameTooltip
	    ok(tip, 'the game tooltip exists')
	    b:GetScript('OnEnter')(b)
	    ok(T.H.visible(tip), 'the tooltip is showing')
	    b:GetScript('OnLeave')(b)
	    ok(not T.H.visible(tip), 'the tooltip is hidden after leaving the big button')
	    T.clean(w)
		end)
		if not good then failed[#failed + 1] = case[1] .. ": " .. tostring(err) end
	end
	if #failed > 0 then error(#failed .. " of " .. #cases .. " cases failed:\n" .. table.concat(failed, "\n"), 0) end
end)
