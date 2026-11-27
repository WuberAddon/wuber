-- RETIRED 24 Nov 2026 (job 2743). Why: it tested the old addon's own main-caster rule; a provider whose window returns no beacon sending no D is now in tests/oldaddon
-- Was in tests/whisper.lua. Not loaded by the suite; kept for the record. It needed the old addon's own code (Ritual Rides 1.4.1), which is not in this repository.

test("whisper: Ritual Rides as provider answers a whispered Q from its main caster only", function()
	if not T.HAVE_RR then error("Ritual Rides 1.4.0 not found") end
	local w = newWorld({ realm = T.H.FOUNDER_REALM })
	local cs = {}
	for i, n in ipairs({ ANITA, FARRA, HAYLEY }) do
		cs[i] = w:addClient(n, { spot = "Ratchet", class = "WARLOCK", addons = { "Wuber", "RitualRides" }, allowMissing = not HAVE_UI })
	end
	w:group({ ANITA, FARRA, HAYLEY })
	w:advance(1)
	for _, c in ipairs(cs) do c:slash("/rr team") end
	w:advance(1)
	cs[1]:slash("/rr on")
	local r = client(w, ROCKS, { copy = "other" })
	settle(w, 20)
	r.W.Ping()
	w:advance(5)
	local x = r.W.drivers["anita lift"]
	ok(x and x.via == "WHISPER", "the leader answers by whisper")
	eq(r.W.drivers["farra way"], nil, "a teammate's window doesn't")
	eq(#whispered(w, "D", FARRA), 0, "no D from Farra")
	eq(#whispered(w, "D", HAYLEY), 0, "no D from Hayley")
	noChatSpam(w)
	clean(w)
end)
