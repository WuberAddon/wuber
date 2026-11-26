-- (BRIEF22 G1) Textures as the game draws them: the client-faithful fake keeps a texture's alpha where the
-- game would (BRIEF19 F5, BRIEF20 B1: a SetVertexColor alpha change on a drawn texture that is hidden, or was
-- just shown again, or under an Alpha animation, is not drawn). Wuber's looks never change a texture's
-- vertex alpha after it is made: a second texture is shown or hidden, or the region's alpha changes.
-- Loaded by tests/run.lua with its helper table T. lab_photo's tour checks the same over every screen.
local T = ...
local H, test, eq, ok = T.H, T.test, T.eq, T.ok
local S = H.state

-- the Wuber lines whose alpha change the game would not draw (world.alphaKept, by line)
local function held(w)
	local out = {}
	for line in pairs(w.alphaKept or {}) do
		if line:find("^Wuber/") and not (H.alphaKnown or {})[line] then out[#out + 1] = line end -- known: tests/fixtures/alpha-known.txt
	end
	table.sort(out)
	return table.concat(out, ", ")
end

-- the shown textures whose drawn alpha is not the one Wuber last asked for
local function stale(c)
	local out = {}
	for _, o in ipairs(c.widgets) do
		local s = S[o]
		if s and (s.otype == "Texture" or s.otype == "Line") and H.visible(o) then
			local _, _, _, drawn = o:GetVertexColor()
			local _, _, _, asked = H.vertexAsked(o)
			if math.abs((drawn or 1) - (asked or 1)) > 1e-6 then
				out[#out + 1] = ("%s %.2f (asked %.2f)"):format(tostring(s.texture or s.otype), drawn or 1, asked or 1)
			end
		end
	end
	return table.concat(out, ", ")
end

test("ui.alpha: a rider's Home cards and Trips, the window shut and opened again, draw the alpha Wuber asks for", function()
	local w = T.newWorld()
	local d = T.driver(w, T.BOB, { netOnly = true })
	local r = T.rider(w)
	T.settle(w)
	T.goOnline(d)
	local UI = r.W.UI
	r.W.db.coach = true
	UI.Toggle(true)
	w:advance(3)
	ok(UI.state.cards["bob stone"], "Bob's card")
	for _ = 1, 2 do
		UI.Toggle(false)
		w:advance(1)
		UI.Toggle(true)
		w:advance(0.1)
		UI.Show("trips")
		w:advance(2)
		UI.Show("home")
		w:advance(2)
	end
	eq(held(w), "", "lines whose alpha change the game would not draw")
	eq(stale(r), "", "shown textures not at the asked alpha")
	eq(#w.errors, 0, "Lua errors (" .. table.concat(w.errors, "; ") .. ")")
	T.clean(w)
end)

test("ui.alpha: the badge picker's ring follows the chosen badge, chosen while Settings is shut (its own ring, shown or hidden)", function()
	local w = T.newWorld()
	local d = T.driver(w, T.BOB)
	T.settle(w)
	local W, UI = d.W, d.W.UI
	W.db.coach = true
	UI.Toggle(true)
	w:advance(3)
	UI.OpenSettings("driving")
	w:advance(1)
	local st = UI.settings
	local picks = {}
	for _, b in ipairs(st.badges or {}) do if b.id ~= "" then picks[#picks + 1] = b end end
	ok(#picks >= 3, "the picker's badges (" .. #picks .. ")")
	W.Char().badge = picks[1].id
	UI.UpdateSettings()
	w:advance(1)
	-- shut, another badge chosen, opened again
	UI.CloseSettings()
	w:advance(1)
	W.Char().badge = picks[2].id
	UI.UpdateSettings()
	UI.OpenSettings("driving")
	w:advance(2)
	for _, b in ipairs(st.badges) do
		local on = b.id == picks[2].id
		local ring = on and b.ring or b.ringOff
		ok(ring and H.visible(ring), b.id .. ": its ring shows")
		ok(not H.visible(on and b.ringOff or b.ring), b.id .. ": the other ring is hidden")
		local _, _, _, a = ring:GetVertexColor()
		eq(("%.2f"):format(a), on and "1.00" or "0.60", b.id .. ": the ring's drawn alpha")
	end
	eq(held(w), "", "lines whose alpha change the game would not draw")
	eq(stale(d), "", "shown textures not at the asked alpha")
	T.clean(w)
end)

test("ui.alpha: the world map's dashed routes keep alpha 1 in their colour; a route's alpha is the line's own (lines are reused)", function()
	local w = T.newWorld()
	local r = T.rider(w, nil, { spot = "Orgrimmar" })
	T.settle(w)
	local W = r.W
	local Mod = W.Mod("UI.Rider.WorldMap")
	Mod.Reset()
	for k in pairs(Mod.cache.maps) do Mod.cache.maps[k] = nil end
	Mod.cache.last = nil
	W.UI.Fold.IsUnfolded = function() return true end
	local holder = r.env.CreateFrame("Frame", nil, r.env.UIParent)
	holder:SetSize(360, 544)
	holder:SetPoint("TOPLEFT", r.env.UIParent, "TOPLEFT", 400, -100)
	Mod.Build(holder)
	Mod.Show("world")
	w:advance(1)
	local wm = Mod.cache.maps[holder]
	ok(wm and wm.hasLines and wm.lines.used > 0, "routes drawn with lines")
	local bad, soft = {}, 0
	for i = 1, wm.lines.used do
		local l = wm.lines.list[i]
		local _, _, _, va = l:GetVertexColor()
		if math.abs((va or 1) - 1) > 1e-6 then bad[#bad + 1] = i .. ": " .. va end
		if (l:GetAlpha() or 1) < 1 then soft = soft + 1 end
	end
	eq(table.concat(bad, ", "), "", "lines with a colour alpha under 1")
	ok(soft > 0, "the dashed routes are soft by the line's own alpha (" .. soft .. ")")
	Mod.Refresh()
	w:advance(1)
	eq(held(w), "", "lines whose alpha change the game would not draw")
	for path in pairs(w.missingFiles) do
		if path:match("Media\\dash$") then w.missingFiles[path] = nil end
	end
	T.clean(w)
end)
