-- Layout scenes of the Group Finder driver side (group B1): the console's Group Finder card with the longest draft words, and the
-- "List me in the Group Finder" sheet with the longest place name. Installed by tests/layout/extra_screens.lua at its end
-- (X.install calls this file's install), so they work alone (--screen gf_,sheet_gf) and inside a whole sweep.
--   gf_console_none   the console closed, setting on, not listed: the status line and the "List me" button
--   gf_console_still  the console closed, setting on, still listed: the longest reminder and the Remove button
--   sheet_gf_list     the "List me" sheet over the console with the longest place (Feathermoon Stronghold)
-- Returns install(L, W): adds the screens, returns the ids it added.
local X = {}

-- a Group Finder that says whether the driver has a listing (the layout world has no C_LFGList of its own)
local function stub(w, listed)
	local okf, env = pcall(getfenv, w.GroupFinder.MyListing)
	if not okf or type(env) ~= "table" then return false end
	X.oldLFG = X.oldLFG or { env = env, was = rawget(env, "C_LFGList") }
	-- RemoveListing takes the listing away, as the game does, so a click on "Remove my listing" shows the console without it
	rawset(env, "C_LFGList", { HasActiveEntryInfo = function() return listed end, RemoveListing = function() listed = false end })
	return true
end

local function undo(w)
	if X.oldLFG then rawset(X.oldLFG.env, "C_LFGList", X.oldLFG.was) X.oldLFG = nil end
	if w.db then w.db.groupFinder = false end
end

local SCENES = {
	{ id = "gf_console_none", base = "console_closed", listed = false, title = "Driver console with the Group Finder on, not listed: the status line and the List me button" },
	{ id = "gf_console_still", base = "console_closed", listed = true, title = "Driver console closed, still listed in the Group Finder: the longest reminder and Remove my listing" },
	{ id = "sheet_gf_list", base = "console_closed", listed = false, sheet = true, title = "List me in the Group Finder sheet: the steps and the note with the longest place" },
}

function X.install(L, W)
	local added = {}
	if not (type(W.GroupFinder) == "table" and type(W.Driver) == "table") then return added end
	for _, sc in ipairs(SCENES) do
		local base
		for _, p in ipairs(L.PHOTO_SCREENS) do if p.id == sc.base then base = p break end end
		if base and type(base.run) == "function" then
			L.PHOTO_SCREENS[#L.PHOTO_SCREENS + 1] = { id = sc.id, side = base.side, unfold = base.unfold, only = base.only, title = sc.title,
				run = function(w)
					local r = base.run(w)
					if r ~= true then return r end
					-- an earlier scene (console_join) leaves the console scrolled to its foot; every scene here starts at the top
					local csc = w.Driver.ui and w.Driver.ui.console and w.Driver.ui.console.scroll
					if csc and csc.ScrollTo then csc:ScrollTo(0, true) end
					if not stub(w, sc.listed) then return "no way to give the fake game a Group Finder" end
					w.db.groupFinder = true
					if sc.sheet then
						local c = type(w.Char) == "function" and w.Char()
						if type(c) == "table" then c.dest = "Feathermoon Stronghold" end
						if not w.Driver.ShowSheet("gflist") then return "the sheet did not open" end
					end
					w.Fire("GROUPFINDER")
					if w.Driver.RefreshNow then w.Driver.RefreshNow() end
					if csc and csc.ScrollTo then csc:ScrollTo(0, true) end
					return true
				end,
				hide = function()
					local D = W.Driver
					if sc.sheet and D and D.ui and D.ui.sheets and D.ui.sheets.gflist then pcall(D.ui.sheets.gflist.frame.Close, D.ui.sheets.gflist.frame, true) end
					undo(W)
					if type(base.hide) == "function" then pcall(base.hide) end
				end }
			added[#added + 1] = sc.id
		end
	end
	return added
end

return X
