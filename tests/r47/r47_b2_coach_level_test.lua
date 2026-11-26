local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H

-- textures that draw OVER the tip card's middle: same strata, parent frame at a higher level, not part of the card
local function coveringTextures(r)
	local c = r.W.UI.state.coach
	local cr = H.rect(c)
	local cx, cy = cr.l + cr.w / 2, cr.b + cr.h / 2
	local out = {}
	for _, o in ipairs(r.widgets) do
		if o.GetObjectType and o:GetObjectType() == "Texture" and H.visible(o) then
			local rc, p = H.rect(o), o:GetParent()
			if rc and p and cx >= rc.l and cx <= rc.l + rc.w and cy >= rc.b and cy <= rc.b + rc.h then
				local mine, q = false, p
				while q do if q == c then mine = true end q = q.GetParent and q:GetParent() end
				if not mine and p:GetFrameStrata() == c:GetFrameStrata() and p:GetFrameLevel() > c:GetFrameLevel() and o:GetEffectiveAlpha() > 0.9 then
					out[#out + 1] = (o:GetTextureFilePath() or "?"):gsub(".*\\", "") .. "@level" .. p:GetFrameLevel()
				end
			end
		end
	end
	return out, c
end

test("r47 b2: first-open tips are drawn behind the app's sheet while the world map is open", function()
	-- control: no map, the card is over everything in the window
	do
		local w = T.newWorld()
		local r = T.rider(w, T.TESTCHAR)
		w:advance(15)
		r.W.UI.Toggle(true) w:advance(3)
		ok(#r:findText("Tip 1 of 5") > 0, "control: tip 1 shows")
		local over = coveringTextures(r)
		eq(#over, 0, "control: without the map nothing draws over the tip card, but: " .. table.concat(over, ","))
	end
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR)
	w:advance(15)
	w:openMap(r)
	r.W.UI.Toggle(true) w:advance(3)
	eq(r.env.WuberFrame:GetFrameStrata(), "FULLSCREEN_DIALOG", "control: the window rides above the open map")
	ok(#r:findText("Tip 1 of 5") > 0, "the tip card is built and shown")
	local over, c = coveringTextures(r)
	eq(#over, 0, "with the world map open the tip card (level " .. c:GetFrameLevel() .. ") is drawn behind " .. #over .. " opaque window textures: " .. table.concat(over, ", "))
	T.clean(w)
end)
