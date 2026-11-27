-- Layout scene of Group Finder group D: nobody online, a usual place (Pin a bounty), the tallest Group Finder card (search row
-- with its reason, the 999 count line): the card goes under the stack, the bounty stays in the page. Installed by
-- tests/layout/extra_screens.lua at its end, so it works alone (--screen home_gf_empty_tall) and in a whole sweep.
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
			if o.usual then shotStub(w, "Usual", function() return { dest = o.usual } end) end
			local r = b.run(w, view)
			if r ~= true then return r end
			if w.UI.RefreshNow then w.UI.RefreshNow() end
			return true
		end
		L.PHOTO_SCREENS[#L.PHOTO_SCREENS + 1] = e
		added[#added + 1] = id
	end
	scene("home_gf_empty_tall", "home_empty", "Rider home, nobody online, usual place: the tallest Group Finder card goes under the stack, Pin a bounty stays in the page", { count = 999, pending = true, usual = "Ironforge" })
	return added
end

return X
