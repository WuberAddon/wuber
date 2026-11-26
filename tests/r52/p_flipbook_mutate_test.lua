-- r52 group P: an outside audit #11 (FX/Effects.lua onUpdate mutated `live` while iterating it with pairs).
-- Promise: whatever badges show, hide or finish, no flipbook skips or double-steps and no "invalid key to 'next'" error.
local T = ...
local test, eq, ok = T.test, T.eq, T.ok

-- 13+ visible looping books (MAX_LIVE is 12): the first 12 are live, the rest wait. One live book stops
-- being visible during the driver's own step (IsVisible lies, so no OnHide runs first): stepBook then
-- unregisters it and promote() puts a waiting book into `live` while onUpdate is walking `live`.
local function run(hide, size)
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR)
	w:advance(15)
	r.W.db.fx = "full"
	local FX = r.W.FX
	local parent = r.env.UIParent
	local books, steps = {}, {}
	for i = 1, size do
		local b = FX.Flipbook(parent, "portal_loop", 24)
		ok(b, "book " .. i)
		b:Show()
		steps[b] = 0
		b.extra = function(self, t, n) steps[self] = steps[self] + 1 end
		books[#books + 1] = b
	end
	eq(FX.Stats().live, 12, "twelve live")
	eq(FX.Stats().waiting, size - 12, "the rest wait")
	local errs = 0
	local liveAtStart = {}
	for i = 1, 12 do liveAtStart[i] = books[i] end
	-- hide some live books at the next step without an OnHide
	for i = 1, hide do
		local b = books[i]
		b.IsVisible = function() return false end
	end
	for _, b in ipairs(books) do steps[b] = 0 end
	w:advance(0.12)
	-- every book that was live and stayed visible stepped, none stepped twice as often as its neighbours
	local first
	for i = hide + 1, 12 do
		local n = steps[books[i]]
		ok(n >= 1, "live book " .. i .. " was stepped (not skipped)")
		first = first or n
		eq(n, first, "live book " .. i .. " stepped as often as the others (no double step)")
	end
	for i = 13, size do ok(steps[books[i]] <= first, "a promoted book " .. i .. " is not stepped more than the others") end
	local st = FX.Stats()
	local visible = size - hide
	eq(st.live, math.min(12, visible), "the waiting books took the freed places")
	eq(st.waiting, math.max(0, visible - 12), "the waiting list shrank by the places taken")
	T.clean(w)
end

-- Sweep: every shape of (books, hidden) from 13 to 20 books and 1 to 12 hidden. The order a table is walked in
-- while a key is added is undefined in Lua 5.1, so one shape alone can pass by luck.
-- failing before the fix: a live book was stepped twice in one frame (the table grew while pairs walked it)
test("fx.effects: 13 to 20 flipbooks, any number hiding during the step: none skipped or double-stepped, no error", function()
	for size = 13, 20, 7 do
		for hide = 1, 12, 5 do run(hide, size) end
	end
	for size = 14, 19, 5 do
		for hide = 2, 11, 5 do run(hide, size) end
	end
end)
