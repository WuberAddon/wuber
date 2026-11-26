-- Lab: no addon code under lab/WuberLab calls ReloadUI (a reload can only come from a click).
-- 26 Nov taint.log: "action blocked because of taint from WuberLabBar - Reload()". GameFacts2.lua fetched ReloadUI with
-- gfn("ReloadUI") and called it with pcall; the game blocks that. The Lab bar's Reload is a secure button instead.
-- A static scan of the Lab's files (comments left out). Wuber Lab is never shipped.
local T = ...
local H, test, ok = T.H, T.test, T.ok

local LAB_DIR = os.getenv("WUBER_LAB_DIR") or (H.root .. "/lab/WuberLab")
local files = H.listFiles(LAB_DIR, "lua")
if #files == 0 then
	test("lab no ReloadUI: the Lab folder not found (skipped)", function() end)
	return
end

test("lab no ReloadUI: no file in lab/WuberLab calls or fetches ReloadUI", function()
	ok(#files > 3, "found the Lab files")
	local bad = {}
	for _, path in ipairs(files) do
		local f = io.open(path, "rb")
		if f then
			local src = f:read("*a")
			f:close()
			local n = 0
			for line in (src .. "\n"):gmatch("([^\n]*)\n") do
				n = n + 1
				line = line:gsub("%-%-.*$", "")
				if line:find("ReloadUI", 1, true) or line:find("C_UI.Reload", 1, true) then
					bad[#bad + 1] = path:match("[^/]+$") .. ":" .. n
				end
			end
		end
	end
	ok(#bad == 0, "ReloadUI used from addon code at " .. table.concat(bad, ", "))
end)
