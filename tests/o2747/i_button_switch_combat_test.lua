-- #23 The big summon button stays exactly where the player put it across a Simple/Advanced switch made in combat,
-- and after combat ends. Loaded by tests/run.lua with its helper table T.
local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H

local function pt(b)
	local p, _, rp, x, y = b:GetPoint(1)
	return table.concat({ tostring(b:IsShown()), tostring(p), tostring(rp), tostring(x), tostring(y), tostring(b:GetScale()), tostring(b:GetWidth()), tostring(b:GetHeight()) }, "|")
end

local function run(step, simpleStart, overlap)
	local w = T.newWorld()
	local d = T.driver(w, T.ANITA, { spot = "Orgrimmar" })
	T.settle(w)
	local W, env = d.W, d.env
	W.SetAdvanced(not simpleStart)
	W.Driver.SetOnline(true)
	w:advance(2)
	if overlap == true then W.db.pos = { "CENTER", "CENTER", 0, 0 } else W.db.pos = { "BOTTOMLEFT", "BOTTOMLEFT", 40, 40 } end
	W.Drive.Button.Place()
	w:advance(step)
	W.UI.Toggle(true)
	W.UI.SelectTab(overlap == "ride" and "Ride" or (overlap == "closed" and "Ride" or "Drive"))
	if overlap == "closed" then W.UI.Toggle(false) end
	w:advance(3 * step > 3 and 3 * step or 3)
	local b = env.WuberDriveButton
	local before = pt(b)
	w:enterCombat(d)
	w:advance(step)
	W.SetAdvanced(not W.Advanced())
	w:advance(step)
	local inFight = pt(b)
	w:leaveCombat(d)
	for _ = 1, math.ceil(6 / step) do w:advance(step) end
	return before, inFight, pt(b), w, b
end

local function promise(step, from, tab)
	local before, inFight, after, w = run(step, from == "simple", tab)
	eq(inFight, before, "unchanged in the fight")
	eq(after, before, "unchanged after the fight")
	eq(#(w.violations or {}), 0, "no secure frame changed in combat: " .. table.concat(w.violations or {}, "; "))
end

-- The promise: one Simple/Advanced switch made in combat leaves the big button exactly where it was, in the fight
-- and after it, at both clock step sizes (combat end is an event; the button settles on a 0.25 s timer).
-- Docked in the Drive tab the slot itself moves a little with the mode, which is what used to pull the button.
for _, step in ipairs({ 1, 5 }) do
	for _, from in ipairs({ "simple", "advanced" }) do
		test(("#23 big button stays put across a Simple/Advanced switch in combat (step %ds, from %s, drive tab)"):format(step, from), function()
			promise(step, from, "drive")
		end)
		-- guard: the floating button (Ride tab, or the window closed) has no slot to follow and never moved
		test(("#23 floating big button stays put across a Simple/Advanced switch in combat (step %ds, from %s, ride tab)"):format(step, from), function()
			promise(step, from, "ride")
		end)
		-- guard: the floating button (Ride tab, or the window closed) has no slot to follow and never moved
		test(("#23 floating big button stays put across a Simple/Advanced switch in combat (step %ds, from %s, window closed)"):format(step, from), function()
			promise(step, from, "closed")
		end)
	end
end

-- the button's bottom-left against its slot's, in screen units
local function offSlot(W, b)
	local slot = W.Driver.Slot()
	if not slot then return "no slot" end
	local k = b:GetEffectiveScale() / slot:GetEffectiveScale()
	return math.max(math.abs(b:GetLeft() * k - slot:GetLeft()), math.abs(b:GetBottom() * k - slot:GetBottom()))
end

local function dockedWorld(step)
	local w = T.newWorld()
	local d = T.driver(w, T.ANITA, { spot = "Orgrimmar" })
	T.settle(w)
	local W = d.W
	W.SetAdvanced(false)
	W.Driver.SetOnline(true)
	w:advance(2)
	W.UI.Toggle(true)
	W.UI.SelectTab("Drive")
	for _ = 1, math.ceil(3 / step) do w:advance(step) end
	return w, d, W, d.env.WuberDriveButton
end

for _, step in ipairs({ 1, 5 }) do
	-- guard: a switch made OUT of combat keeps today's behaviour: the docked button is on its slot in both modes
	test(("#23 docked big button sits on its slot after a switch out of combat (step %ds)"):format(step), function()
		local w, d, W, b = dockedWorld(step)
		ok(W.Drive.Button.Docked(), "docked in the Drive tab")
		eq(offSlot(W, b) < 0.5, true, "on its slot in Simple")
		W.SetAdvanced(true)
		for _ = 1, math.ceil(3 / step) do w:advance(step) end
		eq(offSlot(W, b) < 0.5, true, "on its slot in Advanced")
	end)

	-- guard: the held-button bug the first fix had (a stale hold after the window closed) must not come back
	test(("#23 docked, switch in combat, close the window, fight ends, reopen: the button is on its slot (step %ds)"):format(step), function()
		local w, d, W, b = dockedWorld(step)
		w:enterCombat(d)
		w:advance(step)
		W.SetAdvanced(true)
		w:advance(step)
		w:leaveCombat(d)
		for _ = 1, math.ceil(3 / step) do w:advance(step) end
		eq(offSlot(W, b) < 0.5, true, "exactly on its slot after the fight")
		w:enterCombat(d)
		w:advance(step)
		W.SetAdvanced(false)
		W.UI.Toggle(false)
		w:advance(step)
		w:leaveCombat(d)
		for _ = 1, math.ceil(3 / step) do w:advance(step) end
		W.UI.Toggle(true)
		W.UI.SelectTab("Drive")
		for _ = 1, math.ceil(3 / step) do w:advance(step) end
		ok(W.Drive.Button.Docked(), "docked again")
		eq(offSlot(W, b) < 0.5, true, "on its slot after reopening")
		eq(#(w.violations or {}), 0, "no secure frame changed in combat: " .. table.concat(w.violations or {}, "; "))
	end)
end

-- guard: documents the only case that still moves: Advanced needs the 36-unit row for the switch (no room for it in the
-- header zone), Simple does not show it, so a switch made in combat moves the slot and the button follows after the fight
test("#23 the one case a combat switch still moves the docked button: the switch needs its own row in Advanced", function()
	local w, d, W, b = dockedWorld(1)
	W.UI.HeadRoom = function() return 400 end
	W.SetAdvanced(true)
	for _ = 1, 3 do w:advance(1) end
	local y0 = select(5, b:GetPoint(1))
	eq(offSlot(W, b) < 0.5, true, "on its slot in Advanced")
	w:enterCombat(d)
	w:advance(1)
	W.SetAdvanced(false)
	w:advance(1)
	eq(select(5, b:GetPoint(1)), y0, "frozen in the fight")
	w:leaveCombat(d)
	for _ = 1, 3 do w:advance(1) end
	ok(math.abs(select(5, b:GetPoint(1)) - y0) > 30, "moved with the slot after the fight")
	eq(offSlot(W, b) < 0.5, true, "and sits on its slot")
end)
