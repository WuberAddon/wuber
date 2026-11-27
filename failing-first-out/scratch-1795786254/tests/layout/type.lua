-- The type rule of the layout sweep (design round 3): every text that shows in a Wuber frame is drawn at one of the
-- seven sizes of T.SCALE and in one of the files of T.FONTS. A text drawn at any other size (a raw fs:SetFont(path, 13)),
-- or in another font file (the game's own Arial, Friz Quadrata), is a layout hit of kind "type" (key "type"), named by
-- the shot, the text and what was found. tests/layout/allow.lua can allow it (reason = ...) or list it (known = ...).
-- E.check (tests/layout/engine.lua) lists the font of every text that shows (its 4th result); tests/layout/run.lua
-- judges the list here, as it does the word rule (tests/layout/words.lua).
local Type = {}

-- The sizes and files the theme allows, from a client's Wuber: { sizes = { [px] = true }, files = { [path] = true } },
-- or nil when that client has no theme (a made-up screen with no addon: the caller passes its own).
function Type.allowed(c)
	local W = type(c) == "table" and c.W
	local T = type(W) == "table" and W.Theme
	if type(T) ~= "table" or type(T.FONTS) ~= "table" then return nil end
	local out = { sizes = {}, files = {} }
	-- (a tree from before the scale, T.SCALE missing, is judged by the same seven)
	for _, px in ipairs(type(T.SCALE) == "table" and T.SCALE or { 11, 12, 14, 17, 22, 28, 40 }) do out.sizes[px] = true end
	for _, path in pairs(T.FONTS) do out.files[tostring(path):gsub("/", "\\"):lower()] = true end
	return out
end

-- fonts: { { text, path, size }, ... } (one per text that shows; path and size nil when no font was set);
-- returns the hits: { kind = "type", what, detail, key }
function Type.judge(fonts, allowed)
	local hits, seen = {}, {}
	if not allowed then return hits end
	for _, f in ipairs(fonts or {}) do
		local text = tostring(f.text or ""):gsub("%s+", " ")
		if #text > 40 then text = text:sub(1, 37) .. "..." end
		local why
		if f.size == nil or f.path == nil then
			why = "no font set"
		elseif not allowed.sizes[f.size] then
			why = ("drawn at size %s, not one of the seven"):format(tostring(f.size))
		elseif not allowed.files[tostring(f.path):gsub("/", "\\"):lower()] then
			why = ("drawn in %s, not a theme font"):format(tostring(f.path))
		end
		if why then
			local key = "type " .. text .. " " .. tostring(f.size) .. " " .. tostring(f.path)
			if not seen[key] then
				seen[key] = true
				hits[#hits + 1] = { kind = "type", what = '"' .. text .. '"', detail = why, key = key }
			end
		end
	end
	return hits
end

return Type
