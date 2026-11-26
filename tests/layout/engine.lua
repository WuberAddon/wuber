-- The layout checker's engine (tools/layout-check.lua; BRIEF21 S11). Loaded with the harness H:
--   local E = dofile("tests/layout/engine.lua")(H)
-- E.tag(dirs)            tags every widget made from now on with the addon whose code made it (Wuber / WuberLab)
-- E.scan(c, shot)        the drawn Wuber regions of client c now: texts, solid boxes, controls, clip views
-- E.check(c, shot)       the layout problems on screen now: a list of { kind, what, detail, key } (then the scan, and the
--                        number of words showing: the word rule, E.countWords, tests/layout/words.lua)
-- E.tooltip(c)           the game tooltip's box as the game would draw it (owner + anchor + its lines), or nil
-- Deterministic: no AI, no pictures. Screen units are UIParent's (H.rect). A problem's key is the same
-- from run to run (screen-independent), so the allow-list (tests/layout/allow.lua) can name it.
local H = ...
local S = H.state
local E = {}

local STRATA = { WORLD = 0, BACKGROUND = 1, LOW = 2, MEDIUM = 3, HIGH = 4, DIALOG = 5, FULLSCREEN = 6, FULLSCREEN_DIALOG = 7, TOOLTIP = 8 }
local LAYER = { BACKGROUND = 1, BORDER = 2, ARTWORK = 3, OVERLAY = 4, HIGHLIGHT = 5 }
-- the numbers the checks use (screen units unless said)
E.K = {
	ALPHA = 0.05,      -- drawn: effective alpha at least this
	SOLID = 0.5,       -- a box: a texture at least this opaque
	FILL = 0.7,        -- a box: its texture covers at least this share of its frame
	SLOP = 1.5,        -- overlaps and spills smaller than this (each way) are ignored (anti-aliasing, borders)
	UNDER = 3,         -- a text under a box by less than this is the box's soft edge (art with a see-through rim)
	EDGE = 1,          -- off screen by more than this
	CUE_GAP = 120,      -- a "Scroll for ..." cue with this much blank space above it in its view: the rows are missing
}
local K = E.K
-- (BRIEF22 L6) art whose edge is see-through: the share of each side's cells that draws next to nothing, cut off
-- its box. Measured from the files: in every cell of Media/fx/portal_loop and portal_loop_gold (ADD blend) the
-- outer 4 of 128 rows and columns on each side add at most 1% light (alpha x brightness), so a text that close
-- to the portal sits beside it, not under it.
E.ART_RIM = {
	{ pat = "[/\\]fx[/\\]portal_loop", side = 4 / 128 },
}

---------------------------------------------------------------------------
-- Who made a widget
---------------------------------------------------------------------------

