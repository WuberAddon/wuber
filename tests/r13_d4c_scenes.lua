-- Issue 13: the three ride scenes of tests/layout/d4_c_screens.lua (d4c_ride_tabs, d4c_ride_pay,
-- d4c_ride_stranger) must be produced by the layout tour, not skipped because the tab bar was still gliding away
-- when the scene's setup ran. Runs the layout checker as a child on one window size. Run by tests/run.lua;
-- lua tests/run.lua "r13 d4c scenes"
local T = ...
local test, eq, ok = T.test, T.eq, T.ok
local root = T.dir .. "/.."
local lua = (arg and arg[-1]) or "lua5.1"

test("r13 d4c scenes: the three ride scenes are shot, none skipped for the tab bar", function()
	local cmd = ('"%s" "%s/tools/layout-check.lua" --screen d4c_ride_tabs,d4c_ride_pay,d4c_ride_stranger --config 1920x1080@1 2>&1'):format(lua, root):gsub("\\", "/")
	if package.config:sub(1, 1) == "\\" then cmd = '"' .. cmd .. '"' end -- cmd.exe only; sh takes the line as it is
	local p = assert(io.popen(cmd, "r"))
	local out = p:read("*a")
	p:close()
	ok(out:find("layout-check:", 1, true), "the layout checker ran: " .. out:sub(1, 200) .. " via " .. lua)
	ok(not out:find("the tour skipped", 1, true), "a ride scene was skipped: " .. (out:match("[^\n]*the tour skipped[^\n]*") or ""))
	ok(not out:find("no shot of", 1, true), "a ride scene has no shot: " .. (out:match("[^\n]*no shot of[^\n]*") or ""))
	ok(out:find(", 3 shots,", 1, true), "three shots")
end)
