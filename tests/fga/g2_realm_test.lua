local T = ...
local H, test, eq, ok = T.H, T.test, T.eq, T.ok

-- fga G2: the real client (build 71037) names no realm (GetRealmName() == "", GetNormalizedRealmName() == ""),
-- and a new player has no remembered ruleset. On the same Wuber channel, riders and drivers must still hear
-- each other and a ride must still be booked; the founder lock holds (with no ruleset, another player's
-- founder name is nobody's founder). Founder-only paths (seed whispers to the founders, the community
-- invite, a founder-trusted update note) stay off there by the hard rule: that is REC-02/REC-03, not this.

local function scene(who)
	local w = T.newWorld() -- no realm named: the real default
	local d = T.driver(w, who)
	local r = T.rider(w)
	T.settle(w)
	eq(r.env.GetRealmName(), "", "control: the game names no realm")
	eq(r.W.Ruleset(), nil, "control: a new rider has no ruleset")
	eq(d.W.Ruleset(), nil, "control: a new driver has no ruleset")
	T.goOnline(d)
	return w, d, r
end

local function heardWithin(w, r, key, secs, step)
	local t = 0
	while t < secs do
		if r.W.drivers[key] then return t end
		w:advance(step)
		t = t + step
	end
	return r.W.drivers[key] and t or nil
end

for _, step in ipairs({ 1, 5 }) do
	for _, who in ipairs({ T.BOB, T.ANITA }) do
		local key = who:lower()
		-- guard: the fake named a realm by default before fga, so this passed there too; it pins that hearing never needed one
		test("fga g2: with no realm named a new rider hears driver " .. who .. " on the channel and books (steps of " .. step .. " s)", function()
			local w, d, r = scene(who)
			local at = heardWithin(w, r, key, 70, step)
			ok(at, "the rider hears the driver within 70 s")
			eq(r.W.drivers[key].via, "CHANNEL", "heard on the channel")
			ok(r.W.RequestRide(key), "the rider books")
			w:advance(20)
			ok(r.W.InGroupWith(key), "the driver heard the booking: the rider is in his group (ride state "
				.. tostring(r.W.ride and r.W.ride.state) .. ")")
			T.clean(w)
		end)
	end
end

-- guard: the founder lock with no ruleset (unchanged by fga): nobody else is a founder, the founders are not whispered
test("fga g2: with no realm named a founder's name heard on the channel is no founder, and no founder is whispered", function()
	local w, d, r = scene(T.ANITA)
	ok(heardWithin(w, r, "anita lift", 70, 1), "control: the rider hears her")
	eq(r.W.IsCreator("anita lift"), false, "not a founder to the rider")
	ok(not r.W.drivers["anita lift"].creator, "her driver entry carries no crown")
	eq(r.W.OnFounderRuleset(), false, "the rider is not on the founders' ruleset")
	eq(#r.W.SeedList(), 0, "no seed drivers with no ruleset")
	eq(d.W.IsCreator("anita lift"), true, "her own character still counts on her own client")
	T.clean(w)
end)
