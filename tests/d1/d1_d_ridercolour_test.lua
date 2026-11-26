-- Design round 1 group D: gold only for prices and the one main button on the rider screens. A caption, a count or a
-- fact is grey, what is chosen is violet (words on it ink), a warning is red. Colours only.
local T = ...
local test, eq, ok = T.test, T.eq, T.ok

local function same(a, b)
	return math.abs((a or 0) - (b or 0)) < 0.005
end
-- every FontString and texture under the game's UIParent, found by walking the frame tree
local function walk(root, fn, seen)
	seen = seen or {}
	if seen[root] then return end
	seen[root] = true
	fn(root)
	if root.GetRegions then for _, r in ipairs({ root:GetRegions() }) do fn(r) end end
	if root.GetChildren then for _, ch in ipairs({ root:GetChildren() }) do walk(ch, fn, seen) end end
end
local function texts(c, want)
	local out = {}
	walk(c.env.UIParent, function(r)
		if r.GetText and r.GetTextColor then
			local ok2, t = pcall(r.GetText, r)
			if ok2 and t == want then out[#out + 1] = r end
		end
	end)
	return out
end

local function world()
	local w = T.newWorld()
	local c = T.rider(w, T.TESTCHAR)
	T.settle(w)
	c.W.UI.Toggle(true)
	w:advance(2)
	return w, c
end
local function colourIs(c, fs, name)
	local R, G, B = c.W.Theme.RGB(name)
	local r, g, b = fs:GetTextColor()
	return same(r, R) and same(g, G) and same(b, B)
end

test("d1 d: the Your usual caption is grey, not gold", function()
	local w, c = world()
	local fs = texts(c, "Your usual")
	ok(#fs > 0, "the caption exists")
	for _, f in ipairs(fs) do
		ok(colourIs(c, f, "muted"), "caption is muted")
		ok(not colourIs(c, f, "gold"), "caption is not gold")
	end
	T.clean(w)
end)

-- a texture or text colour equals a token
local function isTex(c, tex, name)
	local R, G, B = c.W.Theme.RGB(name)
	local r, g, b = tex:GetVertexColor()
	return same(r, R) and same(g, G) and same(b, B)
end

test("d1 d: the Done screen's stars are violet, never gold", function()
	local w, c = world()
	local Done = c.W.Mod("UI.Rider.Done")
	local found = 0
	walk(c.env.UIParent, function(r)
		if r.GetTextureFilePath and r.GetVertexColor then
			local ok2, tx = pcall(r.GetTextureFilePath, r)
			if ok2 and type(tx) == "string" and tx:find("star") and not tx:find("outline") and r:GetWidth() == 34 then
				found = found + 1
				ok(isTex(c, r, "glow"), "a rating star is violet")
				ok(not isTex(c, r, "gold"), "a rating star is not gold")
			end
		end
	end)
	ok(found >= 5, "five rating stars found: " .. found)
	T.clean(w)
end)

test("d1 d: a tip key chosen is violet with ink words; the others stay panel with white words", function()
	local w, c = world()
	local keys = {}
	walk(c.env.UIParent, function(r)
		if r.Paint and r.bg and r.top then keys[#keys + 1] = r end
	end)
	ok(#keys >= 4, "tip keys found: " .. #keys)
	local k = keys[1]
	k:Paint("10%", "about 1s", true)
	ok(colourIs(c, k.top, "ink"), "chosen words are ink")
	ok(colourIs(c, k.bottom, "ink"), "chosen second line is ink")
	local R, G, B = c.W.Theme.RGB("glow")
	eq(k.bg.colour, "glow", "chosen key fill is the violet token")
	eq(k.edge.colour, "glow", "chosen key edge is violet")
	k:Paint("10%", "about 1s", false)
	eq(k.bg.colour, "panel", "unchosen key fill is panel")
	ok(colourIs(c, k.top, "white"), "unchosen words are white")
	T.clean(w)
end)
