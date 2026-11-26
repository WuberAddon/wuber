local T = ...
local H, test, eq, ok = T.H, T.test, T.eq, T.ok

test("r33 k5: HUNT-53: a 200 character advert is posted whole after the tag", function()
	local w = H.NewWorld({})
	local c = w:addClient("Ana Smith", { spot = "Undercity", class = "WARLOCK" })
	w:advance(1)
	local own = ("summons to Undercity quick and safe "):rep(6):sub(1, 200):gsub("%s+$", "x")
	eq(#own, 200, "test line is 200 long")
	local line = c.W.AdvertOwnText(own)
	ok(line, "the line is allowed")
	eq(line, c.W.ADVERT_TAG .. " " .. own, "tag then the whole line")
	local long = own .. " and then some more words that are too many"
	local cut = c.W.AdvertOwnText(long)
	ok(cut and #cut <= #c.W.ADVERT_TAG + 1 + 200, "over the limit is still cut")
	T.clean(w)
end)
