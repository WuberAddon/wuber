-- Gate for docs/MODULE-GUIDE.md: every .lua file loaded by Wuber/Wuber.toc
-- must have an entry in docs/MODULE-GUIDE.md, and every Wuber/*.lua entry
-- named in docs/MODULE-GUIDE.md must exist in Wuber/Wuber.toc and on disk.
local T = ...
local test, ok = T.test, T.ok

local function readAll(path)
	local f = io.open(path, "rb")
	if not f then return nil end
	local s = f:read("*a")
	f:close()
	return s
end

test("docs/MODULE-GUIDE.md: matches Wuber/Wuber.toc", function()
	local root = T.dir .. "/.."
	local toc = readAll(root .. "/Wuber/Wuber.toc")
	ok(toc, "Wuber/Wuber.toc exists")
	local guide = readAll(root .. "/docs/MODULE-GUIDE.md")
	ok(guide, "docs/MODULE-GUIDE.md exists")
	if not toc or not guide then return end

	local tocList, tocSet = {}, {}
	for line in toc:gmatch("[^\r\n]+") do
		local trimmed = line:match("^%s*(.-)%s*$")
		if trimmed ~= "" and trimmed:sub(1, 1) ~= "#" then
			local rel = "Wuber/" .. trimmed:gsub("\\", "/")
			if rel:match("%.lua$") then
				tocList[#tocList + 1] = rel
				tocSet[rel] = true
			end
		end
	end

	local guideSet = {}
	for path in guide:gmatch("Wuber/[%w_./-]+%.lua") do
		guideSet[path] = true
	end

	local missing = {}
	for _, rel in ipairs(tocList) do
		if not guideSet[rel] then
			missing[#missing + 1] = rel
		end
	end

	local stale = {}
	for path in pairs(guideSet) do
		if not tocSet[path] then
			stale[#stale + 1] = path .. " (not in Wuber.toc)"
		elseif not readAll(root .. "/" .. path) then
			stale[#stale + 1] = path .. " (missing on disk)"
		end
	end
	table.sort(stale)

	ok(#tocList >= 100, "Wuber.toc lists at least 100 Lua files (got " .. #tocList .. ")")
	ok(#missing == 0, "every Wuber.toc Lua file has an entry in docs/MODULE-GUIDE.md; missing: " .. table.concat(missing, ", "))
	ok(#stale == 0, "every Wuber/*.lua entry in docs/MODULE-GUIDE.md exists in Wuber.toc and on disk; stale: " .. table.concat(stale, ", "))
end)
