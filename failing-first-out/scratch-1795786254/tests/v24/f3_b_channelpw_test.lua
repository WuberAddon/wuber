-- Wuber 2.4 fix round 3, group B: a password on the hidden channel (LRN-04) and the channel slot (LRN section 9).
-- Source of the notice names: Lego_ChannelTransport.lua:1663-1668 (another addon; the idea only). Not proven in game.
local T = ...
local test, eq, ok = T.test, T.eq, T.ok

local OLD = "10 chat channels"
local NEW = "The Wuber channel has a password; requests still work by whisper."

local function capture(W)
	local lines = {}
	local real = W.Print
	W.Print = function(s, ...) lines[#lines + 1] = tostring(s); return real(s, ...) end
	return lines
end

local function has(lines, text)
	for _, s in ipairs(lines) do if s:find(text, 1, true) then return true end end
	return false
end

test("v24 f3b: a refused join because of a password says so, not '10 chat channels'", function()
	local w = T.newWorld()
	-- somebody else owns the channel and has set a password before we log in
	w.channels["wubernet"] = { name = "WuberNet", members = {}, password = "secret" }
	local r = T.rider(w, T.TESTCHAR, { spot = "Ratchet" })
	local lines = capture(r.W)
	w:advance(200)
	ok(has(lines, NEW), "the password line was printed (" .. #lines .. " lines)")
	ok(not has(lines, OLD), "the 10-channels line was not printed")
	T.clean(w)
end)

test("v24 f3b: any other join failure keeps the old 10-channels line", function()
	local w = T.newWorld({ joinFails = true })
	local r = T.rider(w, T.TESTCHAR, { spot = "Ratchet" })
	local lines = capture(r.W)
	w:advance(200)
	ok(has(lines, OLD), "old line kept")
	ok(not has(lines, NEW), "no password line")
	T.clean(w)
end)

test("v24 f3b: the owner clears a password that someone puts on the channel", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, { spot = "Ratchet" })
	T.settle(w)
	ok(r.W.OnNetwork(), "setup: in the channel")
	w:setChannelOwner("WuberNet", r)
	w:setChannelPassword("WuberNet", "secret", "Stranger")
	w:advance(2)
	eq(w.channels["wubernet"].password, nil, "password cleared by the owner")
	eq(r.passwordClears, 1, "SetChannelPassword(name, '') was called once")
	T.clean(w)
end)

test("v24 f3b: the owner's own clear comes back as a notice and is not answered; a second password within 30 s is left", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, { spot = "Ratchet" })
	T.settle(w)
	w:setChannelOwner("WuberNet", r)
	w:setChannelPassword("WuberNet", "secret", "Stranger")
	w:advance(5)
	eq(r.passwordClears, 1, "one clear, although the clear itself was announced to the owner")
	w:setChannelPassword("WuberNet", "again", "Stranger")
	w:advance(5)
	eq(r.passwordClears, 1, "no second clear within 30 s")
	eq(w.channels["wubernet"].password, "again", "the second password stands for the moment")
	w:advance(40)
	eq(r.passwordClears, 2, "one more clear once 30 s have passed")
	eq(w.channels["wubernet"].password, nil, "and the channel is open again")
	w:advance(120)
	eq(r.passwordClears, 2, "and then nothing more by itself")
	T.clean(w)
end)

test("v24 f3b: a member who is not the owner leaves the password alone", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, { spot = "Ratchet" })
	T.settle(w)
	w:setChannelPassword("WuberNet", "secret", "Stranger")
	w:advance(2)
	eq(w.channels["wubernet"].password, "secret", "not ours to clear")
	eq(r.passwordClears or 0, 0, "no clear call")
	T.clean(w)
end)

test("v24 f3b: no SetChannelPassword on this client leaves things alone and does not break", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, { spot = "Ratchet" })
	T.settle(w)
	w:setChannelOwner("WuberNet", r)
	rawset(r.env, "SetChannelPassword", false) -- the client has no such call (a global that is not a function)
	w:setChannelPassword("WuberNet", "secret", "Stranger")
	w:advance(2)
	eq(w.channels["wubernet"].password, "secret", "nothing cleared")
	T.clean(w)
end)

-- Channel slot (section 9) is LEFT OPEN: a swap exchanges two channels, so the player's own top channel would take
-- the hidden channel's low number and their /N would change. The fake game states that, so nobody builds it blind.
test("v24 f3b: the fake game's channel swap exchanges two slots (why the slot move is not built)", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, { spot = "Ratchet" })
	T.settle(w)
	local own = w:channelOf(r.player, 1)
	ok(own, "setup: a channel at /1")
	local top = r.player.channels[#r.player.channels]
	local nameTop, nameOne, topIndex = top.name, own.name, top.index
	r.env.C_ChatInfo.SwapChatChannelsByChannelIndex(1, top.index)
	eq(w:channelOf(r.player, 1).name, nameTop, "the top channel took /1")
	eq(w:channelOf(r.player, topIndex).name, nameOne, "and /1's channel moved up")
	T.clean(w)
end)
