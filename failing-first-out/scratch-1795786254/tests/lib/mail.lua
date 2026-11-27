-- tests/lib/mail.lua: the fake game's mailbox (decisions round, group Q: payment by mail).
-- Loaded once by tests/harness.lua (H.fakeMail); F.api runs for every client while its game API is
-- built. Nothing here fires an event or changes anything unless a test calls a World helper below, so
-- a test that never opens a mailbox behaves as before.
--
-- In every client (always there, as in the real client):
--   GetInboxNumItems()        -> shown, total: the mails in the open mailbox (0, 0 while it is closed:
--                             the real inbox is only filled at a mailbox)
--   GetInboxHeaderInfo(i)     -> packageIcon, stationeryIcon, sender, subject, money, CODAmount, daysLeft,
--                             hasItem, wasRead, wasReturned, textCreated, canReply, isGM (nothing for an
--                             index with no mail, or while the mailbox is closed). A mail made with
--                             secret = true returns the client's secret value for every field
-- The calls that write (send a mail, set its money, take money or items out) are on
-- tools/forbidden.lua: the harness raises on them like on anything else of that list.
--
-- World helpers (w = the World, c = a client):
--   w:mail(c, { sender = "Dan Miller", money = 50000, subject = "Wuber", cod = 0, daysLeft = 30,
--               returned = false, gm = false, secret = false })
--                             puts a mail into c's mailbox (returns the mail); with the mailbox open,
--                             MAIL_INBOX_UPDATE fires
--   w:openMailbox(c)          the player opens a mailbox: MAIL_SHOW, then MAIL_INBOX_UPDATE
--   w:closeMailbox(c)         MAIL_CLOSED
--   w:clearMail(c)            empties the mailbox (MAIL_INBOX_UPDATE while it is open)
-- Events added to H.KNOWN_EVENTS: MAIL_SHOW, MAIL_INBOX_UPDATE, MAIL_CLOSED.

return function(H, World, Client)
	local F = {}

	for _, e in ipairs({ "MAIL_SHOW", "MAIL_INBOX_UPDATE", "MAIL_CLOSED" }) do H.KNOWN_EVENTS[e] = true end

	local function box(client)
		local p = client.player
		p.mailbox = p.mailbox or { open = false, list = {} }
		return p.mailbox
	end

	function F.api(api, client)
		api.GetInboxNumItems = function()
			local b = box(client)
			if not b.open then return 0, 0 end
			return #b.list, #b.list
		end
		api.GetInboxHeaderInfo = function(i)
			local b = box(client)
			local m = b.open and b.list[i] or nil
			if not m then return nil end
			if m.secret then
				local s = H.SECRET
				return s, s, s, s, s, s, s, s, s, s, s, s, s
			end
			return nil, "Interface\\Stationery\\Stationery_Parchment", m.sender, m.subject or "", m.money or 0, m.cod or 0,
				m.daysLeft or 30, m.hasItem and 1 or nil, m.read == true, m.returned == true, true, m.canReply ~= false,
				m.gm == true
		end
	end

	function World:mail(client, mail)
		local b = box(client)
		b.list[#b.list + 1] = mail
		if b.open and client.alive then client:fire("MAIL_INBOX_UPDATE") end
		return mail
	end

	function World:openMailbox(client)
		local b = box(client)
		b.open = true
		client:fire("MAIL_SHOW")
		client:fire("MAIL_INBOX_UPDATE")
	end

	function World:closeMailbox(client)
		box(client).open = false
		client:fire("MAIL_CLOSED")
	end

	function World:clearMail(client)
		local b = box(client)
		b.list = {}
		if b.open then client:fire("MAIL_INBOX_UPDATE") end
	end

	return F
end
