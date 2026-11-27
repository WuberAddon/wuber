-- Module: Drive.Careful
-- Purpose: Strict auto-invite gate DR.Careful(text, channel, sender) and oops learning for whispers and public chat.
-- API: W.Drive, DR.Careful, DR.CanOops, DR.Oops, DR.OopsLog
-- Internals: (none)
-- Uses: Drive.Places
-- Later: Drive.Queue, Drive.Log (DR.Remove, DR.Changed, DR.CountWrong at run time)
-- Events: (none)
-- Standalone: no
-- Test: tests/v24/careful_test.lua
-- From: (new, Wuber 2.4)
--
-- Drive.Careful: decides whether a chat line clearly asks for a summon for the sender ("invite"),
-- should wait as a clickable lead ("lead"), or should be ignored in public chat ("ignore").
-- Strict on purpose: a wrong invite costs trust; a messy honest request costs one click.

local _, W = ...
local Mod = W.Module("Drive.Careful", { "Drive.Places" })
local PlacesMod = W.Mod("Drive.Places")
local SELL, SELLISH, ADVERT_PHRASES = PlacesMod.SELL, PlacesMod.SELLISH, PlacesMod.ADVERT_PHRASES

W.Drive = W.Drive or {}
local DR = W.Drive

local DEFAULT_KEYWORDS = { "summon", "summ", "sum", "inv", "invite", "ride", "taxi" }
local PRICE_WORDS = { "how much", "price", "cost", "fee", "charge" }
local EXTRA_SELL = { sellin = true, offers = true }
local EXTRA_ADVERT_PHRASES = { "whisper me", "dm me", "dm for", "pm for", "msg for", "w for", "hmu" }
local PRICE_UNITS = { g = true, s = true, c = true, gold = true, silver = true, copper = true }
local FROM_WORDS = { from = true, frm = true, fron = true, ["in"] = true, at = true, leaving = true, outside = true, near = true }
local THANKS = { ty = true, thx = true, thanks = true }
local POLITE = { pls = true, plz = true, please = true }
local BUYER_WORDS = { wtb = true, lf = true, lfs = true, lfg = true, looking = true, buy = true, buying = true, pay = true, paying = true, tip = true }
local NEED_WANT = { need = true, want = true }
local FIRST_PERSON_ASK = { "can i", "could i", "i need", "i want" }
local CAN_YOU_ASK = { "can u", "can you", "could you", "can someone" }
local PUBLIC_ASK_WORDS = {
	wtb = true, lf = true, lfs = true, lfg = true, need = true, want = true,
	buy = true, buying = true, pay = true, paying = true,
	pls = true, plz = true, please = true,
	anyone = true, anybody = true, someone = true, somebody = true,
}
local PUBLIC_ASK_PHRASES = {
	"looking for", "looking to", "can i", "could i", "can u", "can you", "could you",
	"summon me", "sum me", "summ me", "inv me", "invite me",
}
local FILLER = {
	hi = true, hey = true, hello = true,
	pls = true, plz = true, please = true,
	can = true, could = true, i = true, get = true, have = true,
	a = true, an = true, the = true, to = true, ["for"] = true,
	me = true, my = true, u = true, you = true,
	need = true, want = true, wtb = true, lf = true, lfs = true, lfg = true,
	looking = true, buy = true, buying = true, paying = true, pay = true, tip = true,
	will = true, ill = true, now = true, asap = true, ["if"] = true, possible = true,
	mate = true, bro = true, ["and"] = true, at = true, ["in"] = true, from = true,
	im = true, am = true, ok = true, ["then"] = true, someone = true, again = true,
	-- (lead, from the larger gauntlet's missed requests: each was tried against all its never-invite and unclear lines)
	fast = true, quick = true, quickly = true, yo = true, sir = true, plss = true, plzz = true,
}

local function hasPhrase(norm, phrase)
	return norm:find(" " .. phrase .. " ", 1, true) ~= nil
end

local function hasAnyPhrase(norm, list)
	for _, p in ipairs(list) do
		if hasPhrase(norm, p) then return true end
	end
	return false
end

local function driverKeywords()
	local opts = DR.opts and DR.opts()
	local list = (opts and type(opts.keywords) == "table" and opts.keywords) or DR.KEYWORDS or DEFAULT_KEYWORDS
	local set = {}
	for _, kw in ipairs(list) do
		kw = tostring(kw):lower()
		if kw ~= "" then set[kw] = true end
	end
	return set
end

-- (AU24-03) "whisper"/"ready" and "whisper me" are advert words only when the line does not ask to buy
local SOFT_SELL = { whisper = true, whisp = true, wisp = true, ready = true }
local function asksToBuy(words)
	for _, w in ipairs(words) do
		if w == "wtb" or w == "lf" or w == "lfs" or w == "lfg" then return true end
		local rest = w:match("^lf(s?u?m+o?n?s?)$") or w:match("^wtb(s?u?m+o?n?s?)$")
		if rest and rest ~= "" and rest:find("^s?um") then return true end
	end
	return false
end

-- (DS24-02) soft: the line clearly asks for a summon (wtb/lf/buying/paying, or anyone/someone with a "?") and names
-- no price, so the weak advert words (service, dm, pst ...) and "dm me" do not make it an advert
local SOFT_PHRASES = { ["dm me"] = true, ["dm for"] = true }
local function findSeller(norm, words, soft)
	local buyer = asksToBuy(words)
	for _, w in ipairs(words) do
		if buyer and SOFT_SELL[w] then
			-- a buyer line: not a seller word
		elseif (SELL and SELL[w]) or EXTRA_SELL[w] or (not soft and SELLISH and SELLISH[w]) then
			return "seller word: " .. w
		end
	end
	if ADVERT_PHRASES then
		for _, p in ipairs(ADVERT_PHRASES) do
			if hasPhrase(norm, p) then return "advert phrase: " .. p end
		end
	end
	for _, p in ipairs(EXTRA_ADVERT_PHRASES) do
		if not (soft and SOFT_PHRASES[p]) and not (buyer and p == "whisper me") and hasPhrase(norm, p) then return "advert phrase: " .. p end
	end
	return nil
end

local SOFT_ASK = { wtb = true, lf = true, lfs = true, lfg = true, looking = true, buy = true, buying = true, pay = true, paying = true }
local SOFT_MAYBE = { anyone = true, anybody = true, someone = true, somebody = true }
-- "need ... summon" with no question mark, and "pls/plz/please", are a buyer's wording (a seller asks "need a summon?")
local SOFT_PLEASE = { pls = true, plz = true, please = true }
local function clearBuyerAsk(text, words)
	local maybe = false
	local asked = text:find("?", 1, true) ~= nil
	local need, summon = false, false
	for i, w in ipairs(words) do
		if SOFT_ASK[w] or SOFT_PLEASE[w] then maybe = true end
		if w == "need" or w == "needs" then need = true end
		if w:match("^summon") then summon = true end
		if SOFT_MAYBE[w] and text:find("?", 1, true) then maybe = true end
		if w:match("^%d+[gsc]$") or w:match("^%d+g%d+s$") or w:match("^%d+s%d+c$")
			or (PRICE_UNITS[w] and i > 1 and words[i - 1]:match("^%d+$")) then return false end
	end
	return maybe or (need and summon and not asked)
end

local function isNumberOrPrice(words, i)
	local w = words[i]
	if w:match("^%d+$") or w:match("^%d+[gsc]$") then return true end
	if w:match("^%d+g%d+s$") or w:match("^%d+s%d+c$") then return true end
	if PRICE_UNITS[w] and i > 1 and words[i - 1]:match("^%d+$") then return true end
	return false
end

local function hasPrice(words)
	for i, w in ipairs(words) do
		if w:match("^%d+[gsc]$") or w:match("^%d+g%d+s$") or w:match("^%d+s%d+c$") then return true end
		if PRICE_UNITS[w] and i > 1 and words[i - 1]:match("^%d+$") then return true end
	end
	return false
end

local function hasPublicAsk(norm, words)
	for _, w in ipairs(words) do
		if PUBLIC_ASK_WORDS[w] then return true end
	end
	return hasAnyPhrase(norm, PUBLIC_ASK_PHRASES)
end

-- Position where a location tail ("I'm at ...", "I'm in ...", "at the ...", "in the ...") starts after a request.
local function findTail(words)
	for i = 2, #words - 1 do
		local w, nxt = words[i], words[i + 1]
		if w == "im" and (nxt == "at" or nxt == "in") then return i end
		if (w == "at" or w == "in") and nxt == "the" then return i end
		if w == "i" and nxt == "am" and (words[i + 2] == "at" or words[i + 2] == "in") then return i end
	end
	return nil
end

-- Mark word indices covered by places found by DR.Mentions, and report whether any is a destination (not from/in/at).
local function markPlaces(words)
	local mine, others = DR.Mentions(words)
	local placePos, hasDest = {}, false
	local function scan(list)
		for _, m in ipairs(list) do
			local before = words[m.at - 1]
			if before == "the" then before = words[m.at - 2] end
			if not (before and FROM_WORDS[before]) then hasDest = true end
			local name = tostring(m.name or "")
			local nw = 1
			for _ in name:gmatch(" ") do nw = nw + 1 end
			if nw == 1 then
				placePos[m.at] = true
			elseif m.at + nw - 1 <= #words then
				local chunk = table.concat(words, " ", m.at, m.at + nw - 1)
				local limit = #name < 6 and 0 or (#name < 8 and 1 or 2)
				if chunk == name or (limit > 0 and #chunk >= 4 and DR.Distance(chunk, name, limit) <= limit) then
					for k = m.at, m.at + nw - 1 do placePos[k] = true end
				else
					placePos[m.at] = true
				end
			else
				placePos[m.at] = true
			end
		end
	end
	scan(mine)
	scan(others)
	return placePos, hasDest
end

local function checkWhisper(text, norm, allWords)
	if text:lower():find("[wuber]", 1, true) then return false, "wuber advert" end
	if #text > 80 then return false, "too long" end
	local lower = text:lower()
	for _, p in ipairs(PRICE_WORDS) do
		if lower:find(p, 1, true) then return false, "price question" end
	end
	local seller = findSeller(norm, allWords, clearBuyerAsk(text, allWords))
	if seller then return false, seller end
	local stripped = text:gsub("\226\128\153", "")
	if stripped:find("[\128-\255]") then return false, "word not understood" end
	for i, w in ipairs(allWords) do
		if THANKS[w] and (i < #allWords or #allWords < 2 or allWords[i - 1] == "for") then
			return false, "thanks about the past"
		end
	end
	local words = allWords
	local tailAt = findTail(allWords)
	if tailAt then
		words = {}
		for i = 1, tailAt - 1 do words[i] = allWords[i] end
	end
	local kw = driverKeywords()
	local reqPos, hasReq, hasActionReq = {}, false, false
	for i, w in ipairs(words) do
		if kw[w] or (DR.Summonish and DR.Summonish(w)) then
			reqPos[i] = true
			hasReq = true
			if w ~= "summoner" and w ~= "summoning" then hasActionReq = true end
		end
	end
	if not hasReq then return false, "no request word" end
	local placePos, hasDest = markPlaces(words)
	for i, w in ipairs(words) do
		local understood = reqPos[i] or placePos[i] or FILLER[w] or isNumberOrPrice(words, i)
			or (THANKS[w] and i == #words)
		if not understood then return false, "word not understood: " .. w end
	end
	for i, w in ipairs(words) do
		if reqPos[i] then
			local nxt, prv = words[i + 1], words[i - 1]
			if nxt == "u" or nxt == "you" then return false, "an offer, not a request" end
			if prv == "i" or prv == "ill" then return false, "an offer, not a request" end
			if (prv == "can" or prv == "could" or prv == "will")
				and not ((words[i - 2] == "u" or words[i - 2] == "you") and nxt == "me") then
				return false, "an offer, not a request"
			end
		end
		if w == "for" and (words[i + 1] == "u" or words[i + 1] == "you") then
			return false, "an offer, not a request"
		end
	end
	local hasMe, hasPolite, hasBuyer, hasNeedWant = false, false, false, false
	for _, w in ipairs(words) do
		if w == "me" then hasMe = true end
		if POLITE[w] then hasPolite = true end
		if BUYER_WORDS[w] then hasBuyer = true end
		if NEED_WANT[w] then hasNeedWant = true end
	end
	local prefixNorm = " " .. table.concat(words, " ") .. " "
	local hasFirstAsk = hasAnyPhrase(prefixNorm, FIRST_PERSON_ASK)
	local hasCanYou = hasAnyPhrase(prefixNorm, CAN_YOU_ASK)
	if not hasActionReq and not (hasPolite or hasBuyer or hasNeedWant) then
		return false, "an offer, not a request"
	end
	if text:find("?", 1, true) and not (hasPolite or hasBuyer or hasFirstAsk or hasMe) then
		return false, "a question"
	end
	if hasPrice(words) and not (hasPolite or hasBuyer or hasNeedWant or hasFirstAsk or hasMe) then
		return false, "no asking word"
	end
	-- a bare request word ("inv", "summ") is not clear enough: the gauntlet marks it unclear, so it is a lead
	if not (hasPolite or hasBuyer or hasNeedWant or hasFirstAsk or hasCanYou or hasMe or hasDest) then
		return false, "no asking word"
	end
	return true, "clear request"
end

local OOPS_MAX = 200
local lastOopsAt = 0

local function oopsStamp()
	local t = (W.Now and W.Now()) or 0
	if t <= lastOopsAt then t = lastOopsAt + 0.0001 end
	lastOopsAt = t
	return t
end

local function oopsDB(create)
	local db = type(DR.db) == "table" and DR.db
		or (type(W.db) == "table" and type(W.db.drive) == "table" and W.db.drive) or nil
	if not db then return nil end
	local o = db.oops
	if type(o) ~= "table" then
		if not create then return nil end
		o = { players = {}, lines = {}, log = {} }
		db.oops = o
	end
	if create then
		if type(o.players) ~= "table" then o.players = {} end
		if type(o.lines) ~= "table" then o.lines = {} end
		if type(o.log) ~= "table" then o.log = {} end
	end
	return o
end

local function putCapped(map, key, at, max)
	if map[key] ~= nil then
		map[key] = at
		return
	end
	local count = 0
	for _ in pairs(map) do count = count + 1 end
	while count >= max do
		local oldK, oldT
		for k, v in pairs(map) do
			local tv = tonumber(v) or 0
			if not oldK or tv < oldT or (tv == oldT and tostring(k) < tostring(oldK)) then
				oldK, oldT = k, tv
			end
		end
		if not oldK then break end
		map[oldK] = nil
		count = count - 1
	end
	map[key] = at
end

local function oopsReason(text, sender)
	local o = oopsDB(false)
	if not o then return nil end
	local key = type(sender) == "string" and sender ~= "" and W.Key(sender) or nil
	if key and type(o.players) == "table" and o.players[key] then
		return "you marked this player's invite as wrong"
	end
	local norm = DR.Norm and DR.Norm(text) or nil
	if type(norm) == "string" and norm:match("%S") and type(o.lines) == "table" and o.lines[norm] then
		return "you marked these words as a wrong invite"
	end
	return nil
end

function DR.CanOops(c)
	if type(c) ~= "table" then return false end
	if not c.auto or c.auto == "" then return false end
	if c.state == "lead" or c.state == "paid" or c.state == "done" then return false end
	if c.oops then return false end
	-- (lead review) only the group's leader can take somebody out: in a crew, the oops lives in the leader's window
	if W.InGroup and W.InGroup() and DR.IsLeader and not DR.IsLeader() then return false end
	return true
end

function DR.Oops(c)
	if not DR.CanOops(c) then return false end
	local key = c.key or (type(c.name) == "string" and W.Key(c.name)) or nil
	local o = oopsDB(true)
	if o then
		local at = oopsStamp()
		if type(key) == "string" and key ~= "" then
			putCapped(o.players, key, at, OOPS_MAX)
		end
		local raw = type(c.autoMsg) == "string" and c.autoMsg or ""
		local norm = (raw ~= "" and DR.Norm) and DR.Norm(raw) or ""
		if type(norm) == "string" and norm:match("%S") then
			putCapped(o.lines, norm, at, OOPS_MAX)
			o.log[#o.log + 1] = { text = raw, at = at }
			while #o.log > OOPS_MAX do table.remove(o.log, 1) end
		end
	end
	if type(DR.CountWrong) == "function" then DR.CountWrong(c) end
	c.oops = true
	-- (R50-03) the player said this invite was wrong: the row is no automatic invite any more (no Oops again, no
	-- self-sent lines in Drive.AutoLines); what it was is kept in c.wrongAuto
	c.wrongAuto, c.auto = c.auto, nil
	local inGroup = type(DR.units) == "table" and key ~= nil and DR.units[key] ~= nil
	if c.state == "queued" and not inGroup then
		if type(DR.Remove) == "function" then DR.Remove(c, "oops") end
	else
		if type(DR.Changed) == "function" then DR.Changed() end
	end
	return true
end

function DR.OopsLog(n)
	local limit = tonumber(n)
	if not limit then limit = 10 end
	local out = {}
	if limit <= 0 then return out end
	local o = oopsDB(false)
	local log = o and type(o.log) == "table" and o.log or nil
	if not log then return out end
	for i = #log, 1, -1 do
		local entry = log[i]
		local text = type(entry) == "table" and entry.text or (type(entry) == "string" and entry or nil)
		if type(text) == "string" and text ~= "" then
			out[#out + 1] = text
			if #out >= limit then break end
		end
	end
	return out
end

-- Decides whether a chat line clearly asks for a summon for the sender.
-- channel: "whisper" or "public". sender: optional player name. Returns verdict ("invite", "lead", "ignore") and a plain reason.
function DR.Careful(text, channel, sender)
	local isPublic = channel == "public"
	if type(text) ~= "string" or text:match("^%s*$") then
		return isPublic and "ignore" or "lead", "empty"
	end
	local norm = DR.Norm((text:gsub(">+", " to ")))
	local allWords = {}
	for w in norm:gmatch("%S+") do allWords[#allWords + 1] = w end
	if #allWords == 0 then
		return isPublic and "ignore" or "lead", "empty"
	end
	if not isPublic then
		local okW, reason = checkWhisper(text, norm, allWords)
		if okW then
			if not (DR.WuberLine and DR.WuberLine(text)) then
				local oopsWhy = oopsReason(text, sender)
				if oopsWhy then return "lead", oopsWhy end
			end
			return "invite", reason
		end
		return "lead", reason
	end
	if text:lower():find("[wuber]", 1, true) then return "ignore", "wuber advert" end
	if DR.HasGameLink and DR.HasGameLink(text) then return "ignore", "game link" end
	local seller = findSeller(norm, allWords, clearBuyerAsk(text, allWords))
	if seller then return "ignore", seller end
	local want = DR.PublicWant and DR.PublicWant(text)
	-- (lead review) the third value is what DR.PublicWant said, so the caller does not ask it twice
	if not want or want == "elsewhere" then
		return "ignore", want == "elsewhere" and "another place" or "not a buyer", want
	end
	local hasAsk = hasPublicAsk(norm, allWords)
	local hasQ = text:find("?", 1, true) ~= nil
	if not hasAsk and not hasQ then return "ignore", "no asking word", nil end
	if want == "match" and hasAsk then
		local okW, reason = checkWhisper(text, norm, allWords)
		if okW then
			local oopsWhy = oopsReason(text, sender)
			if oopsWhy then return "lead", oopsWhy, want end
			return "invite", reason, want
		end
		return "lead", reason, want
	end
	return "lead", not hasAsk and "no asking word" or (want == "noplace" and "no place named" or "unclear destination"), want
end
