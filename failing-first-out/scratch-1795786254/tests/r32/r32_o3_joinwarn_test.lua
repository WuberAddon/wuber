local T = ...
local test, eq, ok = T.test, T.eq, T.ok

-- HUNT-37: after two failed channel joins the chat line must not claim you cannot see drivers
-- (drivers still show by whisper).
test("r32 o3: the failed-join line does not say you cannot see drivers", function()
	local w = T.newWorld({ joinFails = true })
	local r = T.rider(w, T.TESTCHAR, { spot = "Ratchet" })
	local W = r.W
	local lines = {}
	local real = W.Print
	W.Print = function(s, ...) lines[#lines + 1] = tostring(s); return real(s, ...) end
	w:advance(200)
	local joined = false
	for _, s in ipairs(lines) do
		if s:find("Couldn't join the Wuber network", 1, true) then
			joined = true
			ok(not s:find("can't see drivers", 1, true), "line says: " .. s)
			ok(s:find("by whisper", 1, true), "still says whisper works: " .. s)
		end
	end
	ok(joined, "the warning was printed (" .. #lines .. " lines)")
	T.clean(w)
end)

-- AUD-37: a disabled Trade channel is not an advert channel, even through the GetChannelName fallback.
test("r32 o3: a disabled Trade channel is not planned for an advert", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, { spot = "Ratchet" })
	T.settle(w)
	local W = r.W
	local copy = {}
	for _, c in ipairs(r.player.channels) do copy[#copy + 1] = c.name end
	for _, nm in ipairs(copy) do
		if W.ChannelBase(nm) and not nm:find("Trade") then w:leaveChannel(r, nm) end
	end
	local tradeIdx
	for _, c in ipairs(r.player.channels) do if c.name:find("Trade") then tradeIdx = c.index end end
	ok(tradeIdx, "setup: Trade joined")
	eq(W.AdvertChannel(), tradeIdx, "control: an enabled Trade channel is used")
	r.env.GetChannelList = function()
		local out = {}
		for _, c in ipairs(r.player.channels) do
			out[#out + 1], out[#out + 2], out[#out + 3] = c.index, c.name, c.name:find("Trade") ~= nil
		end
		return unpack(out)
	end
	local idx, name = W.AdvertChannel()
	ok(idx == nil, "disabled Trade must not be used, got /" .. tostring(idx) .. " " .. tostring(name))
	T.clean(w)
end)
