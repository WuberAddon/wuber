local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H

-- r50 (job 2609): these bugs are fixed in 2.4.1; their proofs now run as normal tests
local FIXED = { ["H24-01"] = true, ["H24-02"] = true, ["H24-03"] = true, ["H24-04"] = true, ["H24-05"] = true, ["H24-08"] = true, ["H24-15"] = true }
local function proof(id, name, fn)
	if os.getenv("WUBER_H24_PROOF") or FIXED[id] then
		test(id .. ": " .. name, fn)
	else
		test(id .. " (expected fail until fixed): " .. name, function()
			local okp = pcall(fn)
			assert(not okp, id .. " now passes: the bug looks fixed; make this a normal test")
		end)
	end
end


-- ---- sweep helpers (scrolled pages) ----
local function isUnder(o, root)
	while o do if o == root then return true end o = o:GetParent() end
	return false
end

-- every drawn word and button under root (not under skip): { obj, r = rect, what = text or name }
local function items(root, skip, out, seen)
	out, seen = out or {}, seen or {}
	if seen[root] then return out end
	seen[root] = true
	if skip and root == skip then return out end
	if root.GetRegions then
		for _, g in ipairs({ root:GetRegions() }) do
			if g.GetText and H.visible(g) then
				local t = g:GetText()
				if type(t) == "string" and t ~= "" then
					local r = H.rect(g)
					if r and r.w > 0 and r.h > 0 then out[#out + 1] = { obj = g, r = r, what = t } end
				end
			end
		end
	end
	if root.GetObjectType and root:GetObjectType() == "Button" and H.visible(root) then
		local r = H.rect(root)
		if r and r.w > 0 and r.h > 0 then out[#out + 1] = { obj = root, r = r, what = "button " .. tostring(root:GetName() or "") } end
	end
	if root.GetChildren then
		for _, c in ipairs({ root:GetChildren() }) do items(c, skip, out, seen) end
	end
	return out
end

local function overlap(a, b)
	return a.l < b.l + b.w - 0.5 and b.l < a.l + a.w - 0.5 and a.b < b.b + b.h - 0.5 and b.b < a.b + a.h - 0.5
end
local function top(r) return r.b + r.h end

local function plain(t) return (tostring(t or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end

-- Promise: a control's tooltip says only what its click does now. In a fight the shift card's pill reads
-- "Share after combat" and its click only toasts; the tooltip still says it posts "once, on your click".
proof("H24-15", "the shift card's share pill tooltip says it waits in combat", function()
	local w = T.newWorld()
	local a = T.driver(w, T.ANITA, { spot = "Undercity" })
	w:advance(15)
	local W = a.W
	if W.UI.WindowWide then W.UI.WindowWide(false) end
	T.openDrive(a)
	W.UI.ShowDrive("console")
	w:advance(1)
	local D = W.Driver
	w:addBot("Vex Shade", { spot = "Orgrimmar" })
	w:group({ T.ANITA, "Vex Shade" })
	w:advance(1)
	D.lastShift = { rides = 5, copper = 20000, tips = 0, open = 3600, crewRides = 2, crewCopper = 10000, at = 1,
		cut = { rows = {
			{ key = W.myKey, name = T.ANITA, casts = 3, clicks = 0, share = 18000 },
			{ key = "vex shade", name = "Vex Shade", casts = 0, clicks = 2, share = 12000 },
		}, rule = "clicks", pct = 40 } }
	ok(D.ShowSheet("shift"), "the card opens")
	w:advance(1)
	local p = W.UI.drive.screens.shift.split.post
	local function tip()
		local t = p.wuberTip.text
		if type(t) == "function" then t = t() end
		return plain(t):lower()
	end
	ok(tip():find("click", 1, true), "control: out of combat the tip talks of the click")
	w:enterCombat(a) w:advance(1)
	eq(plain(p.label:GetText()), "Share after combat", "control: the pill waits")
	ok(tip():find("combat", 1, true) or tip():find("fight", 1, true) or tip():find("wait", 1, true) or tip():find("after", 1, true),
		"in combat the tip still reads: " .. tip():sub(1, 90))
	T.clean(w)
end)

-- H24-05 (BUGS-NEXT, Earnings.lua:886-895): the "Scroll for more" cue promises more to read. It may show only while
-- scrolling reveals a drawn word or button that lies below the view at the top. Unfolded Earnings (Advanced) keeps the
-- strip the folded page set (s.strip is never reset on the wide branch) and its content is only about 7 px taller than
-- the view: the cue shows under "Reset stats" with nothing but empty padding below.
local function earnW(scope)
	local w = T.newWorld()
	local a = T.driver(w, T.ANITA, { spot = "Orgrimmar", screenW = 1365, screenH = 768 })
	T.settle(w)
	local W = a.W
	W.db.coach = true
	W.db.fold = { v = 1, pages = {}, narrow = false }
	W.SetAdvanced(true)
	T.openDrive(a)
	W.UI.ShowDrive("console") w:advance(1)
	W.Driver.ShowScreen("earnings") w:advance(2)
	local s = W.UI.drive.screens.earnings
	s.scope = scope s.update() w:advance(1)
	return w, W, s
end
proof("H24-05", "unfolded Earnings: the Scroll for more cue shows only while a word or button lies below the view", function()
	for _, scope in ipairs({ "me", "crew" }) do
		local w, W, s = earnW(scope)
		ok(W.Driver.Wide("earnings"), "control: the page is unfolded")
		s.scroll:ScrollTo(0, true) w:advance(0.6)
		local view = H.rect(s.scroll)
		local below = 0
		for _, it in ipairs(items(s.content)) do
			if it.r.b < view.b - 0.5 then below = below + 1 end
		end
		-- r50: the control "the cue shows at the top" asserted the bug (nothing lies below on this page); the promise both ways:
		ok(s.cue:IsShown() == (below > 0), scope .. ": the cue shows exactly while a word or button lies below the view (cue " .. tostring(s.cue:IsShown()) .. ", below " .. below .. ")")
		T.clean(w)
	end
end)
