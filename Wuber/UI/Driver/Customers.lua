-- Module: UI.Driver.Customers
-- Purpose: the customer book on the driver's console (round 9, Y1 and Y3): the row menu's "Get Wuber",
--   "Note..." and "Gifted" items, the note and gift marks on queue rows and their tooltip lines, the
--   Note sheet (the note, the Gifted stamp, the facts from the log) and the Customers screen (search,
--   newest ride first; the footer's Customers link). (BRIEF17) Where "Get Wuber" isn't offered, the
--   menu, the Note sheet and the Customers pane say why; the list says it scrolls; Save says only
--   what it did, and an empty Save over a note asks once before it removes it.
-- API: D.CustomerMenu, D.CustomerPick, D.CustomerTip, D.PaintMarks, D.CustomerFacts, D.CrewOwnMark,
--   D.screens.note, D.screens.customers, D.FOLD.customers
--   (design 4, H) a rider who left owing gets one more pill on the Note sheet and the side pane (Advanced only):
--   "Don't serve again until <date>" (Drive.Book's DR.ServeHold: the driver's own, never sent), a click sets or lifts it
-- Internals: SERVE (its words), serveLook, serveClick, dayText, factsText, noteRow, giftOf, giftLook / giftTip (round 13: the tick and "a free ride"),
--   liveCustomer (BRIEF19 F4: the queue's own customer, for the right pane's Invite to Wuber pill),
--   savedFlash / savedReset (Save says "Saved"), askPaint (BRIEF20 B1: "Remove note?" is its own pill,
--   shown or hidden), appWhy / APP_WHY (why no "Get Wuber"), saveNote (one
--   Save's outcome), scrollCue (the Customers list's "Scroll for N more"),
--   r.shownTip (a row's tooltip follows a note saved under it); Mod.WhyInvite (/wuber why: why the Invite
--   to Wuber pill is not on the right pane)
-- Uses: UI.Driver.Screens
-- Later: UI.Driver.Console (D.SidePane, D.WideLayout's D.wide, run time); the "Mail seen" line on a row's
--   tooltip and under a customer's name is Drive.Mail's (DR.MailNote, through the customer book)
-- Events: (none: UI.Driver.Sheets' row menu calls D.CustomerMenu / D.CustomerPick, UI.Driver.Rows calls
--   D.CustomerTip / D.PaintMarks, UI.Driver.Crew's member cards call D.CrewOwnMark; the data is
--   Drive.Book's; the menu's "Get Wuber" pick is UI.Driver.Rows' D.ToggleGetApp, as the row's pill)
-- Standalone: no
-- Test: tests/ui/driver/customers_test.lua
-- From: new in Wuber 2.3.0 round 9 (FIXROUND-2.3.0 items 1 and 3)
--
-- Nothing here is made until it is first used (a row with a note, the menu opened, the screen shown),
-- so a driver without notes has the same frames as before. The note is the driver's alone: only this
-- driver and the crew windows it marked "My own account" (on their Crew cards) ever see it
-- (Drive.Book), never the rider.

local _, W = ...
local Mod = W.Module("UI.Driver.Customers", { "UI.Driver.Screens" })
local ScreensMod = W.Mod("UI.Driver.Screens")
local INNER, PAD, Pool, Screen = ScreensMod.INNER, ScreensMod.PAD, ScreensMod.Pool, ScreensMod.Screen
local dr, para, plural, safeScript = ScreensMod.dr, ScreensMod.para, ScreensMod.plural, ScreensMod.safeScript
local setShown, short, st, toast = ScreensMod.setShown, ScreensMod.short, ScreensMod.st, ScreensMod.toast
local T = W.Theme
local function wrapH(n, size) return n * T.DrawnSize(size) + (n - 1) * T.Spacing(size) end -- n wrapped lines, spacing between them

local DR = W.Drive
local D = W.Driver

local S, N = W.Str, W.Num

local function adv() return type(W.Advanced) ~= "function" or W.Advanced() == true end

local LIST_MAX = 100 -- rows drawn on the Customers screen (search for the rest)
local REMOVE_SECS = 5 -- (BRIEF17 B1) an empty Save over a note asks this long ("Remove note?")
local SAVED_SECS = 2 -- a Save says "Saved" with a tick this long (round 12)
local SAVED_CLOSE = 1.2 -- the folded Note sheet closes this long after its Save
local ROW_H = 54
local SUB_W = INNER - 80 -- the line under a customer's name (clear of the note and gift marks)

-- "19 Nov" (an epoch), or nil
local function dayText(t)
	t = N(t)
	if not t or type(date) ~= "function" then return nil end
	local ok, s = pcall(date, "%d %b", t)
	if not ok or type(s) ~= "string" then return nil end
	return (s:gsub("^0", ""))
end

local function entry(name)
	local rec = dr("BookEntry", name)
	return type(rec) == "table" and rec or nil
end

local function giftOf(name)
	local rec = entry(name)
	return rec and N(rec.gift) or nil
end

-- "3 rides with you · last 12 Nov · Orgrimmar" (from the earnings log), or "No rides with you yet"
local function factsText(name)
	local f = dr("CustomerFacts", name)
	if type(f) ~= "table" or (N(f.rides) or 0) < 1 then return "No rides with you yet" end
	local parts = { plural(N(f.rides) or 0, "ride") .. " with you" }
	local day = dayText(f.last)
	if day then parts[#parts + 1] = "last " .. day end
	if S(f.place) then parts[#parts + 1] = W.Clean(S(f.place), 24) end
	return table.concat(parts, " · ")
end
D.CustomerFacts = factsText

---------------------------------------------------------------------------
-- The row menu (UI.Driver.Sheets): "Get Wuber", and Note... | Gifted on one row
---------------------------------------------------------------------------

local function getappWords(state)
	if state == "queued" then
		return "Cancel \"Get Wuber\"", "Not sent yet: your next big-button click would send it"
	end
	return "Send \"Get Wuber\"", "Your next big-button click whispers how to get Wuber"
end

-- (BRIEF17 B3) why "Get Wuber" isn't offered (DR.GetAppState), as the menu line and its sub
local APP_WHY = {
	app = { "Already uses Wuber", "No need to tell them about it" },
	crew = { "Already uses Wuber", "One of your crew" },
	sent = { "Sent \"Get Wuber\" today", "Once a day per rider: again tomorrow" },
	off = { "\"Get Wuber\" is off", "Whispers are off, or its message is empty (Messages)" },
}
local APP_WHY_TIP = "\"Get Wuber\" whispers a rider who asked in chat how to get Wuber. It isn't offered to"
	.. " riders Wuber knows run it, more than once a day, or while whispers are off."

-- the live queue customer of this name (its "Get Wuber" may be queued), else a plain one
local function customerOf(name)
	local k = W.Key(S(name) or "")
	local cs = DR.customers
	local c = k and type(cs) == "table" and cs[k] or nil
	if type(c) ~= "table" and type(cs) == "table" then
		for _, x in pairs(cs) do
			if type(x) == "table" and S(x.name) and (x.name == name or W.Key(x.name) == k) then c = x end
		end
	end
	return type(c) == "table" and c or { name = name, key = k }
end

-- the queue's own customer of this name (what a queue row acts on), or nil
local function liveCustomer(name)
	local c = customerOf(name)
	local cs = DR.customers
	if type(cs) == "table" and c.key and cs[c.key] == c then return c end
	return nil
end

-- one short line on this customer's Wuber: why "Get Wuber" isn't offered, or that it waits (nil: say
-- nothing). brief: the short form for a header; c: their queue row's customer, when the caller has it.
local function appWhy(name, brief, c)
	if not S(name) then return nil end
	local state = dr("GetAppState", type(c) == "table" and c or customerOf(name), true) -- read only (painting)
	if APP_WHY[state] then return APP_WHY[state][1] end
	if state == "queued" then return brief and "\"Get Wuber\" queued" or "\"Get Wuber\" goes with your next big-button click" end
	return nil
end

-- the Note... | Gifted row: two buttons (132 | 180: "Gifted 15 Nov" is the longer words) in one 320 x 46 frame
local function noteRow(s, b)
	local f = CreateFrame("Frame", nil, b)
	f:SetSize(320, 46)
	f.note = T.ListButton(f, 132, 46, "Note...", nil, "note", "glow")
	f.note:SetPoint("LEFT", f, "LEFT", 0, 0)
	safeScript(f.note, "OnClick", function() s.pick("note") end)
	T.Tip(f.note, "Note", function()
		local rec = entry(s.c and s.c.name)
		return (rec and S(rec.note) and ("\"" .. rec.note .. "\"\n\n") or "")
			.. "Your own note about this rider. Only you and the crew windows you marked as your own accounts see it; the rider never does."
	end)
	f.gift = T.ListButton(f, 180, 46, "Gifted", nil, "gift", "glow")
	f.gift:SetPoint("RIGHT", f, "RIGHT", 0, 0)
	safeScript(f.gift, "OnClick", function() s.pick("gifted") end)
	T.Tip(f.gift, "Gifted", function()
		local at = giftOf(s.c and s.c.name)
		if at then return "You gave them a ride as a gift on " .. (dayText(at) or "?") .. ". The stamp stops you gifting them twice." end
		return "Click when you give this rider a ride as a gift: it stamps today's date, so you never gift the same person twice. Your own accounts (marked on the Crew page) get the stamp too."
	end)
	return f
end

-- (UI.Driver.Sheets' s.layout) adds this rider's items to the menu's list, before "helper".
function D.CustomerMenu(s, list, item, c)
	if not adv() then return end
	if type(c) ~= "table" or not S(c.name) or S(c.helperOf) or c.iouOnly or s.raid then return end
	local add = {}
	local state = dr("GetAppState", c)
	if state == "ok" or state == "queued" then
		local text, sub = getappWords(state)
		if not s.items.getapp then
			item("getapp", text, sub, "chat", "glow")
			T.Tip(s.items.getapp, "Get Wuber", function()
				return "For a rider who asked in chat, not through the app: whispers them how to get Wuber ("
					.. "edit it in Messages). Only when you click the big button, at most once a day per rider."
			end)
		end
		s.items.getapp.label:SetText(text)
		s.items.getapp.sub:SetText(sub)
		add[#add + 1] = "getapp"
	elseif APP_WHY[state] then
		-- (BRIEF17 B3) not offered: a quiet line says why, so the item never just vanishes
		local why = APP_WHY[state]
		if not s.items.getappwhy then
			item("getappwhy", why[1], why[2], "portal", "muted")
			T.Tip(s.items.getappwhy, "Get Wuber", APP_WHY_TIP)
		end
		local r = s.items.getappwhy
		r.label:SetText(why[1])
		r.label:SetTextColor(T.RGB("muted"))
		r.sub:SetText(why[2])
		add[#add + 1] = "getappwhy"
	end
	if not s.items.custnote then s.items.custnote = noteRow(s, s.frame.body) end
	local at = giftOf(c.name)
	local row = s.items.custnote
	row.gift.label:SetText(at and ("Gifted " .. (dayText(at) or "")) or "Gifted")
	row.gift.label:SetTextColor(T.RGB(at and "muted" or "white"))
	local rec = entry(c.name)
	row.note.label:SetText((rec and S(rec.note)) and "Edit note" or "Note...")
	add[#add + 1] = "custnote"
	local at2 = #list + 1
	for i, id in ipairs(list) do
		if id == "helper" then
			at2 = i
			break
		end
	end
	for i, id in ipairs(add) do table.insert(list, at2 + i - 1, id) end
end

-- (UI.Driver.Sheets' s.pick) true when the item was one of these.
function D.CustomerPick(s, id)
	local c = s.c
	if id == "getapp" then
		D.ToggleGetApp(c) -- (BRIEF17 B2) the same as the row's pill (UI.Driver.Rows)
		s.frame:Close()
		D.Refresh(true)
		return true
	elseif id == "getappwhy" then
		return true -- a reason, not an action: the menu stays
	elseif id == "note" then
		s.frame:Close(true)
		D.ShowSheet("note", c)
		return true
	elseif id == "gifted" then
		local okG, at = dr("SetGifted", c and c.name)
		if okG then
			toast(short(c and c.name) .. " stamped gifted " .. (dayText(at) or "today"), "info")
		else
			toast(short(c and c.name) .. " was already gifted on " .. (dayText(at) or "?"), "info")
		end
		s.frame:Close()
		D.Refresh(true)
		return true
	end
	return false
end

---------------------------------------------------------------------------
-- Queue rows (UI.Driver.Rows): the marks and the tooltip lines
---------------------------------------------------------------------------

-- (D.RowTip) the note and the stamp, only when there are some
function D.CustomerTip(c, lines)
	if type(c) ~= "table" or not S(c.name) then return end
	local rec = entry(c.name)
	if rec and S(rec.note) then lines[#lines + 1] = "Note: " .. W.Clean(rec.note, 200) end
	if rec and N(rec.gift) then lines[#lines + 1] = "Gifted on " .. (dayText(rec.gift) or "?") .. ": you gave them a ride as a gift." end
	if dr("GetAppState", c) == "queued" then lines[#lines + 1] = "\"Get Wuber\" goes with your next big-button click." end
	-- (payment by mail, Drive.Mail) "Mail seen: 5g from Dan, 21 Nov.": what lay in the mailbox, never "paid"
	local mail = S(dr("MailNote", c.name))
	if mail then lines[#lines + 1] = mail end
end

-- (D.PaintRow; c = nil for a raid row) a small note mark (top-right) and gift mark (bottom-left) on the ring, made on first use
function D.PaintMarks(r, c)
	local rec = type(c) == "table" and S(c.name) and entry(c.name) or nil
	local hasNote, hasGift = rec ~= nil and S(rec.note) ~= nil, rec ~= nil and N(rec.gift) ~= nil
	if hasNote and not r.noteMark then
		r.noteMark = T.Icon(r, "note", 13, "glow", "OVERLAY")
		r.noteMark:SetPoint("CENTER", r.disc, "TOPRIGHT", -2, -3)
	end
	if hasGift and not r.giftMark then
		r.giftMark = T.Icon(r, "gift", 13, "glow", "OVERLAY")
		r.giftMark:SetPoint("CENTER", r.disc, "BOTTOMLEFT", 2, 3) -- bottom-left: the Pioneer badge has the top-left
	end
	if r.noteMark then setShown(r.noteMark, hasNote) end
	if r.giftMark then setShown(r.giftMark, hasGift) end
	-- round 12 (the author's marks test): a tooltip showing on this row follows a note or stamp saved (or synced)
	-- under it; redrawn only when its words changed
	if r.wuberTipShown and type(c) == "table" and type(D.RowTip) == "function" then
		local okT, tip = pcall(D.RowTip, c)
		if okT and tip ~= r.shownTip then
			r.shownTip = tip
			T.RefreshTip(r)
		end
	elseif not r.wuberTipShown then
		r.shownTip = nil
	end
end

---------------------------------------------------------------------------
-- The Crew page: "My own account" on each member's card (who gets the notes)
---------------------------------------------------------------------------

local OWN_TIP = "Share customer notes with this window. Only mark your own characters."

-- (UI.Driver.Crew) m = the crew member on card r, or nil (the card shows something else)
function D.CrewOwnMark(r, m)
	-- (HUNT-66) nothing is sent while Settings "Share notes with my own accounts" is off: no offer then
	local show = type(m) == "table" and not m.me and m.app ~= false and S(m.key) ~= nil and dr("BookShareOn") ~= false
	if not show and not r.own then return end
	if not r.own then
		r.own = T.Toggle(r, false, function(on, t)
			if not r.ownKey then return end
			if dr("SetBookOwn", r.ownKey, on) ~= true then
				-- not changed: the switch shows what is saved
				t:SetOn(dr("BookOwn", r.ownKey) == true, true)
				return
			end
			-- the other window sends and takes notes only once it has marked this one too
			toast(on and ("Notes go to " .. short(r.ownName) .. " once it marks this window too")
				or ("Notes no longer go to " .. short(r.ownName)), "info")
		end)
		T.Tip(r.own, "My own account", OWN_TIP)
		r.ownLabel = T.Text(r, "caption", "muted", "CENTER", "medium")
		r.ownLabel:SetText("my account")
		r.ownLabel:SetWidth(72)
		r.ownLabel:SetPoint("TOP", r.own, "BOTTOM", 0, -1)
	end
	r.ownKey, r.ownName = show and m.key or nil, show and S(m.name) or nil
	setShown(r.own, show)
	setShown(r.ownLabel, show)
	local right = (r.btn and r.btn:IsShown()) and 102 or 14
	r.own:ClearAllPoints()
	r.own:SetPoint("RIGHT", r, "RIGHT", -right, 5)
	if show then r.own:SetOn(dr("BookOwn", m.key) == true) end
	-- the name and the line under it stop short of the switch
	r.name:SetPoint("RIGHT", r, "RIGHT", show and -(right + 52) or -100, 0)
	r.sub:SetPoint("RIGHT", r, "RIGHT", show and -(right + 52) or -12, 0)
	-- (round 13, I18) fitted again to the room the switch leaves ('Summons and clicks · 14 sh...')
	-- (its room before the row is placed: the row's width less the left inset and the right end)
	local rw = tonumber((r:GetWidth())) or 0
	r.name.wuberRoom = rw > 0 and (rw - 50 - (show and (right + 52) or 100)) or nil
	r.sub.wuberRoom = rw > 0 and (rw - 50 - (show and (right + 52) or 12)) or nil
	r.sub.wuberSpare = 1.06
	T.Fit(r.name)
	T.Fit(r.sub)
end

---------------------------------------------------------------------------
-- The Note sheet
---------------------------------------------------------------------------

-- Round 12 (TEST-FINDINGS-1119 item 6: "not sure it saved"): a Save that kept the note says so on the
-- button itself, "Saved" with a tick for SAVED_SECS, then "Save" again (the label and an icon only,
-- nothing scaled).
-- (BRIEF20 B1) "Remove note?" is its own pink pill, shown or hidden over the hidden fill: never an
-- alpha change. In the game a fill kept its alpha when it changed while not drawn (the sheet shut while
-- it asked, then another note opened): Save came back pale (the ask's alpha, 0.16).
local function askPaint(btn)
	local on = btn.removeAsk and true or false
	if on and not btn.ask then
		btn.ask = T.PillFill(btn, T.PILL_STYLES.danger.bg, N(btn:GetHeight()) or 38, "BACKGROUND", 1)
		btn.ask:SetShown(false)
		for _, ev in ipairs({ "OnEnter", "OnLeave", "OnMouseDown", "OnMouseUp" }) do
			btn:HookScript(ev, function(self) pcall(askPaint, self) end)
		end
	end
	if not btn.ask then return end
	btn.ask:SetShown(on)
	btn.fill:SetShown(not on)
	if on then btn.label:SetTextColor(T.RGB(T.PILL_STYLES.danger.text)) end
end

local function savedReset(btn)
	btn.savedToken = (btn.savedToken or 0) + 1
	btn.removeAsk = nil
	if btn.baseStyle then
		btn:SetStyle(btn.baseStyle)
		btn.baseStyle = nil
	end
	askPaint(btn)
	btn:SetStyle(btn.style) -- drops the ask's red text: a pill keeps a colour its screen set until its style is set again (AUD-149)
	btn:SetLabel("Save")
	if btn.tick then btn.tick:Hide() end
end

local function savedFlash(btn)
	-- (design 1) the tick takes the colour of the button's words: ink on the gold main button, white on a second button
	if not btn.tick then btn.tick = T.Icon(btn, "check", 14, btn.style == "primary" and "ink" or "white", "OVERLAY") end
	btn:SetLabel("Saved")
	local okW, wd = pcall(btn.label.GetStringWidth, btn.label)
	wd = (okW and type(wd) == "number" and wd > 0) and wd or 40
	btn.tick:ClearAllPoints()
	btn.tick:SetPoint("RIGHT", btn.label, "CENTER", -(wd / 2) - 4, 0)
	btn.tick:Show()
	btn.savedToken = (btn.savedToken or 0) + 1
	local token = btn.savedToken
	W.After(SAVED_SECS, function()
		if btn.savedToken == token then savedReset(btn) end
	end)
	return token
end

-- (BRIEF17 B1) One Save of the note box for name, on its Save button btn. It says only what it did:
-- "Nothing to save" (empty, no note), "No changes to save" (the kept words), and an empty box over a
-- kept note (cleared by hand, or by mistake) only asks on the first click ("Remove note?", for
-- REMOVE_SECS); the second removes it. Returns "saved", "removed", "same", "empty", "ask", or false
-- when the book refused.
local function saveNote(btn, name, text)
	local clean = W.Clean(S(text) or "", DR.BOOK.NOTE_MAX)
	local rec = entry(name)
	local old = rec and S(rec.note) or ""
	if clean == old then
		savedReset(btn)
		toast(clean == "" and "Nothing to save: the note is empty" or "No changes to save", "info")
		return clean == "" and "empty" or "same"
	end
	if clean == "" and not btn.removeAsk then
		savedReset(btn)
		btn.removeAsk = true
		askPaint(btn)
		btn:SetLabel("Remove note?")
		local token = btn.savedToken
		W.After(REMOVE_SECS, function()
			if btn.savedToken == token then savedReset(btn) end
		end)
		toast("The box is empty: click again to remove the note for " .. short(name), "warn")
		return "ask"
	end
	savedReset(btn)
	if dr("SetNote", name, clean) ~= true then return false end
	toast((clean == "" and "Note removed for " or "Note saved for ") .. short(name), "info")
	return clean == "" and "removed" or "saved"
end

local SAVE_TIP = "Keeps the note. To remove one, empty the box and click Save twice. Your own accounts get it too, once each has marked the other on the Crew page."

-- (round 13, I27) the Gifted pill: "Gifted" or, stamped, a tick and "Gifted 17 Nov"; its tooltip says
-- what the stamp means (a free ride given), so a new driver can read it
local function giftLook(btn, at)
	btn:SetLabel(at and ("Gifted " .. (dayText(at) or "")) or "Gifted")
	if at and not btn.gtick then btn.gtick = T.Icon(btn, "check", 12, "glow", "OVERLAY") end
	if not btn.gtick then return end
	setShown(btn.gtick, at ~= nil)
	if not at then return end
	local okW, wd = pcall(btn.label.GetStringWidth, btn.label)
	wd = (okW and type(wd) == "number" and wd > 0) and wd or 60
	btn.gtick:ClearAllPoints()
	btn.gtick:SetPoint("RIGHT", btn.label, "CENTER", -(wd / 2) - 4, 0)
end

-- (design 4, H) "Don't serve again until <date>": the driver's own hold on a rider who left owing (Drive.Book).
-- The words, in one table so the author can swap them. The label shows the date it ends (when set) or would end.
local SERVE = {
	LABEL = "Don't serve again until ",
	TIP = "Don't serve again",
	TIP_OFF = "For %d days Wuber will not invite this rider by itself or whisper them back; their request stays on your list for you to decide. Only you see this: they are never told and it is never sent to anyone.",
	TIP_ON = "Wuber is not inviting or answering this rider by itself until then. Their request still shows on your list. Click to take it off.",
}

-- shows or hides the pill: only in Advanced, only for a rider who left owing (or already has a hold, so it can come off)
local function serveLook(btn, name)
	local held = name and N(dr("ServeHold", name)) or nil
	local show = adv() and name ~= nil and (held ~= nil or dr("OwesFare", name) == true)
	setShown(btn, show)
	if not show then return false end
	local t = held or ((type(time) == "function" and time() or 0) + DR.BOOK.HOLD_DAYS * 86400)
	btn:SetLabel(SERVE.LABEL .. (dayText(t) or ""))
	btn:SetStyle(held and "violet" or "dark")
	T.RefreshTip(btn)
	return true
end

local function serveClick(name)
	if not name then return end
	dr("SetServeHold", name, N(dr("ServeHold", name)) == nil)
end

local function serveTip(name)
	if N(dr("ServeHold", name)) then return SERVE.TIP_ON end
	return SERVE.TIP_OFF:format(DR.BOOK.HOLD_DAYS)
end

local function giftTip(at)
	if at then return "You gave them a ride as a gift on " .. (dayText(at) or "?") .. ". The stamp stops you gifting them twice." end
	return "Click when you give this rider a ride as a gift: it stamps today's date, so you never gift the same person twice."
end

-- A note box never shows more than Save keeps: the game's SetMaxBytes counts an end byte (hence NOTE_MAX + 1
-- below), so if it ever lets one byte more through, typed text over NOTE_MAX bytes is cut here, at a whole
-- letter (never inside a two-byte one), as Save's W.Clean would. Only the length is cut; spacing is left to Save.
-- The cut SetText is not a user change, so it does not come back here.
local function capNote(field)
	return function(text)
		text = S(text) or ""
		local max = DR.BOOK.NOTE_MAX
		if #text <= max then return end
		local cut = max
		while cut > 0 do
			local b = text:byte(cut + 1)
			if not b or b < 128 or b >= 192 then break end
			cut = cut - 1
		end
		field:SetText(text:sub(1, cut))
	end
end

D.screens.note = function(parent)
	local sh = T.Sheet(parent, 330, "Note")
	local s = { frame = sh }
	local b = sh.body
	s.facts = T.Text(b, "caption", "glow", "LEFT", "medium")
	s.facts:SetPoint("TOPLEFT", b, "TOPLEFT", 20, -2)
	s.facts:SetWidth(320)
	s.field = T.Field(b, 320, 92, { multi = true, max = 200, size = "sub",
		placeholder = "Anything you want to remember (200 letters)", onChange = function(t) s.cap(t) end })
	s.cap = capNote(s.field)
	s.field:SetPoint("TOPLEFT", b, "TOPLEFT", 20, -24)
	-- the game counts an end byte, so NOTE_MAX + 1 takes the book's 200 bytes (an accented letter is two)
	pcall(s.field.edit.SetMaxBytes, s.field.edit, DR.BOOK.NOTE_MAX + 1)
	T.Tip(s.field.edit, "Note", "One note per rider, 200 letters at most (accented letters count double). Only you and the crew windows you marked as your own accounts see it; the rider never does.")
	s.privacy = para(b, "caption", "muted", 320)
	s.privacy:SetPoint("TOPLEFT", b, "TOPLEFT", 20, -124)
	s.privacy:SetText("Only you and the crew windows you marked as your own accounts see notes. Never the rider.")
	-- Save and Gifted share the note box's 320 (round 9 previews: two 156s from both card edges met)
	s.save = T.MainButton(sh.card, "Save") -- (Design 2) the one main button's place
	T.Tip(s.save, "Save", SAVE_TIP)
	s.gift = T.Pill(s.frame.card, "Gifted", "dark", 150, 34)
	s.gift:SetPoint("BOTTOMRIGHT", sh.card, "BOTTOMRIGHT", -T.MAIN.side, T.MAIN.foot + T.MAIN.h + 8)
	T.Tip(s.gift, "Gifted", function() return giftTip(giftOf(s.name)) end)
	s.serve = T.Pill(b, SERVE.LABEL, "dark", 320, 34)
	s.serve:SetPoint("TOPLEFT", b, "TOPLEFT", 20, -168)
	T.Tip(s.serve, SERVE.TIP, function() return serveTip(s.name) end)
	safeScript(s.serve, "OnClick", function() serveClick(s.name) s.update() end)
	safeScript(s.save, "OnClick", function()
		local name = s.name
		local done = saveNote(s.save, name, s.field:Text())
		if done == "ask" or done == "empty" then return end -- the sheet stays (typing, or the second click)
		if done ~= "saved" then
			sh:Close()
			D.Refresh(true)
			return
		end
		local rec = entry(name)
		s.field:SetText(rec and S(rec.note) or "") -- what was kept (one clean line)
		-- the sheet stays a moment with "Saved" on the button, then closes
		local token = savedFlash(s.save)
		D.Refresh(true)
		W.After(SAVED_CLOSE, function()
			if s.save.savedToken == token and s.name == name and sh.open then sh:Close() end
		end)
	end)
	safeScript(s.gift, "OnClick", function()
		local okG, at = dr("SetGifted", s.name)
		toast(short(s.name) .. (okG and " stamped gifted " or " was already gifted on ") .. (dayText(at) or "today"), "info")
		s.update()
	end)
	function s.update()
		giftLook(s.gift, giftOf(s.name))
		-- the sheet grows by the pill's row when it is there (nothing is cut or moved over)
		sh:SetSheetHeight(serveLook(s.serve, s.name) and 330 + 44 or 330)
	end
	s.enter = function(c)
		s.name = S(type(c) == "table" and c.name or c) or "?"
		local why = appWhy(s.name, true, c) -- (BRIEF17 B3) why no "Get Wuber", in the header
		sh:SetTitle(s.name, why and ("Your note · " .. why) or "Your note")
		s.facts:SetText(factsText(s.name))
		local rec = entry(s.name)
		s.field:SetText(rec and S(rec.note) or "")
		savedReset(s.save)
		s.update()
	end
	return s
end


---------------------------------------------------------------------------
-- Unfolded (FIXROUND item 3: the Customers list as a two-pane page when there is room): the list
-- stays left, the picked customer's note, facts and Gifted stamp are on the right. Folded, a click
-- opens the Note sheet as before.
---------------------------------------------------------------------------

local SIDE_W = 324
local cside -- the side pane, once the page has unfolded

local function buildSide(p)
	local c = p.content
	p.title = T.Text(c, "heading", "white", "LEFT", "bold")
	p.title:SetPoint("TOPLEFT", c, "TOPLEFT", PAD, -8)
	p.title:SetWidth(SIDE_W)
	p.facts = T.Text(c, "caption", "glow", "LEFT", "medium")
	p.facts:SetPoint("TOPLEFT", c, "TOPLEFT", PAD, -34)
	p.facts:SetWidth(SIDE_W)
	p.field = T.Field(c, SIDE_W, 110, { multi = true, max = 200, size = "sub",
		placeholder = "Anything you want to remember (200 letters)", onChange = function(t) p.cap(t) end })
	p.cap = capNote(p.field)
	p.field:SetPoint("TOPLEFT", c, "TOPLEFT", PAD, -58)
	pcall(p.field.edit.SetMaxBytes, p.field.edit, DR.BOOK.NOTE_MAX + 1) -- (as the Note sheet's)
	T.Tip(p.field.edit, "Note", "One note per rider, 200 letters at most (accented letters count double). Only you and the crew windows you marked as your own accounts see it; the rider never does.")
	-- (round 13, I27) the Note sheet's order: the note, the privacy line, then Save | Gifted
	p.privacy = para(c, "caption", "muted", SIDE_W)
	p.privacy:SetPoint("TOPLEFT", c, "TOPLEFT", PAD, -176)
	p.privacy:SetText("Only you and the crew windows you marked as your own accounts see notes. Never the rider.")
	p.save = T.Pill(c, "Save", "dark", 156, 36)
	p.save:SetPoint("TOPLEFT", c, "TOPLEFT", PAD, -214)
	T.Tip(p.save, "Save", SAVE_TIP)
	p.gift = T.Pill(c, "Gifted", "dark", 156, 36)
	p.gift:SetPoint("TOPLEFT", c, "TOPLEFT", PAD + SIDE_W - 156, -214)
	T.Tip(p.gift, "Gifted", function() return giftTip(giftOf(p.name)) end)
	-- (BRIEF17 B3) their Wuber, under Save | Gifted: why "Get Wuber" isn't offered, or that it waits
	p.app = T.Text(c, "caption", "muted", "LEFT", "medium")
	p.app:SetPoint("TOPLEFT", c, "TOPLEFT", PAD, -262)
	p.app:SetWidth(SIDE_W)
	-- (BRIEF19 F4) the Invite to Wuber action, as the queue row's pill (D.ToggleGetApp), for a rider in the queue
	p.invite = T.Pill(c, "Invite to Wuber", "dark", SIDE_W, 36)
	p.invite:SetPoint("TOPLEFT", c, "TOPLEFT", PAD, -262)
	T.Tip(p.invite, function() return p.inviteQueued and "Next click sends" or "Invite to Wuber" end, function()
		if p.inviteQueued then
			return "Queued: your next big-button click whispers " .. short(p.name) .. " how to get Wuber. Click again to cancel."
		end
		return "Your next big-button click whispers " .. short(p.name) .. " how to get Wuber (edit it in Messages). At most once a day per rider."
	end)
	safeScript(p.invite, "OnClick", function()
		local lc = p.name and liveCustomer(p.name)
		if lc then D.ToggleGetApp(lc) end
		D.Refresh(true)
	end)
	p.serve = T.Pill(c, SERVE.LABEL, "dark", SIDE_W, 36)
	p.serve:SetPoint("TOPLEFT", c, "TOPLEFT", PAD, -316)
	T.Tip(p.serve, SERVE.TIP, function() return serveTip(p.name) end)
	safeScript(p.serve, "OnClick", function()
		serveClick(p.name)
		D.Refresh(true)
	end)
	p.none = para(c, "sub", "muted", SIDE_W)
	p.none:SetPoint("TOPLEFT", c, "TOPLEFT", PAD, -8)
	p.none:SetText("Pick a customer on the left: their note, rides and Gifted stamp show here.")
	safeScript(p.save, "OnClick", function()
		local done = p.name and saveNote(p.save, p.name, p.field:Text())
		if done == "saved" or done == "removed" then
			-- the box shows what was kept, and a later crew edit may replace it while unedited
			local rec = entry(p.name)
			p.shownNote, p.shownAt = rec and S(rec.note) or "", rec and N(rec.noteAt) or nil
			p.field:SetText(p.shownNote)
			if done == "saved" then savedFlash(p.save) end
		end
		D.Refresh(true)
	end)
	safeScript(p.gift, "OnClick", function()
		if not p.name then return end
		local okG, at = dr("SetGifted", p.name)
		toast(short(p.name) .. (okG and " stamped gifted " or " was already gifted on ") .. (dayText(at) or "today"), "info")
		D.Refresh(true)
	end)
	p.scroll:SetContentHeight(364)
end

-- the right pane for one customer (name), or its empty state (nil)
local function paintSide(p, name)
	local has = name ~= nil
	for _, f in ipairs({ p.title, p.facts, p.field, p.save, p.gift, p.privacy }) do setShown(f, has) end
	setShown(p.none, not has)
	serveLook(p.serve, has and name or nil)
	local why = has and appWhy(name) or nil
	-- (BRIEF19 F4) "Get Wuber" state: ok / queued is the Invite pill (a rider in the queue; a past customer
	-- has no one to whisper now), anything else says why not
	local lc = has and liveCustomer(name) or nil
	local st2 = lc and dr("GetAppState", lc, true) or nil
	local offer = st2 == "ok" or st2 == "queued"
	setShown(p.invite, offer)
	if offer then
		p.inviteQueued = st2 == "queued"
		p.invite:SetLabel(p.inviteQueued and "Next click sends" or "Invite to Wuber")
		p.invite:SetStyle(p.inviteQueued and "violet" or "dark")
		T.RefreshTip(p.invite)
		why = nil
	end
	setShown(p.app, why ~= nil)
	if why then p.app:SetText(why) end
	if not has then
		p.name = nil
		return
	end
	-- another customer, or this one's note changed (a crew window's edit) while the box is unedited
	local rec = entry(name)
	local note, at = rec and S(rec.note) or "", rec and N(rec.noteAt) or nil
	if p.name ~= name or (at ~= p.shownAt and p.field:Text() == p.shownNote) then
		p.field:SetText(note)
		p.shownNote, p.shownAt = note, at
	end
	if p.name ~= name then savedReset(p.save) end
	p.name = name
	p.title:SetText(name)
	p.facts:SetText(factsText(name))
	giftLook(p.gift, giftOf(name))
end

D.FOLD.customers = {
	build = function(holder)
		if cside or type(D.SidePane) ~= "function" then return end
		cside = D.SidePane(holder)
		buildSide(cside)
	end,
	layout = function(unfolded)
		D.wide.customers = unfolded == true
		local s = st.screens.customers
		if s and s.update then W.Safe("drive customers", s.update) end
	end,
}

local function isWide() return cside ~= nil and D.Wide("customers") end

---------------------------------------------------------------------------
-- The Customers screen (the footer's Customers link)
---------------------------------------------------------------------------

local function custRow(parent)
	local r = CreateFrame("Button", nil, parent)
	r:SetSize(INNER, ROW_H - 6)
	r:RegisterForClicks("LeftButtonUp")
	r.bg = T.Rounded(r, "card", 12, "BACKGROUND", 0)
	r.name = T.Text(r, "body", "white", "LEFT", "bold")
	r.name:SetPoint("TOPLEFT", r, "TOPLEFT", 14, -7)
	r.name:SetWidth(INNER - 120)
	r.rides = T.Text(r, "caption", "white", "RIGHT", "bold")
	r.rides:SetPoint("TOPRIGHT", r, "TOPRIGHT", -12, -8)
	r.rides:SetWidth(80)
	r.sub = T.Text(r, "caption", "muted", "LEFT", "regular")
	r.sub:SetPoint("TOPLEFT", r.name, "BOTTOMLEFT", 0, -4)
	r.sub:SetWidth(SUB_W) -- clear of the note and gift marks
	r.gift = T.Icon(r, "gift", 13, "glow", "OVERLAY")
	r.gift:SetPoint("RIGHT", r, "RIGHT", -12, -8)
	r.note = T.Icon(r, "note", 13, "glow", "OVERLAY")
	r.note:SetPoint("RIGHT", r.gift, "LEFT", -6, 0)
	safeScript(r, "OnEnter", function(self) self.bg:SetColor("hover") end)
	safeScript(r, "OnLeave", function(self) self.bg:SetColor(self.picked and "raised" or "card") end)
	T.Press(r, { fill = r.bg })
	safeScript(r, "OnClick", function(self)
		if not self.e then return end
		local s = st.screens.customers
		if isWide() and s then
			s.picked = self.e.name -- unfolded: the right pane shows them
			s.update()
		else
			D.ShowSheet("note", { name = self.e.name })
		end
	end)
	T.Tip(r, function(self) return self.e and self.e.name or "Customer" end, function(self)
		local e = self.e or {}
		local lines = { factsText(e.name) }
		if S(e.note) then lines[#lines + 1] = "Note: " .. e.note end
		if N(e.gift) then lines[#lines + 1] = "Gifted on " .. (dayText(e.gift) or "?") .. ": you gave them a ride as a gift." end
		local why = appWhy(e.name) -- (BRIEF17 B3)
		if why then lines[#lines + 1] = why .. "." end
		lines[#lines + 1] = " "
		lines[#lines + 1] = isWide() and "Click: their note on the right." or "Click: the note and the Gifted stamp."
		return table.concat(lines, "\n")
	end)
	return r
end

-- the line under a name: the facts, then the whole note. (2.4 fix round 3) A long note wraps onto more
-- lines and its row grows; it is never cut with "...".
local SUB_LINE = 13 -- one line of the 10 px sub text
local function subLines(text)
	if type(T.ParaLines) ~= "function" then return 1 end
	local ok, n = pcall(T.ParaLines, text, 10, "regular", SUB_W - 4)
	return ok and N(n) or 1
end

-- (BRIEF17 S6) "Scroll for 3 more" over the list's bottom edge while rows are hidden below it (the
-- soft fade alone read as a cut-off row). Never takes the mouse; checked 5 times a second.
local CUE_LIFT = 45 -- frame levels above the list (its fades sit at 40)
local CUE_CLEAR = 30 -- (BRIEF19 F4) the cue's height plus its gap: a row reaching into it is hidden, not sliced

local function scrollCue(s)
	local sc = s.scroll
	local lvl = (N(sc:GetFrameLevel()) or 1) + CUE_LIFT
	if N(s.cue:GetFrameLevel()) ~= lvl then s.cue:SetFrameLevel(lvl) end
	local max, off = N(sc.max) or 0, N(sc.offset) or 0
	local below = 0
	local edge = off + (s.contentH or 0) - max -- the view's bottom, in content px
	local cueOn = max - off > 1
	for i = 1, s.rowsShown or 0 do
		local row = s.pool.list[i]
		local cut = cueOn and (row and row.top or 46 + (i - 1) * ROW_H) + (row and N(row:GetHeight()) or ROW_H - 6) > edge - CUE_CLEAR + 0.5
		if cut then below = below + 1 end
		-- (BRIEF19 F4) a row that would peek out under the "Scroll for N more" pill is hidden whole
		if row and row.SetAlpha and row.cutAlpha ~= (cut and 0 or 1) then
			row.cutAlpha = cut and 0 or 1
			row:SetAlpha(row.cutAlpha)
			row:EnableMouse(not cut)
		end
	end
	setShown(s.cue, below > 0)
	if below < 1 then return end
	local text = "Scroll for " .. below .. " more"
	if s.cue.label:GetText() ~= text then
		s.cue.label:SetText(text)
		local width = T.TextWidth(s.cue.label, text)
		s.cue:SetWidth(math.floor((width > 0 and width or #text * 6) + 24))
	end
end

local function paintCust(r, e)
	r.e = e
	r.name:SetText(e.name)
	r.rides:SetText((N(e.rides) or 0) > 0 and plural(e.rides, "ride") or "")
	local sub = {}
	local day = dayText(e.last)
	if day then sub[#sub + 1] = "last " .. day end
	if S(e.place) then sub[#sub + 1] = W.Clean(S(e.place), 20) end
	local base = table.concat(sub, " · ")
	-- the whole note (200 is the most a note can hold where it is typed, DR.SetNote; W.Clean still cleans one that
	-- came from a crew mate's window before it is drawn)
	local note = S(e.note) and W.Clean(e.note, 200) or nil
	if note == "" then note = nil end
	local text = note and ((base ~= "" and (base .. " · ") or "") .. "\"" .. note .. "\"") or base
	if text == "" then text = "no rides yet" end
	-- (payment by mail, Drive.Mail) "Mail seen: 5g from Dan, 21 Nov." after the facts and the note, whole
	local mail = S(e.mail)
	if mail then text = text .. " · " .. mail end
	local lines = subLines(text)
	r.sub:SetWordWrap(lines > 1)
	local subH = math.max(lines * SUB_LINE, wrapH(lines, "caption")) -- the spacing counted
	r.sub:SetText(text)
	r.sub:SetHeight(subH)
	r:SetHeight(ROW_H - 6 + subH - SUB_LINE)
	setShown(r.gift, N(e.gift) ~= nil)
	setShown(r.note, S(e.note) ~= nil)
	r:Show()
end

D.screens.customers = function(parent)
	local s = Screen(parent, "Customers")
	st.screens.customers = s
	local c = s.content
	s.search = T.Field(c, INNER, 32, { max = 40, placeholder = "Search by name", onChange = function() s.update() end })
	s.search:SetPoint("TOPLEFT", c, "TOPLEFT", PAD, -4)
	T.Tip(s.search.edit, "Search", "Type part of a name.")
	s.empty = para(c, "sub", "muted", INNER - 8)
	s.empty:SetPoint("TOPLEFT", c, "TOPLEFT", PAD + 4, -48)
	s.pool = Pool(c, custRow)
	s.more = T.Text(c, "caption", "muted", "CENTER", "regular")
	s.more:SetWidth(INNER)
	s.cue = CreateFrame("Frame", nil, s.frame)
	s.cue:SetSize(120, 20)
	s.cue:SetPoint("BOTTOM", s.scroll, "BOTTOM", 0, 4)
	s.cue:EnableMouse(false)
	s.cue.fill = T.PillFill(s.cue, "panel", 20, "BACKGROUND", 0)
	s.cue.label = T.Text(s.cue, "caption", "muted", "CENTER", "medium")
	s.cue.label:SetPoint("CENTER", s.cue, "CENTER", 0, 0)
	s.cue:Hide()
	s.cueTick = CreateFrame("Frame", nil, s.frame)
	s.cueTick.wait = 0
	s.cueTick:SetScript("OnUpdate", function(self, elapsed)
		self.wait = self.wait - (N(elapsed) or 0)
		if self.wait > 0 then return end
		self.wait = 0.2
		local okC, err = pcall(scrollCue, s)
		if not okC then W.Error("drive customers cue", err) end
	end)
	function s.update()
		local list = dr("Customers", s.search:Text()) or {}
		local n = math.min(#list, LIST_MAX)
		local y = 46
		local wide = isWide()
		if wide then
			-- keep the pick while it is in the list; else the first
			local still = false
			for i = 1, n do if list[i].name == s.picked then still = true end end
			if not still then s.picked = list[1] and list[1].name or nil end
		end
		for i = 1, n do
			local r = s.pool.get(i)
			paintCust(r, list[i])
			r.picked = wide and list[i].name == s.picked or nil
			r.bg:SetColor(r.picked and "raised" or "card")
			r:ClearAllPoints()
			r:SetPoint("TOPLEFT", c, "TOPLEFT", PAD, -y)
			r.top = y -- (2.4 fix round 3) a row with a wrapped note is taller: scrollCue reads this
			y = y + (N(r:GetHeight()) or ROW_H - 6) + 6
		end
		s.pool.hideFrom(n)
		local filtered = S(s.search:Text()) ~= nil
		setShown(s.empty, #list == 0)
		if #list == 0 then
			s.empty:SetText(filtered and "Nobody by that name." or "Nobody yet. Riders who pay you show here, the latest first, with your notes and gifts.")
			y = y + (s.empty.paraH or 20)
		end
		setShown(s.more, #list > n)
		if #list > n then
			s.more:ClearAllPoints()
			s.more:SetPoint("TOPLEFT", c, "TOPLEFT", PAD, -y)
			s.more:SetText((#list - n) .. " more: search by name")
			y = y + 20
		end
		s.right:SetText(#list > 0 and plural(#list, "customer") or "")
		if cside then paintSide(cside, wide and s.picked or nil) end
		s.scroll:SetContentHeight(y + 10)
		s.contentH, s.rowsShown = y + 10, n
		scrollCue(s)
	end
	return s
end

-- for other modules (REFACTOR-MAP section 2)
Mod.dayText = dayText
Mod.factsText = factsText

-- (REC-01) /wuber why: why the right pane's Invite to Wuber pill (paintSide) is not there, read only.
-- nil when it shows, or when no rider is picked on the unfolded Customers pane.
local INVITE_WHY = {
	live = "Invite to Wuber: only for a rider in your queue now.",
	app = "Invite to Wuber: this rider already has Wuber.",
	crew = "Invite to Wuber: this rider is one of your crew.",
	sent = "Invite to Wuber: already sent today.",
	raid = "Invite to Wuber: not in raid mode.",
	off = "Invite to Wuber: whispers to customers are off.",
	empty = "Invite to Wuber: your whisper text is empty.",
}
function Mod.WhyInvite()
	local s = st.screens.customers
	local name = s and isWide() and S(s.picked)
	if not name then return nil end
	local f = s.frame
	if not (f and f.IsVisible and f:IsVisible()) then return nil end
	local lc = liveCustomer(name)
	if not lc then return INVITE_WHY.live end
	local state = dr("GetAppState", lc, true)
	-- (DR.GetAppState says "off" for both: whispers off, or the Get Wuber text cleans to nothing)
	if state == "off" and dr("ChatMode") ~= "off" then state = "empty" end
	return INVITE_WHY[state]
end
