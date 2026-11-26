-- Flight recorder, lane B1: the fake game's logging in and /reload checked against the real client.
-- Each test asks the fake game a question the test addon asked the real one (WoW Forever, 17-21 Nov 2026)
-- and expects the REAL answer. The facts (id, what was seen, verbatim log lines) are in
-- tests/fixtures/rec/lab-real-facts.lua; the ids are quoted at each test.
local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H

local FACTS = dofile(T.dir .. "/fixtures/rec/lab-real-facts.lua")
local function fact(id)
	for _, f in ipairs(FACTS) do if f.id == id then return f end end
	error("no recorded fact " .. id)
end

-- every event the named player's game windows fire while fn runs (addon messages left out):
-- { ev, at, args }; the wrap goes even when fn fails
local function listen(name, fn)
	local got, orig = {}, H.Client.fire
	H.Client.fire = function(self, ev, ...)
		if self.player and self.player.name == name and ev ~= "CHAT_MSG_ADDON" then
			got[#got + 1] = { ev = ev, at = self.world.time, args = { n = select("#", ...), ... } }
		end
		return orig(self, ev, ...)
	end
	local okf, err = pcall(fn, got)
	H.Client.fire = orig
	if not okf then error(err, 0) end
	return got
end

local function only(got, ev)
	local out = {}
	for _, e in ipairs(got) do if e.ev == ev then out[#out + 1] = e end end
	return out
end

local function channelCount(c)
	return math.floor(select("#", c.env.GetChannelList()) / 3)
end

-- login.pew.reload (26 of 26 reloads): "Anita Lift 20 Nov 23:55:36 PEW login=false reload=true (after
-- PLAYER_LOGOUT 23:55:27)", and no ZONE_CHANGED_NEW_AREA after any reload. The fake's reload used to be a
-- second login: PLAYER_ENTERING_WORLD(true, false) and the zone event, so the round 26 tip bug (a reload
-- taken for a login) passed every offline test.
test("rec: real: a /reload fires PLAYER_ENTERING_WORLD(false, true) and no zone event (login.pew.reload)", function()
	ok(fact("login.pew.reload").value:find("PEW(false,true)", 1, true), "the recorded fact")
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR)
	w:advance(10)
	local got = listen(T.TESTCHAR, function()
		w:reload(r)
		w:advance(10)
	end)
	local pew = only(got, "PLAYER_ENTERING_WORLD")
	eq(#pew, 1, "one PLAYER_ENTERING_WORLD")
	eq(pew[1] and pew[1].args[1], false, "isInitialLogin")
	eq(pew[1] and pew[1].args[2], true, "isReloadingUi")
	eq(#only(got, "ZONE_CHANGED_NEW_AREA"), 0, "no ZONE_CHANGED_NEW_AREA after a reload")
	eq(got[1] and got[1].ev, "PLAYER_LOGOUT", "the old window's PLAYER_LOGOUT first")
	T.clean(w)
end)

-- login.pew.fresh (48 of 48 fresh logins in the lines): "Wuber Rocks 20 Nov 23:54:52 PEW login=true
-- reload=false; 23:54:55 ZONE_CHANGED_NEW_AREA zone=Thunder Bluff". The delay was 0.2 to 10 s, most often
-- about 3 s, and in 32 of 34 logins it came in the same frame as the game's channels (CHANNEL_UI_UPDATE),
-- just after them.
test("rec: real: a fresh login fires PLAYER_ENTERING_WORLD(true, false), the zone event about 3 s later (login.pew.fresh)", function()
	local w = T.newWorld()
	local t0 = w.time
	local got = listen(T.TESTCHAR, function()
		T.rider(w, T.TESTCHAR)
		w:advance(10)
	end)
	local pew = only(got, "PLAYER_ENTERING_WORLD")
	eq(#pew, 1, "one PLAYER_ENTERING_WORLD")
	eq(pew[1].args[1], true, "isInitialLogin")
	eq(pew[1].args[2], false, "isReloadingUi")
	eq(pew[1].at, t0, "at the login")
	local zone = only(got, "ZONE_CHANGED_NEW_AREA")
	eq(#zone, 1, "one zone event")
	ok(zone[1].at - t0 >= 2.5 and zone[1].at - t0 <= 4, "about 3 s after PLAYER_ENTERING_WORLD: " .. (zone[1].at - t0))
	local ui = only(got, "CHANNEL_UI_UPDATE")
	ok(ui[1] and ui[1].at == zone[1].at, "the game's channels in the same frame")
	local iz, iu
	for i, e in ipairs(got) do
		if e == zone[1] then iz = i end
		if e == ui[1] then iu = i end
	end
	ok(iu and iz and iu < iz, "the channels first, then the zone")
	T.clean(w)
end)

-- login.channels.fresh (34 of 34): "Farra Way 21 Nov 23:54:35 'channels=0 wuberIndex=nil (login)'; Wuber Rocks
-- 23:54:55 'channels=6 wuberIndex=nil (CHANNEL_UI_UPDATE)'; 23:54:59 'JoinTemporaryChannel(WuberNet) called'
-- 'CheckChannel(true) -> false index=6 channels=7'". The game's channels came 2 to 4 s after
-- PLAYER_ENTERING_WORLD, Wuber's join at +6.0 to +7.8 s; Wuber's channel took /6 (one character with more
-- channels of its own: /7). The 6 are five channels at /1 to /5 and a community channel (not in the fake).
test("rec: real: a fresh login starts with no channel, the game's come about 3 s later, Wuber's takes /6 (login.channels.fresh)", function()
	local w = T.newWorld()
	local t0 = w.time
	local r = T.rider(w, T.TESTCHAR)
	local joins = {}
	local join = r.env.JoinTemporaryChannel
	r.env.JoinTemporaryChannel = function(name, ...)
		joins[#joins + 1] = { name = name, at = w.time }
		return join(name, ...)
	end
	eq(channelCount(r), 0, "no channel at login")
	eq(r.W.ChannelIndex(), nil, "not on Wuber's channel")
	w:advance(2)
	eq(channelCount(r), 0, "none 2 s after")
	w:advance(1.5)
	eq(channelCount(r), 5, "the game's own five, 3.5 s after")
	T.settle(w)
	eq(r.W.ChannelIndex(), 6, "Wuber's channel at /6")
	eq(channelCount(r), 6, "six in all")
	ok(joins[1] and joins[1].name == "WuberNet", "Wuber joined its channel")
	ok(joins[1] and joins[1].at - t0 >= 5.5 and joins[1].at - t0 <= 8, "about 6 s after the login: " .. tostring(joins[1] and joins[1].at - t0))
	T.clean(w)
end)

-- login.channels.reload: "After /reload the channel list is kept: 19 reloads show channels=7 (Wuber at 6) and 7
-- show channels=9 (Wuber at 7) at login time" ("Farra Way 23:55:57 'channels=7 wuberIndex=6 (login)'"), and
-- Wuber is on its network at once ("fire NETWORK true" and its Q on /6 in the second of the login).
test("rec: real: a /reload keeps the channel list and Wuber's channel, on the network at once (login.channels.reload)", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR)
	T.settle(w)
	eq(r.W.ChannelIndex(), 6, "on Wuber's channel before")
	local before = channelCount(r)
	local r2 = w:reload(r)
	eq(channelCount(r2), before, "the same channels at PLAYER_LOGIN")
	eq(r2.W.ChannelIndex(), 6, "Wuber's channel kept, at /6")
	eq(r2.W.OnNetwork(), true, "on the network at once")
	eq(r2.W.net.joined, true, "Wuber saw it at login (no join needed)")
	w:advance(1)
	local sent = false
	for _, e in ipairs(w.addonLog) do
		if e.from == T.TESTCHAR and e.chatType == "CHANNEL" and e.at >= w.time - 1 then sent = true end
	end
	ok(sent, "a message on the channel in the first second")
	T.clean(w)
end)

-- login.pew.reload, the round 26 tip bug: tests/r26_a_tips.lua and r25_a_tips.lua had to patch the client to
-- fire (false, true); with the fake's own w:reload the tip code now takes its reload path untouched.
local function tipsLogin(w, saved)
	local c = T.rider(w, T.TESTCHAR, { saved = saved or { Wuber = { coach = true } }, class = "WARLOCK" })
	w:advance(2)
	return c
end
local function cardUp(c)
	local card = c.W.Mod("UI.Tips").Card()
	return card and H.visible(card) and card or nil
end

test("rec: real: w:reload takes the tips' reload path: the login's tip waits, a shown one does not come back (login.pew.reload)", function()
	if not T.HAVE_UI then return end
	local w = T.newWorld()
	local c = tipsLogin(w)
	eq(c.W.db.tipsPending, true, "a login saves its tip as pending")
	local c2 = w:reload(c)
	eq(c2.W.Mod("UI.Tips").state.armed, true, "the reload keeps the pending tip")
	c2.W.UI.Toggle(true)
	w:advance(5)
	ok(cardUp(c2), "the tip shows on the first open")
	c2.W.UI.Toggle(false)
	w:advance(1)
	local c3 = w:reload(c2)
	eq(c3.W.Mod("UI.Tips").state.armed, false, "a reload after the tip showed: nothing armed")
	c3.W.UI.Toggle(true)
	w:advance(5)
	ok(not cardUp(c3), "and no second tip")
	T.clean(w)
end)
