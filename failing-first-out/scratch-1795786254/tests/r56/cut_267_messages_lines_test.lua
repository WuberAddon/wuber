-- #267: the Messages lines are not cut (job 2885, #238: the fake game draws text at the real game's measured widths).
-- The fix wraps or moves; the player's words are not changed.
local T = ...
local H, test, eq, ok = T.H, T.test, T.eq, T.ok
local probe = assert(loadfile(H.root .. "/tests/layout/probe.lua"))(H)

test("#267: the Messages lines are not cut", function()
	for _, cfg in ipairs({ "1920x1080@1.15,ui0.65", "1920x1080@1.15,ui0.71" }) do
		local hits = probe(cfg, { "messages_line" }, { "\"You're next, Dan", "\"Welcome to Feathermoon", "\"Wuber whispers it without" }, "cut")
		eq(#hits, 0, cfg .. ": " .. (hits[1] and (hits[1].shot .. " " .. tostring(hits[1].what)) or ""))
	end
end)
