-- Tests of the Settings split (issue 8): UI.Settings.Panel stays under check.lua's 1,500-line warning, and the
-- parts moved to UI.Settings.Pages are reached the same way as before. Loaded by tests/run.lua with its helper table T.
local T = ...
local test, eq, ok = T.test, T.eq, T.ok

local function lineCount(path)
	local f = io.open(path, "rb")
	if not f then return nil end
	local n = 0
	for _ in f:lines() do n = n + 1 end
	f:close()
	return n
end

test("settings panel: Panel.lua is under the 1,500-line warning", function()
	local n = lineCount("Wuber/UI/Settings/Panel.lua")
	ok(n ~= nil, "Panel.lua is found from the repository root")
	ok(n and n < 1500, "Panel.lua has " .. tostring(n) .. " lines, the warning is at 1,500")
end)

test("settings panel: the pages frame and the section moves are on UI.Settings.Pages, Panel keeps its names", function()
	local W, w = T.contract("UI.Settings.Pages", "tests/ui/settings/pages_test.lua", {
		["UI.HELP_TITLE"] = "string", ["UI.HELP"] = "table", ["UI.HELP_FOOTER"] = "string",
		["Mod.pagesOf"] = "function", ["Mod.mayTravel"] = "function", ["Mod.coverTab"] = "function",
		["Mod.coverSoon"] = "function", ["Mod.panelMove"] = "function", ["Mod.sectionMove"] = "function",
		["Mod.SECTIONS"] = "table", ["Mod.sectionRanges"] = "function",
	})
	local Pages, Panel = W.Mod("UI.Settings.Pages"), W.Mod("UI.Settings.Panel")
	eq(Panel.sectionMove, Pages.sectionMove, "Panel.sectionMove is the same function")
	eq(Panel.SECTIONS, Pages.SECTIONS, "Panel.SECTIONS is the same table")
	eq(Panel.sectionRanges, Pages.sectionRanges, "Panel.sectionRanges is the same function")
	T.clean(w)
end)
