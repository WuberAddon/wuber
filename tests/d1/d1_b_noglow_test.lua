-- Design round 1, group B: nothing inside the phone window draws a glow. The glow picture (Media\glow), the shimmer
-- that swept across a driver card and the glowing outline picture (Media\edge) are never SHOWN with alpha above 0 on a
-- region under the Wuber window, the login tip card or the What's new card (the handset's own shadow, the map
-- pins on the game's map, the driver's big button banner and the floating button are not this test's).
local T = ...
local H, test, eq, ok = T.H, T.test, T.eq, T.ok
local S = H.state

local BAD = { glow = true, shimmer = true, edge = true }

local function fileOf(t)
	local ok2, p = pcall(t.GetTextureFilePath, t)
	if not ok2 or type(p) ~= "string" then return nil end
	return (p:match("([^\\/]+)$") or p):gsub("%.%w+$", "")
end

-- map pins sit on the picture of the game's map (item 18), the driver's big button banner is item 19: not here
-- (the slider knob's halo is in Theme/Widgets.lua, the handset's own aura is the window's own regions: group A and Phone.lua)
local function skip(path, name)
	if path:find("/dots/", 1, true) then return true end
	if path == "/WuberFrame" and name == "edge" then return true end
	if path:match("/top$") then return true end
	return false
end

local function keyOf(parent, obj)
	if type(parent) == "table" then
		for k, v in pairs(parent) do if v == obj and type(k) == "string" then return k end end
	end
	return "?"
end

local function found(root, out, seen, path)
	if type(root) ~= "table" or seen[root] then return end
	seen[root] = true
	local nm = root.GetName and root:GetName()
	path = path .. "/" .. tostring(nm or keyOf(root.GetParent and root:GetParent(), root))
	for _, r in ipairs({ root:GetRegions() }) do
		if r.GetObjectType and r:GetObjectType() == "Texture" and r:IsShown() then
			local name = fileOf(r)
			local a = r.GetAlpha and r:GetAlpha() or 1
			local _, _, _, va = r:GetVertexColor()
			if name and BAD[name] and a > 0 and (va == nil or va > 0) and not skip(path, name) then
				out[#out + 1] = name .. " " .. keyOf(root, r) .. " under " .. path .. " (" .. tostring(S[r] and S[r].layer) .. ")"
			end
		end
	end
	for _, c in ipairs({ root:GetChildren() }) do found(c, out, seen, path) end
end

local function scan(c, extra)
	local out, seen = {}, {}
	found(c.env.WuberFrame, out, seen, "")
	for _, f in ipairs(extra or {}) do found(f, out, seen, "") end
	return out
end

test("d1 b: the rider's phone draws no glow, shine or glowing outline", function()
	local w = T.newWorld()
	local c = T.rider(w, T.TESTCHAR, { saved = { Wuber = { coach = true } } })
	w:advance(2)
	local W = c.W
	W.UI.Toggle(true)
	w:advance(5)
	local Tips = W.Mod("UI.Tips")
	pcall(Tips.ShowNow)
	w:advance(2)
	local extra = { Tips.Card and Tips.Card() or nil }
	local WN = W.Mod("UI.WhatsNew")
	if WN.Show then pcall(WN.Show) end
	extra[#extra + 1] = WN.Card and WN.Card() or nil
	local out = scan(c, extra)
	ok(#out == 0, #out .. " glow textures shown:\n  " .. table.concat(out, "\n  "))
	T.clean(w)
end)

test("d1 b: the driver's phone draws no glow, shine or glowing outline", function()
	local w = T.newWorld()
	local d = T.driver(w, T.TESTCHAR)
	w:advance(2)
	T.openDrive(d)
	w:advance(3)
	local out = scan(d)
	ok(#out == 0, #out .. " glow textures shown:\n  " .. table.concat(out, "\n  "))
	T.clean(w)
end)
