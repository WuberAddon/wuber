local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H
local RATCHET = {
	{ name = "Ratchet, The Barrens", type = "CURRENT", cost = 0 },
	{ name = "Gadgetzan, Tanaris", type = "REACHABLE", cost = 2345 },
	{ name = "Orgrimmar, Durotar", type = "REACHABLE", cost = 610 },
	{ name = "Crossroads, The Barrens", type = "REACHABLE", cost = 150 },
}
local function sentF(w, from)
	local n = 0
	for _, e in ipairs(w.addonLog) do
		if e.from == from and e.prefix == "WUBER" and e.result == 0 and e.text:find("^F~") then n = n + 1 end
	end
	return n
end

test("r33 o AUD-40: a flight-price retry timer is never given a negative delay (it would fire every frame)", function()
	local w = H.NewWorld({})
	local r = T.rider(w, T.TESTCHAR, { spot = "Ratchet" })
	T.settle(w)
	local W = r.W
	w:openTaxi(r, RATCHET)
	local nowt = r.env.time()
	for i, t in ipairs({ "orgrimmar", "undercity", "thunder bluff", "crossroads", "camp mojache", "everlook", "gadgetzan" }) do
		W.FlightMerge("H", "booty bay", t, 500 + i, nil, nowt - i * 60, "p")
		W.FlightMerge("H", t, "booty bay", 600 + i, 120 + i, nowt - i * 60, "p")
	end
	local peer = "Peer Ason"
	w:addBot(peer, { spot = "Ratchet" })
	-- first F goes (control)
	w:inject(peer, "F~1~H~?~ratchet:gadgetzan", "WHISPER", r)
	w:advance(10)
	eq(sentF(w, T.TESTCHAR), 1, "control: the first F went to the peer")
	-- three minutes later: the outbox is busy, so the next F waits for the full send allowance
	w:advance(200)
	local delays = {}
	local after = W.After
	W.After = function(d, fn) delays[#delays + 1] = d return after(d, fn) end
	for i = 1, 6 do W.SendTo(peer, "V", "ask", "drain" .. i) end
	w:inject(peer, "F~1~H~?~ratchet:orgrimmar", "WHISPER", r) -- an F is queued (waits)
	eq(sentF(w, T.TESTCHAR), 1, "control: the second F is still waiting in the outbox")
	w:inject(peer, "F~1~H~?~ratchet:crossroads", "WHISPER", r) -- the peer asks again meanwhile
	local worst
	for _, d in ipairs(delays) do if type(d) == "number" and (not worst or d < worst) then worst = d end end
	ok(worst ~= nil, "control: a retry timer was set (delays: " .. #delays .. ")")
	ok(worst == nil or worst > 0, "the flight-price retry timer was given a delay of " .. tostring(worst) .. " s; the game runs it on the very next frame, and it re-arms itself every frame until the F leaves")
	W.After = after
	T.clean(w)
end)
