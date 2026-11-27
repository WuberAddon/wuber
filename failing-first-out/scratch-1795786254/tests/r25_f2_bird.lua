-- Round 25 follow-up: the bird card message keeps its full wording and the card grows to fit.
local T = ...
local test, ok = T.test, T.ok

-- Greedy word wrap at a character budget (11pt text is about 6 px a character; 160 px is 26).
local function lines(s, per)
	local n, cur = 1, 0
	for word in s:gmatch("%S+") do
		if cur > 0 and cur + 1 + #word > per then n, cur = n + 1, #word
		else cur = cur + (cur > 0 and 1 or 0) + #word end
	end
	return n
end

test("r25 F2: full wording kept", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, { screenW = 1365, screenH = 768 })
	w:advance(15)
	local Mod = r.W.Mod("UI.Bird")
	local d = { short = "Mia", dest = "Tarren Mill", price = 5000 }
	for _, c in ipairs({ { 1750, 600 }, { 9000, 600 } }) do
		local s = Mod.Message(d, { cost = c[1], secs = c[2], about = true })
		ok(s:find("Skip the bird: Mia summons to Tarren Mill for ", 1, true), s)
	end
	local s = Mod.Message(d, { cost = 1750, secs = 600, about = true })
	ok(s:find("17s 50c", 1, true) and s:find("really about 32s 50c", 1, true) and s:find("and about 10 min back", 1, true), s)
	T.clean(w)
end)
