-- Layout scenes for Wuber's own tooltip, the frame WuberTip (design round 4, group D). Installed by
-- tests/layout/extra_screens.lua at its end (X.install calls this file's install), so they work alone
-- (--screen tip_) and inside a whole sweep.
--   tip_edge   the driver's console with the tip of the control nearest the screen's right edge showing. Unfolded,
--              the window ends at the screen's edge: the tip has no room on its right and stands on another side,
--              wholly on the screen and never on the control it explains (the engine's "tooltip" rule, E.tipCard).
--   tip_long   the same page with a tip of many words on a control in the middle of the window: it wraps at the
--              card's width, none of it is cut.
--   tip_whole  a rider's row in the console whose name is too long for its place: the card's first words are the name whole.
-- The tip is taken down by a wrapper of L.PhotoReset, which the tour calls before every screen and at its end.
-- Returns install(L, W): adds the screens, returns the ids it added.
local X = {}
X.LONG = "Aaaaaaaaaaaaaaa-Bbbbbbbbbbbbbbbbbbb of the Very Long Realm Name"

local function children(f, out)
	if type(f) ~= "table" or type(f.GetChildren) ~= "function" then return out end
	for _, ch in ipairs({ f:GetChildren() }) do
		out[#out + 1] = ch
		children(ch, out)
	end
	return out
end

-- the visible controls of the window that have a tip, each with its box in the window's own units
local function tipped(w)
	local env = type(getfenv) == "function" and type(w.Theme.Tip) == "function" and getfenv(w.Theme.Tip)
	local win = type(env) == "table" and rawget(env, "WuberFrame")
	local list = {}
	if type(win) ~= "table" then return list end
	for _, f in ipairs(children(win, {})) do
		-- (a control: the window's thin drag edges have a tip too and are no place to show one)
		if type(f.wuberTip) == "table" and type(f.wuberTip.title) == "string" and f:IsVisible() and f:GetRight() and f:GetLeft()
			and (f:GetWidth() or 0) >= 16 and (f:GetHeight() or 0) >= 16 and f.wuberTip.title ~= "Wuber" then
			list[#list + 1] = f
		end
	end
	return list, win
end

local function show(w, frame)
	if not frame then return "no control with a tip shows" end
	frame.wuberTipShown = true
	w.Theme.RefreshTip(frame)
	if w.Theme.TipOwner() ~= frame then return "the tip did not show" end
	return true
end

function X.install(L, W)
	local added = {}
	if not (type(W.Theme) == "table" and type(W.Theme.TipShow) == "function") then return added end
	local base
	for _, s in ipairs(L.PHOTO_SCREENS) do if s.id == "row_marks" then base = s end end
	if not (base and type(base.run) == "function") then return added end
	local reset = L.PhotoReset
	L.PhotoReset = function(w, ...)
		if type(w) == "table" and type(w.Theme) == "table" and type(w.Theme.TipHide) == "function" then w.Theme.TipHide() end
		if X.undo then X.undo() end
		if reset then return reset(w, ...) end
	end
	L.PHOTO_SCREENS[#L.PHOTO_SCREENS + 1] = { id = "tip_edge", side = "driver", unfold = true,
		title = "Wuber's tooltip at the screen's edge: the tip of the control nearest the right edge, beside it and on the screen",
		run = function(w) return base.run(w) end,
		post = function(w)
			local best
			for _, f in ipairs(tipped(w)) do
				if not best or f:GetRight() * f:GetEffectiveScale() > best:GetRight() * best:GetEffectiveScale() then best = f end
			end
			return show(w, best)
		end }
	added[#added + 1] = "tip_edge"
	L.PHOTO_SCREENS[#L.PHOTO_SCREENS + 1] = { id = "tip_long", side = "driver", unfold = true,
		title = "Wuber's tooltip with many words: it wraps at the card's width and nothing is cut",
		run = function(w) return base.run(w) end,
		post = function(w)
			local best, most = nil, 0
			for _, f in ipairs(tipped(w)) do
				local text = f.wuberTip.text
				if type(text) == "function" then
					local ok, got = pcall(text, f)
					text = ok and got or nil
				end
				if type(text) == "string" and #text > most then best, most = f, #text end
			end
			return show(w, best)
		end }
	added[#added + 1] = "tip_long"
	-- (group I2) a driver row whose name is cut: hovering it shows the name whole, first, on the same card
	L.PHOTO_SCREENS[#L.PHOTO_SCREENS + 1] = { id = "tip_whole", side = "driver", unfold = true,
		title = "Wuber's tooltip over a cut driver-row name: the whole name first, then the row's own words, beside the row",
		run = function(w) return base.run(w) end,
		post = function(w)
			local env = type(getfenv) == "function" and getfenv(w.Theme.Tip)
			local win = type(env) == "table" and rawget(env, "WuberFrame")
			if type(win) ~= "table" then return "no window" end
			local D = w.Driver
			if type(D) ~= "table" or type(D.PaintRow) ~= "function" or type(D.Row) ~= "function" then return "no driver rows" end
			-- the console paints its rows through D.PaintRow: one rider's name is a long one from now on (put back by PhotoReset)
			local paint = D.PaintRow
			X.undo = function() D.PaintRow = paint X.undo = nil end
			D.PaintRow = function(r, c, ...)
				if type(c) == "table" and c.name == "Dan Rider" then
					local copy = {}
					for k, v in pairs(c) do copy[k] = v end
					copy.name = X.LONG
					c = copy
				end
				return paint(r, c, ...)
			end
			if type(D.RefreshNow) == "function" then D.RefreshNow() end
			local row
			for _, f in ipairs(children(win, {})) do
				if type(f.name) == "table" and type(f.name.GetText) == "function" and f:IsVisible() and tostring(f.name:GetText()):find("^Aaaaaaaa") then row = f end
			end
			if not row then
				local seen = {}
				for _, f in ipairs(children(win, {})) do if type(f.name) == "table" and type(f.name.GetText) == "function" and f:IsVisible() then seen[#seen + 1] = tostring(f.name:GetText()) end end
				return "the long name did not reach a row: " .. table.concat(seen, ",")
			end
			w.Theme.WholeOnHover(row.name) -- (T.Fit sets it a moment after layout; a scene does not wait)
			local owner = row.name.wuberWhole
			if not owner then return "the long name got no hover" end
			if not w.Theme.CutOneLine(row.name) then return "the long name is not cut here" end
			return show(w, owner)
		end }
	added[#added + 1] = "tip_whole"
	-- (group I2) the Messages screen's chips: the tip beside a chip, not on the chips below it
	local edit
	for _, s in ipairs(L.PHOTO_SCREENS) do if s.id == "messages_edit" then edit = s end end
	if edit and type(edit.run) == "function" then
		L.PHOTO_SCREENS[#L.PHOTO_SCREENS + 1] = { id = "tip_chip", side = edit.side, unfold = true,
			title = "A message chip's tooltip: beside the chip, covering no chip of the rows below",
			run = function(w) return edit.run(w) end,
			post = function(w)
				local list = tipped(w)
				local pick
				for _, f in ipairs(list) do
					local text = f.wuberTip.text
					if type(text) == "function" then
						local ok, got = pcall(text, f)
						if ok and type(got) == "string" and got:find("Tap to put it", 1, true) then pick = pick or f end
					end
				end
				return show(w, pick)
			end }
		added[#added + 1] = "tip_chip"
	end
	return added
end

return X
