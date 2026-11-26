-- Layout scenes of the toast fit fix: a toast holds its whole text. Installed by tests/layout/extra_screens.lua at its end
-- (X.install calls this file's install), so they work alone (--screen toast_long) and inside a whole sweep.
--   toast_long        the rider's home with the toast of a long typed place: "No place called " and several words
--   toast_longword    the same with one long unbroken word (the toast grows wider, up to the screen, so nothing is cut)
--   toast_long_stack  that toast with an Undo toast stacked under it (the portal alert holds the first place): the layout follows its height
-- The tour sinks UI.Toast while it runs (no toasts over the shots), so each scene calls the real one, kept at install, and takes
-- its toast away in afterShot (a click, with an onClick that does nothing).
-- Returns install(L, W): adds the screens, returns the ids it added.
local X = {}

function X.install(L, W)
	local added = {}
	local base
	for _, s in ipairs(L.PHOTO_SCREENS) do if s.id == "home" then base = s end end
	if not (base and type(base.run) == "function" and type(W.UI.Toast) == "function") then return added end
	local realToast, realUndo = W.UI.Toast, W.UI.UndoToast
	local up = {}
	local function show(w, text, kind, undo)
		local sunk = w.UI.Toast
		w.UI.Toast = realToast
		local t = realToast(text, kind, function() end)
		if t and undo and type(realUndo) == "function" then up[#up + 1] = realUndo("3 settings reset.", function() end) end
		w.UI.Toast = sunk
		if type(t) ~= "table" then return false end
		up[#up + 1] = t
		return true
	end
	local function drop()
		for _, t in ipairs(up) do
			local click = t.GetScript and t:GetScript("OnClick")
			if click and t:IsShown() then pcall(click, t, "LeftButton", false) end
		end
		up = {}
	end
	local function scene(id, title, text, kind, undo)
		L.PHOTO_SCREENS[#L.PHOTO_SCREENS + 1] = { id = id, side = "rider", unfold = true, title = title,
			run = function(w) return base.run(w) end,
			-- (post runs once the page has settled, after the tour set the fold and the sizes: the toast is placed against the phone as it stands)
			post = function(w)
				if not show(w, text, kind, undo) then return "the toast did not show" end
				return true
			end,
			afterShot = drop }
		added[#added + 1] = id
	end
	scene("toast_long", "Rider home: the toast of a long typed place, several words",
		"No place called " .. ("Stormwind Harbour Crossing "):rep(3) .. "Inn", "warn")
	scene("toast_longword", "Rider home: the toast of a long typed place, one long word",
		"No place called " .. ("x"):rep(44) .. "~", "warn")
	scene("toast_long_stack", "Rider home: a long toast with an Undo toast stacked under it",
		"No place called " .. ("Stormwind Harbour Crossing "):rep(1) .. "Inn", "portal", true)
	return added
end

return X
