-- p242 group I: the editable blocked-word list (Core.Words) and AU24-23 (a place nickname in a driver's sentence).
-- Promise: one data table (W.Words) holds the blocked words; W.SPAM_WORDS is that same table; editing it at run
-- time changes SpamReason and SentenceSpam; ALLOWED_PLACES words (Org) pass in a driver's own sentence but a
-- service name still refuses them, and so does an address (".org").
local T = ...
local test, eq, ok = T.test, T.eq, T.ok

local function W()
	local w = T.newWorld()
	local r = T.rider(w, nil, { spot = "Undercity" })
	T.settle(w)
	return r.W
end

test("p242 I: W.SPAM_WORDS is the blocked list of the data file", function()
	local W = W()
	ok(W.Words and W.Words.BLOCKED and W.Words.ANYWHERE and W.Words.ALLOWED_PLACES, "W.Words has the three lists")
	ok(W.SPAM_WORDS == W.Words.BLOCKED, "same table")
end)

test("p242 I: a nickname of a place passes in a sentence, not in a service name", function()
	local W = W()
	eq(W.SentenceSpam("Summons to Org, UC and SW, tips welcome"), nil, "sentence")
	eq(W.SentenceSpam("Org"), nil, "just Org")
	ok(W.SpamReason("Org") ~= nil, "service name Org refused")
	ok(W.SpamReason("Summons to Org") ~= nil, "service name with Org refused")
	-- (the advert line itself, W.AdvertOwnText, calls W.SpamReason in Net/Outreach.lua: another group's file)
end)

-- guard: link-like and gold-selling text is refused as before, in a sentence and as a service name
test("p242 I: guards, links and gold selling still refused", function()
	local W = W()
	ok(W.SpamReason("abc org") ~= nil, "abc org as a service name")
	ok(W.SentenceSpam("see abc.org for gold") ~= nil, "gold in a sentence")
	ok(W.SentenceSpam("go to example.org now") ~= nil, ".org address in a sentence")
	ok(W.SentenceSpam("visit www.example.com") ~= nil, "www link")
	ok(W.SentenceSpam("cheap gold here") ~= nil, "cheap gold")
end)

-- guard: names that merely start with a blocked word pass
test("p242 I: Orgrimmar Express and Goldshire Cabs pass", function()
	local W = W()
	eq(W.SpamReason("Orgrimmar Express"), nil)
	eq(W.SpamReason("Goldshire Cabs"), nil)
	eq(W.SentenceSpam("Orgrimmar Express to Org"), nil)
end)

test("p242 I: editing the lists at run time takes effect", function()
	local W = W()
	eq(W.SpamReason("Fast Taxi"), nil)
	table.insert(W.Words.BLOCKED, "taxi")
	ok(W.SpamReason("Fast Taxi") ~= nil, "added blocked word refused in a service name")
	ok(W.SentenceSpam("a fast taxi") ~= nil, "added blocked word refused in a sentence")
	table.insert(W.Words.ALLOWED_PLACES, "taxi")
	eq(W.SentenceSpam("a fast taxi"), nil, "allowed place word passes in a sentence")
	ok(W.SpamReason("Fast Taxi") ~= nil, "still refused as a service name")
	table.insert(W.Words.ANYWHERE, "zzz")
	ok(W.SpamReason("abzzzcd") == "link", "anywhere word")
end)

test("p242 I: the advert line and a message template let Org through", function()
	local w = T.newWorld()
	local r = T.rider(w, nil, { spot = "Undercity" })
	T.settle(w)
	local W = r.W
	local DR = W.Drive
	local line, why = W.AdvertOwnText("Summons to Org, UC and SW, tips welcome")
	ok(line, "advert line refused: " .. tostring(why))
	ok(DR and DR.TemplateSpam, "DR.TemplateSpam")
	eq(DR.TemplateSpam("Summons to Org, thanks"), nil, "template")
end)

-- guard: gold and link adverts are still refused by the advert line and the template check
test("p242 I: a gold or link advert is still refused", function()
	local w = T.newWorld()
	local r = T.rider(w, nil, { spot = "Undercity" })
	T.settle(w)
	local W = r.W
	local DR = W.Drive
	local l1, w1 = W.AdvertOwnText("cheap gold at example.org")
	ok(not l1 and w1 == "spam", "gold advert")
	local l2 = W.AdvertOwnText("visit abc.org for rides")
	ok(not l2, "address advert")
	ok(DR and DR.TemplateSpam("buy gold www.x.com") ~= nil, "template")
end)
