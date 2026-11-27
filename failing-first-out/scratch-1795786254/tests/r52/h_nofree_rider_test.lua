-- r52 H: the author's 24 Nov 07:25 decision: no rider screen calls a ride or summon "free" (33-words page, "change").
-- Each file is read and the old words must be gone and the new words present.
local T = ...
local test, ok = T.test, T.ok
local function read(p)
	local f = io.open(p, "rb") or io.open("../" .. p, "rb")
	local s = f and f:read("*a") or ""
	if f then f:close() end
	return s
end
local function has(s, w) return s:find(w, 1, true) ~= nil end
local ITEMS = {
	{ "Wuber/UI/Moments.lua", "from this crew is free, up to", "from this crew costs nothing, up to the amount shown." },
	{ "Wuber/UI/Moments.lua", '"One free summon"', '"One summon at no charge"' },
	{ "Wuber/UI/Moments.lua", "Raincheck kept: one free summon from", "Raincheck kept: one summon at no charge from" },
	{ "Wuber/UI/Rider/Booking.lua", '" is free"', '" costs nothing"' },
	{ "Wuber/UI/Rider/Confirm.lua", "is one free summon from this crew", "is one summon at no charge from this crew" },
	{ "Wuber/UI/Rider/Done.lua", "for one free summon later instead.", "for one summon later at no charge instead." },
	{ "Wuber/UI/Rider/Home.lua", "Your raid \194\183 free summons", "Your raid \194\183 summons at no charge" },
	{ "Wuber/UI/Rider/Home.lua", "runs free summons for the raid", "runs summons at no charge for the raid" },
	{ "Wuber/UI/Rider/Home.lua", "accept when it pops. Free.", "accept when it pops. It costs nothing." },
	{ "Wuber/UI/Rider/Ride.lua", 'or "Free")', 'or "Nothing to pay")' },
	{ "Wuber/UI/Rider/Trips.lua", '"Free summons drivers gave you', '"Summons at no charge that drivers gave you' },
	{ "Wuber/UI/Rider/Trips.lua", '": one free summon up to "', '": one summon at no charge, up to "' },
}
test("r52 h: the rider screens say 'at no charge' or 'costs nothing', never free (F19-F32)", function()
	for _, it in ipairs(ITEMS) do
		local s = read(it[1])
		ok(#s > 0, "can read " .. it[1])
		ok(has(s, it[3]), it[1] .. " has the new words: " .. it[3])
	end
	local olds = { "is free, up to the amount", '"One free summon"', "Raincheck kept: one free summon", '" is free"',
		"is one free summon from", "one free summon later instead", "raid \194\183 free summons", "runs free summons",
		"pops. Free.", 'or "Free")', '"Free summons drivers', "one free summon up to" }
	local files = { "Moments", "Rider/Booking", "Rider/Confirm", "Rider/Done", "Rider/Home", "Rider/Ride", "Rider/Trips" }
	for _, f in ipairs(files) do
		local s = read("Wuber/UI/" .. f .. ".lua")
		for _, o in ipairs(olds) do ok(not has(s, o), f .. " no longer says " .. o) end
	end
end)
