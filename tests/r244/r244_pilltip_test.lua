local T = ...
local test, ok = T.test, T.ok
local root = T.dir .. "/.."
-- Retire card (Wuber/UI/Driver/Sheets.lua): since #230/#231 the pill switches the old addon off and the player types /reload.
-- The maintainer approved (26 Nov 2026, card 2) the tooltip "...and asks you to type /reload to finish"; the label stays.

local function sheets()
	local f = assert(io.open(root .. "/Wuber/UI/Driver/Sheets.lua", "rb"))
	local src = f:read("*a")
	f:close()
	return src
end

test("retire pill tooltip no longer promises to reload the interface, it says the player types /reload", function()
	local src = sheets()
	ok(not src:find("reloads your interface", 1, true), "the tooltip still says it reloads your interface")
	ok(src:find("Turns your old summoning addon off and asks you to type /reload to finish. Wuber then drives with everything it had.", 1, true), "the approved tooltip words are there")
end)

-- guard: the label was kept on purpose (card 2: change only the tooltip)
test("retire pill label is unchanged: Switch it off and reload", function()
	ok(sheets():find('T.Pill(card, "Switch it off and reload"', 1, true), "the pill label is kept")
end)
