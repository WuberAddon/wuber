-- Layout scenes for the rider's Group Finder rows on Home (group B2; docs/DESIGN-GROUP-FINDER.md). Installed by
-- tests/layout/extra_screens.lua at its end (X.install calls this file's install), so they work alone (--screen home_gf)
-- and inside a whole sweep. The setting is switched on by stubs for this shot only (L.PhotoReset puts them back).
--   home_gf        the list: every driver's card says "In the Group Finder, Eastern Plaguelands" (the longest zone), the
--                  count line says 999 listings, and the search row says why it is off (No Group Finder category found)
--   home_gf_busy   the same list while a search is pending (Searching...)
--   home_gf_empty  nobody online: the search row stands above the empty state
-- Returns install(L, W): adds the screens, returns the ids it added.
local X = {}

function X.install(L, W)
	local added = {}
	if type(W.GroupFinder) ~= "table" then return added end
	local K = L.PhotoKit
	local function base(id)
		for _, s in ipairs(L.PHOTO_SCREENS) do if s.id == id then return s end end
	end
	local function shotStub(tbl, key, value)
		local t = K and type(K.tour) == "function" and K.tour()
		if not (t and type(K.stub) == "function") then return false end
		t.shotStubs = t.shotStubs or {}
		t.shotStubs[#t.shotStubs + 1] = { tbl, key, tbl[key] }
		return K.stub(tbl, key, value)
	end
	local function scene(id, baseId, title, o)
		local b = base(baseId)
		if not (b and type(b.run) == "function") then return end
		local e = {}
		for k, v in pairs(b) do e[k] = v end
		e.id, e.title = id, title
		e.run = function(w, view)
			local GF = w.GroupFinder
			shotStub(w.db, "groupFinder", true)
			shotStub(GF, "On", function() return true end)
			if o.zone then shotStub(GF, "ListedZone", function() return o.zone end) end
			shotStub(GF, "ExtraCount", function() return o.count or 0 end)
			shotStub(GF, "Pending", function() return o.pending == true end)
			shotStub(GF, "SearchCategory", function() if o.nocat then return nil end return 10 end)
			shotStub(GF, "Search", function() return true end)
			local r = b.run(w, view)
			if r ~= true then return r end
			if w.UI.RefreshNow then w.UI.RefreshNow() end
			return true
		end
		L.PHOTO_SCREENS[#L.PHOTO_SCREENS + 1] = e
		added[#added + 1] = id
	end
	scene("home_gf", "home", "Rider home: Group Finder card lines, 999 more listings, no category", { zone = "Eastern Plaguelands", count = 999, nocat = true })
	scene("home_gf_busy", "home", "Rider home: Group Finder search pending (Searching...)", { zone = "Eastern Plaguelands", count = 999, pending = true })
	scene("home_gf_empty", "home_empty", "Rider home, nobody online: Group Finder search row above the empty state", { count = 1 })
	return added
end

return X
