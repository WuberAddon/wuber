-- Tests of tools/checklist.lua (round 15, agent E): the short real-game release checklist, made from
-- the files that changed. Loaded by tests/run.lua with its helper table T.
local T = ...
local test, eq, ok = T.test, T.eq, T.ok

local CL = assert(loadfile(T.dir .. "/../tools/checklist.lua"))("--lib")

local function changes(list)
	local out = {}
	for _, s in ipairs(list) do
		local st, path = s:match("^(%u) (.+)$")
		out[#out + 1] = { status = st, path = path }
	end
	return out
end

local function has(items, text)
	for _, it in ipairs(items) do if it:find(text, 1, true) then return true end end
	return false
end

test("tools/checklist.lua: always the trade, the portal click, taint.log, the photo tour and the passive lab; tests and docs add nothing", function()
	local md, items = CL.build(changes({ "M tests/run.lua", "M tools/check.lua", "A notes15/e.md" }),
		{ version = "2.3.2", from = "1c0fa02", to = "abc1234" })
	eq(#items, 5, "the five every release needs")
	ok(has(items, "/console taintLog 1"), "taint.log on")
	ok(has(items, "_forever_\\Logs\\taint.log"), "where the file is")
	ok(has(items, "tools/taint.lua"), "and the tool that reads it")
	ok(has(items, "no \"blocked\" popup"), "no blocked popup")
	ok(has(items, "/lab passive on") and has(items, "/lab passive status"), "the passive lab, both commands")
	ok(has(items, "A real trade"), "a trade")
	ok(has(items, "types the gold themselves"), "the player pays, never Wuber")
	ok(has(items, "A real portal click"), "a portal click")
	ok(has(items, "Start photo tour") and has(items, "/lab tour"), "the photo tour")
	ok(md:find("# Release checklist: Wuber 2.3.2 (1c0fa02..abc1234)", 1, true), md)
	ok(md:find("Changed in Wuber: 0 files.", 1, true), md)
	ok(not md:find("Quit the game", 1, true), "no restart without a new file")
	ok(not md:find("WuberLab", 1, true), "the lab by its short name only")
end)

test("tools/checklist.lua: changed modules pick their quick looks; a new or removed file asks for a game restart", function()
	local _, items = CL.build(changes({ "M Wuber/FX/Nameplates.lua", "M Wuber/UI/Rider/Confirm.lua", "A Wuber/FX/Emblem.lua",
		"M Wuber/Wuber.toc", "M Wuber/Theme/Tokens.lua" }), {})
	eq(items[1]:find("Quit the game and start it again", 1, true) ~= nil, true, "the restart first: " .. items[1])
	ok(has(items, "Pioneer's"), "nameplates changed: look at a Pioneer's nameplate")
	ok(has(items, "Open Confirm folded and unfolded"), "Confirm changed")
	eq(#items, 8, "restart, five always, two looks (Nameplates and Emblem share one)")
	local md = CL.build(changes({ "M Wuber/Theme/Tokens.lua" }), {})
	ok(md:find("covered by the tour and the passive lab only: Theme.Tokens", 1, true), md)
	eq(CL.modOf("Wuber/UI/Rider/Confirm.lua"), "UI.Rider.Confirm", "a module is its path with dots")
	eq(CL.modOf("Wuber\\Drive\\Trade.lua"), "Drive.Trade")
	eq(CL.modOf("tests/run.lua"), nil)
	eq(#changes({ "D Wuber/UI/Old.lua" }), 1)
	local _, gone = CL.build(changes({ "D Wuber/UI/Old.lua" }), {})
	ok(has(gone, "Quit the game"), "a removed file too")
end)

test("tools/checklist.lua: never more than 12 items (10 minutes); the rest join one 'also changed' line", function()
	local all = {}
	for _, m in ipairs({ "FX/Nameplates", "UI/Rider/Confirm", "UI/Fold", "UI/Secure", "Core/Flights", "UI/Map/Pins",
		"UI/Rider/Home", "UI/Driver/Rows", "Drive/Chat", "Drive/Raid", "Drive/Danger", "UI/Rider/Done", "UI/Settings/Panel",
		"Net/Community", "Net/Base", "UI/Commands", "UI/Minimap", "UI/Phone", "Core/Runtime" }) do
		all[#all + 1] = "M Wuber/" .. m .. ".lua"
	end
	all[#all + 1] = "A Wuber/Media/pioneer.tga"
	local _, items = CL.build(changes(all), {})
	eq(#items, CL.MAX, "capped")
	ok(items[#items]:find("^Also changed, a quick look if time allows: "), items[#items])
	ok(items[#items]:find("Core.Runtime", 1, true) and items[#items]:find("Wuber/Media/pioneer.tga", 1, true), items[#items])
	ok(has(items, "Pioneer's"), "the first rules win the room")
	-- exactly enough looks: no 'also changed' line
	local few = {}
	for i = 1, 6 do few[#few + 1] = all[i] end
	local _, six = CL.build(changes(few), {})
	eq(#six, 11, "five always and six looks")
	ok(not six[#six]:find("Also changed", 1, true), six[#six])
end)

test("tools/checklist.lua: git diff --name-status lines (renames off) become changes", function()
	local ch = CL.parseStatus("M\tWuber/UI/Fold.lua\r\nA\tWuber/FX/Emblem.lua\nD\tWuber/UI/Old.lua\n")
	eq(#ch, 3)
	eq(ch[2].status .. " " .. ch[2].path, "A Wuber/FX/Emblem.lua")
end)

test("tools/checklist.lua: --max 8 keeps it to about 5 minutes (8 items, the rest on the 'also changed' line)", function()
	local all = {}
	for _, m in ipairs({ "UI/Rider/Confirm", "UI/Fold", "UI/Secure", "UI/Rider/Home", "UI/Driver/Rows", "Drive/Raid",
		"Drive/Danger", "UI/Settings/Panel", "Net/Rides" }) do
		all[#all + 1] = "M Wuber/" .. m .. ".lua"
	end
	local md, items = CL.build(changes(all), { max = 8 })
	eq(#items, 8, "capped at 8")
	ok(items[#items]:find("^Also changed, a quick look if time allows: "), items[#items])
	ok(md:find("about 5 minutes", 1, true), "says 5 minutes")
	local md12 = CL.build(changes(all), {})
	ok(md12:find("about 10 minutes", 1, true), "the default still says 10")
end)
