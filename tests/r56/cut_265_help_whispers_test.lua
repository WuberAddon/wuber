-- #265: Help's "Whispers are the backup" paragraph is not cut (job 2885, #238: the fake game draws text at the real game's measured widths).
-- The fix wraps or moves; the player's words are not changed.
local T = ...
local H, test, eq, ok = T.H, T.test, T.eq, T.ok
local probe = assert(loadfile(H.root .. "/tests/layout/probe.lua"))(H)

test("#265: Help's \"Whispers are the backup\" paragraph is not cut", function()
	for _, cfg in ipairs({ "1920x1080@1.15,ui0.65", "1920x1080@1.15,ui0.71", "1920x1080@1.15,ui1.0", "1920x1080@1.0,ui1.15" }) do
		local hits = probe(cfg, { "help" }, { "\"Whispers are the backup" }, "cut")
		eq(#hits, 0, cfg .. ": " .. (hits[1] and (hits[1].shot .. " " .. tostring(hits[1].what)) or ""))
	end
end)
