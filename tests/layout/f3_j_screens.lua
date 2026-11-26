-- Layout scene for the What's new card (UI.WhatsNew), FIX3 group J. Installed by tests/layout/extra_screens.lua at its end
-- (X.install calls this file's install), so it works alone (--screen whatsnew) and inside a whole sweep.
--   whatsnew  the pop-up (title, [See what's new], [Not now]), beside the open phone
--   whatsnew_list  the card opened by [See what's new]: the longest entry of UI.WhatsNew.NOTES (three long lines)
-- Returns install(L, W): adds the screen, returns the ids it added.
local X = {}

-- in a whole sweep the scenes before this one (the floating button's, the mid-flight card's) leave their windows up: the
-- stage is cleared of Wuber's other windows first, so the card is judged against the phone alone
local shownWas, stageGame
local function clearStage(w)
	stageGame = w
	-- the driver's big button is held away (its saved "shown" choice) while the shot is up, then given back
	local okc, Cast = pcall(w.Mod, "Drive.Cast")
	local b = okc and type(Cast) == "table" and type(Cast.btnDB) == "function" and Cast.btnDB() or nil
	if type(b) == "table" then
		if shownWas == nil then shownWas = (b.shown == nil) and "nil" or b.shown end
		b.shown = false
	end
	local DR, D = w.Drive, w.Driver
	if type(DR) == "table" and type(DR.Button) == "table" and type(DR.Button.Refresh) == "function" then pcall(DR.Button.Refresh) end
	if type(D) == "table" then
		if type(D.SyncMini) == "function" then pcall(D.SyncMini) end
		if type(D.UpdateMini) == "function" then pcall(D.UpdateMini) end
	end
	local okf, IF = pcall(w.Mod, "UI.InFlight")
	if okf and type(IF) == "table" and type(IF.Hide) == "function" then pcall(IF.Hide) end
	local btn = type(DR) == "table" and DR.button
	if type(btn) == "table" and type(btn.Hide) == "function" then pcall(btn.Hide, btn) end
end
local function restoreStage(w)
	if shownWas == nil then return end
	local okc, Cast = pcall(w.Mod, "Drive.Cast")
	local b = okc and type(Cast) == "table" and type(Cast.btnDB) == "function" and Cast.btnDB() or nil
	if type(b) == "table" then if shownWas == "nil" then b.shown = nil else b.shown = shownWas end end
	shownWas = nil
end

function X.install(L, W)
	local added = {}
	local ok, M = pcall(W.Mod, "UI.WhatsNew")
	if not (ok and type(M) == "table" and type(M.Show) == "function" and type(M.Longest) == "function") then return added end
	L.PHOTO_SCREENS[#L.PHOTO_SCREENS + 1] = { id = "whatsnew", side = "rider", unfold = true,
		title = "What's new card: the pop-up (title, See what's new, Not now), over the phone",
		run = function(w)
			w.db.coach = true
			local okc, Coach = pcall(w.Mod, "UI.Coach") -- the first-open marks may be up already: stop them (as the tip card's scene does)
			if okc and type(Coach) == "table" and type(Coach.stopCoachForNow) == "function" then Coach.stopCoachForNow() end
			w.UI.Show("home")
			-- the tour applies the fold after this run (the phone widens when unfolded): do it now, so the card is placed beside the final phone
			local F = w.UI.Fold
			if type(F) == "table" and type(F.Apply) == "function" then pcall(F.Apply, true) end
			clearStage(w)
			local v = M.Longest()
			if not v then return "UI.WhatsNew has no entry" end
			if not M.Show(v) then return "the What's new card did not show" end
			return true
		end,
		hide = function()
			M.Hide()
			if stageGame then restoreStage(stageGame) end
		end }
	added[#added + 1] = "whatsnew"
	L.PHOTO_SCREENS[#L.PHOTO_SCREENS + 1] = { id = "whatsnew_list", side = "rider", unfold = true,
		title = "What's new card opened by [See what's new]: the longest entry (three long lines), over the phone",
		run = function(w)
			w.db.coach = true
			local okc, Coach = pcall(w.Mod, "UI.Coach") -- the first-open marks may be up already: stop them (as the tip card's scene does)
			if okc and type(Coach) == "table" and type(Coach.stopCoachForNow) == "function" then Coach.stopCoachForNow() end
			w.UI.Show("home")
			-- the tour applies the fold after this run (the phone widens when unfolded): do it now, so the card is placed beside the final phone
			local F = w.UI.Fold
			if type(F) == "table" and type(F.Apply) == "function" then pcall(F.Apply, true) end
			clearStage(w)
			local v = M.Longest()
			if not v then return "UI.WhatsNew has no entry" end
			if not M.Show(v, true) then return "the What's new card did not show" end
			return true
		end,
		hide = function()
			M.Hide()
			if stageGame then restoreStage(stageGame) end
		end }
	added[#added + 1] = "whatsnew_list"
	return added
end

return X
