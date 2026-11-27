-- Layout scenes of the decisions round, group N. Installed by tests/layout/extra_screens.lua at its end (X.install calls
-- this file's install), so they work alone (--screen settings_sending) and inside a whole sweep.
--   settings_sending    Settings > Riding scrolled to the quiet row "What Wuber sends" (the search's match opened: the
--                       whole line, wrapped, in its row)
--   settings_undo       Settings > This window with the toast of a reset up: the longest line "12 settings reset." and
--                       its Undo button (UI.UndoToast)
--   settings_undo_news  (N2) the same toast with the What's new card up beside the phone: the toast keeps clear of it
-- (N2) The tour never calls a scene's "hide": what a scene before these left up stays up. The What's new card's scene
-- runs just before them in a whole sweep, so each scene here closes that card first (the third then shows it itself,
-- placed against the phone as it stands), and takes its own toast and card away in afterShot, which the tour does call.
-- The existing Settings scenes run with the Drive tab's Messages screen under Settings (the tour's Messages scenes come
-- just before them): these put it there too, so the Ride tab's page, which is not seen under Settings, is not
-- measured against its rows (at size 2.2 the checker does not take that page's list as wholly covered).
-- Returns install(L, W): adds the screens, returns the ids it added.
local X = {}

local function newsOf(w)
	local ok, M = pcall(w.Mod, "UI.WhatsNew")
	if ok and type(M) == "table" and type(M.Hide) == "function" then return M end
	return nil
end

-- the stage as the existing Settings scenes find it: no What's new card, the Drive tab under Settings
local function stage(w)
	local M = newsOf(w)
	if M then pcall(M.Hide) end
	local UI = w.UI
	if type(UI.SelectTab) == "function" and type(UI.state) == "table" and UI.state.tab ~= "Drive" then
		if type(UI.CloseSettings) == "function" then pcall(UI.CloseSettings, true) end
		if type(w.Char) == "function" and type(w.Char()) == "table" then w.Char().wizard = true end
		pcall(UI.SelectTab, "Drive")
	end
	-- the driver's Messages screen, as in a whole sweep (the tour's Messages scenes come just before its Settings ones)
	local D = w.Driver
	if type(D) == "table" and type(D.ShowScreen) == "function" then pcall(D.ShowScreen, "messages") end
end

function X.install(L, W)
	local added = {}
	local base
	for _, s in ipairs(L.PHOTO_SCREENS) do if s.id == "settings" then base = s end end
	local okr, Rows = pcall(W.Mod, "UI.Settings.Rows")
	if not (base and type(base.run) == "function" and okr and type(Rows) == "table") then return added end
	if type(Rows.sendingRow) == "function" then
		L.PHOTO_SCREENS[#L.PHOTO_SCREENS + 1] = { id = "settings_sending", side = "settings", unfold = true,
			title = "Settings: Riding, the row \"What Wuber sends\" (found by the search, opened)",
			run = function(w)
				stage(w)
				local r = base.run(w)
				if r ~= true then return r end
				local Find, Panel = w.Mod("UI.Settings.Find"), w.Mod("UI.Settings.Panel")
				local hit
				for _, m in ipairs(Find.match("what wuber sends")) do if m.label == "What Wuber sends" then hit = m end end
				if not hit then return "the search does not find the row" end
				Panel.openResult(hit)
				local st = w.UI.settings
				if not (st and st.sendingRow and st.sendingRow.sub:GetText() == Rows.SENDING.text) then return "the row does not hold the whole line" end
				return true
			end }
		added[#added + 1] = "settings_sending"
	end
	if type(W.UI.UndoToast) == "function" then
		local toast
		local realToast = W.UI.Toast -- the tour sinks UI.Toast while it runs (no toasts over the shots): this shot is the toast
		local function undoToast(w)
			local sunk = w.UI.Toast
			w.UI.Toast = realToast
			local okt, t = pcall(w.UI.UndoToast, "12 settings reset.", function() end)
			w.UI.Toast = sunk
			toast = okt and t or nil
			return type(toast) == "table" and toast.undo and toast.undo:IsShown()
		end
		-- the toast goes with its shot (as a click on Undo; its undo does nothing)
		local function dropToast()
			if toast and toast.undo and toast.undoFn then toast.undo:GetScript("OnClick")(toast.undo, "LeftButton", false) end
			toast = nil
		end
		L.PHOTO_SCREENS[#L.PHOTO_SCREENS + 1] = { id = "settings_undo", side = "settings", unfold = true,
			title = "Settings: This window, a reset's toast \"12 settings reset.\" with its Undo button",
			run = function(w)
				stage(w)
				local r = base.run(w)
				if r ~= true then return r end
				w.UI.OpenSettings("window")
				if not undoToast(w) then return "the Undo toast did not show" end
				return true
			end,
			afterShot = function() dropToast() end }
		added[#added + 1] = "settings_undo"
		local M = newsOf(W)
		if M and type(M.Show) == "function" and type(M.Longest) == "function" then
			L.PHOTO_SCREENS[#L.PHOTO_SCREENS + 1] = { id = "settings_undo_news", side = "settings", unfold = true,
				title = "Settings: a reset's Undo toast with the What's new card up beside the phone",
				run = function(w)
					stage(w)
					local r = base.run(w)
					if r ~= true then return r end
					w.UI.OpenSettings("window")
					-- the tour applies the fold after this run: now, so the card is placed beside the phone as it will stand
					local F = w.UI.Fold
					if type(F) == "table" and type(F.Apply) == "function" then pcall(F.Apply, true) end
					local v = M.Longest()
					if not v then return "UI.WhatsNew has no entry" end
					-- (with no room beside Wuber's windows the card rightly waits: the shot is then the toast alone)
					M.Show(v)
					if not undoToast(w) then return "the Undo toast did not show" end
					return true
				end,
				afterShot = function()
					dropToast()
					pcall(M.Hide)
				end }
			added[#added + 1] = "settings_undo_news"
		end
	end
	return added
end

return X
