-- Tests of blocked-for-not-paying toast when a rider asks for a summon again (item 2.4.4).
local T = ...
local test, eq, ok = T.test, T.eq, T.ok
local ANITA = T.ANITA or "Anita Lift"

local function scene()
	local w = T.newWorld()
	local a = w:addClient(ANITA, { spot = "Undercity", class = "WARLOCK", allowMissing = true })
	local DR = a.W.Drive
	DR.SetOpen(true)
	w:addBot("Dan Miller", { spot = "Orgrimmar" })
	w:addBot("Bob Green", { spot = "Orgrimmar" })
	return w, a, DR
end

local function unpaidRide(w, a, DR)
	a:chatEvent("CHAT_MSG_WHISPER", "summon pls", "Dan Miller")
	w:advance(3)
	DR.Do("CAST", "Dan Miller")
	DR.Do("END", "Dan Miller", 1)
	w:move("Dan Miller", "Undercity")
	w:advance(2)
	w:leave("Dan Miller")
	w:advance(3)
end

local function captureToasts(a)
	local toasts = {}
	local real = a.W.UI.Toast
	a.W.UI.Toast = function(text, kind, fn)
		toasts[#toasts + 1] = { text = text, kind = kind }
		return real(text, kind, fn)
	end
	return toasts, function() a.W.UI.Toast = real end
end

local function countMatching(toasts, exact)
	local n = 0
	for _, t in ipairs(toasts) do
		if t.text == exact then n = n + 1 end
	end
	return n
end

local function whispersSentTo(a, target)
	local n = 0
	for _, m in ipairs(a.sentChat or {}) do
		if m.kind == "WHISPER" and m.target == target then n = n + 1 end
	end
	return n
end

test("2.4.4 blocked_toast: unpaid rider whisper shows exact toast, 60s cooldown, no whisper sent", function()
	local w, a, DR = scene()
	unpaidRide(w, a, DR)
	ok(DR.BlockEntry("dan miller"), "blocked after unpaid ride")

	local toasts, restore = captureToasts(a)
	local sentBefore = whispersSentTo(a, "Dan Miller")

	-- 1. First ask after block -> toast shows with exact wording
	a:chatEvent("CHAT_MSG_WHISPER", "summon please", "Dan Miller")
	w:advance(1)
	eq(countMatching(toasts, "Dan asked again: blocked for not paying."), 1, "first ask shows exact toast")
	eq(whispersSentTo(a, "Dan Miller"), sentBefore, "no message sent to rider on first ask")

	-- 2. Second ask within 60s -> no second toast
	w:advance(30)
	a:chatEvent("CHAT_MSG_WHISPER", "summon please", "Dan Miller")
	w:advance(1)
	eq(countMatching(toasts, "Dan asked again: blocked for not paying."), 1, "no second toast within 60s")
	eq(whispersSentTo(a, "Dan Miller"), sentBefore, "no message sent to rider on second ask")

	-- 3. After 60s -> shows again
	w:advance(30)
	a:chatEvent("CHAT_MSG_WHISPER", "summon please", "Dan Miller")
	w:advance(1)
	eq(countMatching(toasts, "Dan asked again: blocked for not paying."), 2, "shows again after 60s")
	eq(whispersSentTo(a, "Dan Miller"), sentBefore, "no message sent to rider after 60s")

	restore()
	T.clean(w)
end)

-- guard: the negative cases (no toast for unblocked riders, manual blocks, unblocked after unpaid) hold on the base too, by design
test("2.4.4 blocked_toast: unblocked rider and non-nonpay blocked rider get no toast", function()
	local w, a, DR = scene()
	local toasts, restore = captureToasts(a)

	-- 4a. Unblocked rider asks -> no blocked toast
	a:chatEvent("CHAT_MSG_WHISPER", "summon please", "Bob Green")
	w:advance(1)
	eq(countMatching(toasts, "Bob asked again: blocked for not paying."), 0, "unblocked rider gets no toast")

	-- 4b. Rider blocked for another reason -> no non-paying toast
	DR.Blacklist("Eva White", "blocked by hand")
	w:addBot("Eva White", { spot = "Orgrimmar" })
	a:chatEvent("CHAT_MSG_WHISPER", "summon please", "Eva White")
	w:advance(1)
	eq(countMatching(toasts, "Eva asked again: blocked for not paying."), 0, "manual block gets no non-paying toast")

	-- 4c. Rider unblocked after unpaid ride -> no toast
	unpaidRide(w, a, DR)
	DR.Unblacklist("Dan Miller")
	a:chatEvent("CHAT_MSG_WHISPER", "summon please", "Dan Miller")
	w:advance(1)
	eq(countMatching(toasts, "Dan asked again: blocked for not paying."), 0, "unblocked after unpaid gets no toast")

	restore()
	T.clean(w)
end)

test("2.4.4 blocked_toast: Wuber app request from unpaid blocked rider shows toast with 60s cooldown", function()
	local w, a, DR = scene()
	unpaidRide(w, a, DR)
	ok(DR.BlockEntry("dan miller"), "blocked after unpaid ride")

	local toasts, restore = captureToasts(a)
	local sentBefore = whispersSentTo(a, "Dan Miller")

	DR.ENGINE.onRequest({ id = "r-blocked-1", buyer = "Dan Miller", dest = "Undercity", price = 50000 })
	w:advance(1)
	eq(countMatching(toasts, "Dan asked again: blocked for not paying."), 1, "Wuber request shows exact toast")
	eq(whispersSentTo(a, "Dan Miller"), sentBefore, "no whisper sent on Wuber request")

	w:advance(20)
	DR.ENGINE.onRequest({ id = "r-blocked-2", buyer = "Dan Miller", dest = "Undercity", price = 50000 })
	w:advance(1)
	eq(countMatching(toasts, "Dan asked again: blocked for not paying."), 1, "no second toast within 60s for Wuber request")

	w:advance(45)
	DR.ENGINE.onRequest({ id = "r-blocked-3", buyer = "Dan Miller", dest = "Undercity", price = 50000 })
	w:advance(1)
	eq(countMatching(toasts, "Dan asked again: blocked for not paying."), 2, "shows again after 60s for Wuber request")

	restore()
	T.clean(w)
end)
