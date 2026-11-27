-- job 2934 F4: the rider's "Time to pay" page: the instruction "Put 60s in the trade window for Mia." wraps to three lines
-- and its last line lies partly under the step bar's "Accepted" frame (in the real game: WoWScrnShot 192426).
-- The offline sweep keeps this green only through the known entry in tests/layout/allow.lua; this test ignores the allow-list.
local T = ...
local test, eq = T.test, T.eq
local H = T.H
local probe = assert(loadfile(H.root .. "/tests/layout/probe.lua"))(H)

test("pay_trade: the trade instruction is not partly under the step bar", function()
	local hits = probe("2662x2089@2.2,ui0.7353", { "pay_trade" }, "^Ride%.lua:%d+.-Put 60s in the trade window", "under")
	local lines = {}
	for _, h in ipairs(hits) do lines[#lines + 1] = h.shot .. " " .. h.what .. " " .. tostring(h.detail) end
	eq(#hits, 0, "text half under the Accepted frame: " .. table.concat(lines, "; "))
end)
