
local T = ...
local test, ok, eq = T.test, T.ok, T.eq

-- The game's own OnMouseUp on the map's scroll container opens the zone under the cursor
-- (continent map -> zone map) BEFORE addon post-hooks run. We model that by putting such a
-- handler first in the chain, ahead of the addon's hook, as HookScript orders them.
local function blizzardFirst(sc, wm, zoneMap)
	local addon = sc:GetScript("OnMouseUp")
	sc:SetScript("OnMouseUp", function(self, button, ...)
		if button == "LeftButton" then wm:SetMapID(zoneMap) end
		if addon then addon(self, button, ...) end
	end)
end

test("r47 d3: audit C37r-1: Ctrl-click on Gadgetzan on the Kalimdor map books the place under the cursor after the zoom, not Gadgetzan", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, { spot = "Orgrimmar" })
	T.settle(w)
	local M = r.W.Map
	local wm = r.env.WorldMapFrame
	wm:SetMapID(1414) wm:Show() w:advance(1)
	r.mouseOver = wm.ScrollContainer -- the cursor is over the map
	-- find where Gadgetzan is drawn on the continent map (cursor spot)
	local spot
	for ix = 0, 100 do
		for iy = 0, 100 do
			r.mapCursorX, r.mapCursorY = ix / 100, iy / 100
			local p = M.PlaceUnderCursor(false)
			if p and p.name == "Gadgetzan" then spot = { ix / 100, iy / 100 } break end
		end
		if spot then break end
	end
	ok(spot, "control: Gadgetzan can be pointed at on the continent map")
	r.mapCursorX, r.mapCursorY = spot[1], spot[2]
	eq(M.PlaceUnderCursor(true).name, "Gadgetzan", "control: the cursor is over Gadgetzan before the click")
	local booked
	-- watch what the click books (MouseUp calls M.BookPlace(place))
	M.BookPlace = function(place) booked = place and place.name or "(nothing)" return true end
	local sc = wm.ScrollContainer
	local function ctrlClick()
		booked = "(no booking)"
		r.mods.ctrl = true
		sc:GetScript("OnMouseDown")(sc, "LeftButton")
		sc:GetScript("OnMouseUp")(sc, "LeftButton")
		r.mods.ctrl = false
		w:advance(1)
	end
	ctrlClick() -- control: a map that does not zoom on the click
	eq(booked, "Gadgetzan", "control: Ctrl-click on Gadgetzan books Gadgetzan when the map stays put")
	wm:SetMapID(1414)
	blizzardFirst(sc, wm, 1446) -- the game zooms into Tanaris on the click
	ctrlClick()
	eq(wm:GetMapID(), 1446, "the map zoomed into Tanaris")
	ok(booked == "Gadgetzan", "the player Ctrl-clicked Gadgetzan but Wuber opened: " .. tostring(booked))
	T.clean(w)
end)
