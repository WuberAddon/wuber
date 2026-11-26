-- Group D (prep-242): AU24-11 refused reply is un-recorded; AU24-24 an Undo toast is never lost.
local T = ...
local test = T.test

local function ok(c, m) if not c then error(m, 2) end end

local function openOrgDriver()
	local w = T.newWorld()
	local a = T.driver(w, T.ANITA, { spot = "Orgrimmar" })
	T.settle(w)
	local DR = a.W.Drive
	DR.opts().autoInvite = true
	DR.opts().watchPublic = true
	assert(DR.SetOpen(true), "driver open in Orgrimmar")
	w:advance(3)
	return w, a, DR, (a.player and a.player.faction) or "Horde"
end

local function sayInTrade(w, faction, name, text)
	if not w:player(name) then w:addBot(name, { spot = "Ratchet", acceptsInvites = false, faction = faction }) end
	w:chatFrom(name, text, "CHANNEL", "Trade", faction)
	w:advance(0.5)
end

-- the promise: a refused send is not remembered, so after Retry the asker is answered
test("p242 D: a refused auto-reply is answered after Retry (db and session record undone)", function()
	local w, a, DR, faction = openOrgDriver()
	local ci = a.env.C_ChatInfo
	local real = ci.SendChatMessage
	ci.SendChatMessage = function() a:fire("ADDON_ACTION_BLOCKED", "Wuber", "SendChatMessage()") end
	sayInTrade(w, faction, "Dan Miller", "WTB summon to Orgrimmar")
	local r = a.W.db and a.W.db.drive and a.W.db.drive.replied or {}
	for k in pairs(r) do ok(false, "refused reply still recorded for " .. tostring(k)) end
	ci.SendChatMessage = real
	DR.Command("retry")
	w:advance(30)
	sayInTrade(w, faction, "Dan Miller", "WTB summon to Orgrimmar")
	ok(#w:whispersTo("Dan Miller", "reply") == 1, "Dan got no reply after Retry")
	T.clean(w)
end)

-- guard: a reply the game accepts is still remembered: a second ask within the hour gets no second whisper
test("p242 D: an accepted auto-reply is still sent once per hour", function()
	local w, a, DR, faction = openOrgDriver()
	sayInTrade(w, faction, "Dan Miller", "WTB summon to Orgrimmar")
	w:advance(30)
	sayInTrade(w, faction, "Dan Miller", "WTB summon to Orgrimmar")
	ok(#w:whispersTo("Dan Miller", "reply") == 1, "exactly one reply, got " .. #w:whispersTo("Dan Miller", "reply"))
	T.clean(w)
end)

local function portalUp()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, {})
	T.settle(w)
	local UI = r.W.UI
	UI.Toast("Click the portal now", "portal")
	return w, r, UI
end

for _, step in ipairs({ 1, 5 }) do
	test("p242 D: an Undo toast shows and works while the portal toast is up (step " .. step .. " s)", function()
		local w, r, UI = portalUp()
		w:advance(step)
		local undone = false
		local t = UI.UndoToast("3 settings reset.", function() undone = true end)
		ok(t ~= nil and UI.UndoPending(), "Undo toast shown")
		w:advance(step)
		ok(UI.UndoPending(), "still pending after " .. step .. " s")
		t.undo:GetScript("OnClick")(t.undo)
		ok(undone, "Undo ran")
		ok(not UI.UndoPending(), "gone after use")
		T.clean(w)
	end)
end

-- guard: a plain lesser toast within the portal window is still dropped (the portal call stays up)
test("p242 D: a plain info toast is still dropped while the portal toast is up", function()
	local w, r, UI = portalUp()
	w:advance(2)
	ok(UI.Toast("Something minor", "info") == nil, "lesser toast dropped")
	T.clean(w)
end)

-- guard: without a portal toast an Undo toast shows as before
test("p242 D: an Undo toast alone shows as before", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, {})
	T.settle(w)
	local t = r.W.UI.UndoToast("1 setting reset.", function() end)
	ok(t ~= nil and r.W.UI.UndoPending(), "shown")
	T.clean(w)
end)