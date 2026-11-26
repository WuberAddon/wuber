-- Wuber 2.4 fix round 3, group D (LRN-06): a public chat line carrying a game link is never a lead, never an invite and never gets a reply whisper. Loaded by tests/run.lua with its helper table T.
local T = ...
local test, eq, ok = T.test, T.eq, T.ok

local function key(name) return (name:lower():gsub("[%s%-]+", " ")) end

local function openOrgDriver()
	local w = T.newWorld()
	local a = T.driver(w, T.ANITA, { spot = "Orgrimmar" })
	T.settle(w)
	local DR = a.W.Drive
	DR.opts().autoInvite = true
	DR.opts().watchPublic = true
	ok(DR.SetOpen(true), "driver open in Orgrimmar")
	w:advance(3)
	return w, a, DR, (a.player and a.player.faction) or "Horde"
end

local LINES = {
	"|cff9d9d9d|Hitem:12345::::::::60:::::|h[Portal Scroll: Orgrimmar]|h|r wtb summon to Orgrimmar pls",
	"WTB summon to Orgrimmar |cff71d5ff|Hspell:23161|h[Summon Dreadsteed]|h|r",
	"wtb summon to Orgrimmar pls |cffffff00|Hquest:123:60|h[A Quest]|h|r",
	"summon to Orgrimmar pls? |cffffd000|Hachievement:6:0:0:0:0:0:0:0:0:0|h[Level 10]|h|r",
	"WTB summon to Orgrimmar pls |cffffd000|Henchant:7418|h[Enchant Bracer]|h|r",
	"need a summon to Orgrimmar pls |cffffd000|Htrade:2259:1:1|h[Alchemy]|h|r",
}
local CONTROL = "WTB summon to Orgrimmar pls"

test("v24 f3 d: Careful ignores a public line with any game link, and still reads a whisper as before", function()
	local w, a, DR = openOrgDriver()
	local v0 = DR.Careful(CONTROL, "public", "Dan Miller")
	ok(v0 ~= "ignore", "control: the plain line is read (" .. tostring(v0) .. ")")
	for _, line in ipairs(LINES) do
		local v, why = DR.Careful(line, "public", "Dan Miller")
		eq(v, "ignore", "public ignored: " .. line)
		eq(why, "game link", "reason")
	end
	-- a link in a whisper to the driver is read as before (the link is only a part of the text)
	local wv, wwhy = DR.Careful(LINES[1], "whisper", "Dan Miller")
	ok(wv ~= "ignore" and wwhy ~= "game link", "whisper with a link is not dropped for the link")
	T.clean(w)
end)

test("v24 f3 d: the public reader makes no lead and no invite from a link line", function()
	local w, a, DR, faction = openOrgDriver()
	local inv0 = #w.invites
	for i, line in ipairs(LINES) do
		local name = "Linker" .. string.char(64 + i) .. " Test"
		w:addBot(name, { spot = "Ratchet", acceptsInvites = false, faction = faction })
		w:chatFrom(name, line, "CHANNEL", "Trade", faction)
		w:advance(0.5)
		ok(DR.customers[key(name)] == nil, "no lead for: " .. line)
	end
	eq(#w.invites, inv0, "nobody invited")
	-- control: the plain line becomes a lead or an invite
	w:addBot("Plain Buyer", { spot = "Ratchet", acceptsInvites = false, faction = faction })
	w:chatFrom("Plain Buyer", CONTROL, "CHANNEL", "Trade", faction)
	w:advance(0.5)
	ok(DR.customers[key("Plain Buyer")] ~= nil, "control: a plain line makes a row")
	T.clean(w)
end)

test("v24 f3 d: the auto-reply sends no whisper for a link line", function()
	local w, a, DR, faction = openOrgDriver()
	for i, line in ipairs(LINES) do
		local name = "Replier" .. string.char(64 + i) .. " Test"
		w:addBot(name, { spot = "Ratchet", acceptsInvites = false, faction = faction })
		w:chatFrom(name, line, "CHANNEL", "Trade", faction)
		w:advance(0.5)
		eq(#w:whispersTo(name, "reply"), 0, "no reply for: " .. line)
	end
	local okTry = DR.TryReply("Direct Test", LINES[1], "invite")
	ok(not okTry, "TryReply itself refuses a link line")
	w:addBot("Plain Buyer", { spot = "Ratchet", acceptsInvites = false, faction = faction })
	w:chatFrom("Plain Buyer", CONTROL, "CHANNEL", "Trade", faction)
	w:advance(0.5)
	eq(#w:whispersTo("Plain Buyer", "reply"), 1, "control: the plain line gets its one reply")
	T.clean(w)
end)

test("v24 f3 d: DR.PublicWant reads no buyer in a link line", function()
	local w, a, DR = openOrgDriver()
	for _, line in ipairs(LINES) do
		eq(DR.PublicWant(line), nil, "PublicWant: " .. line)
	end
	T.clean(w)
end)
