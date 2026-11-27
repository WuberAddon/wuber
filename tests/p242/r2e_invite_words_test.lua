-- p242 round 2, group E, DS24-04: the words on "Invite public chat riders" (the settings row, its tooltip and the
-- /wuber drive market line) said "Trade and LookingForGroup only", but an auto-invite comes from any channel in
-- the player's watchChannels list (default: services, trade, lookingforgroup, world, general; Drive/Queue.lua market()).
-- Promise: the words say it is the public chat channels you read (the "Chat channels" list), and name no fixed pair.
local T = ...
local test, eq, ok = T.test, T.eq, T.ok

local function rowTexts(d, w)
	d.W.db.coach = true
	d.W.UI.Toggle(true)
	w:advance(3)
	d.W.UI.OpenSettings("driving")
	w:advance(1)
	local t = d.W.UI.settings.controls["drive.autoPublic"]
	local row = t.row
	local tip = row.wuberTip or t.wuberTip
	local body = tip and (type(tip.text) == "function" and tip.text(row) or tip.text) or ""
	return row.desc:GetText() or "", body
end

test("DS24-04: the invite-public-buyers words match the channels the code really invites from", function()
	local w = T.newWorld()
	local d = T.driver(w, T.BOB)
	T.settle(w)
	local DR = d.W.Drive
	-- what the code does: every default watched channel is a market
	for _, ch in ipairs({ "Services - City", "Trade - City", "LookingForGroup", "World", "General - Orgrimmar" }) do
		ok(DR.Market(ch), "an auto-invite can come from " .. ch)
	end
	ok(not DR.Market("Guild"), "a channel that is not watched never invites")
	-- what the words say
	local desc, tip = rowTexts(d, w)
	ok(desc:find("not whispers", 1, true), "still says not whispers: " .. desc)
	for _, s in ipairs({ desc, tip }) do
		ok(not s:find("Trade and LookingForGroup", 1, true) and not s:find("Trade or LookingForGroup", 1, true),
			"names no fixed pair of channels: " .. s)
	end
	ok(desc:find("channels you read", 1, true), "the line points at the channels you read: " .. desc)
	ok(tip:find("channels you read", 1, true), "so does the tooltip: " .. tip)
	-- the /wuber drive market line
	local seen = {}
	for _, c in ipairs({ "market" }) do d:slash("/wuber drive " .. c) end
	w:advance(1)
	local blob = table.concat(d.chatLines or {}, "\n")
	ok(not blob:find("Inviting Trade and LookingForGroup", 1, true), "the command line names no fixed pair: " .. blob)
	ok(blob:find("channels you read", 1, true), "the command line points at the channels you read: " .. blob)
	T.clean(w)
end)

-- guard: a channel outside the list never invites, so "channels you read" is the exact rule
test("DS24-04 guard: narrowing the Chat channels list narrows where auto-invites come from", function()
	local w = T.newWorld()
	local d = T.driver(w, T.BOB)
	T.settle(w)
	d.W.Drive.opts().watchChannels = "trade"
	ok(d.W.Drive.Market("Trade - City"), "trade still read")
	ok(not d.W.Drive.Market("World"), "world no longer read")
	T.clean(w)
end)
