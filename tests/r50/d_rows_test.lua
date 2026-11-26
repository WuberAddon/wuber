-- r50 group D: Settings rows (H24-03 search word, AU24-26 singular shard).
local T = ...
local test, ok = T.test, T.ok

local function open(adv)
	local w = T.newWorld()
	local c = T.rider(w)
	T.settle(w)
	c.W.SetAdvanced(adv)
	c.W.db.coach = true
	c.W.UI.Toggle(true)
	w:advance(3)
	c.W.UI.OpenSettings()
	w:advance(2)
	return w, c, c.W.UI.settings, c.W.Mod("UI.Settings.Panel")
end

-- the promise: every name a player may type for the Flight offers row finds it, Simple and Advanced
for _, q in ipairs({ "skip the bird", "skip", "flight master tip", "flight offers", "bird" }) do
	test("r50 d find '" .. q .. "' finds the Flight offers row", function()
		for _, adv in ipairs({ false, true }) do
			local w, _, st, P = open(adv)
			P.search(q)
			w:advance(1)
			ok((st.find.count or 0) >= 1, "Find finds a row for '" .. q .. "' (advanced " .. tostring(adv) .. ")")
			T.clean(w)
		end
	end)
end

-- the promise: the slider says "shard" for 1 and "shards" otherwise (0 reads "never")
for _, n in ipairs({ 1, 2, 0, 10 }) do
	-- guard: neighbours 0, 2 and 10 already read right on the base
	test("r50 d shard slider reads right for " .. n, function()
		local w = T.newWorld()
		local d = T.driver(w, T.BOB)
		T.settle(w)
		d.W.db.coach = true
		d.W.UI.Toggle(true)
		w:advance(3)
		d.W.UI.OpenSettings("driving")
		w:advance(1)
		local sl = d.W.UI.settings.controls["drive.lowShards"]
		d.W.Drive.SetOpt("lowShards", n)
		d.W.UI.UpdateSettings()
		w:advance(1)
		local t = sl.label:GetText() or ""
		local want = n == 0 and "never" or (n == 1 and "1 shard" or (n .. " shards"))
		ok(t:find(want, 1, true) and not t:find("1 shards", 1, true), "reads: " .. t)
		T.clean(w)
	end)
end
