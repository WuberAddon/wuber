-- tests/autodiscover/folders_test.lua: run.lua finds the test folders itself (no folder list to edit).
-- This file is in a folder no list names, so that it runs at all proves a new folder is found.
local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H

local function foldersOnDisk()
	local out = {}
	for _, path in ipairs(H.listFiles(T.dir)) do out[#out + 1] = path:match("([^/\\]+)$") end
	return out
end

test("run.lua finds every test folder by itself: sorted, a folder nobody listed is run, none is both found and loaded by name", function()
	local auto = H.autoFolders
	ok(type(auto) == "table" and #auto > 40, "run.lua found the folders (" .. tostring(auto and #auto) .. ")")
	local set = {}
	for i, name in ipairs(auto) do
		set[name] = true
		if i > 1 then ok(auto[i - 1] < name, "sorted by name: " .. auto[i - 1] .. " before " .. name) end
		ok(not H.notAutoFolders[name], name .. " is found AND skipped as loaded by name")
	end
	ok(set.autodiscover, "this folder (autodiscover), in no list, was found")
	for _, name in ipairs({ "r27", "r54", "winners", "lab", "gf" }) do ok(set[name], "the old list's folder " .. name .. " is found") end
	for _, name in ipairs(foldersOnDisk()) do
		if not name:find("^[._]") and not name:find("%.") and not H.notAutoFolders[name] then
			ok(set[name], "tests/" .. name .. " exists and is neither found nor skipped by name")
		end
	end
end)
