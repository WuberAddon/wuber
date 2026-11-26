-- Help-text claims (job 2886): player text that did not match the code, corrected.
-- Each entry: file, words that must be gone, words that must be there.
local T = ...
local test, eq, ok = T.test, T.eq, T.ok

local function read(rel)
	local f = assert(io.open(T.dir .. "/../" .. rel, "rb"))
	local s = f:read("*a")
	f:close()
	return s
end

local FIX = {
	{ "Wuber/UI/Settings/Pages.lua",
		{ [[every Wuber nearby hears them]], [[It reaches every layer and every copy of the world.]], [[Nobody can fake a driver or a price.]] },
		{ [[every Wuber on your realm hears them]], [[It reaches every Wuber on your realm.]], [[A driver's price comes only from that driver's own character.]] } },
	{ "Wuber/UI/Coach.lua",
		{ [[Cheaper drivers glow brighter. ]], [[then Request.]], [[Settings > Replay tips shows them again]] },
		{ [[Click a card to see the fare, then Request summon.]], [[Settings > Riding > Tips > Replay shows them again]] } },
	{ "Wuber/UI/TipTexts.lua",
		{ [[look for the \"Skip the bird\" card]], [[in Drive setup.]] },
		{ [[look for the card that says \"Summon]], [[in Set up driving.]] } },
	{ "Wuber/UI/Settings/Panel.lua",
		{ [["Right-click a driver's card to hide them.]] },
		{ [["In Advanced mode, right-click a driver's card to hide them.]] } },
	{ "Wuber/UI/Commands.lua",
		{ [[Asked drivers to check in.]], [[You're not on the network yet, so riders can't see you.]] },
		{ [[Drivers have been asked to check in.]], [[You're not on the Wuber network yet, so riders can't see you unless your community is joined.]] } },
	{ "Wuber/UI/Settings/Rows.lua",
		{ [[falls back to the chat box if the game refuses]], [[Fit window sizes it for small multibox windows.]], [[good for small multibox windows]], [[nobody is in your list]] },
		{ [[falls back to the chat box if your whispers do not go through]], [[Fit window sizes it for small screens.]], [[good for small screens]], [[whether or not anyone is in your list]] } },
	{ "Wuber/UI/Settings/Find.lua",
		{ [[Other players' names are left out]] },
		{ [[Other players' names become \"player 1\", \"player 2\"]] } },
	{ "Wuber/UI/Driver/Wizard.lua",
		{ [[They tap Yes or No.]] },
		{ [[They tap Yes or No thanks.]] } },
}

test("help text claims: corrected words are in, the wrong words are gone", function()
	for _, f in ipairs(FIX) do
		local src = read(f[1])
		for _, old in ipairs(f[2]) do
			ok(not src:find(old, 1, true), f[1] .. " still says: " .. old)
		end
		for _, new in ipairs(f[3]) do
			ok(src:find(new, 1, true), f[1] .. " lacks: " .. new)
		end
	end
end)

test("help text claims: the Help cards and tip texts carry the corrected claims", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR)
	w:advance(15)
	local UI = r.W.UI
	eq(UI.HELP[1].text, "Wuber is a radio network. Drivers call out; every Wuber on your realm hears them.", "card 1")
	eq(UI.HELP[2].text, "It reaches every Wuber on your realm.", "card 2")
	ok(UI.HELP[3].text:find("A driver's price comes only from that driver's own character.", 1, true), "card 3")
	for _, t in ipairs(r.W.Mod("UI.TipTexts").list) do
		ok(not t.text:find("Drive setup", 1, true), "no Drive setup in " .. t.id)
		ok(not t.text:find("Skip the bird", 1, true), "no Skip the bird in " .. t.id)
	end
end)
