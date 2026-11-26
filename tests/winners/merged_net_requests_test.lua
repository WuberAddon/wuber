-- Merged table-driven tests (test audit): each group below was several near-identical tests of tests/winners/net_requests_test.lua, the same body with different
-- literals. One body, one table of cases; every case keeps its own assertions and a failing case is named in the message.
local T = ...
local test, eq, ok = T.test, T.eq, T.ok

-- from tests/winners/net_requests_test.lua: line 77; line 161; line 186
test("breakit Net.Requests: a rider cannot rate before the driver has arrived (3 cases)", function()
	local failed = {}
	local cases = {
		{ "breakit Net.Requests: a rider cannot rate before the driver has arrived", 'an unfinished request cannot rate the driver' },
		{ "breakit Net.Requests: an unfinished ride cannot be rated by the rider", 'an unfinished request cannot rate the driver' },
		{ "breakit Net.Requests: a new request does not allow the rider to rate the driver", 'a new request cannot rate the driver' },
	}
	for _, case in ipairs(cases) do
		local C = { select(2, unpack(case)) }
		local good, err = pcall(function()
		local w = T.newWorld()
		local d = T.driver(w, T.ANITA, { spot = 'Ratchet' })
		T.settle(w)
		d.W.provider = nil
		d.W.engine = nil
		d.W.incoming[#d.W.incoming + 1] = {
			id = 'abcdef',
			buyer = T.TESTCHAR,
			buyerKey = d.W.Key(T.TESTCHAR),
			addr = T.TESTCHAR,
			name = T.TESTCHAR,
			spot = 'Ratchet',
			price = 5000,
			state = 'new',
			stage = 'new',
			at = 1e12,
		}
		w:inject(T.TESTCHAR, 'T~1~abcdef~5', 'WHISPER', d)
		w:advance(0.5)
		ok(not d:said('rated your ride 5 out of 5'), C[1])
		T.clean(w)
		end)
		if not good then failed[#failed + 1] = case[1] .. ": " .. tostring(err) end
	end
	if #failed > 0 then error(#failed .. " of " .. #cases .. " cases failed:\n" .. table.concat(failed, "\n"), 0) end
end)

-- from tests/winners/net_requests_test.lua: line 102; line 122; line 211
test("breakit Net.Requests: blocked rider rating hidden from the driver (3 cases)", function()
	local failed = {}
	local cases = {
		{ "breakit Net.Requests: blocked rider rating hidden from the driver" },
		{ "breakit Net.Requests: blocking a rider hides their rating from the driver" },
		{ "breakit Net.Requests: driver never sees rating from a blocked rider" },
	}
	for _, case in ipairs(cases) do
		local C = { select(2, unpack(case)) }
		local good, err = pcall(function()
		local w = T.newWorld()
		local d = T.driver(w, T.ANITA, { spot = 'Ratchet' })
		w:addBot(T.TESTCHAR, { spot = 'Orgrimmar' })
		T.settle(w)
		T.goOnline(d, { price = 5000 })
		w:advance(3)
		w:inject(T.TESTCHAR, 'R~1~paidid~Ratchet~5000', 'WHISPER', d)
		w:advance(1)
		d.W.SendStage('paidid', 'paid', T.TESTCHAR)
		d.W.provider = nil
		d.W.engine = nil
		d.W.Drive.BlockEntry = function() return true end
		w:inject(T.TESTCHAR, 'T~1~paidid~5', 'WHISPER', d)
		w:advance(0.5)
		ok(not d:said('rated your ride 5 out of 5'), 'the driver sees no rating from a blocked rider')
		T.clean(w)
		end)
		if not good then failed[#failed + 1] = case[1] .. ": " .. tostring(err) end
	end
	if #failed > 0 then error(#failed .. " of " .. #cases .. " cases failed:\n" .. table.concat(failed, "\n"), 0) end
end)

-- from tests/winners/net_requests_test.lua: line 142; line 231; line 250
test("breakit Net.Requests: a zero-star rating shows as one star (3 cases)", function()
	local failed = {}
	local cases = {
		{ "breakit Net.Requests: a zero-star rating shows as one star", "T~1~paidid~0", "rated your ride 1 out of 5", "zero stars is shown as one star" },
		{ "breakit Net.Requests: a one-star rating shows as one star", "T~1~paidid~1", "rated your ride 1 out of 5", "one star is shown as one star" },
		{ "breakit Net.Requests: a six-star rating is capped at five stars", "T~1~paidid~6", "rated your ride 5 out of 5", "six stars is capped at five" },
	}
	for _, case in ipairs(cases) do
		local C = { select(2, unpack(case)) }
		local good, err = pcall(function()
		local w = T.newWorld()
		local d = T.driver(w, T.ANITA, { spot = "Ratchet" })
		w:addBot(T.TESTCHAR, { spot = "Orgrimmar" })
		T.settle(w)
		T.goOnline(d, { price = 5000 })
		w:advance(3)
		w:inject(T.TESTCHAR, "R~1~paidid~Ratchet~5000", "WHISPER", d)
		w:advance(1)
		d.W.SendStage("paidid", "paid", T.TESTCHAR)
		d.W.provider = nil
		d.W.engine = nil
		w:inject(T.TESTCHAR, C[1], "WHISPER", d)
		w:advance(0.5)
		ok(d:said(C[2]), C[3])
		T.clean(w)
		end)
		if not good then failed[#failed + 1] = case[1] .. ": " .. tostring(err) end
	end
	if #failed > 0 then error(#failed .. " of " .. #cases .. " cases failed:\n" .. table.concat(failed, "\n"), 0) end
end)
