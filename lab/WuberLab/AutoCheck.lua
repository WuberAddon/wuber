-- Wuber Lab (developer only, never ship): Auto check (job 105c). One click, out of combat: the game looks
-- at Wuber's screens itself, so the tester doesn't have to.
--
--                       (job 2880) A screenshot is taken only of a screen with a "look", of a screen new to the
--                       WuberLabDB.autoSeen list, or of every screen when /lab auto shots asks: the checks run on every screen.
--   L.AutoStart(opts)   /lab auto, the Lab bar's "Auto check" button. Runs the photo tour's machinery (Photo.lua:
--                       nothing is sent, WuberDB is put back exactly, a click anywhere or a fight stops it) over
--                       every tour screen (PhotoShots.lua: demo data, folded and unfolded, at the window's own
--                       size) and the Auto check's extra screens (AutoSteps.lua: every Settings section and the
--                       checks that stand in for a manual step). On each settled screen, before its screenshot:
--     cut        every drawn FontString asked FontString:IsTruncated() (the real game, the real fonts)
--     offscreen  a text or a control off the game window
--     overlap    two drawn texts on top of each other
--     under      a text half under an opaque card, pill or bar drawn above it
--     buttons    two clickable things half over each other
--     scrollbar  a list's scroll bar or soft edge (T.EdgeFade) drawn over something outside its list, or two
--                scroll bars side by side
--     tooltips   every shown frame's own OnEnter is called (its tooltip opens), the tooltip must be on the
--                screen with no line cut, then its OnLeave. Secure (protected) frames are never touched.
--     verify     a screen's own verdict (AutoSteps.lua): a safe button pressed and its result, a tooltip's words
--                       Lists that scroll (Settings' sections, T.Scroll lists) are looked at from top to bottom.
--                       (job 2913) Targeted: the Steps note (WuberLabBarSteps.auto, from "<!-- auto: home_bounty home -->" in
--                       STEPS-*.md) names the screens a run needs; with no words the run walks only those, folded and
--                       unfolded, with the same checks, and shoots each named screen once (plus any look). "/lab auto all"
--                       or a note naming none: every screen. The start line says about how many seconds it takes.
--   L.AutoStop()        /lab auto stop
--
-- It NEVER presses anything that talks to other players: the only clicks are the named, local ones in
-- AutoSteps.lua (Reset, Replay tips, switches that are put back), and while it runs the tour has every sender
-- of Wuber's stubbed anyway (Photo.lua: quiet). No taint: only GetScript/IsShown-style reads and a frame's own
-- insecure OnEnter / OnLeave / OnClick handlers, never on a protected frame, never a protected call.
--
-- Results: WuberLabDB.autoCheck (the last run; tools/labreport.js prints it after a /reload)
--   { v, started, ended, char, wuber, lab, stepsFile, reason, planned, done, minutes, screen, window, api,
--     counts = { pass, look, skip, info },
--     screens = { { id, view, title, n, at, pass = "cut offscreen ...", texts, tips, secure } },   n: its shot's number
--     results = { { id, view, kind, status, detail, steps } },   every result that isn't a plain pass, and every one
--                                                                 that stands in for a manual step
--     steps = { ["HUNT-72"] = "pass" | "look" | "skip" },        the manual steps (newest STEPS-*.md) it stood in for
--     shots = { { n, id, view, at } } }                            as WuberLabDB.photoTour's
-- and timeline lines of kind "auto". In chat: "Auto check: 112 passed, 3 need a look".
-- New files AutoCheck.lua and AutoSteps.lua: restart the game once.

local _, L = ...

local show, str, num = L.show, L.str, L.num

local A = {
	V = 1,
	ALPHA = 0.05,      -- drawn: effective alpha at least this
	FADED = 0.3,       -- texts and controls fainter than this are mid-fade: not compared
	SOLID = 0.5,       -- a box: textures at least this opaque...
	FILL = 0.7,        -- ...covering at least this share of their frame
	SLOP = 2,          -- overlaps smaller than this (each way) are ignored
	COVER = 3,         -- under a box by less than this is its soft edge
	EDGE = 1,          -- off the screen by more than this
	MAX_NODES = 8000, MAX_DEPTH = 40, MAX_HOVER = 250,
	MAX_FIND = 6,      -- findings kept per result
	SCROLL_STEPS = 8,  -- stops down a scrolled list at most
	KINDS = { "cut", "offscreen", "overlap", "under", "buttons", "scrollbar", "tooltips" },
}
L.AUTO = A
L.AUTO_SHOT_WAIT = 0.35    -- seconds between a screen's check and its screenshot (hover looks fade back)
L.AUTO_ABOUT_MIN = 6       -- minutes a whole run takes in the game, about (said on the Lab bar and in the steps list)
A.MARK = 40                -- two small sibling buttons (both under this size) are marks on a map (pins, flight points): they may overlap
L.AUTO_ALLOW = L.AUTO_ALLOW or {}      -- { kind, screen (pattern on "home+unfolded"), text (pattern), reason }: meant to be so
L.AUTO_COVERS = L.AUTO_COVERS or {}    -- ["home+unfolded"] = { scrollbar = { "REV-r25-1" } }: tour screens that stand in for a step
L.AUTO_SCREENS = L.AUTO_SCREENS or {}  -- the extra screens (AutoSteps.lua)

local STRATA = { WORLD = 0, BACKGROUND = 1, LOW = 2, MEDIUM = 3, HIGH = 4, DIALOG = 5, FULLSCREEN = 6, FULLSCREEN_DIALOG = 7, TOOLTIP = 8 }
local CONTROL = { Button = true, CheckButton = true, EditBox = true, Slider = true }
local SIDE = { l = "left", r = "right", b = "bottom", t = "top" }

---------------------------------------------------------------------------
-- Guarded reads
---------------------------------------------------------------------------

local function fn(t, k) return type(t) == "table" and type(t[k]) == "function" end

-- o:name(...) under pcall: up to four results, nothing when the method is missing or throws
local function m(o, name, ...)
	if type(o) ~= "table" then return nil end
	local f = o[name]
	if type(f) ~= "function" then return nil end
	local ok, a, b, c, d = pcall(f, o, ...)
	if not ok then return nil end
	return a, b, c, d
end

local function plain(t)
	return (tostring(t or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", "#"):gsub("|A.-|a", "#"):gsub("|n", " "):gsub("%s+", " "))
end

-- the first n bytes, never through the middle of a UTF-8 letter
local function short(t, n)
	t = tostring(t or "")
	n = n or 44
	if #t <= n then return t end
	while n > 1 do
		local c = t:byte(n + 1)
		if not c or c < 128 or c >= 192 then break end
		n = n - 1
	end
	return t:sub(1, n) .. "~"
end

local function winOf(W)
	local st = type(W) == "table" and type(W.UI) == "table" and W.UI.state
	local win = type(st) == "table" and st.win
	return (type(win) == "table" and fn(win, "GetWidth")) and win or nil
end

---------------------------------------------------------------------------
-- Boxes (UIParent's units, origin bottom left)
---------------------------------------------------------------------------

local function inter(a, b)
	if not a or not b then return nil end
	local l, r = math.max(a.l, b.l), math.min(a.r, b.r)
	local bt, t = math.max(a.b, b.b), math.min(a.t, b.t)
	if r - l <= 0 or t - bt <= 0 then return nil end
	return { l = l, b = bt, r = r, t = t }
end

-- a box as its clip lets it show (clip nil: all of it)
local function clipped(box, clip)
	if not box then return nil end
	if not clip then return box end
	return inter(box, clip)
end

local function inside(a, b, slop)
	slop = slop or A.SLOP
	return a.l >= b.l - slop and a.r <= b.r + slop and a.b >= b.b - slop and a.t <= b.t + slop
end

local function area(a) return a and (a.r - a.l) * (a.t - a.b) or 0 end

-- how far a reaches past b: the worst side and by how much, or nil
local function spill(a, b, least)
	local side, n = nil, least or A.EDGE
	local sp = { l = b.l - a.l, r = a.r - b.r, b = b.b - a.b, t = a.t - b.t }
	for k, v in pairs(sp) do if v > n then side, n = k, v end end
	return side, n
end

-- the region's box: GetScaledRect (real pixels) over UIParent's scale, else its own sides times its scale
local function rectOf(o, k, up)
	local l, b, w, h = m(o, "GetScaledRect")
	l, b, w, h = num(l), num(b), num(w), num(h)
	if l and b and w and h and up > 0 then
		return { l = l / up, b = b / up, r = (l + w) / up, t = (b + h) / up }
	end
	l, b, w, h = num(m(o, "GetLeft")), num(m(o, "GetBottom")), num(m(o, "GetWidth")), num(m(o, "GetHeight"))
	if not (l and b and w and h) then return nil end
	return { l = l * k, b = b * k, r = (l + w) * k, t = (b + h) * k }
end

-- a text's ink: the lines it really takes, placed by its justify in its box
local function inkOf(fs, rr, k)
	local w = num(m(fs, "GetWrappedWidth")) or num(m(fs, "GetStringWidth"))
	local h = num(m(fs, "GetStringHeight"))
	local rw, rh = rr.r - rr.l, rr.t - rr.b
	w = w and math.min(w * k, rw) or rw
	h = h and math.min(h * k, rh) or rh
	if w <= 0 or h <= 0 then return nil end
	local jh, jv = str(m(fs, "GetJustifyH")) or "CENTER", str(m(fs, "GetJustifyV")) or "MIDDLE"
	local l = jh == "LEFT" and rr.l or (jh == "RIGHT" and rr.r - w) or (rr.l + (rw - w) / 2)
	local b = jv == "BOTTOM" and rr.b or (jv == "TOP" and rr.t - h) or (rr.b + (rh - h) / 2)
	return { l = l, b = b, r = l + w, t = b + h }
end

---------------------------------------------------------------------------
-- Names (for a finding a person can find again)
---------------------------------------------------------------------------

-- the field of a frame's own table that holds obj ("desc", "rows.3"), or nil
local function keyIn(holder, obj)
	if type(holder) ~= "table" then return nil end
	for k, v in pairs(holder) do
		if v == obj and type(k) == "string" then return k end
	end
	for k, v in pairs(holder) do
		if type(v) == "table" and type(k) == "string" and rawget(v, 0) == nil and type(v.GetObjectType) ~= "function" then
			local n = 0
			for k2, v2 in pairs(v) do
				if v2 == obj then return k .. "." .. tostring(k2) end
				n = n + 1
				if n > 300 then break end
			end
		end
	end
	return nil
end

-- "WuberWindow/rows.3/desc": the nearest named frame, then the fields down to obj (four steps at most)
local function nameOf(obj, holder)
	local parts = {}
	local o, p = obj, holder
	for _ = 1, 4 do
		local n = str(m(o, "GetName"))
		if n then
			table.insert(parts, 1, n)
			break
		end
		table.insert(parts, 1, (p and keyIn(p.f, o)) or str(m(o, "GetObjectType")) or "?")
		if not p then break end
		o, p = p.f, p.parent
	end
	return table.concat(parts, "/")
end

local function textName(t) return '"' .. short(t.text) .. '" (' .. nameOf(t.obj, t.info) .. ")" end
-- a frame: its name, its own (or a child's) first words, and for a frame with no name of its own where it is
-- (x from the game window's left, y from its top, in UI units) and how big
local function frameName(info)
	local name = nameOf(info.f, info.parent)
	local label = info.label and (' "' .. short(info.label, 24) .. '"') or ""
	local at = ""
	if info.vis and info.screen and not str(m(info.f, "GetName")) then
		at = (" at %.0f,%.0f (%.0f x %.0f)"):format(info.vis.l, info.screen.t - info.vis.t, info.vis.r - info.vis.l, info.vis.t - info.vis.b)
	end
	return name .. label .. at
end

---------------------------------------------------------------------------
-- What is on screen: Wuber's shown frames, their texts, boxes, controls, lists
---------------------------------------------------------------------------

-- drawn above for sure: a higher strata, or the same strata and a higher frame level (a tie is unknown)
local function above(a, b)
	if a.strata ~= b.strata then return a.strata > b.strata end
	return a.level > b.level
end

-- a is b, or one of b's parents
local function isAnc(a, b)
	local p = b
	while p do
		if p == a then return true end
		p = p.parent
	end
	return false
end

local walk
walk = function(S, f, parent, clip)
	if type(f) ~= "table" or S.info[f] then return end
	local depth = parent and parent.depth + 1 or 1
	if depth > A.MAX_DEPTH or S.n >= A.MAX_NODES then
		S.capped = true
		return
	end
	if m(f, "IsForbidden") == true or m(f, "IsShown") ~= true then return end
	S.n = S.n + 1
	local es = num(m(f, "GetEffectiveScale")) or (parent and parent.es) or 1
	local k = S.up > 0 and es / S.up or 1
	local alpha = num(m(f, "GetEffectiveAlpha"))
	if not alpha then alpha = (parent and parent.alpha or 1) * (num(m(f, "GetAlpha")) or 1) end
	local otype = str(m(f, "GetObjectType")) or "Frame"
	local info = { f = f, parent = parent, depth = depth, es = es, k = k, alpha = alpha, otype = otype, clip = clip,
		strata = STRATA[str(m(f, "GetFrameStrata")) or ""] or 3, level = num(m(f, "GetFrameLevel")) or 0 }
	info.root = parent and parent.root or info
	info.screen = S.screen
	S.info[f] = info
	local rect = rectOf(f, k, S.up)
	info.rect = rect
	info.vis = clipped(rect, clip)
	info.protected = m(f, "IsProtected") == true
	if info.protected then S.secure = S.secure + 1 end

	-- its texts, and whether its own textures fill it (a card, a pill, a bar)
	local regs = { pcall(f.GetRegions, f) }
	local filled, bb = 0, nil
	for i = 2, #regs do
		local r = regs[i]
		if type(r) == "table" and m(r, "IsShown") == true then
			local rt = str(m(r, "GetObjectType"))
			if rt == "FontString" then
				local text = str(m(r, "GetText"))
				text = text and plain(text)
				if text and text:find("%S") then
					local rr = rectOf(r, k, S.up)
					if rr and rr.r - rr.l > 0.5 and rr.t - rr.b > 0.5 then
						local ink = inkOf(r, rr, k)
						local t = { obj = r, info = info, rect = rr, ink = ink, vis = clipped(ink, clip), text = text,
							alpha = alpha * (num(m(r, "GetAlpha")) or 1) }
						S.texts[#S.texts + 1] = t
						if not info.label then info.label = text end
					end
				end
			elseif rt == "Texture" and rect and alpha >= A.SOLID then
				local _, _, _, va = m(r, "GetVertexColor")
				local ta = alpha * (num(m(r, "GetAlpha")) or 1) * (num(va) or 1)
				if ta >= A.SOLID and str(m(r, "GetDrawLayer")) ~= "HIGHLIGHT" then
					local part = inter(rectOf(r, k, S.up), rect)
					if part then
						filled = filled + area(part)
						bb = bb and { l = math.min(bb.l, part.l), b = math.min(bb.b, part.b), r = math.max(bb.r, part.r), t = math.max(bb.t, part.t) } or part
					end
				end
			end
		end
	end
	if rect and bb and area(rect) > 4 and filled >= A.FILL * area(rect) then
		S.boxes[#S.boxes + 1] = { info = info, rect = bb, vis = clipped(bb, clip) }
		info.box = true
	end
	local mouse = m(f, "IsMouseEnabled") ~= false
	if CONTROL[otype] and mouse and rect then S.ctrls[#S.ctrls + 1] = info end
	if mouse and rect and type(m(f, "GetScript", "OnEnter")) == "function" then S.hovers[#S.hovers + 1] = info end
	-- a clipped list (T.EdgeFade: its soft edges and thin scroll bar), a list that scrolls (T.Scroll)
	local fd = f.edgeFade
	if type(fd) == "table" and type(fd.holder) == "table" then S.fades[#S.fades + 1] = { fd = fd, info = info } end
	if type(f.ScrollTo) == "function" and type(f.content) == "table" and num(f.max) then S.scrolls[#S.scrolls + 1] = info end

	local childClip = clip
	if otype == "ScrollFrame" or m(f, "DoesClipChildren") == true or (type(fd) == "table" and fd.view == f) then
		childClip = rect and (clipped(rect, clip) or { l = 0, b = 0, r = 0, t = 0 }) or clip
	end
	local kids = { pcall(f.GetChildren, f) }
	for i = 2, #kids do walk(S, kids[i], info, childClip) end
end

-- Wuber's own top frames: its window, and every child of UIParent and the minimap whose name starts "Wuber"
local function roots(W)
	local out, seen = {}, {}
	local function add(f)
		if type(f) == "table" and not seen[f] and fn(f, "IsShown") then
			seen[f] = true
			out[#out + 1] = f
		end
	end
	add(winOf(W))
	-- (job 2904) Wuber's flight master card has no name of its own: asked for by its module
	local okB, Bd = pcall(function() return type(W.Mod) == "function" and W.Mod("UI.Bird") or nil end)
	if okB and type(Bd) == "table" and fn(Bd, "Card") then
		local okC, card = pcall(Bd.Card)
		if okC then add(card) end
	end
	for _, holder in ipairs({ rawget(_G, "UIParent") or false, rawget(_G, "Minimap") or false }) do
		if type(holder) == "table" and fn(holder, "GetChildren") then
			local kids = { pcall(holder.GetChildren, holder) }
			for i = 2, #kids do
				local c = kids[i]
				local name = type(c) == "table" and str(m(c, "GetName"))
				if name and name:find("^Wuber") and not name:find("^WuberLab") and not name:find("^WuberRec") and not name:find("^WuberTest") then add(c) end
			end
		end
	end
	return out
end

local function scan(W)
	local up = rawget(_G, "UIParent")
	local S = { texts = {}, ctrls = {}, boxes = {}, fades = {}, scrolls = {}, hovers = {}, info = {}, n = 0, secure = 0,
		up = num(m(up, "GetEffectiveScale")) or 1,
		screen = { l = 0, b = 0, r = num(m(up, "GetWidth")) or 1024, t = num(m(up, "GetHeight")) or 768 } }
	for _, f in ipairs(roots(W)) do
		local ok, err = pcall(walk, S, f, nil, nil)
		if not ok then S.err = show(err) end
	end
	-- not on screen: no part shows, too faint, or whole under an opaque box drawn above it
	local function under(info, vis)
		for _, bx in ipairs(S.boxes) do
			local bi = bx.info
			if bi ~= info and bx.vis and above(bi, info) and inside(vis, bx.vis, 0.5) and not isAnc(bi, info) then return true end
		end
		return false
	end
	for _, t in ipairs(S.texts) do
		t.hidden = not t.vis or t.alpha < A.ALPHA or under(t.info, t.vis)
		-- a frame with no words of its own is named by its child's (a pill's label, a row's name): two levels up
		local p = t.info.parent
		for _ = 1, 2 do
			if not p then break end
			if not p.label then p.label = t.text end
			p = p.parent
		end
	end
	for _, info in pairs(S.info) do
		info.hidden = not info.vis or info.alpha < A.ALPHA or under(info, info.vis)
	end
	return S
end
L.AutoScan = scan

---------------------------------------------------------------------------
-- Findings
---------------------------------------------------------------------------

-- (job 2904) WATCH: what a round changed (words a player reads, a tooltip, a screen), so the next in-game run proves each
-- one reached the real game and was looked at. L.AUTO_WATCH = { { id, what, words = { plain substrings: any one }, on = "text" or
-- "tip" (default: either), screens = { ids: at least one of them must have been walked }, steps = { hidden step ids } } }
-- (AutoSteps7.lua holds the list). A run that ends normally judges each entry: its words seen on a screen that shows them
-- (or in a tooltip a hover opened) is a pass; words never seen, or none of its screens walked, is a look.
L.AUTO_WATCH = L.AUTO_WATCH or {}
local run = nil -- { results, screens, byKey, toasts, counts, started, watch }
local function watchNote(text, key, how)
	local r = run
	if not r or type(text) ~= "string" then return end
	r.watch = r.watch or {}
	for _, item in ipairs(L.AUTO_WATCH) do
		if not r.watch[item.id] and (not item.on or item.on == how) and type(item.words) == "table" then
			for _, w in ipairs(item.words) do
				if text:find(w, 1, true) then r.watch[item.id] = key break end
			end
		end
	end
end

local function newFindings(screenKey)
	local F = { seen = {}, hovered = {}, key = screenKey or "", allowed = 0, tips = 0, notip = {} }
	for _, k in ipairs(A.KINDS) do F[k] = {} end
	return F
end

local function allowed(kind, key, text)
	for _, a in ipairs(L.AUTO_ALLOW) do
		if (not a.kind or a.kind == kind) and (not a.screen or key:find(a.screen)) and (not a.text or text:find(a.text)) then return true end
	end
	return false
end

-- one finding (the same words once per screen; extra: sizes that change as a list scrolls)
local function add(F, kind, text, extra)
	-- (the same thing at another scroll position is the same finding: its place is not part of the key)
	local key = kind .. "\1" .. text:gsub(" at %-?%d+,%-?%d+ %(%d+ x %d+%)", "")
	if F.seen[key] then return end
	F.seen[key] = true
	if allowed(kind, F.key, text) then
		F.allowed = F.allowed + 1
		return
	end
	local list = F[kind]
	list[#list + 1] = text .. (extra or "")
end

-- one sits on an opaque box that is drawn above the other: layers, not a clash
local function layered(S, a, b, common)
	for _, bx in ipairs(S.boxes) do
		local bi = bx.info
		if bx.vis and inter(bx.vis, common) then
			if isAnc(bi, b) and above(bi, a) and not isAnc(bi, a) then return true end
			if isAnc(bi, a) and above(bi, b) and not isAnc(bi, b) then return true end
		end
	end
	return false
end

local function findCut(S, F)
	for _, t in ipairs(S.texts) do
		if not t.hidden and not t.obj.wuberEllipsis then -- (wuberEllipsis: Wuber's own mark for a string cut on purpose)
			local isCut = m(t.obj, "IsTruncated")
			if isCut == nil then
				-- a client without IsTruncated: one line, wider than its box
				F.noTruncated = true
				local w, full = num(m(t.obj, "GetWidth")), num(m(t.obj, "GetStringWidth"))
				local lines = num(m(t.obj, "GetMaxLines"))
				isCut = w and full and w > 0 and full > w + 1 and (lines == 1 or m(t.obj, "CanWordWrap") == false)
			end
			if isCut == true then add(F, "cut", textName(t)) end
		end
	end
end

local function findOffscreen(S, F)
	for _, t in ipairs(S.texts) do
		if not t.hidden then
			local side, n = spill(t.vis, S.screen)
			if side then add(F, "offscreen", textName(t), (" off the %s by %.0f"):format(SIDE[side], n)) end
		end
	end
	for _, info in ipairs(S.ctrls) do
		if not info.hidden then
			local side, n = spill(info.vis, S.screen)
			if side then add(F, "offscreen", frameName(info), (" off the %s by %.0f"):format(SIDE[side], n)) end
		end
	end
end

local function findOverlap(S, F)
	local list = {}
	for _, t in ipairs(S.texts) do
		if not t.hidden and t.alpha >= A.FADED then list[#list + 1] = t end
	end
	table.sort(list, function(a, b) return a.vis.l < b.vis.l end)
	for i = 1, #list do
		local a = list[i]
		for j = i + 1, #list do
			local b = list[j]
			if b.vis.l >= a.vis.r - A.SLOP then break end
			if a.info.root == b.info.root then
				local c = inter(a.vis, b.vis)
				if c and c.r - c.l > A.SLOP and c.t - c.b > A.SLOP and not layered(S, a.info, b.info, c) then
					local n1, n2 = textName(a), textName(b)
					if n2 < n1 then n1, n2 = n2, n1 end
					add(F, "overlap", n1 .. " over " .. n2, (" (%.0f x %.0f)"):format(c.r - c.l, c.t - c.b))
				end
			end
		end
	end
end

-- a text in a row (or any frame above it) whose own alpha is 0 draws nothing, whatever the game says of its effective alpha:
-- the Raid rows under the "+N more below" cue are made so on purpose
-- (#317) "draws nothing" is the Lab's own line (A.ALPHA, 0.05), not only an exact 0: a fade that ends at 0.004 is as invisible,
-- and so is a frame whose effective alpha the game says is under that line
local function inInvisibleRow(info)
	local p, d = info, 0
	while p and d < 60 do
		local a = num(m(p.f, "GetAlpha"))
		if a and a < A.ALPHA then return true end
		p, d = p.parent, d + 1
	end
	local e = num(m(info.f, "GetEffectiveAlpha"))
	return e ~= nil and e < A.ALPHA
end

local function findUnder(S, F)
	for _, t in ipairs(S.texts) do
		if not t.hidden and t.alpha >= A.FADED and not inInvisibleRow(t.info) then
			for _, bx in ipairs(S.boxes) do
				local bi = bx.info
				-- (a box of another window over this one is window layering, not this page's layout)
				if bi ~= t.info and bi.root == t.info.root and bx.vis and not bi.hidden and above(bi, t.info) and not isAnc(bi, t.info) then
					local c = inter(t.vis, bx.vis)
					if c and c.r - c.l > A.COVER and c.t - c.b > A.COVER and not inside(t.vis, bx.vis, 0.5) then
						add(F, "under", textName(t) .. " half under " .. frameName(bi), (" (%.0f x %.0f)"):format(c.r - c.l, c.t - c.b))
					end
				end
			end
		end
	end
end

-- (job 2904, #255 HUNT-07) the floating big button (WuberDriveButton) lies over none of the phone's clickable controls: a tap on a
-- tab, a back arrow or the Me | Crew switch must never reach the big button. Other windows' roots are compared here, which the
-- pairs below skip (they only compare controls of one root).
local function findBigOverPhone(S, F)
	local big
	for _, info in ipairs(S.ctrls) do
		if m(info.f, "GetName") == "WuberDriveButton" and not info.hidden and info.alpha >= A.FADED then big = info break end
	end
	if not big then return end
	for _, info in ipairs(S.ctrls) do
		if info ~= big and not info.hidden and info.alpha >= A.FADED and info.root ~= big.root and not isAnc(info, big) and not isAnc(big, info) then
			local c = inter(big.vis, info.vis)
			if c and c.r - c.l > 1 and c.t - c.b > 1 then
				add(F, "buttons", "the big button over " .. frameName(info), (" (%.0f x %.0f)"):format(c.r - c.l, c.t - c.b))
			end
		end
	end
end

local function findButtons(S, F)
	pcall(findBigOverPhone, S, F)
	local list = {}
	for _, info in ipairs(S.ctrls) do
		if not info.hidden and info.alpha >= A.FADED then list[#list + 1] = info end
	end
	table.sort(list, function(a, b) return a.vis.l < b.vis.l end)
	for i = 1, #list do
		local a = list[i]
		for j = i + 1, #list do
			local b = list[j]
			if b.vis.l >= a.vis.r - A.COVER then break end
			local marks = a.parent == b.parent and math.max(a.rect.r - a.rect.l, a.rect.t - a.rect.b, b.rect.r - b.rect.l, b.rect.t - b.rect.b) < A.MARK
			if a.root == b.root and not marks and not isAnc(a, b) and not isAnc(b, a) then
				local c = inter(a.vis, b.vis)
				if c and c.r - c.l > A.COVER and c.t - c.b > A.COVER and not inside(a.vis, b.vis) and not inside(b.vis, a.vis)
					and not layered(S, a, b, c) then
					local n1, n2 = frameName(a), frameName(b)
					if n2 < n1 then n1, n2 = n2, n1 end
					add(F, "buttons", n1 .. " half over " .. n2, (" (%.0f x %.0f)"):format(c.r - c.l, c.t - c.b))
				end
			end
		end
	end
end

-- a list's scroll bar or soft edge drawn over something that is not in the list (a card of the other pane, a
-- page above it); two scroll bars side by side
local function findScrollbar(S, F)
	local thumbs = {}
	for _, e in ipairs(S.fades) do
		local fd, view = e.fd, e.info
		local holder = S.info[fd.holder]
		if holder and not holder.hidden and holder.alpha >= A.ALPHA then
			for _, p in ipairs({ { fd.thumb, "scroll bar" }, { fd.track, "scroll bar" }, { fd.top, "soft edge" }, { fd.bottom, "soft edge" } }) do
				local tex = p[1]
				if type(tex) == "table" and m(tex, "IsShown") == true then
					local vis = clipped(rectOf(tex, holder.k, S.up), holder.clip)
					if vis then
						if tex == fd.thumb then thumbs[#thumbs + 1] = { vis = vis, view = view } end
						local function meets(item, name)
							local info = item.info or item
							if item.hidden or isAnc(view, info) or isAnc(info, view) or not above(holder, info) then return end
							local c = inter(vis, item.vis)
							if c and c.r - c.l > A.EDGE and c.t - c.b > A.COVER then
								-- (a backdrop that holds the whole list is behind it, not under its bar)
								if item.rect and view.vis and inside(view.vis, item.vis, 0.5) then return end
								add(F, "scrollbar", "the " .. p[2] .. " of " .. frameName(view) .. " runs over " .. name)
							end
						end
						for _, t in ipairs(S.texts) do if t.alpha >= A.FADED then meets(t, textName(t)) end end
						for _, bx in ipairs(S.boxes) do
							if not bx.info.hidden and bx.vis then meets({ info = bx.info, vis = bx.vis, rect = bx.rect }, frameName(bx.info)) end
						end
					end
				end
			end
		end
	end
	for i = 1, #thumbs do
		for j = i + 1, #thumbs do
			local a, b = thumbs[i], thumbs[j]
			local dx = math.abs((a.vis.l + a.vis.r) / 2 - (b.vis.l + b.vis.r) / 2)
			local dy = math.min(a.vis.t, b.vis.t) - math.max(a.vis.b, b.vis.b)
			if dx < 14 and dy > 6 then
				local n1, n2 = frameName(a.view), frameName(b.view)
				if n2 < n1 then n1, n2 = n2, n1 end
				add(F, "scrollbar", "two scroll bars side by side: " .. n1 .. " and " .. n2)
			end
		end
	end
end

---------------------------------------------------------------------------
-- Tooltips: the owner's own OnEnter, the game tooltip looked at, its OnLeave
---------------------------------------------------------------------------

-- a tip's shown lines: { fs, text } (Wuber's own card WuberTip or the game tooltip: L.Tip, Log.lua)
local function tipLines(s, kind)
	local out = {}
	for _, l in ipairs(L.Tip.lines(s, kind)) do
		local t = str(l.text)
		if t then out[#out + 1] = { fs = l.fs, text = plain(t) } end
	end
	return out
end

-- Opens a frame's tooltip as the mouse would (its own OnEnter). -> shown, lines, why not, the frame it shows on
local function tipOpen(f)
	local gt = rawget(_G, "GameTooltip")
	if type(f) ~= "table" then return false, nil, "no such frame" end
	if m(f, "IsProtected") == true then return false, nil, "a secure frame: never touched by the lab" end
	local enter = m(f, "GetScript", "OnEnter")
	if type(enter) ~= "function" then return false, nil, "no OnEnter" end
	L.Tip.hide()
	if type(gt) == "table" then pcall(gt.Hide, gt) end
	local ok, err = pcall(enter, f, false)
	if not ok then return false, nil, "its OnEnter broke: " .. show(err) end
	local s, kind = L.Tip.surface()
	if not s then return false, nil, "no tooltip showed" end
	return true, tipLines(s, kind), nil, s
end

local function tipClose(f)
	local gt = rawget(_G, "GameTooltip")
	local leave = type(f) == "table" and m(f, "GetScript", "OnLeave")
	if type(leave) == "function" then pcall(leave, f, false) end
	L.Tip.hide()
	if type(gt) == "table" then pcall(gt.Hide, gt) end
end

-- a frame's tooltip as one text, and what is wrong with it (cut lines, off the screen): text, problems, why not
local function tipRead(f, S)
	local shown, lines, why, gt = tipOpen(f)
	if not shown then
		tipClose(f)
		return nil, nil, why
	end
	local words, bad = {}, {}
	for _, l in ipairs(lines) do
		words[#words + 1] = l.text
		if m(l.fs, "IsTruncated") == true then bad[#bad + 1] = 'line cut: "' .. short(l.text) .. '"' end
	end
	local up = S and S.up or num(m(rawget(_G, "UIParent"), "GetEffectiveScale")) or 1
	local es = num(m(gt, "GetEffectiveScale")) or up
	local r = rectOf(gt, up > 0 and es / up or 1, up)
	local screen = S and S.screen
	if not screen then
		local uip = rawget(_G, "UIParent")
		screen = { l = 0, b = 0, r = num(m(uip, "GetWidth")) or 1024, t = num(m(uip, "GetHeight")) or 768 }
	end
	if r then
		local side, n = spill(r, screen)
		if side then bad[#bad + 1] = ("off the %s of the screen by %.0f"):format(SIDE[side], n) end
	end
	tipClose(f)
	return table.concat(words, " / "), bad
end
L.AutoTip = tipRead

local function findTooltips(S, F)
	local hov = 0
	for _, info in ipairs(S.hovers) do
		if hov >= A.MAX_HOVER then break end
		if not info.hidden and not info.protected and info.alpha >= A.FADED and area(info.vis) > 16 and not F.hovered[info.f] then
			F.hovered[info.f] = "none"
			hov = hov + 1
			local text, bad, why = tipRead(info.f, S)
			if text then
				watchNote(text, F.key, "tip")
				F.tips = F.tips + 1
				F.hovered[info.f] = "tip"
				for _, b in ipairs(bad) do add(F, "tooltips", "tooltip of " .. frameName(info) .. ' "' .. short(text, 30) .. '": ' .. b) end
			elseif why and why:find("^its OnEnter broke") then
				add(F, "tooltips", frameName(info) .. ": " .. why)
			end
		end
	end
	-- (not a verdict, a note) controls on screen with no tooltip of their own
	for _, info in ipairs(S.ctrls) do
		if not info.hidden and not info.protected and info.alpha >= A.FADED and F.hovered[info.f] ~= "tip" then
			local n = frameName(info)
			if not F.seen["notip\1" .. n] then
				F.seen["notip\1" .. n] = true
				F.notip[#F.notip + 1] = n
			end
		end
	end
end

-- one look at the screen as it stands: every finding into F
local function look(W, F, meta)
	local S = scan(W)
	meta.scans = (meta.scans or 0) + 1
	meta.texts = math.max(meta.texts or 0, #S.texts)
	meta.secure = math.max(meta.secure or 0, S.secure)
	if S.capped then meta.capped = true end
	if S.err then meta.err = S.err end
	if run and #L.AUTO_WATCH > 0 then
		for _, t in ipairs(S.texts) do
			if not t.hidden then watchNote(t.text, F.key, "text") end
		end
	end
	for _, check in ipairs({ findCut, findOffscreen, findOverlap, findUnder, findScrollbar, findTooltips }) do
		local ok, err = pcall(check, S, F)
		if not ok then meta.err = show(err) end
	end
	-- (run 2, F7) two controls "half over" each other were read from rects taken before the page's rows had finished their layout:
	-- the buttons are compared on a fresh read taken after the other checks
	local okS, S2 = pcall(scan, W)
	local okB, errB = pcall(findButtons, okS and S2 or S, F)
	if not okB then meta.err = show(errB) end
	return S
end

-- (tests) one look, its findings: F (F.cut, F.overlap, ... lists of words; F.tips; F.allowed), meta
function L.AutoLook(W, key)
	local F, meta = newFindings(key or "look"), {}
	look(W or L.W(), F, meta)
	return F, meta
end

---------------------------------------------------------------------------
-- Lists that scroll: looked at from top to bottom, then put back
---------------------------------------------------------------------------

local function stops(lo, hi, page)
	local out = {}
	local n = math.min(A.SCROLL_STEPS, math.max(1, math.ceil((hi - lo) / math.max(20, page * 0.8))))
	for i = 0, n do out[#out + 1] = lo + (hi - lo) * i / n end
	return out
end

local function scrollPass(W, F, meta, S0)
	-- Settings' own list (its scroll is Settings' st.scroll: content anchored to the clip, as Wuber's own snap does)
	local UI = W.UI
	local st, ui = type(UI) == "table" and UI.settings, type(UI) == "table" and UI.state
	if type(st) == "table" and type(ui) == "table" and ui.settingsOpen and type(st.content) == "table" and type(st.clip) == "table"
		and m(st.clip, "IsVisible") == true and not (fn(UI, "HelpShown") and UI.HelpShown()) and m(st.content, "IsProtected") ~= true then
		local lo, hi = num(st.scrollMin) or 0, num(st.scrollMax) or 0
		local page = num(m(st.clip, "GetHeight")) or 0
		local at, target = num(st.scroll) or 0, st.scrollTarget
		if hi - lo > 4 and page > 40 then
			local function place(y)
				st.scroll, st.scrollTarget = y, y
				pcall(function()
					st.content:ClearAllPoints()
					st.content:SetPoint("TOPLEFT", st.clip, "TOPLEFT", 0, y)
				end)
			end
			for _, y in ipairs(stops(lo, hi, page)) do
				if math.abs(y - at) > 2 then
					place(y)
					look(W, F, meta)
				end
			end
			place(at)
			st.scrollTarget = target
		end
	end
	-- T.Scroll lists
	for _, info in ipairs(S0.scrolls) do
		local s = info.f
		local max, page, at = num(s.max) or 0, num(m(s, "GetHeight")) or 0, num(s.offset) or 0
		if not info.hidden and max > 4 and page > 40 and m(s, "IsProtected") ~= true then
			for _, y in ipairs(stops(0, max, page)) do
				if math.abs(y - at) > 2 then
					pcall(s.ScrollTo, s, y, true)
					look(W, F, meta)
				end
			end
			pcall(s.ScrollTo, s, at, true)
		end
	end
end

---------------------------------------------------------------------------
-- A run
---------------------------------------------------------------------------

local hooks = {}

local function say(text) if L.Say then L.Say(text) end end

-- the manual steps a result stands in for: the screen's covers = { any = { cut = { "HUNT-113" } }, unfolded = { ... } },
-- and L.AUTO_COVERS["home+unfolded"] = { scrollbar = { "REV-r25-1" } } for the tour's own screens
local function stepsOf(e, kind)
	local list, seen = {}, {}
	local function take(c)
		c = type(c) == "table" and c[kind] or nil
		if type(c) == "string" then c = { c } end
		for _, id in ipairs(type(c) == "table" and c or {}) do
			if not seen[id] then
				seen[id] = true
				list[#list + 1] = id
			end
		end
	end
	local cv = type(e.s.covers) == "table" and e.s.covers or {}
	take(cv[e.view])
	take(cv.any)
	take(L.AUTO_COVERS[e.key])
	return list
end

local RANK = { pass = 1, info = 1, skip = 2, look = 3 }

local function result(e, kind, status, detail, steps)
	local r = run
	r.counts[status] = (r.counts[status] or 0) + 1
	steps = steps or {}
	for _, id in ipairs(steps) do
		local old = r.steps[id]
		if not old or RANK[status] > RANK[old] then r.steps[id] = (status == "info") and "pass" or status end
	end
	if status ~= "pass" or #steps > 0 then
		r.results[#r.results + 1] = { id = e.s.id, view = e.view, kind = kind, status = status,
			detail = detail and short(detail, 900) or nil, steps = #steps > 0 and table.concat(steps, ",") or nil }
	end
	if status == "look" then
		r.lookKeys = r.lookKeys or {}
		r.lookKeys[e.key] = true -- (job 2880) this screen gets a screenshot
		-- the same thing on twenty screens is one thing to look at
		local what = kind .. "\1" .. tostring(detail or ""):gsub(" at %-?%d+,%-?%d+ %(%d+ x %d+%)", ""):gsub(" %(%d+ x %d+%)", "")
		if not r.things[what] then
			r.things[what] = true
			r.distinct = r.distinct + 1
		end
	end
	if status ~= "pass" then
		L.Log("auto", ("%s %s %s %s: %s"):format(status == "look" and "LOOK" or status, e.s.id, e.view, kind, short(tostring(detail or ""), 200)))
	end
end

local function joined(list)
	local out = {}
	for i = 1, math.min(#list, A.MAX_FIND) do out[i] = list[i] end
	local text = table.concat(out, "; ")
	if #list > A.MAX_FIND then text = text .. ("; and %d more"):format(#list - A.MAX_FIND) end
	return text
end

-- For a screen's own verify (AutoSteps.lua): looks, tooltips, safe presses, what was toasted.
local X = {}
L.AutoKit = X
function X.scan(W) return scan(W or L.W()) end
-- the first drawn text matching the pattern (plain = true: a plain substring): its entry, or nil
function X.find(S, pattern, isPlain)
	for _, t in ipairs(S.texts) do
		if not t.hidden and t.text:find(pattern, 1, isPlain) then return t end
	end
	return nil
end
X.tip = tipRead
X.plain = plain
X.short = short
X.nameOf = function(t) return textName(t) end
-- A click on a NAMED, local-only button of Wuber's (never a secure one): its own OnClick. -> true, or false and why
function X.press(f, button)
	if type(f) ~= "table" then return false, "no such button" end
	if m(f, "IsProtected") == true then return false, "a secure button: never pressed by the lab" end
	local click = m(f, "GetScript", "OnClick")
	if type(click) ~= "function" then return false, "no click handler" end
	local ok, err = pcall(click, f, button or "LeftButton", false)
	if not ok then return false, "its click broke: " .. show(err) end
	return true
end
-- the mouse over a frame and off again (its own OnEnter, OnLeave)
function X.hover(f)
	if type(f) ~= "table" or m(f, "IsProtected") == true then return false end
	local enter, leave = m(f, "GetScript", "OnEnter"), m(f, "GetScript", "OnLeave")
	if type(enter) == "function" then pcall(enter, f, false) end
	if type(leave) == "function" then pcall(leave, f, false) end
	L.Tip.hide()
	local gt = rawget(_G, "GameTooltip")
	if type(gt) == "table" then pcall(gt.Hide, gt) end
	return true
end
-- toasts Wuber asked for since the run began (the tour shows none): was one with these words asked for since n?
function X.toasts() return run and run.toasts or {} end
-- words: one string, or a list of strings (any of them)
function X.toasted(words, since)
	local list = X.toasts()
	if type(words) ~= "table" then words = { words } end
	for i = (since or 0) + 1, #list do
		for _, w in ipairs(words) do
			if list[i]:find(w, 1, true) then return true end
		end
	end
	return false
end

-- The settled screen looked over (the tour calls this before its shot).
function hooks.audit(W, e)
	if not run then return end
	local s = e.s
	local key = e.key
	local F = newFindings(key)
	local meta = {}
	local S0 = look(W, F, meta)
	local okS, errS = pcall(scrollPass, W, F, meta, S0)
	if not okS then meta.err = show(errS) end
	local passed = {}
	for _, kind in ipairs(A.KINDS) do
		local list = F[kind]
		local steps = stepsOf(e, kind)
		if #list == 0 then
			passed[#passed + 1] = kind
			result(e, kind, "pass", nil, steps)
		else
			result(e, kind, "look", joined(list), steps)
		end
	end
	if meta.err then result(e, "check", "look", "the check itself broke: " .. tostring(meta.err)) end
	if #F.notip > 0 then result(e, "notip", "info", "no tooltip of their own: " .. joined(F.notip)) end
	-- the screen's own verdicts: "pass" / "look" / "skip", detail; or a list of { name, status, detail, steps }
	if type(s.verify) == "function" then
		local ok, a, b = pcall(s.verify, W, e.view, X, e)
		if not ok then
			result(e, "verify", "look", "the check itself broke: " .. show(a), stepsOf(e, "verify"))
		elseif type(a) == "table" then
			for _, v in ipairs(a) do
				result(e, "verify " .. tostring(v.name or "?"), RANK[v.status] and v.status or "look", v.detail, v.steps or stepsOf(e, "verify"))
			end
		elseif a ~= nil then
			result(e, "verify", RANK[a] and a or "look", b, stepsOf(e, "verify"))
		end
	end
	local row = { id = s.id, view = e.view, title = tostring(s.title or ""), pass = table.concat(passed, " "), texts = meta.texts or 0,
		tips = F.tips, secure = meta.secure or 0, scans = meta.scans or 1, allowed = F.allowed > 0 and F.allowed or nil }
	if F.noTruncated then run.noTruncated = true end
	run.screens[#run.screens + 1] = row
	run.byKey[key] = row
end

-- (job 2880) A screenshot only where it is worth one: a check said "look" (or the screen's own verify did), the screen
-- is new (its key is not in WuberLabDB.autoSeen: one picture the first time it appears), or the run asked for all of
-- them (/lab auto shots). The checks themselves run on every screen either way: they read the real game's answers.
function hooks.wantShot(e)
	if not run then return true end
	if run.allShots then return true end
	if run.shotNamed and e.s and run.shotNamed[tostring(e.s.id):lower()] then return true end -- (job 2913) a screen the STEPS file names
	if run.lookKeys and run.lookKeys[e.key] then return true end
	local db = L.db
	if type(db) ~= "table" then return true end
	if type(db.autoSeen) ~= "table" then return true end
	return db.autoSeen[e.key] == nil
end

function hooks.shot(e, n, at)
	local row = run and run.byKey[e.key]
	if row then row.n, row.at = n, at end
	local db = L.db
	if run and type(db) == "table" then
		if type(db.autoSeen) ~= "table" then db.autoSeen = {} end
		if db.autoSeen[e.key] == nil then
			db.autoSeen[e.key] = { at = at, wuber = run.wuber } -- the "new screens" list: shot once, then only on a look
			run.newShots = (run.newShots or 0) + 1
		end
	end
end

function hooks.skipped(e, why)
	if not run then return end
	local steps = {}
	for _, kind in ipairs(A.KINDS) do
		for _, id in ipairs(stepsOf(e, kind)) do steps[#steps + 1] = id end
	end
	for _, id in ipairs(stepsOf(e, "verify")) do steps[#steps + 1] = id end
	for _, id in ipairs(type(e.s.steps) == "table" and e.s.steps or {}) do steps[#steps + 1] = id end -- (a verify that names its own steps)
	result(e, "screen", "skip", tostring(why or "skipped"), steps)
end

local function plural(n, one, many) return n .. " " .. (n == 1 and one or many) end

-- (job 2904) the WATCH list judged at the end of a run that ran to its end: one row each ("watch <id>")
local function watchJudge(r, subset)
	local walked = {}
	for _, row in ipairs(r.screens) do walked[row.id] = true end
	local e = { s = { id = "watch" }, view = "all", key = "watch" }
	local n, seen, missing = 0, 0, {}
	for _, item in ipairs(L.AUTO_WATCH) do
		local any, wanted = false, type(item.screens) == "table" and #item.screens > 0
		if wanted then
			for _, id in ipairs(item.screens) do if walked[id] then any = true end end
		end
		-- a whole run judges everything; a run of some screens only the entries whose screens it walked
		if (not subset) or (wanted and any) then
			n = n + 1
			local where = r.watch and r.watch[item.id]
			local steps = type(item.steps) == "table" and item.steps or nil
			if wanted and not any then
				missing[#missing + 1] = item.id
				result(e, "watch " .. item.id, "look", ("%s: none of its screens was walked (%s)"):format(tostring(item.what), table.concat(item.screens, ", ")), steps)
			elseif type(item.words) == "table" and #item.words > 0 and not where then
				missing[#missing + 1] = item.id
				result(e, "watch " .. item.id, "look", ("%s: its words were on no screen and in no tooltip (%s)"):format(tostring(item.what), short(item.words[1], 50)), steps)
			else
				seen = seen + 1
				result(e, "watch " .. item.id, "pass", where and ("seen on " .. tostring(where)) or "walked", steps)
			end
		end
	end
	return { n = n, seen = seen, missing = missing }
end

function hooks.done(reason, last)
	local watched = nil
	if run and not reason then
		local okW, w = pcall(watchJudge, run, run.subset ~= nil)
		if okW then watched = w end
	end
	local r = run
	run = nil
	if not r then return end
	local c = r.counts
	local db = L.db
	local pt = db and db.photoTour
	local shots = {}
	for _, s in ipairs(type(pt) == "table" and type(pt.shots) == "table" and pt.shots or {}) do
		shots[#shots + 1] = { n = s.n, id = s.id, view = s.view, at = s.at }
	end
	local secs = L.Now() - r.t0
	local saved = { v = A.V, started = r.started, ended = math.floor(L.Epoch and L.Epoch() or 0), char = L.me, wuber = r.wuber, lab = L.VERSION,
		stepsFile = r.stepsFile, reason = reason, planned = last and last.planned or 0, done = #r.screens, minutes = math.floor(secs / 6 + 0.5) / 10,
		screen = r.screen, window = r.window, api = r.api, noTruncated = r.noTruncated, distinct = r.distinct, taintLog = r.taint,
		counts = { pass = c.pass or 0, look = c.look or 0, skip = c.skip or 0, info = c.info or 0 },
		screens = r.screens, results = r.results, steps = r.steps, shots = shots, subset = r.subset, targeted = r.targeted, planSecs = r.planSecs, watch = watched }
	saved.speed = L.SpeedTake and L.SpeedTake() or nil -- (speed job 2749) the timing pass's rows (AutoSpeed.lua)
	if db then db.autoCheck = saved end
	L.lastAuto = saved
	if L.GameFactsInstant then pcall(L.GameFactsInstant, "auto") end -- (job 129) Game facts: the instant checks, at the end of a run
	local line = ("Auto check%s: %d passed, %s"):format(reason and (" stopped (" .. tostring(reason) .. ") after " .. plural(#r.screens, "screen", "screens")) or "",
		saved.counts.pass, saved.counts.look == 0 and "nothing needs a look" or plural(saved.counts.look, "needs a look", "need a look"))
	if saved.counts.look > r.distinct and r.distinct > 0 then line = line .. " (" .. plural(r.distinct, "different thing", "different things") .. ")" end
	if saved.counts.skip > 0 then line = line .. ", " .. saved.counts.skip .. " skipped" end
	L.Log("auto", line .. (" in %.0f s, %d screenshots"):format(secs, last and last.shots or 0))
	say(line .. ". " .. (reason and "Press Auto check again when you can leave the game alone." or "Now click Reload (that saves it), then do the Steps that are left."))
	if L.RefreshPanel then pcall(L.RefreshPanel) end
end

-- The screens of a run: the tour's own (not the gated ones: they need the flight map or OpenMap's window), then the extra ones.
function L.AutoScreens()
	local out = {}
	for _, s in ipairs(L.PHOTO_SCREENS or {}) do out[#out + 1] = s end
	for _, s in ipairs(L.AUTO_SCREENS) do out[#out + 1] = s end
	return out
end

-- seconds a run takes, about
function L.AutoEstimate(screens, allShots)
	local n = 0
	for _, s in ipairs(screens or L.AutoScreens()) do
		if s.only ~= "unfolded" then n = n + 1 end
		if s.unfold or s.only == "unfolded" then n = n + 1 end
	end
	if not allShots then -- (job 2880) no screenshot, no wait: the checks and the settling only (new screens add a shot each)
		return math.ceil(n * (L.PHOTO_WAIT + 2 * L.PHOTO_POLL + L.AUTO_NOSHOT_GAP + 0.25)), n
	end
	return math.ceil(n * (math.max(L.PHOTO_WAIT + 2 * L.PHOTO_POLL + L.PHOTO_GAP + 0.1, L.PHOTO_APART + 0.2) + L.AUTO_SHOT_WAIT + 0.25)), n
end

-- the screens of a list of ids, in run order (for the time estimate)
function L.AutoScreensOf(ids)
	local want, out = {}, {}
	for _, id in ipairs(ids or {}) do want[id] = true end
	for _, s in ipairs(L.AutoScreens()) do if want[s.id] then out[#out + 1] = s end end
	return out
end

-- words -> screen ids: "steps" (the extra screens), "ride" / "drive" / "settings" (the tour's sides), an id or its start
-- exact (a STEPS file names screens): a word that is a screen's whole id means that screen only ("home" is not home_bounty)
local function resolve(words, exact)
	local want, unknown = {}, {}
	local all = L.AutoScreens()
	for _, w in ipairs(words) do
		local hit = false
		local whole = false
		if exact then
			for _, s in ipairs(all) do if s.id:lower() == w then whole = true end end
		end
		for _, s in ipairs(all) do
			local id = s.id:lower()
			local side = s.side == "rider" and "ride" or (s.side == "driver" and "drive" or s.side)
			if whole then
				if id == w then want[s.id] = true hit = true end
			elseif (w == "steps" and s.auto) or (w == side and not s.auto) or id == w or id:sub(1, #w) == w then
				want[s.id] = true
				hit = true
			end
		end
		if not hit then unknown[#unknown + 1] = w end
	end
	local ids = {}
	for _, s in ipairs(L.AutoScreens()) do if want[s.id] then ids[#ids + 1] = s.id end end
	return ids, unknown
end

local function has(o, name) return fn(o, name) and "yes" or "no" end

function L.AutoStart(opts)
	opts = opts or {}
	if run then
		say("Auto check is already running (/lab auto stop)")
		return false, "already running"
	end
	local can, why = L.TourCan()
	if not can then
		say("Auto check: " .. tostring(why))
		L.Log("auto", "refused: " .. tostring(why))
		return false, why
	end
	local W = L.W()
	L.speedRows = nil
	local steps = rawget(_G, "WuberLabBarSteps")
	-- (job 2913) A targeted check: with no words of its own, the run walks only the screens the Steps note names
	-- (WuberLabBarSteps.auto, from "<!-- auto: home_bounty home -->" in STEPS-*.md). /lab auto all (opts.full) or a note
	-- with no names: every screen, as before. Each named screen also gets its one screenshot.
	local words, exact, named = opts.words, false, nil
	if type(words) ~= "table" or #words == 0 then
		words = nil
		if not opts.full and type(steps) == "table" and type(steps.auto) == "table" and #steps.auto > 0 then
			words, exact, named = steps.auto, true, {}
			for _, w in ipairs(words) do named[tostring(w):lower()] = true end
		end
	end
	local only
	if words then
		local ids, unknown = resolve(words, exact)
		if #unknown > 0 or #ids == 0 then
			say("Auto check: no screen called " .. table.concat(unknown, ", ") .. " (steps, ride, drive, settings, or a screen id)")
			return false, "unknown screen"
		end
		only = ids
		if type(opts.shotWords) == "table" and #opts.shotWords > 0 then
			named = {}
			for _, w in ipairs(opts.shotWords) do named[tostring(w):lower()] = true end
		end
	end
	local up, win = rawget(_G, "UIParent"), winOf(W)
	local cvar = rawget(_G, "C_CVar")
	local getCVar = type(cvar) == "table" and cvar.GetCVar or rawget(_G, "GetCVar")
	local okT, taint = pcall(function() return getCVar("taintLog") end)
	run = { results = {}, screens = {}, byKey = {}, toasts = {}, counts = {}, steps = {}, things = {}, distinct = 0, t0 = L.Now(),
		taint = okT and str(taint) or nil,
		allShots = opts.shots == true,
		started = math.floor(L.Epoch and L.Epoch() or 0), wuber = str(W.VERSION), subset = only and table.concat(words, " ") or nil,
		targeted = (opts.words == nil or #opts.words == 0) and only ~= nil or nil, shotNamed = named,
		stepsFile = type(steps) == "table" and str(steps.name) or nil,
		screen = ("%.0f x %.0f, UI scale %.2f"):format(num(m(up, "GetWidth")) or 0, num(m(up, "GetHeight")) or 0, num(m(up, "GetEffectiveScale")) or 0),
		window = win and ("%.0f x %.0f, scale %.2f"):format(num(m(win, "GetWidth")) or 0, num(m(win, "GetHeight")) or 0, num(m(win, "GetScale")) or 0) or "?",
		api = ("GetScaledRect %s, DoesClipChildren %s, GetEffectiveAlpha %s"):format(has(up, "GetScaledRect"), has(up, "DoesClipChildren"), has(up, "GetEffectiveAlpha")) }
	local ok, why2 = L.TourStart({ screens = L.AutoScreens(), only = only, subset = "auto" .. (run.subset and (" " .. run.subset) or ""), auto = hooks })
	if not ok then
		run = nil
		return false, why2
	end
	-- the tour shows no toasts: the Auto check notes what Wuber asked to say ("Every page is back to Auto")
	local K = L.PhotoKit
	if type(W.UI) == "table" and fn(W.UI, "Toast") then
		local r = run
		K.stub(W.UI, "Toast", function(text) r.toasts[#r.toasts + 1] = tostring(text) end)
	end
	-- Reset answers with the Undo toast ("3 settings reset."): noted the same way, and still shown (the settings_undo
	-- screens shoot it)
	if type(W.UI) == "table" and fn(W.UI, "UndoToast") then
		local r, undo = run, W.UI.UndoToast
		K.stub(W.UI, "UndoToast", function(text, ...)
			r.toasts[#r.toasts + 1] = tostring(text)
			return undo(text, ...)
		end)
	end
	if only then
		local secs, n = L.AutoEstimate(L.AutoScreensOf and L.AutoScreensOf(only) or nil, run.allShots)
		run.planSecs = secs
		say(("Auto check of %d screens only%s: about %d s"):format(#only, run.targeted and " (the ones this run's Steps note names)" or "", secs))
	end
	L.Log("auto", "start: " .. run.screen .. "; window " .. run.window .. "; " .. run.api)
	return true
end

function L.AutoStop(reason)
	if not run then return false end
	L.TourStop(reason or "/lab auto stop")
	return true
end

function L.AutoRunning() return run ~= nil end
