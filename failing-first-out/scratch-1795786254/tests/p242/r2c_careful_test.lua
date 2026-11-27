local T = ...
local test = T.test
local function verdicts(lines)
	local w = T.newWorld()
	local a = T.driver(w, T.ANITA, { spot = "Undercity" })
	w:advance(15)
	local out = {}
	for _, line in ipairs(lines) do
		local v, why = a.W.Drive.Careful(line, "public", "Zed")
		out[#out + 1] = { line = line, v = v, why = tostring(why) }
	end
	T.clean(w)
	return out
end
test("DS24-02: public buyer lines using service/dm/pst are not dropped as sellers", function()
	local bad = {}
	for _, r in ipairs(verdicts({
		"anyone doing a summon service to UC?", "wtb summon to UC, dm me", "LF summon to UC dm me",
		"wtb summon to Orgrimmar dm me", "lf summon to UC pst", "anybody doing a summon service to Orgrimmar?",
		"LF summon service to Undercity", "wtb summon to Ratchet, dm me pls",
		"need a summon service to UC pls", "need summon to UC, dm", "need a summon to Org pst", "summon to UC dm me pls",
	})) do
		if r.why:find("seller word", 1, true) or r.why:find("advert phrase", 1, true) then
			bad[#bad + 1] = r.line .. " => " .. r.v .. " (" .. r.why .. ")"
		end
	end
	assert(#bad == 0, "buyer lines dropped as seller: " .. table.concat(bad, "; "))
end)
-- guard: real adverts were sellers before and must stay sellers (carries a price, a sell word, or no ask)
test("DS24-02 guard: seller adverts stay sellers", function()
	local bad = {}
	for _, r in ipairs(verdicts({
		"WTS summons to UC 5g", "selling summons to UC, dm me", "summons to UC 5g whisper me",
		"summons to Orgrimmar 5g pst", "portal service 70s to org", "summon service to UC dm me",
		"warlock summons to UC 2g dm me", "summon service UC 10g, pst me", "WTS summon service to UC",
		"lf more customers, summon service to UC dm me 5g",
		"need a summon? pst me", "Need a summon to UC? whisper me", "need summons? 5g pst", "need summon service 5g dm me",
	})) do
		if r.v ~= "ignore" or not (r.why:find("seller word", 1, true) or r.why:find("advert phrase", 1, true)) then
			bad[#bad + 1] = r.line .. " => " .. r.v .. " (" .. r.why .. ")"
		end
	end
	assert(#bad == 0, "not seller: " .. table.concat(bad, "; "))
end)
-- guard: the same buyer lines without the weak words were leads or invites before
test("DS24-02 guard: plain buyer lines are not ignored as sellers", function()
	local bad = {}
	for _, r in ipairs(verdicts({
		"wtb summon to UC", "LF summon to UC", "anyone summon to UC?", "wtb summon to UC pls",
		"lf summon to Orgrimmar", "buying summon to UC", "need a summon to UC pls", "anyone doing summons to UC?",
	})) do
		if r.why:find("seller word", 1, true) or r.why:find("advert phrase", 1, true) then bad[#bad + 1] = r.line .. " (" .. r.why .. ")" end
	end
	assert(#bad == 0, table.concat(bad, "; "))
end)
