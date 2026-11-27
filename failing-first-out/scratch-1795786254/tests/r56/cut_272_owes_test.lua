-- #272: the floating Drive bar's owes-50s is not cut (job 2885, #238: the fake game draws text at the real game's measured widths).
-- The fix wraps or moves; the player's words are not changed.
local T = ...
local H, test, eq, ok = T.H, T.test, T.eq, T.ok
local probe = assert(loadfile(H.root .. "/tests/layout/probe.lua"))(H)

test("#272: the floating Drive bar's owes-50s is not cut", function()
	for _, cfg in ipairs({ "1920x1080@1.5,ui1.0", "1920x1080@1.15,ui0.71" }) do
		local hits = probe(cfg, { "float_" }, "^Rows%.lua:%d+", "cut")
		eq(#hits, 0, cfg .. ": " .. (hits[1] and (hits[1].shot .. " " .. hits[1].key) or ""))
	end
end)
