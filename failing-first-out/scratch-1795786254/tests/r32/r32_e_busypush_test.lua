local T = ...
local test, eq, ok = T.test, T.eq, T.ok

-- AUD-29 (a reviewer C06b-1): a busy driver's price change, state change or going offline is
-- whispered to every rider who asked by whisper in the last 5.5 min, not only the first 16
-- (the outbox's burst of 4 and its 12 waiting whisper-fallback messages): the rest are spread
-- about a second apart, inside the allowance, and nothing is dropped.

local function setup(n)
	local w = T.newWorld()
	local d = T.driver(w, T.ANITA, { spot = "Ratchet" })
	T.settle(w)
	T.goOnline(d)
	w:advance(5)
	local names = {}
	for i = 1, n do
		names[i] = "Rider" .. string.char(64 + i) .. "x"
		w:addBot(names[i], { spot = "Orgrimmar" })
	end
	for i = 1, n do
		w:inject(names[i], d.W.Encode("Q", "0"), "WHISPER", d)
		w:advance(1)
	end
	w:advance(10)
	return w, d, names
end

local function told(w, d, kind, needle)
	local who, n = {}, 0
	for _, e in ipairs(w:messages(kind, d.player.name, "WHISPER")) do
		if (not needle or e.text:find(needle, 1, true)) and not who[e.target] then who[e.target] = true n = n + 1 end
	end
	return n
end

test("r32 e: AUD-29 8 whisper riders all hear the driver's price change (control)", function()
	local w, d = setup(8)
	d.W.Char().price = 7000
	w:advance(20)
	eq(told(w, d, "D", "~7000~"), 8, "riders told the new price")
	T.clean(w)
end)

test("r32 e: AUD-29 25 whisper riders all hear the driver's price change, none dropped", function()
	local w, d = setup(25)
	local dropped = d.W.net.dropped
	d.W.Char().price = 7000
	w:advance(40)
	eq(told(w, d, "D", "~7000~"), 25, "riders told the new price")
	eq(d.W.net.dropped, dropped, "messages the outbox dropped")
	T.clean(w)
end)

test("r32 e: AUD-29 25 whisper riders all hear the driver go offline, none dropped", function()
	local w, d = setup(25)
	local dropped = d.W.net.dropped
	d.W.Driver.SetOnline(false)
	w:advance(40)
	eq(told(w, d, "X"), 25, "riders told the driver went offline")
	eq(d.W.net.dropped, dropped, "messages the outbox dropped")
	T.clean(w)
end)
