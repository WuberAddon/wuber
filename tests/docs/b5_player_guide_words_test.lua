-- Gate for docs/PLAYER-GUIDE.md: every quoted button, tab, row, and label name
-- must exist in the addon's shipped text (excluding the 5 files being changed
-- by other open work, whose exclusive names are skipped and listed).
local T = ...
local test, ok = T.test, T.ok

local EXCLUDED = {
	["Wuber/Core/Words.lua"] = true,
	["Wuber/UI/Driver/Messages.lua"] = true,
	["Wuber/UI/Driver/Sheets.lua"] = true,
	["Wuber/Net/GroupFinder.lua"] = true,
	["Wuber/UI/Rider/Ride.lua"] = true,
}

-- Quotes in docs/PLAYER-GUIDE.md that are example player inputs or WoW client messages, not Wuber UI names.
local NON_UI_QUOTES = {
	["WTB summon to Orgrimmar, whisper me"] = true,
	["how do I turn off sounds?"] = true,
	["where is the minimap button?"] = true,
	["AddOn blocked"] = true,
	["from unknown"] = true,
}

-- Quoted examples of dynamically formatted Wuber strings -> the literal shipped fragment(s) that build them.
local DYNAMIC_FRAGMENTS = {
	["Ride again · <place> · <price>"] = { "Ride again · " },
	["Usually about 45 sec"] = { "Usually " },
	["n of m"] = { " of " },
	["continues by boat"] = { "continues by " },
	["continues by zeppelin"] = { "continues by " },
	["Advanced mode: on."] = { "Advanced mode: " },
	["Advanced mode: off."] = { "Advanced mode: " },
}

local function readAll(path)
	local f = io.open(path, "rb")
	if not f then return nil end
	local s = f:read("*a")
	f:close()
	return s
end

-- Strip Lua comments so comments in Wuber/ do not count as shipped text.
local function stripLuaComments(src)
	src = src:gsub("%-%-%[%[.-%]%]", "")
	local out = {}
	for line in (src .. "\n"):gmatch("(.-)\r?\n") do
		local i, n = 1, #line
		local inS, inD = false, false
		local cut = nil
		while i <= n do
			local c = line:sub(i, i)
			if c == "\\" then
				i = i + 2
			elseif c == "'" and not inD then
				inS = not inS
				i = i + 1
			elseif c == '"' and not inS then
				inD = not inD
				i = i + 1
			elseif c == "-" and not inS and not inD and line:sub(i, i + 1) == "--" then
				cut = i - 1
				break
			else
				i = i + 1
			end
		end
		out[#out + 1] = cut and line:sub(1, cut) or line
	end
	return table.concat(out, "\n")
end

local function loadShippedTexts(root)
	local toc = readAll(root .. "/Wuber/Wuber.toc")
	if not toc then return nil, nil end
	local otherParts, exclParts = {}, {}
	for line in toc:gmatch("[^\r\n]+") do
		local trimmed = line:match("^%s*(.-)%s*$")
		if trimmed ~= "" and trimmed:sub(1, 1) ~= "#" then
			local rel = "Wuber/" .. trimmed:gsub("\\", "/")
			local body = readAll(root .. "/" .. rel)
			if body and rel:match("%.lua$") then
				local code = stripLuaComments(body)
				if EXCLUDED[rel] then
					exclParts[#exclParts + 1] = code
				else
					otherParts[#otherParts + 1] = code
				end
			end
		end
	end
	return table.concat(otherParts, "\n"), table.concat(exclParts, "\n")
end

test("docs/PLAYER-GUIDE.md: every quoted UI name exists in shipped text", function()
	local root = T.dir .. "/.."
	local doc = readAll(root .. "/docs/PLAYER-GUIDE.md")
	ok(doc, "docs/PLAYER-GUIDE.md exists")
	local otherText, exclText = loadShippedTexts(root)
	ok(otherText and #otherText > 0, "loaded shipped Wuber Lua files")
	if not doc or not otherText then return end

	local skipped, skippedSeen = {}, {}
	local missing = {}
	local checked = 0
	local lineNo = 0
	for line in (doc .. "\n"):gmatch("(.-)\r?\n") do
		lineNo = lineNo + 1
		for q in line:gmatch('"([^"\n]+)"') do
			if not NON_UI_QUOTES[q] then
				checked = checked + 1
				local frags = DYNAMIC_FRAGMENTS[q] or { q }
				local foundOther, foundExcl = true, true
				for _, frag in ipairs(frags) do
					if not otherText:find(frag, 1, true) then
						foundOther = false
					end
					if not exclText:find(frag, 1, true) then
						foundExcl = false
					end
				end
				if not foundOther then
					if foundExcl then
						if not skippedSeen[q] then
							skippedSeen[q] = true
							skipped[#skipped + 1] = q
						end
					else
						missing[#missing + 1] = string.format("L%d: %q", lineNo, q)
					end
				end
			end
		end
	end

	print("PLAYER-GUIDE skipped (excluded files only): " .. (#skipped > 0 and table.concat(skipped, ", ") or "(none)"))
	ok(checked >= 50, "checked at least 50 quoted UI names (got " .. checked .. ")")
	ok(#missing == 0, "all quoted UI names found in shipped text; missing: " .. table.concat(missing, "; "))
end)
