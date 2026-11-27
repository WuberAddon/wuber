-- The layout checker's "covered" kind (job 211, group C; the covered-button / topmost check).
-- At every shot: every drawn, mouse-enabled Wuber button (Button / CheckButton) whose centre has another mouse-taking
-- visible frame drawn above it (higher strata or level; Wuber's, another addon's or the game's) is a problem: a click on the
-- button would go to the frame above (the Tips card over Settings' back chevron, run 1). One hit a button.
-- The algorithm is tests/lib/topmost.lua (job 206 BS1, used by tests/bs); this file only picks the buttons and
-- shapes the hits like E.check's. Frames of the Lab (names starting "WuberLab": the tour's own catcher) are not counted as covers.
--   local Top = dofile(root .. "/tests/layout/topmost.lua")
--   Top.hits(H, E, client)            -> { { kind = "covered", what, detail, key }, ... }
--   Top.wrap(H, E)                    -> makes E.check add them to its hits; returns an undo function
-- Intended cases go in tests/layout/allow.lua (kind = "covered", key = the button's name, with a reason).
local Top = {}

local MIN_ALPHA = 0.05

-- the nearest scroll views' common box above a frame (as the engine's clipOf), or nil
local function clipBox(S, H, f)
	local box
	local p = S[f].parent
	while p do
		local s = S[p]
		if s.clips or s.otype == "ScrollFrame" then
			local r = H.rect(p)
			if r then
				local b = { l = r.l, b = r.b, r = r.l + r.w, t = r.b + r.h }
				if not box then box = b else box = { l = math.max(box.l, b.l), b = math.max(box.b, b.b), r = math.min(box.r, b.r), t = math.min(box.t, b.t) } end
			end
		end
		p = s.parent
	end
	return box
end
local function inClip(box, x, y) return not box or (x >= box.l and x <= box.r and y >= box.b and y <= box.t) end

-- is this frame an ancestor of that one?
local function isAnc(S, anc, f)
	while f do if f == anc then return true end f = S[f] and S[f].parent end
	return false
end
local function zKey(H, f, idx) return H.STRATA_RANK(f:GetFrameStrata()) * 1e8 + (tonumber(f:GetFrameLevel()) or 0) * 1e4 + idx end

function Top.hits(H, E, c)
	local T = dofile((H.root or ".") .. "/tests/lib/topmost.lua")
	local S = H.state
	local out = {}
	-- (a page hidden whole under another solid box drawn above it, as the engine's rule: its buttons are not on screen, whatever is
	-- over their centres: a Drive page under the Customers page, the console under a sheet)
	-- (job 2525, E) a page frame wholly under a visible modal sheet's dim is covered on purpose (E.sheets); one the dim cuts is sheet-edge's
	local sheetsUp = type(E.sheets) == "function" and E.sheets(c, E.chromeOf(c)) or {}
	local idx = {}
	for i, f in ipairs(c.frames) do idx[f] = i end
	local okScan, sc = pcall(E.scan, c)
	local boxes = okScan and sc.boxes or {}
	local function hiddenPage(f)
		local p = f
		while p do
			for _, b in ipairs(boxes) do
				if b.frame == p then
					local kb = zKey(H, p, idx[p] or 0)
					for _, o in ipairs(boxes) do
						if o ~= b and not isAnc(S, o.frame, p) and not isAnc(S, p, o.frame) and zKey(H, o.frame, idx[o.frame] or 0) > kb
							and b.rect.l >= o.rect.l - 1 and b.rect.r <= o.rect.r + 1 and b.rect.b >= o.rect.b - 1 and b.rect.t <= o.rect.t + 1 then
							return true
						end
					end
				end
			end
			p = S[p].parent
		end
		return false
	end
	-- the Lab's own apparatus (its full-screen photo catcher and the like) is not a game frame: it never covers a button for a player
	local ignore = {}
	for _, f in ipairs(c.frames) do
		local nm = S[f].name
		if nm and nm:find("^WuberLab") then ignore[f] = true end
	end
	for _, f in ipairs(c.frames) do
		local s = S[f]
		local ot = s and s.otype
		if (ot == "Button" or ot == "CheckButton") and E.tagOf(f) == "Wuber" and f:IsMouseEnabled() == true
			and H.visible(f) and (f:GetEffectiveAlpha() or 0) > MIN_ALPHA then
			local r = H.rect(f)
			local sw, sh = c.env.UIParent:GetWidth(), c.env.UIParent:GetHeight()
			if r and r.w > 0 and r.h > 0 then
				local cx, cy = r.l + r.w / 2, r.b + r.h / 2
				-- (a button whose centre is off the screen is the offscreen kind's)
				if cx >= 0 and cy >= 0 and cx <= sw and cy <= sh then
					local res = T.checkButton(H, c, f, { mouseOnly = true, minAlpha = MIN_ALPHA, ignore = ignore })
					-- (scrolled out of its view the button is not drawn or clickable; a cover scrolled out of its view covers nothing)
					local top
					if not res.ok and inClip(clipBox(S, H, f), cx, cy) then
						for _, b in ipairs(res.blockers) do
							-- (a secure click button lies on the control it clicks for, by design: UI.Secure, Drive.Button)
							if not S[b.frame].secure and inClip(clipBox(S, H, b.frame), cx, cy) then top = b.frame break end
						end
					end
					local under = false
					for _, m in ipairs(sheetsUp) do if m.under(f, { l = r.l, b = r.b, r = r.l + r.w, t = r.b + r.h }) then under = true end end
					if top and not hiddenPage(f) and not under then
						out[#out + 1] = { kind = "covered", what = E.nameOf(f),
							detail = ("button covered at its centre by %s"):format(E.nameOf(top)),
							key = E.nameOf(f) .. " covered by " .. E.nameOf(top) }
					end
				end
			end
		end
	end
	return out
end

function Top.wrap(H, E)
	local orig = E.check
	E.check = function(c, opts)
		local a, b, d, e = orig(c, opts)
		if type(a) == "table" then
			local ok, more = pcall(Top.hits, H, E, c)
			if ok then for _, h in ipairs(more) do a[#a + 1] = h end
			else a[#a + 1] = { kind = "covered", what = "topmost", detail = "the covered check threw: " .. tostring(more), key = "topmost threw" } end
		end
		return a, b, d, e
	end
	return function() E.check = orig end
end

return Top
