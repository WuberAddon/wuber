local T = ...
local H, test, eq, ok = T.H, T.test, T.eq, T.ok

-- r34 e2 (HUNT-77): "Your crew shares this list" must be true for a blocked list longer than 40 names.
test("r34 e2: a blocked list of 90 names reaches the whole crew over time, one BLK per name", function()
	local w = H.NewWorld({})
	local names = { "Ana Lift", "Bea Lift" }
	local cs = {}
	for i, n in ipairs(names) do cs[i] = w:addClient(n, { spot = "Orgrimmar", class = "WARLOCK" }) end
	w:group(names)
	w:advance(1)
	local ana = cs[1]
	ana.W.Drive.SetOpen(true)
	w:advance(2)
	for i = 1, 90 do ana.W.db.drive.blocklist["spammer" .. i .. " x"] = { reason = "r", at = "" } end
	ana.W.Drive.SyncNow()
	w:advance(120)
	local seen, n = {}, 0
	for _, e in ipairs(w.addonLog) do
		if e.prefix == "WUBERT" and e.from == "Ana Lift" then
			local k = e.text:match("^BLK~%d+~([^~]*)")
			if k and k:find("^spammer") and not seen[k] then seen[k] = true n = n + 1 end
		end
	end
	if n == 0 then for _, e in ipairs(w.addonLog) do if e.text:find("BLK") then print(e.prefix, e.from, e.text, e.result) end end end
	eq(n, 90, "distinct blocked names sent to the crew")
end)