function E.tag(dirs)
	-- One tagger at a time, however many times E.tag runs in a process (engine.lua is loaded by several test files, layout/run.lua
	-- installs a tagger on load, and the hunt's U.install stacks its own wrapper above one): a second tagger tagged every widget
	-- twice and changed its name ("Confirm.lua:658(Confirm.lua:658(Widgets.lua))"), which the hunt's allow table did not match,
	-- so r49-f failed in its shard after e3b_11b and the word-rule test but passed alone. While one is in, a repeat for the same
	-- folders adds nothing; its restore does nothing either (the first caller's restore removes the tagger).
	local on = H.tagActive
	if on and on.Wuber == dirs.Wuber and on.WuberLab == dirs.WuberLab then return function() end end
	local orig = H.newWidget
	H.tagActive = dirs
	H.newWidget = function(client, otype, name, parent, kind)
		local obj = orig(client, otype, name, parent, kind)
		-- the first Wuber code on the stack makes it Wuber's; it is named by the first caller outside the
		-- shared widget kit (Theme/, FX/Effects), e.g. "Trips.lua:211" rather than "Widgets.lua:635"
		local s = S[obj]
		for level = 2, 40 do
			local info = debug.getinfo(level, "Sl")
			if not info then break end
			local src = info.source or ""
			local at = src:find(dirs.Wuber, 1, true)
			if at then
				local f = src:sub(at + #dirs.Wuber + 1)
				local here = f:gsub("^.*/", "") .. ":" .. tostring(info.currentline)
				if not s.lcTag then s.lcTag, s.lcSrc = "Wuber", here end
				if not (f:find("Theme/", 1, true) or f:find("FX/Effects", 1, true)) then
					if s.lcSrc ~= here then s.lcSrc = here .. "(" .. s.lcSrc:gsub(":%d+$", "") .. ")" end
					break
				end
			elseif dirs.WuberLab and src:find(dirs.WuberLab, 1, true) then
				if not s.lcTag then s.lcTag = "WuberLab" end
				break
			end
		end
		return obj
	end
	return function() H.newWidget = orig H.tagActive = nil end
end

local function tagOf(obj)
	local s = S[obj]
	while s do
		if s.lcTag then return s.lcTag end
		if not s.parent then return nil end
		s = S[s.parent]
	end
	return nil
end
E.tagOf = tagOf

---------------------------------------------------------------------------
-- Drawn
---------------------------------------------------------------------------

-- alpha as drawn: own times the parents', up to one that ignores its parent's alpha
local function effAlpha(obj)
	local a, s = 1, S[obj]
	while s do
		a = a * (s.alpha or 1)
		if s.ignoreParentAlpha or not s.parent then break end
		s = S[s.parent]
	end
	return a
end
E.effAlpha = effAlpha

local function plain(t)
	return (tostring(t or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", "#"):gsub("|n", " "))
end
E.plain = plain

-- The word rule (tests/layout/words.lua): the words of one text. Split on whitespace; a token with no letter or digit
-- (only punctuation, symbols, a texture's "#") is not a word; "50s" is one word. (Dots, bullets and arrows of UTF-8
-- are symbols too.)
function E.countWords(text)
	local s = tostring(text or "")
	for _, sym in ipairs({ "\194\183", "\226\128\148", "\226\128\147", "\226\128\162", "\226\134\146", "\195\151", "\226\128\166" }) do
		s = s:gsub(sym, " ")
	end
	local n = 0
	for tok in plain(s):gmatch("%S+") do
		if tok:find("[%w\128-\255]") then n = n + 1 end
	end
	return n
end

local function ownerOf(obj)
	local s = S[obj]
	if s.kind == "frame" then return obj end
	return s.parent
end

-- draw order: strata, level, the frame's age, layer, sublevel, the region's age
local function zOf(obj, order)
	local s = S[obj]
	local f = ownerOf(obj)
	local fs = S[f]
	local strata = STRATA[f:GetFrameStrata()] or 3
	local layer, sub = 0, 0
	if s.kind ~= "frame" then layer, sub = LAYER[s.layer or "ARTWORK"] or 3, s.sublevel or 0 end
	return { strata, f:GetFrameLevel(), order[f] or 0, layer, sub, order[obj] or 0, fs = fs }
end
local function above(a, b)
	for i = 1, 6 do
		if a[i] ~= b[i] then return a[i] > b[i] end
	end
	return false
end
E.above = above

local function isAncestor(anc, obj)
	local s = S[obj]
	while s and s.parent do
		if s.parent == anc then return true end
		s = S[s.parent]
	end
	return false
end
E.isAncestor = isAncestor

local function rootOf(obj, up)
	local o = obj
	while S[o].parent and S[o].parent ~= up do o = S[o].parent end
	return o
end

-- the nearest ancestors that clip their children (scroll views): their common box, or nil
local function clipOf(obj)
	local box
	local p = S[obj].parent
	while p do
		local s = S[p]
		if s.clips or s.otype == "ScrollFrame" then
			local r = H.rect(p)
			if r then
				if not box then box = { l = r.l, b = r.b, r = r.l + r.w, t = r.b + r.h, frame = p }
				else box = { l = math.max(box.l, r.l), b = math.max(box.b, r.b), r = math.min(box.r, r.l + r.w), t = math.min(box.t, r.b + r.h), frame = box.frame } end
			end
		end
		p = s.parent
	end
	return box
end

local function box(r) return { l = r.l, b = r.b, r = r.l + r.w, t = r.b + r.h } end
E.box = box
local function inter(a, b)
	local w = math.min(a.r, b.r) - math.max(a.l, b.l)
	local h = math.min(a.t, b.t) - math.max(a.b, b.b)
	if w <= 0 or h <= 0 then return 0, 0 end
	return w, h
end
E.inter = inter
local function inside(a, b, slop) -- a inside b
	slop = slop or K.SLOP
	return a.l >= b.l - slop and a.r <= b.r + slop and a.b >= b.b - slop and a.t <= b.t + slop
end
E.inside = inside
local function spill(a, b) -- how far a reaches past b on each side
	return { l = b.l - a.l, r = a.r - b.r, b = b.b - a.b, t = a.t - b.t }
end
local function worst(sp)
	local side, n = nil, K.SLOP
	for k, v in pairs(sp) do if v > n then side, n = k, v end end
	return side, n
end
local SIDE = { l = "left", r = "right", b = "bottom", t = "top" }

-- a text's ink: the lines it really takes, placed by its justify in its box
local function inkOf(fs, r)
	local s = S[fs]
	local e = H.effScale(fs)
	local w, h
	if H.textMetrics and H.metricLayout then
		local ok, L = pcall(H.metricLayout, fs)
		if ok and L then w, h = (L.width or 0) * e, (L.height or 0) * e end
	end
	if not w then
		w = math.min(r.w, (fs.GetUnboundedStringWidth and fs:GetUnboundedStringWidth() or r.w / e) * e)
		h = math.min(r.h, ((s.font and s.font.size) or 12) * 1.2 * e)
	end
	w, h = math.min(w, r.w), math.min(h, r.h)
	if w <= 0 or h <= 0 then return nil end
	local jh, jv = s.justifyH or "CENTER", s.justifyV or "MIDDLE"
	local l = jh == "LEFT" and r.l or (jh == "RIGHT" and r.l + r.w - w) or (r.l + (r.w - w) / 2)
	local b = jv == "BOTTOM" and r.b or (jv == "TOP" and r.b + r.h - h) or (r.b + (r.h - h) / 2)
	return { l = l, b = b, r = l + w, t = b + h }
end
E.inkOf = inkOf

local function texAlpha(s)
	local a = 1
	if type(s.color) == "table" then a = a * (tonumber(s.color[4] or s.color.a) or 1) end
	if type(s.vertex) == "table" then a = a * (tonumber(s.vertex[4] or s.vertex.a) or 1) end
	return a
end

-- drawn in the world, under every window (the crown over the player's own head: BACKGROUND strata)
local function worldly(obj)
	local f = ownerOf(obj)
	local st = f and f.GetFrameStrata and f:GetFrameStrata()
	return st == "BACKGROUND" or st == "WORLD"
end

---------------------------------------------------------------------------
-- What is on screen
---------------------------------------------------------------------------

-- texts: { obj, rect, ink, z, root, clip, text }; boxes: { frame, rect, z } (a frame filled by its own
-- texture: a card, a pill, a bar); views: clip boxes. Only Wuber's (E.tagOf), only drawn.
function E.scan(c)
	local order = {}
	for i, o in ipairs(c.widgets) do order[o] = i end
	local up = c.env.UIParent
	local out = { texts = {}, boxes = {}, controls = {}, screen = box(H.rect(up)), up = up }
	local boxed = {}
	for _, obj in ipairs(c.widgets) do
		local s = S[obj]
		local ot = s.otype
		if (ot == "FontString" or ot == "Texture" or ot == "Button" or ot == "CheckButton" or ot == "EditBox") and s.shown then
			local tag = tagOf(obj)
			if tag == "Wuber" and H.visible(obj) and not worldly(obj) then
				local a = effAlpha(obj)
				if a >= K.ALPHA then
					local r = H.rect(obj)
					if r and r.w > 0.5 and r.h > 0.5 then
						if ot == "FontString" then
							local text = plain(s.text)
							if text:match("%S") then
								local ink = inkOf(obj, r)
								if ink then
									out.texts[#out.texts + 1] = { obj = obj, rect = box(r), ink = ink, z = zOf(obj, order), root = rootOf(obj, up),
										clip = clipOf(obj), text = text, alpha = a }
								end
							end
						elseif ot == "Texture" then
							-- a frame filled by its own solid textures (one, or a 3-slice) is a box
							local f = s.parent
							if f and (s.texture or s.color) and a * texAlpha(s) >= K.SOLID then
								local fr = H.rect(f)
								if fr and fr.w > 2 and fr.h > 2 then
									local w, h = inter(box(r), box(fr))
									local acc = boxed[f]
									if not acc then
										acc = { area = 0, need = K.FILL * fr.w * fr.h, fr = fr }
										boxed[f] = acc
									end
									acc.area = acc.area + w * h
									if w > 0 and h > 0 then
										local tb = box(r)
										local fb = box(fr)
										local ib = { l = math.max(tb.l, fb.l), b = math.max(tb.b, fb.b), r = math.min(tb.r, fb.r), t = math.min(tb.t, fb.t) }
										local bb = acc.bb
										acc.bb = bb and { l = math.min(bb.l, ib.l), b = math.min(bb.b, ib.b), r = math.max(bb.r, ib.r), t = math.max(bb.t, ib.t) } or ib
									end
									local z = zOf(obj, order)
									if not acc.z or above(acc.z, z) then acc.z = z end
									if not acc.done and acc.area >= acc.need then
										acc.done = true
										out.boxes[#out.boxes + 1] = { frame = f, tex = obj, rect = box(fr), z = acc.z, acc = acc, root = rootOf(f, up), clip = clipOf(f) }
									end
								end
							end
						else
							out.controls[#out.controls + 1] = { frame = obj, rect = box(r), z = zOf(obj, order), root = rootOf(obj, up), clip = clipOf(obj) }
						end
					end
				end
			end
		end
	end
	-- a box is where its solid textures are (a cell's frame may be taller than its card)
	for _, b in ipairs(out.boxes) do
		b.z = b.acc.z
		b.rect = b.acc.bb or b.rect
		-- art with a see-through rim: only what it draws (E.ART_RIM)
		local path = tostring(S[b.tex] and S[b.tex].texture or "")
		for _, a in ipairs(E.ART_RIM) do
			if path:find(a.pat) then
				local r = b.rect
				local dw, dh = (r.r - r.l) * a.side, (r.t - r.b) * a.side
				b.rect = { l = r.l + dw, b = r.b + dh, r = r.r - dw, t = r.t - dh }
				break
			end
		end
	end
	return out
end

---------------------------------------------------------------------------
-- Names
---------------------------------------------------------------------------

-- a widget's name: its global name, else "<the Wuber file:line that made it> <the field that holds it, or its type>"
local function keyIn(parent, obj)
	if not parent then return nil end
	for k, v in pairs(parent) do
		if v == obj and type(k) == "string" then return k end
	end
	-- one level of plain tables (v.rows[3].name)
	for k, v in pairs(parent) do
		if type(v) == "table" and not S[v] and type(k) == "string" then
			for k2, v2 in pairs(v) do
				if v2 == obj then return k .. "." .. tostring(k2) end
			end
		end
	end
	return nil
end
function E.nameOf(obj)
	local s = S[obj]
	if s.name then return s.name end
	local k = keyIn(s.parent, obj)
	local src = s.lcSrc or "?"
	return src .. " " .. (k or s.otype)
end
local function short(t, n)
	n = n or 28
	t = t:gsub("%s+", " ")
	if #t > n then return t:sub(1, n) .. "~" end
	return t
end
E.short = short
local function textName(t) return E.nameOf(t.obj) .. ' "' .. short(t.text) .. '"' end
local function boxName(b)
	-- a box is named by its first text, if it has one (a pill's label, a row's name)
	local label
	for _, fs in ipairs(b.texts or {}) do label = label or fs end
	return E.nameOf(b.frame) .. (label and (' "' .. short(label, 20) .. '"') or "")
end

---------------------------------------------------------------------------
-- The tooltip
---------------------------------------------------------------------------

E.TIP = { pad = 10, header = 14, text = 12, gap = 2, wrap = 210, font = "Fonts\\FRIZQT__.TTF" }
-- the game tooltip's box (screen units) as the game would draw it before any clamp, or nil
function E.tooltip(c, TL)
	local tt = c.env.GameTooltip
	local s = tt and S[tt]
	if not (s and s.shown and s.owner and #(s.tipLines or {}) > 0) then return nil end
	if s.wuberMirror then return nil end -- Wuber's own tip card: a real frame (E.tipCard), nothing to work out
	if tagOf(s.owner) ~= "Wuber" then return nil end
	local P = E.TIP
	-- placed by points of its own (Wuber moves a tip back on): the harness's own rect when it has a size
	local orr = H.rect(s.owner)
	if not orr then return nil end
	local maxW, hgt = 0, 0
	for i, text in ipairs(s.tipLines) do
		local meta = (s.tipMeta or {})[i] or {}
		local size = i == 1 and P.header or P.text
		local w, h
		if TL then
			local L = TL.layout(P.font, size, text, { width = meta[4] and P.wrap or nil })
			w, h = L.width, L.height
		else
			w = math.min(#plain(text) * size * 0.5, meta[4] and P.wrap or 1e9)
			h = size * 1.2 * math.ceil(#plain(text) * size * 0.5 / (meta[4] and P.wrap or 1e9))
		end
		if w > maxW then maxW = w end
		hgt = hgt + h + (i > 1 and P.gap or 0)
	end
	local e = H.effScale(tt)
	local W, Hh = (maxW + 2 * P.pad) * e, (hgt + 2 * P.pad - 2) * e
	local a = s.tipAnchor or { "ANCHOR_RIGHT", 0, 0 }
	local kind, ax, ay = a[1], (a[2] or 0) * e, (a[3] or 0) * e
	local l, b
	if #(s.points or {}) > 0 and kind ~= "ANCHOR_NONE" then
		-- SetOwner then points: the points win (Wuber's move back on)
		local r = H.rect(tt)
		if r then l, b = r.l, r.b + r.h - Hh end
	end
	if not l then
		if kind == "ANCHOR_LEFT" then l, b = orr.l - W, orr.b + orr.h
		elseif kind == "ANCHOR_TOP" then l, b = orr.l + orr.w / 2 - W / 2, orr.b + orr.h
		elseif kind == "ANCHOR_BOTTOM" then l, b = orr.l + orr.w / 2 - W / 2, orr.b - Hh
		elseif kind == "ANCHOR_TOPLEFT" then l, b = orr.l, orr.b + orr.h
		elseif kind == "ANCHOR_TOPRIGHT" then l, b = orr.l + orr.w - W, orr.b + orr.h
		elseif kind == "ANCHOR_BOTTOMLEFT" then l, b = orr.l - W, orr.b - Hh
		elseif kind == "ANCHOR_BOTTOMRIGHT" then l, b = orr.l + orr.w, orr.b - Hh
		elseif kind == "ANCHOR_CURSOR" or kind == "ANCHOR_NONE" or kind == "ANCHOR_PRESERVE" then l, b = orr.l + orr.w / 2 + 8, orr.b + orr.h / 2 + 8
		else l, b = orr.l + orr.w, orr.b + orr.h end
		l, b = l + ax, b + ay
	end
	return { l = l, b = b, r = l + W, t = b + Hh, owner = s.owner, anchor = kind, title = s.tipLines[1] }
end

-- (design 4) Wuber's own tip card, the frame WuberTip: it must lie wholly on the screen and never on the control it
-- explains (its owner). Returns a list of { what, detail, key } (empty: fine, or no tip shows).
function E.tipCard(c)
	local out = {}
	local card = c.env.WuberTip
	if not (card and H.visible(card)) then return out end
	local r = H.rect(card)
	local up = H.rect(c.env.UIParent)
	if not (r and up) then return out end
	local owner = card.owner
	local name = "tooltip of " .. (owner and E.nameOf(owner) or "?")
	local cb, sb = box(r), box(up)
	local side, n = worst(spill(cb, sb))
	if side and n > 0.5 then
		out[#out + 1] = { what = name, detail = ("off the screen (%s by %.0f)"):format(side, n), key = name .. " off screen" }
	end
	local orr = owner and S[owner] and H.rect(owner)
	if orr then
		local w, h = inter(cb, box(orr))
		if w > 0.5 and h > 0.5 then
			out[#out + 1] = { what = name, detail = ("covers what it explains (%.0f x %.0f)"):format(w, h), key = name .. " on its owner" }
		end
	end
	return out
end

---------------------------------------------------------------------------
-- The checks
---------------------------------------------------------------------------

local function add(out, kind, what, detail, key)
	out[#out + 1] = { kind = kind, what = what, detail = detail, key = key or what }
end

-- (for --debug) a widget and its ancestors: name, type, shown, alpha, box, clips, strata/level
function E.chain(obj)
	local parts = {}
	local o = obj
	while o and S[o] do
		local s = S[o]
		local r = H.rect(o)
		local f = s.kind == "frame" and o or s.parent
		parts[#parts + 1] = ("%s[%s%s a=%.2f %s%s %s/%s]"):format(s.name or s.lcSrc or "?", s.otype, s.shown and "" or " HIDDEN", s.alpha or 1,
			r and ("%.0f,%.0f %.0fx%.0f"):format(r.l, r.b, r.w, r.h) or "norect", s.clips and " CLIPS" or "",
			f and f.GetFrameStrata and f:GetFrameStrata() or "-", f and f.GetFrameLevel and f:GetFrameLevel() or "-")
		o = s.parent
	end
	return table.concat(parts, " < ")
end

-- sweep: pairs of items whose boxes meet on x (sorted by left)
local function pairsOf(list, field, fn)
	table.sort(list, function(a, b) return a[field].l < b[field].l end)
	for i = 1, #list do
		local a = list[i]
		for j = i + 1, #list do
			local b = list[j]
			if b[field].l >= a[field].r then break end
			fn(a, b)
		end
	end
end

local function clipTo(a, clip)
	if not clip then return a end
	local l, b, r, t = math.max(a.l, clip.l), math.max(a.b, clip.b), math.min(a.r, clip.r), math.min(a.t, clip.t)
	if r - l <= 0 or t - b <= 0 then return nil end
	return { l = l, b = b, r = r, t = t }
end
E.clipTo = clipTo

-- two of Wuber's windows on top of each other (the big button on the phone): one problem per pair a shot
local function windows(out, hiRoot, loRoot, w, h, how)
	local a, b = E.nameOf(hiRoot), E.nameOf(loRoot)
	add(out, "windows", a, ("over the window %s (%s, %.0f x %.0f)"):format(b, how, w, h), a .. " over " .. b)
end

-- a shot's problems. opts.TL: the text layout (tooltip widths)
function E.check(c, opts)
	opts = opts or {}
	local sc = E.scan(c)
	local out = {}
	local scr = sc.screen
	-- (design 4) Wuber's own tip card (WuberTip) lies over other things by nature: it is no window on a window,
	-- and what is under it is not "partly under" a box. Its own rule is below (E.tipCard).
	local tipRoot = c.env.WuberTip
	if tipRoot and not H.visible(tipRoot) then tipRoot = nil end
	-- what really shows of each: its box cut to its scroll view
	local texts, boxes = {}, {}
	for _, t in ipairs(sc.texts) do
		t.vis = clipTo(t.ink, t.clip)
		if t.vis then texts[#texts + 1] = t end
	end
	local all = {}
	for _, b in ipairs(sc.boxes) do
		b.vis = clipTo(b.rect, b.clip)
		b.texts = {}
		if b.vis then all[#all + 1] = b end
	end
	-- a box hidden whole under another drawn above it (a sub-page over its tab's page) is not on screen
	for _, b in ipairs(all) do
		local hidden = false
		for _, o in ipairs(all) do
			if o ~= b and not isAncestor(o.frame, b.frame) and above(o.z, b.z) and inside(b.vis, o.vis, 0) and not (tipRoot and o.root == tipRoot and b.root ~= tipRoot) then hidden = true break end
		end
		if not hidden then boxes[#boxes + 1] = b end
	end
	local boxOf = {}
	for _, b in ipairs(boxes) do boxOf[b.frame] = b end
	for _, t in ipairs(texts) do
		local o = S[t.obj].parent
		while o and S[o] do
			local b = boxOf[o]
			if b then b.texts[#b.texts + 1] = t.text break end
			o = S[o].parent
		end
	end
	-- the boxes drawn above a text (not its own ancestors') that meet what shows of it
	local function coversOf(t)
		local list = {}
		for _, b in ipairs(boxes) do
			if b.frame ~= ownerOf(t.obj) and not isAncestor(b.frame, t.obj) and above(b.z, t.z) and not (tipRoot and b.root == tipRoot) then
				local w, h = inter(t.vis, b.vis)
				if w > K.UNDER and h > K.UNDER then list[#list + 1] = { box = b, w = w, h = h } end
			end
		end
		return list
	end
	-- a text hidden whole under an opaque box above it is not on screen; partly under one: a problem
	local shown = {}
	for _, t in ipairs(texts) do
		local cov = coversOf(t)
		local hidden = false
		for _, cv in ipairs(cov) do
			if inside(t.vis, cv.box.vis, 0) then hidden = true break end
		end
		if not hidden then
			shown[#shown + 1] = t
			for _, cv in ipairs(cov) do
				if cv.box.root ~= t.root then
					windows(out, cv.box.root, t.root, cv.w, cv.h, "a text partly under it")
				else
					add(out, "under", textName(t), ("partly under %s (%.0f x %.0f)"):format(boxName(cv.box), cv.w, cv.h),
						E.nameOf(t.obj) .. " under " .. E.nameOf(cv.box.frame))
				end
			end
		end
	end
	-- (BRIEF24 B2) a text drawn over the edge of a box that is not its own (a pill, a card): half on it, half off,
	-- as the bird card's "Don't show again" over the "Open Wuber" pill. Kind "straddle"; only a Button's box
	-- counts (a pill): a text on a map strip, a heatmap or a card is often meant to lie across it.
	for _, t in ipairs(shown) do
		for _, b in ipairs(boxes) do
			if b.frame ~= ownerOf(t.obj) and not isAncestor(b.frame, t.obj) and not above(b.z, t.z) and b.root == t.root
				and (function(f) local ok, ty = pcall(f.GetObjectType, f) return ok and ty == "Button" end)(b.frame) then
				local w, h = inter(t.vis, b.vis)
				if w > K.SLOP and h > K.SLOP and not inside(t.vis, b.vis, 0) and not inside(b.vis, t.vis, 0) then
					add(out, "straddle", textName(t), ("half over %s (%.0f x %.0f)"):format(boxName(b), w, h),
						E.nameOf(t.obj) .. " straddles " .. E.nameOf(b.frame))
				end
			end
		end
	end
	for _, t in ipairs(shown) do
		local fs = t.obj
		local name = E.nameOf(fs)
		-- cut short ("..."), or laid out before its font loaded
		local okT, isT = pcall(fs.IsTruncated, fs)
		local tr = H.truncation and H.truncation(fs)
		if tr and tr.stale then
			add(out, "cut", textName(t), "laid out before its font loaded: drawn cut short", name .. " stale")
		elseif okT and isT and not rawget(fs, "wuberEllipsis") then
			-- (fs.wuberEllipsis: Wuber's own mark for a string cut on purpose, with its reason)
			add(out, "cut", textName(t), "cut short (\"...\")", name .. " cut")
		end
		-- off the screen
		local side, n = worst(spill(t.vis, scr))
		if side then add(out, "offscreen", textName(t), ("off the screen (%s by %.0f)"):format(SIDE[side], n), name .. " off screen") end
		-- cut by its scroll view (partly in, partly out)
		if t.clip then
			local s2, n2 = worst(spill(t.ink, t.clip))
			if s2 then add(out, "clipped", textName(t), ("cut by its view %s (%s by %.0f)"):format(E.nameOf(t.clip.frame), SIDE[s2], n2), name .. " clipped") end
		end
		-- runs out of what it is drawn on: partly over a card, pill or window of its own (beneath it or its
		-- ancestor), and on none that holds it whole
		local best, bw, held = nil, 0, false
		for _, b in ipairs(boxes) do
			if b.root == t.root and (isAncestor(b.frame, fs) or not above(b.z, t.z)) then
				local w, h = inter(t.vis, b.vis)
				if w > 0 and h > 0 then
					if inside(t.vis, b.vis) then held = true break end
					if w * h > bw then best, bw = b, w * h end
				end
			end
		end
		if best and not held then
			local s4, n4 = worst(spill(t.vis, best.vis))
			if s4 then add(out, "spill", textName(t), ("runs out of %s (%s by %.0f)"):format(boxName(best), SIDE[s4], n4), name .. " spills") end
		end
	end
	-- text on text
	pairsOf(shown, "vis", function(a, b)
		local w, h = inter(a.vis, b.vis)
		if tipRoot and a.root ~= b.root and (a.root == tipRoot or b.root == tipRoot) then
			-- the tip card's words over the page's: what a tip is
		elseif w > K.SLOP and h > K.SLOP and a.root ~= b.root then
			if above(b.z, a.z) then a, b = b, a end
			windows(out, a.root, b.root, w, h, "texts on texts")
		elseif w > K.SLOP and h > K.SLOP then
			local n1, n2 = textName(a), textName(b)
			if n2 < n1 then n1, n2 = n2, n1 end
			local k1, k2 = E.nameOf(a.obj), E.nameOf(b.obj)
			if k2 < k1 then k1, k2 = k2, k1 end
			add(out, "overlap", n1, ("overlaps %s (%.0f x %.0f)"):format(n2, w, h), k1 .. " x " .. k2)
		end
	end)
	local sheetsUp = E.sheets(c, opts.chrome or E.chromeOf(c))
	-- box on box: a pill, card or bar half over another (neither inside the other, neither the other's ancestor)
	pairsOf(boxes, "vis", function(a, b)
		if isAncestor(a.frame, b.frame) or isAncestor(b.frame, a.frame) then return end
		if tipRoot and a.root ~= b.root and (a.root == tipRoot or b.root == tipRoot) then return end
		local w, h = inter(a.vis, b.vis)
		-- (job 2525, E) a page box wholly under a modal sheet's dim is covered on purpose: the sheet's frames (or another box under
		-- the dim) lying over it are no overlap; a box the dim cuts is the sheet-edge kind's
		if w > K.SLOP and h > K.SLOP and #sheetsUp > 0 then
			local hi, lo = a, b
			if above(b.z, a.z) then hi, lo = b, a end
			for _, m in ipairs(sheetsUp) do
				if m.under(lo.frame, lo.vis) and (m.mine(hi.frame) or m.under(hi.frame, hi.vis)) then return end
			end
		end
		if w > K.SLOP and h > K.SLOP and a.root ~= b.root then
			local hi, lo = a, b
			if above(b.z, a.z) then hi, lo = b, a end
			windows(out, hi.root, lo.root, w, h, "boxes meet")
		elseif w > K.SLOP and h > K.SLOP and not inside(a.vis, b.vis) and not inside(b.vis, a.vis) then
			local hi, lo = a, b
			if above(b.z, a.z) then hi, lo = b, a end
			add(out, "boxes", boxName(hi), ("half over %s (%.0f x %.0f)"):format(boxName(lo), w, h), E.nameOf(hi.frame) .. " over " .. E.nameOf(lo.frame))
		end
	end)
	-- boxes and controls off the screen
	for _, b in ipairs(boxes) do
		local side, n = worst(spill(b.vis, scr))
		if side and n > K.EDGE then add(out, "offscreen", boxName(b), ("off the screen (%s by %.0f)"):format(SIDE[side], n), E.nameOf(b.frame) .. " off screen") end
	end
	for _, ctl in ipairs(sc.controls) do
		local v = clipTo(ctl.rect, ctl.clip)
		local side, n
		if v then side, n = worst(spill(v, scr)) end
		if side and n > K.EDGE and not boxOf[ctl.frame] then add(out, "offscreen", E.nameOf(ctl.frame), ("off the screen (%s by %.0f)"):format(SIDE[side], n), E.nameOf(ctl.frame) .. " off screen") end
	end
	-- a scroll cue under an empty view: the rows it says are below never drew (a text, or a drawn card or square
	-- such as the heatmap's, right above it is a row that drew: BRIEF22 L1)
	for _, t in ipairs(shown) do
		if t.text:match("^Scroll for") or t.text:match("more below") then
			local top = nil
			for _, list in ipairs({ shown, boxes }) do
				for _, u in ipairs(list) do
					if u ~= t and u.root == t.root and u.vis.b >= t.vis.t - 0.5 then
						local w = math.min(u.vis.r, t.rect.r) - math.max(u.vis.l, t.rect.l)
						if w > 0 and (not top or u.vis.b < top) then top = u.vis.b end
					end
				end
			end
			if top and top - t.vis.t > K.CUE_GAP then
				add(out, "emptycue", textName(t), ("%.0f units of blank space above the cue: the rows it points at are missing"):format(top - t.vis.t), E.nameOf(t.obj) .. " empty")
			end
		end
	end
	-- the tooltip
	local tip = E.tooltip(c, opts.TL)
	for _, p in ipairs(E.tipCard(c)) do add(out, "tooltip", p.what, p.detail, p.key) end
	if tip then
		local side, n = worst(spill(tip, scr))
		if side and n > K.EDGE then
			add(out, "tooltip", "tooltip of " .. E.nameOf(tip.owner) .. ' "' .. short(plain(tip.title)) .. '"', ("off the screen (%s by %.0f, %s)"):format(SIDE[side], n, tip.anchor), "tooltip " .. E.nameOf(tip.owner))
		end
	end
	for _, h in ipairs(E.world(c)) do out[#out + 1] = h end
	-- (design 2, C) chrome: the window's own furniture that page content keeps clear of, whatever is drawn on top:
	-- the header's round buttons and the tab bar (opts.chrome, else E.chromeOf(c): Wuber's own). A text or a box
	-- inside the window that is not part of them and shares more than 2 x 2 with one is a problem; a box that holds
	-- a whole button is what the button lies on (a map, a bar, a page) and is fine. A problem the rules above
	-- already named for the same thing is not named twice.
	local ch = opts.chrome or E.chromeOf(c)
	if ch then
		local named = {}
		for _, h in ipairs(out) do named[h.what] = true end
		local function part(obj)
			for _, f in ipairs(ch.own or {}) do
				if obj == f or isAncestor(f, obj) then return true end
			end
			return false
		end
		local function page(obj) return not part(obj) and (not ch.win or isAncestor(ch.win, obj)) end
		local zones = {}
		for _, b in ipairs(ch.buttons or {}) do
			if H.visible(b) then zones[#zones + 1] = { r = box(H.rect(b)), name = "the header button " .. E.nameOf(b), hold = true } end
		end
		if ch.bar and H.visible(ch.bar) then zones[#zones + 1] = { r = box(H.rect(ch.bar)), name = "the tab bar" } end
		for _, z in ipairs(zones) do
			for _, t in ipairs(texts) do
				local w, h = inter(t.vis, z.r)
				if w > 2 and h > 2 and page(t.obj) and not named[textName(t)] then
					add(out, "chrome", textName(t), ("in the place of %s (%d x %d)"):format(z.name, w, h), E.nameOf(t.obj) .. " chrome")
				end
			end
			for _, b in ipairs(boxes) do
				local w, h = inter(b.vis, z.r)
				if w > 2 and h > 2 and page(b.frame) and not (z.hold and inside(z.r, b.vis, 0)) and not named[boxName(b)] then
					add(out, "chrome", boxName(b), ("in the place of %s (%d x %d)"):format(z.name, w, h), E.nameOf(b.frame) .. " chrome")
				end
			end
		end
	end
	for _, h in ipairs(E.sheetEdge(c, texts, boxes, ch)) do out[#out + 1] = h end
	-- the word rule: the words of what shows (the phone's clock is not counted); run.lua knows the budget
	local clock = type(c.W) == "table" and type(c.W.UI) == "table" and c.W.UI.state and c.W.UI.state.phone
	clock = type(clock) == "table" and clock.clock or nil
	local words = 0
	local fonts = {}
	for _, t in ipairs(shown) do
		if t.obj ~= clock then words = words + E.countWords(t.text) end
		-- the type rule (tests/layout/type.lua): the font each shown text is drawn in
		local f = S[t.obj].font
		fonts[#fonts + 1] = { text = t.text, path = f and f.path, size = f and f.size }
	end
	return out, sc, words, fonts
end

-- (job 2525, E) sheet-edge: with a modal sheet up (a T.Sheet: a visible frame with .dim and .card, over a window with a
-- header), (1) its dim reaches up to the header's bottom edge (no strip of page between them stays undimmed), and (2) every
-- page text and box in the window is fully under the dim or fully outside it (none cut by the dim's edge; a box that holds
-- the whole dim is a background and is fine). Kind "sheet-edge". texts/boxes are E.check's drawn lists; ch = E.chromeOf.
-- the modal sheets up now: { sh, name, D (the dim's box), zs (its draw order), page(obj) = a page frame of the window, drawn under the dim,
-- under(obj, r) = that page frame (box r) is wholly under the dim (a page frame under a modal sheet is covered on purpose) }
function E.sheets(c, ch)
	local list = {}
	if not ch then return list end
	local order = {}
	for i, o in ipairs(c.widgets) do order[o] = i end
	for _, sh in ipairs(c.widgets) do
		local ss = S[sh]
		local dim = ss and ss.kind == "frame" and type(sh) == "table" and rawget(sh, "dim") or nil
		if dim and S[dim] and type(rawget(sh, "card")) == "table" and tagOf(sh) == "Wuber" and H.visible(sh)
			and effAlpha(dim) >= K.ALPHA and (not ch.win or isAncestor(ch.win, sh)) then
			local dr = H.rect(dim)
			if dr and dr.w > 2 and dr.h > 2 then
				local D, zs = box(dr), zOf(dim, order)
				local m = { sh = sh, name = E.nameOf(sh), D = D }
				function m.mine(obj) return obj == sh or isAncestor(sh, obj) end
				function m.page(obj)
					for _, f in ipairs(ch.own or {}) do if obj == f or isAncestor(f, obj) then return false end end
					if m.mine(obj) then return false end
					-- a secure overlay (UI.Secure: WuberRequestButton, WuberShareButton) stands over its pill inside the window: under a modal sheet it is covered on purpose, like the pill (job 253, gate edit)
					local pill = type(obj) == "table" and rawget(obj, "pill") or nil
					if type(pill) == "table" and ch.win and isAncestor(ch.win, pill) then return not above(zOf(obj, order), zs) end
					if ch.win and not isAncestor(ch.win, obj) then return false end
					return not above(zOf(obj, order), zs)
				end
				function m.under(obj, r) return m.page(obj) and inside(r, D) end
				list[#list + 1] = m
			end
		end
	end
	return list
end

function E.sheetEdge(c, texts, boxes, ch)
	local out = {}
	local head = ch and ch.head and H.visible(ch.head) and box(H.rect(ch.head)) or nil
	for _, m in ipairs(E.sheets(c, ch)) do
		local D, name = m.D, m.name
		if head and D.l < head.r and D.r > head.l and head.b - D.t > K.SLOP then
			add(out, "sheet-edge", name, ("the dim starts %.0f below the header's bottom edge: a strip of page between them is not dimmed"):format(head.b - D.t), name .. " strip")
		end
		local function cut(r, nm, key, isBox)
			local w, h = inter(r, D)
			if w > K.SLOP and h > K.SLOP and not inside(r, D) and not (isBox and inside(D, r)) then
				add(out, "sheet-edge", nm, ("cut by the edge of the dim of %s: %.0f x %.0f under it, the rest outside"):format(name, w, h), key .. " cut by " .. name)
			end
		end
		for _, t in ipairs(texts) do if m.page(t.obj) then cut(t.vis, textName(t), E.nameOf(t.obj), false) end end
		for _, b in ipairs(boxes) do if m.page(b.frame) then cut(b.vis, boxName(b), E.nameOf(b.frame), true) end end
	end
	return out
end

-- Wuber's chrome for the rule above: the window, its header buttons (the x, the cog, the fold button) and the tab
-- bar; nil on a copy of the addon that has no tab bar (older trees), or with no Wuber at all.
function E.chromeOf(c)
	local ui = type(c) == "table" and type(c.W) == "table" and type(c.W.UI) == "table" and c.W.UI.state
	if type(ui) ~= "table" or not (ui.win and ui.tabbar) then return nil end
	local fold = type(ui.phone) == "table" and ui.phone.fold or nil
	local own, buttons = { ui.tabbar }, {}
	for _, f in ipairs({ ui.top, ui.close, ui.gear, fold }) do own[#own + 1] = f end
	for _, f in ipairs({ ui.close, ui.gear, fold }) do buttons[#buttons + 1] = f end
	return { win = ui.win, bar = ui.tabbar, buttons = buttons, own = own, head = ui.top }
end

---------------------------------------------------------------------------
-- (BRIEF26 item 3) The World view: each continent whole inside the view, both at one scale
---------------------------------------------------------------------------

E.WORLD = { MARGIN = 4, SCALE_TOL = 0.01, STEP = 1000, GAP_TOL = 1 }

-- WM: the World map module (Box, Project); view = { w, h } of the pane. Returns hits of kind "world":
--   "continent leaves the view"  a continent's drawn box is not inside the view with E.WORLD.MARGIN to spare
--   "gap between the continents"  the boxes are more than GAP_TOL px apart or overlap by more than that
--   "continent scales differ"    the two continents' pixels per world yard differ by more than E.WORLD.SCALE_TOL
-- The scale is measured through WM.Project on three known world points (a step along each world axis).
function E.worldRule(WM, view)
	local out, K = {}, E.WORLD
	local scale = {}
	for _, cont in ipairs({ 1, 0 }) do
		local x, y, w, h = WM.Box(cont)
		if x then
			local sp = ("box %.0f,%.0f %.0fx%.0f in a %.0fx%.0f view"):format(x, y, w, h, view.w, view.h)
			if x < K.MARGIN or y < K.MARGIN or x + w > view.w - K.MARGIN or y + h > view.h - K.MARGIN then
				add(out, "world", "World view continent " .. cont, "continent leaves the view (" .. sp .. ")", "world leaves " .. cont)
			end
			local px, py = WM.Project(cont, 0, 0)
			local ax, ay = WM.Project(cont, K.STEP, 0)
			local bx, by = WM.Project(cont, 0, K.STEP)
			if px and ax and bx then
				scale[cont] = { x = math.sqrt((ax - px) ^ 2 + (ay - py) ^ 2) / K.STEP, y = math.sqrt((bx - px) ^ 2 + (by - py) ^ 2) / K.STEP }
			end
		end
	end
	-- (round 26b) no gap: the two boxes touch (within E.WORLD.GAP_TOL px), side by side
	local ka, kb = { WM.Box(1) }, { WM.Box(0) }
	if ka[1] and kb[1] then
		local l, r = ka, kb
		if kb[1] < ka[1] then l, r = kb, ka end
		local gap = r[1] - (l[1] + l[3])
		if math.abs(gap) > K.GAP_TOL then
			add(out, "world", "World view continents", ("gap between the continents (%.1f px, at most %d allowed)"):format(gap, K.GAP_TOL), "world gap")
		end
	end
	-- one scale = the same pixels per square yard (the geometric mean of x and y): a learned calibration can
	-- stretch one continent's art (Kalimdor east-west), so x and y cannot both match; the area always can
	local a, b = scale[1], scale[0]
	if a and b then
		local sa, sb = math.sqrt(a.x * a.y), math.sqrt(b.x * b.y)
		local hi, lo = math.max(sa, sb), math.min(sa, sb)
		if lo <= 0 or (hi - lo) / hi > K.SCALE_TOL then
			add(out, "world", "World view continents", ("continent scales differ (px per yard: Kalimdor %.5f, Eastern Kingdoms %.5f)"):format(sa, sb), "world scales")
		end
	end
	return out
end

-- the rule on the client's World view when it is showing (hits; none when the view is not the World map)
function E.world(c)
	local W = c and c.W
	local okm, WM = pcall(function() return W and W.Mod("UI.Rider.WorldMap") end)
	if not (okm and type(WM) == "table" and type(WM.Box) == "function" and type(WM.cache) == "table") then return {} end
	local wm = WM.cache.last
	local view = wm and wm.view
	if not (view and wm.mode == "world") then return {} end
	local okv, shown = pcall(view.IsVisible, view)
	if not (okv and shown) then return {} end
	local okr, hits = pcall(E.worldRule, WM, { w = view:GetWidth(), h = view:GetHeight() })
	return okr and hits or {}
end

return E
