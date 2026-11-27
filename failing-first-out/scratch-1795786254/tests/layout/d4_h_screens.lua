-- Layout scenes for "Don't serve again until <date>" (design round 4, group H: UI.Driver.Customers). Installed by
-- tests/layout/extra_screens.lua (X.install calls this file's install), so they work alone (--screen note_serve,customers_serve)
-- and inside a whole sweep.
--   note_serve       the Note sheet of a customer who left owing, the hold set: the longest label and the sheet grown by its row
--   customers_serve  the Customers screen, unfolded: the side pane's pill, the hold set
-- The stubs are the tour's own shot stubs (L.PhotoKit): L.PhotoReset puts everything back before the next screen.
-- Returns install(L, W): adds the screens, returns the ids it added.
local X = {}

function X.install(L, W)
	local added = {}
	local DR = W.Drive
	if not (type(DR) == "table" and type(DR.ServeHold) == "function" and type(DR.OwesFare) == "function") then return added end
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
	local function addAfter(base, s)
		local _, at = screen(base)
		table.insert(L.PHOTO_SCREENS, (at or #L.PHOTO_SCREENS) + 1, s)
		added[#added + 1] = s.id
	end
	local function stubs()
		local at = (type(time) == "function" and time() or 0) + 30 * 86400
		if shotStub(DR, "OwesFare", function() return true end) == false then return false end
		shotStub(DR, "ServeHold", function() return at end)
		return true
	end

	local note = screen("note")
	if note and type(note.run) == "function" then
		addAfter("note", { id = "note_serve", side = "driver", unfold = note.unfold, only = note.only,
			title = "Note sheet of a rider who left owing, \"Don't serve again until\" set (Advanced)",
			run = function(w)
				local r = note.run(w)
				if r ~= true then return r end
				if not stubs() then return "no shot stub (L.PhotoKit)" end
				local d = w.Driver
				local s = type(d.ui) == "table" and type(d.ui.sheets) == "table" and d.ui.sheets.note or nil
				if type(s) ~= "table" or type(s.update) ~= "function" then return "no note sheet" end
				s.update()
				if not (s.serve and s.serve:IsShown()) then return "the pill is not shown" end
				return true
			end })
	end

	local cust = screen("customers")
	if cust and type(cust.run) == "function" then
		addAfter("customers", { id = "customers_serve", side = "driver", unfold = true, only = cust.only,
			title = "Customers, wide: the side pane's \"Don't serve again until\" pill, set (Advanced)",
			run = function(w)
				local r = cust.run(w)
				if r ~= true then return r end
				if not stubs() then return "no shot stub (L.PhotoKit)" end
				local d = w.Driver
				if type(d.ShowScreen) == "function" then d.ShowScreen("customers") end
				if type(d.RefreshNow) == "function" then d.RefreshNow() elseif type(d.Refresh) == "function" then d.Refresh(true) end
				return true
			end })
	end
	return added
end

return X
