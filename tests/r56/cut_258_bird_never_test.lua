-- #258: the Bird card's "Don't show again" is whole at the real game's measured text width (job 2885, #238):
-- the label's room is its real width (LABEL_MIN 98), the words are not changed.
local T = ...
local H, test, eq, ok = T.H, T.test, T.eq, T.ok
local probe = assert(loadfile(H.root .. "/tests/layout/probe.lua"))(H)

test("#258: \"Don't show again\" on the bird card is not cut at the maintainer's setting or at 1.0", function()
	for _, cfg in ipairs({ "1920x1080@1.0,ui1.0", "1920x1080@1.15,ui0.71" }) do
		local hits = probe(cfg, { "bird" }, "^Bird%.lua:%d+", "cut")
		eq(#hits, 0, cfg .. ": " .. (hits[1] and (hits[1].shot .. " " .. hits[1].key) or ""))
	end
end)
