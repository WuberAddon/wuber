-- Layout scenes for payment by mail (decisions round, group Q: Drive.Mail). Installed by tests/layout/extra_screens.lua
-- (X.install calls this file's install), so the scenes work alone (--screen done_unpaid_mail,customers_mail) and inside a
-- whole sweep.
--   done_unpaid_mail  the rider's Done screen of a ride that ended unpaid after arriving (the lab's done_unpaid), with the
--                     longest line the card can get: "Still owe the fare? Send 123g 45s 67c to Wolfgangbert Longsurname by
--                     mail, subject Wuber."
--   customers_mail    the driver's Customers screen (the lab's customers): every customer's line under the name ends
--                     with the longest note "Mail seen: 123g 45s 67c from Wolfgangbert, 21 Nov."
-- The stubs are the tour's own shot stubs (L.PhotoKit): L.PhotoReset puts everything back before the next screen.
-- Returns install(L, W): adds the screens, returns the ids it added.
local X = {}

X.LINE = "Still owe the fare? Send 123g 45s 67c to Wolfgangbert Longsurname by mail, subject Wuber."
X.NOTE = "Mail seen: 123g 45s 67c from Wolfgangbert, 21 Nov."

function X.install(L, W)
	local added = {}
	local okm, Mail = pcall(W.Mod, "Drive.Mail")
	local DR = W.Drive
	if not (okm and type(Mail) == "table" and type(Mail.RiderLine) == "function" and type(DR) == "table" and type(DR.MailNote) == "function") then
		return added
	end
	local K = L.PhotoKit
	local function shotStub(tbl, key, value)
		local t = K and type(K.tour) == "function" and K.tour()
		if not (t and type(K.stub) == "function") then return false end
		t.shotStubs = t.shotStubs or {}
		t.shotStubs[#t.shotStubs + 1] = { tbl, key, tbl[key] }
		return K.stub(tbl, key, value)
	end
	local function screen(id)
		for i, s in ipairs(L.PHOTO_SCREENS) do if s.id == id then return s, i end end
	end
	-- a scene goes right after the lab's screen it builds on (as tests/layout/f3_e_screens.lua says why)
	local function addAfter(base, s)
		local _, at = screen(base)
		table.insert(L.PHOTO_SCREENS, (at or #L.PHOTO_SCREENS) + 1, s)
		added[#added + 1] = s.id
	end

	local done = screen("done_unpaid")
	if done and type(done.run) == "function" then
		addAfter("done_unpaid", { id = "done_unpaid_mail", side = "rider", unfold = done.unfold, only = done.only,
			title = "Done, not paid after arriving: what to send by mail, the longest amount and name",
			run = function(w)
				local r = done.run(w)
				if r ~= true then return r end
				-- (the lab makes a fresh demo ride for every shot: these need no putting back)
				local ride = w.ride
				if type(ride) ~= "table" then return "no demo ride" end
				ride.arrivedAt = type(time) == "function" and time() or 1
				ride.price, ride.paidSoFar = 1234567, nil
				ride.payee, ride.payto = "Wolfgangbert Longsurname", "Wolfgangbert"
				if Mail.RiderLine(ride) ~= X.LINE then return "the line is not the longest: " .. tostring(Mail.RiderLine(ride)) end
				w.Fire("RIDE")
				w.UI.Show("done")
				local scr = type(w.UI.state) == "table" and type(w.UI.state.screens) == "table" and w.UI.state.screens.done
				if type(scr) == "table" and type(scr.update) == "function" then scr.update() end
				-- the scene checks itself: the card shows the line (a shot of something else would prove nothing)
				local text = type(scr) == "table" and scr.unpaidText and scr.unpaidText:GetText() or ""
				if not tostring(text):find(X.LINE, 1, true) then return "the unpaid card does not show the mail line" end
				return true
			end })
	end

	local cust = screen("customers")
	if cust and type(cust.run) == "function" then
		addAfter("customers", { id = "customers_mail", side = "driver", unfold = cust.unfold, only = cust.only,
			title = "Customers: a mail was seen from every customer (the longest note under each name)",
			run = function(w)
				local r = cust.run(w)
				if r ~= true then return r end
				-- the lab's demo customer book stands in for DR.Customers: each of its customers gets the note, as
				-- Drive.Book's own list carries it (e.mail); the tooltip's source says the same
				local dr = w.Drive
				local list0 = dr.Customers
				if shotStub(dr, "Customers", function(...)
					local out = list0(...)
					for _, e in ipairs(type(out) == "table" and out or {}) do
						if type(e) == "table" then e.mail = X.NOTE end
					end
					return out
				end) == false then return "no shot stub (L.PhotoKit)" end
				shotStub(dr, "MailNote", function() return X.NOTE end)
				local d = w.Driver
				if type(d.ShowScreen) == "function" then d.ShowScreen("customers") end
				if type(d.RefreshNow) == "function" then d.RefreshNow() elseif type(d.Refresh) == "function" then d.Refresh(true) end
				local oks, Screens = pcall(w.Mod, "UI.Driver.Screens")
				local s = oks and type(Screens) == "table" and type(Screens.st) == "table" and type(Screens.st.screens) == "table"
					and Screens.st.screens.customers or nil
				local list = type(s) == "table" and type(s.pool) == "table" and s.pool.list or {}
				for _, row in ipairs(list) do
					local t = row:IsShown() and row.sub and row.sub:GetText() or ""
					if tostring(t):find(X.NOTE, 1, true) then return true end
				end
				return "no customer row shows the mail note"
			end })
	end
	return added
end

return X
