-- Design round 1, group I: the pictures. Six new glyphs in Wuber/Media; Settings home gives each section its own;
-- the Help headings carry no picture; "Get Wuber" / "Invite to Wuber" use the speech bubble, not the bell.
-- Loaded by tests/run.lua with its helper table T (the folder list near its end).
local T = ...
local test, eq, ok = T.test, T.eq, T.ok

local NEW = { "wheel", "question", "bug", "speaker", "phone_glyph", "chevron" }

local function texName(t)
	local p = t and t.GetTextureFilePath and t:GetTextureFilePath()
	return type(p) == "string" and (p:match("([^\\/]+)$") or p) or nil
end

-- every texture under a frame (children too)
local function walk(f, fn)
	if f.GetRegions then for _, r in ipairs({ f:GetRegions() }) do fn(r) end end
	if f.GetChildren then for _, c in ipairs({ f:GetChildren() }) do walk(c, fn) end end
end

test("d1 i: the six new glyphs are files in Wuber/Media and load as 64 px TGAs", function()
	for _, n in ipairs(NEW) do
		local f = io.open(T.dir .. "/../Wuber/Media/" .. n .. ".tga", "rb")
		ok(f, n .. ".tga exists")
		if f then
			local head = f:read(18)
			f:close()
			eq(#head, 18, n .. " has a TGA header")
			eq(head:byte(3), 2, n .. " is uncompressed true colour")
			eq(head:byte(13) + head:byte(14) * 256, 64, n .. " is 64 wide")
		end
	end
end)

test("d1 i: Settings home gives each section its own glyph, none the header's cog", function()
	local w = T.newWorld()
	local c = T.driver(w)
	T.settle(w)
	c.W.UI.OpenSettings()
	w:advance(1)
	local st = c.W.Mod("UI.Settings.Rows").st
	local cards = st.find and st.find.cards
	ok(cards and #cards >= 7, "the home lists its cards")
	local want = { driving = "wheel", sound = "speaker", window = "phone_glyph", help = "question", bug = "bug" }
	local seen, n = {}, 0
	for _, b in ipairs(cards) do
		local name = texName(b.icon)
		if want[b.key] then eq(name, want[b.key], b.key .. " row glyph") end
		ok(name ~= "gear", b.key .. " row does not use the cog")
		if name then seen[name] = (seen[name] or 0) + 1 end
		n = n + 1
	end
	for name, k in pairs(seen) do eq(k, 1, "the glyph " .. name .. " belongs to one row") end
	ok(n >= 7)
end)

test("d1 i: the Help headings carry no ring, bars or tick", function()
	local w = T.newWorld()
	local c = T.driver(w)
	T.settle(w)
	c.W.UI.OpenSettings()
	w:advance(1)
	c.W.UI.OpenHelp()
	w:advance(1)
	local help = c.W.Mod("UI.Settings.Panel")
	local hs = c.W.Mod("UI.Settings.Rows").st.help
	ok(hs and hs.cards and #hs.cards > 0, "the Help cards are built")
	for i, card in ipairs(hs.cards) do
		eq(card.icon, nil, "card " .. i .. " has no icon")
		walk(card, function(r)
			local name = texName(r)
			ok(not (name == "pulse" or name == "signal" or name == "check" or name == "star" or name == "pin"
				or name == "lock" or name == "bell"), "card " .. i .. " holds the glyph " .. tostring(name))
		end)
	end
end)

test("d1 i: Get Wuber and Invite to Wuber use the speech bubble, not the bell", function()
	local f = io.open(T.dir .. "/../Wuber/UI/Driver/Rows.lua", "rb")
	local rows = f:read("*a")
	f:close()
	ok(rows:find('T.Icon(b, "chat"', 1, true), "the Invite pill's glyph is the bubble")
	ok(not rows:find('"bell"', 1, true), "no bell left in the queue chips")
	f = io.open(T.dir .. "/../Wuber/UI/Driver/Customers.lua", "rb")
	local cust = f:read("*a")
	f:close()
	ok(cust:find('item("getapp", text, sub, "chat", "glow")', 1, true), "the row sheet's Send Get Wuber is the bubble")
end)
