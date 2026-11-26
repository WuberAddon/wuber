-- #261: Settings' Replay and Reset place buttons hold their words (job 2885, #238: the fake game draws text at the real game's measured widths).
-- The fix wraps or moves; the player's words are not changed.
local T = ...
local H, test, eq, ok = T.H, T.test, T.eq, T.ok
local probe = assert(loadfile(H.root .. "/tests/layout/probe.lua"))(H)

test("#261: Settings' Replay and Reset place buttons hold their words", function()
	for _, cfg in ipairs({ "1920x1080@1.0,ui1.0", "1920x1080@1.15,ui0.71", "3840x2160@1.5,ui1.0" }) do
		local hits = probe(cfg, { "settings" }, { "Rows%.lua:%d+.-\"Replay\"", "Rows%.lua:%d+.-\"Reset place\"" }, "cut")
		eq(#hits, 0, cfg .. ": " .. (hits[1] and (hits[1].shot .. " " .. tostring(hits[1].what)) or ""))
	end
end)
