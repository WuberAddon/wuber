-- Tests of UI.Window. Loaded by tests/run.lua with its helper table T.
-- (BRIEF20 B1, tour #1-17, #89) the nav Ride | Trips | Drive lights the tab that is open, in the
-- game's terms: on the Ride tab the game drew Ride clear and Drive as a solid white pill with pale words.
-- (design 2, C) the tabs are in the bar at the bottom: the open one has a violet glyph and word, the others grey,
-- no pill at all; still no alpha changes after the build.
local T = ...
local test, eq, ok = T.test, T.eq, T.ok

-- In the game a texture of these pills kept the alpha it had (the tour changed the tab while the window
-- was shut, and a later SetVertexColor changed the colour, not the alpha). Here every alpha change after
-- the build is not drawn, as in the game, and one on a texture that shows is noted.
local function asGame(buttons)
	local changed = {}
	for _, b in ipairs(buttons) do
		for _, r in ipairs({ b:GetRegions() }) do
			if r:GetObjectType() == "Texture" then
				local orig = r.SetVertexColor
				r.SetVertexColor = function(self, cr, cg, cb, ca)
					local _, _, _, a0 = self:GetVertexColor()
					if self:IsShown() and math.abs((ca or 1) - (a0 or 1)) > 0.01 then changed[#changed + 1] = ("%s %.2f -> %.2f"):format(tostring(b.tabName), a0 or 1, ca or 1) end
					return orig(self, cr, cg, cb, a0)
				end
			end
		end
	end
	return changed
end

local function near(r, g, b, c, Th)
	local cr, cg, cb = Th.RGB(c)
	return math.abs(r - cr) + math.abs(g - cg) + math.abs(b - cb) < 0.03
end

-- the tabs that are lit as the game draws them: a violet glyph, drawn solid
local function lit(ui, Th)
	local out = {}
	for _, tab in ipairs(ui.tabs) do
		local r, g, b, al = tab.button.glyph:GetVertexColor()
		if tab.button.glyph:IsVisible() and (al or 1) > 0.3 and near(r, g, b, "accent", Th) then out[#out + 1] = tab.name end
	end
	return table.concat(out, ",")
end

-- the label of a tab is violet (the open one), the quiet grey, or white under the mouse
local function words(ui, name, Th)
	for _, tab in ipairs(ui.tabs) do
		if tab.name == name then
			local r, g, b = tab.button.label:GetTextColor()
			for _, c in ipairs({ "accent", "offText", "white" }) do
				if near(r, g, b, c, Th) then return c end
			end
			return ("%.2f,%.2f,%.2f"):format(r, g, b)
		end
	end
end

local function whiteFill(ui)
	local out = {}
	for _, tab in ipairs(ui.tabs) do
		for _, r in ipairs({ tab.button:GetRegions() }) do
			if r:GetObjectType() == "Texture" and r:IsVisible() then
				local cr, cg, cb, al = r:GetVertexColor()
				if r ~= tab.button.glyph and (al or 1) > 0.3 and cr > 0.9 and cg > 0.9 and cb > 0.9 then out[#out + 1] = tab.name break end
			end
		end
	end
	return table.concat(out, ",")
end

test("ui.window: B1 the nav lights the open tab as the game draws it (tour: Drive, shut, Ride; tabs; hover; reopen)", function()
	local w = T.newWorld()
	local a = T.driver(w, T.ANITA, { spot = "Undercity" })
	w:advance(15)
	local W = a.W
	W.db.coach = true
	T.openDrive(a)
	local UI = W.UI
	local ui = UI.state
	eq(ui.tab, "Drive", "on the Drive tab")
	local changed = asGame((function() local t = {} for _, tab in ipairs(ui.tabs) do t[#t + 1] = tab.button end return t end)())
	local function check(want, when)
		eq(ui.tab, want, when .. ": the open tab")
		eq(lit(ui, W.Theme), want, when .. ": the lit pill, as the game draws it")
		eq(whiteFill(ui), "", when .. ": no solid white pill")
		for _, tab in ipairs(ui.tabs) do
			eq(words(ui, tab.name, W.Theme), tab.name == want and "accent" or "offText", when .. ": " .. tab.name .. "'s words")
		end
	end
	check("Drive", "Drive open")
	-- the photo tour: the window shut, the Ride tab chosen, the window opened again (#1)
	UI.Toggle(false)
	w:advance(1)
	UI.SelectTab("Ride")
	UI.Toggle(true)
	w:advance(3)
	check("Ride", "reopened on Ride")
	-- a click on Trips, then Drive, then Ride
	for _, name in ipairs({ "Trips", "Drive", "Ride" }) do
		for _, tab in ipairs(ui.tabs) do if tab.name == name then a:clickOn(tab.button) end end
		w:advance(1)
		check(name, "a click on " .. name)
	end
	-- hover over Drive and away: its words go white, then grey; no pill
	local drive
	for _, tab in ipairs(ui.tabs) do if tab.name == "Drive" then drive = tab.button end end
	drive:GetScript("OnEnter")(drive)
	eq(lit(ui, W.Theme), "Ride", "hovering Drive lights no other pill")
	eq(words(ui, "Drive", W.Theme), "white", "hovered Drive: white words")
	drive:GetScript("OnLeave")(drive)
	check("Ride", "after a hover")
	-- the chosen pill under the mouse and away
	local ride = ui.tabs[1].button
	ride:GetScript("OnEnter")(ride)
	eq(lit(ui, W.Theme), "Ride", "hovered Ride still lit")
	ride:GetScript("OnLeave")(ride)
	check("Ride", "after a hover on Ride")
	eq(#changed, 0, "no alpha change after the tabs are made (the game keeps the first): " .. table.concat(changed, ", "))
	T.clean(w)
end)
