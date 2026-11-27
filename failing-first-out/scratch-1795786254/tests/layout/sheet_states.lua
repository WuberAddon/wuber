-- Layout scenes for the sheet-edge rule (job 2525, group E; lesson L4, change C11): the Report a bug sheet over the states the bug
-- hunt found it wrong in. Installed by tests/layout/extra_screens.lua at its end (X.install calls this file's install), so it works
-- alone (--screen sheet_) and inside a whole sweep. Each scene runs a tour screen's own scene, then opens the sheet (UI.Bug.Open).
--   sheet_fm_unknown   the booking card (the tour's "confirm") as at a flight master with the flight to the drivers not known
--                      (hunt: place=fm_unknown, after flights.unknown_price_hidden), the bug sheet over it
--   sheet_done         a ride just ended (the tour's "done_paid" screen), the bug sheet over it
--   sheet_home_online  Home with drivers online (the tour's "home"), the bug sheet over it
-- Returns install(L, W): adds the screens, returns the ids it added.
local X = {}

local SCENES = {
	{ id = "sheet_fm_unknown", base = "confirm", title = "Report a bug sheet over the booking card (flight to the drivers not known): the page under the dim" },
	{ id = "sheet_done", base = "done_paid", title = "Report a bug sheet over the Done screen after a ride: the page under the dim" },
	{ id = "sheet_home_online", base = "home", title = "Report a bug sheet over Home with drivers online: the page under the dim" },
}

function X.install(L, W)
	local added = {}
	local okb, Bug = pcall(function() return W.UI and W.UI.Bug end)
	if not (okb and type(Bug) == "table" and type(Bug.Open) == "function") then return added end
	for _, sc in ipairs(SCENES) do
		local base
		for _, p in ipairs(L.PHOTO_SCREENS) do if p.id == sc.base then base = p break end end
		if base and type(base.run) == "function" then
			L.PHOTO_SCREENS[#L.PHOTO_SCREENS + 1] = { id = sc.id, side = base.side, unfold = base.unfold, title = sc.title,
				run = function(w)
					if sc.id == "sheet_fm_unknown" then
						-- the hunt's state: the flight to the drivers is not known, so no price or time is shown for it
						local okf, F = pcall(w.Mod, "Core.Flights")
						if okf and type(F) == "table" and type(F.Reset) == "function" then pcall(F.Reset) end
					end
					local r = base.run(w)
					if r ~= true then return r end
					local B = w.UI.Bug
					if type(B) ~= "table" or type(B.Open) ~= "function" then return "W.UI.Bug.Open is missing" end
					B.Open()
					return true
				end,
				hide = function()
					local B = W.UI and W.UI.Bug
					if type(B) == "table" and type(B.Close) == "function" then pcall(B.Close) end
					if type(base.hide) == "function" then pcall(base.hide) end
				end }
			added[#added + 1] = sc.id
		end
	end
	return added
end

return X
