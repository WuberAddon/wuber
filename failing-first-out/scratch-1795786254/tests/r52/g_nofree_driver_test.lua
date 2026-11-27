-- r52 group G (33 words F01-F18): no player string in these files calls a ride or summon free; each says the new words.
local T = ...
local test, ok = T.test, T.ok

local function read(p)
	local f = assert(io.open(T.dir .. "/../" .. p, "rb"))
	local s = f:read("*a")
	f:close()
	return s
end

local SWAPS = {
	{ "Wuber/Drive/Commands.lua", "Raid summons: raiders who say 123 in raid chat are summoned, free.", "Raid summons: raiders who say 123 in raid chat are summoned at no charge.", 1 },
	{ "Wuber/Net/Rides.lua", "This ride is free.", "This ride costs nothing, so there is nothing to pay.", 1 },
	{ "Wuber/UI/Driver/Build.lua", "Free for your raid", "No charge for your raid", 1 },
	{ "Wuber/UI/Driver/Build.lua", "one by one. Free, no adverts, no invites.", "one by one. No charge, no adverts, no invites.", 1 },
	{ "Wuber/UI/Driver/Build.lua", "Free summons for your own raid: raiders", "Summons at no charge for your own raid: raiders", 1 },
	{ "Wuber/UI/Driver/Build.lua", "Free raid summons for your own raid too", "Raid summons at no charge for your own raid too", 1 },
	{ "Wuber/UI/Driver/Customers.lua", "You gave them a free ride on", "You gave them a ride as a gift on", 2 },
	{ "Wuber/UI/Driver/Customers.lua", "Click when you give this rider a free ride:", "Click when you give this rider a ride as a gift:", 2 },
	{ "Wuber/UI/Driver/Customers.lua", ": you gave them a free ride.", ": you gave them a ride as a gift.", 2 },
	{ "Wuber/UI/Driver/Draw.lua", "Free|r", "No charge|r", 1 },
	{ "Wuber/UI/Driver/Earnings.lua", "One free summon later, given instead", "One summon later at no charge, given instead", 1 },
	{ "Wuber/UI/Driver/Mini.lua", "next raider. Free, for your own raid", "next raider. No charge, for your own raid", 1 },
	{ "Wuber/UI/Driver/Mini.lua", "one free summon later. It counts", "one summon later at no charge. It counts", 1 },
	{ "Wuber/UI/Driver/Sheets.lua", "One free summon later from your crew", "One summon later at no charge from your crew", 1 },
	{ "Wuber/UI/Driver/Sheets.lua", "Raid summon · free", "Raid summon · no charge", 1 },
}

test("r52 g: the 18 'free' strings in the driver files read as the 33-words replacements", function()
	for _, s in ipairs(SWAPS) do
		local src = read(s[1])
		ok(not src:find(s[2], 1, true), s[1] .. " still has: " .. s[2])
		local n, from = 0, 1
		while true do
			local a, b = src:find(s[3], from, true)
			if not a then break end
			n, from = n + 1, b + 1
		end
		ok(n == s[4], s[1] .. " has " .. n .. " of (want " .. s[4] .. "): " .. s[3])
	end
end)
