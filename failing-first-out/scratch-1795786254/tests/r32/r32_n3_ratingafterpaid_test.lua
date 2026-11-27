local T = ...
local test, eq, ok = T.test, T.eq, T.ok

-- Reached here through the same lost-entry path as C07b-1 (the live ride is no longer in W.incoming when
-- the driver sends S paid): the stage is sent but the ride is never remembered, so the rating is dropped.
local function run(secondR)
	local w = T.newWorld()
	local d = T.driver(w, T.ANITA, { spot = "Ratchet" })
	local r = T.rider(w, T.TESTCHAR, { spot = "Orgrimmar" })
	T.settle(w)
	r.W.db.autoAccept = true
	T.goOnline(d) w:advance(5)
	local ride = r.W.RequestRide("anita lift") w:advance(1) T.take(d) w:advance(6)
	local DR = d.W.Drive
	local key = d.W.Key("Wuber TestCharacter")
	DR.customers[key].voucher = "Rc0000C1"
	if secondR then
		local f = T.fields(w:messages("R", T.TESTCHAR, "WHISPER")[1])
		f[3] = "ZZ" .. ride.id:sub(3)
		w:inject(T.TESTCHAR, table.concat(f, "~"), "WHISPER", d)
		w:advance(1)
	end
	if secondR then for i = #d.W.incoming, 1, -1 do table.remove(d.W.incoming, i) end end -- the ride aged out or was wiped
	local got = {}
	d.W.Listen("RATING", function(id, name, stars) got[#got + 1] = id .. ":" .. stars end)
	DR.SetState(DR.customers[key], "paid")
	w:advance(2)
	local paidSent = false
	for _, e in ipairs(w:messages("S", T.ANITA, "WHISPER")) do local g = T.fields(e) if g[3] == ride.id and g[4] == "paid" then paidSent = true end end
	w:inject(T.TESTCHAR, "T~" .. d.W.PROTO .. "~" .. ride.id .. "~5", "WHISPER", d)
	w:advance(2)
	return w, ride, got, paidSent
end

test("r32 n3: AUD-34 a rating still counts when S paid goes out for a ride no longer in W.incoming", function()
	local w0, ride0, got0, paid0 = run(false)
	ok(paid0, "control setup: S paid was sent")
	eq(#got0, 1, "control: with the ride still listed the rating arrives")
	local w, ride, got, paid = run(true)
	ok(paid, "S paid was still sent to the rider")
	eq(#got, 1, "the driver still receives the rating")
	T.clean(w)
end)
