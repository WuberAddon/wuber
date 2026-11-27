-- tests/lib/listfade.lua (round 9, S6): the clipped-list check. Every visible frame that clips its
-- children is a list viewport (maps say so with frame.noEdgeFade = "<why>" and are skipped). A
-- visible row part (a font string with text, or a texture that shows; soft shadows and glows are
-- decoration, not rows) that is partly outside a viewport it sits in, at its top or bottom, must
-- have that viewport's soft fade (T.EdgeFade: frame.edgeFade) showing at that edge: a row cut by a
-- hard edge is the bug the author saw. Viewports are applied from the nearest out, so a part already
-- hidden by an inner list (or cut there under its fade) is judged only by what still shows.
--
-- (round 13, I18) It also fails on any visible font string whose text the game cuts with "..." (a reviewer
-- found 'Waiting for Mia to open tra...', 'Top window: 17:00-20:...', '50s to Orgrim...' and more):
-- the harness models truncation (H.truncation: wider than its width with word wrap off, or more
-- lines than SetMaxLines). Intended ellipses are listed in ALLOW (a short list, each with its why),
-- or a label says so itself with fs.wuberEllipsis = "<why>".
--
--   local check = dofile(dir .. "/lib/listfade.lua")(H)
--   local bad = check(client, "page name") -- { "<page>: <viewport> bottom edge ...: <part> cut 12 px", ... }
return function(H)
	local S = H.state
	local SLOP = 1.5
	local DECOR = { "shadow", "glow", "halo", "shimmer", "spark" }
	-- intended ellipses: { text pattern, why } (keep it short; prefer fs.wuberEllipsis on the label)
	local ALLOW = {
	}

	local function allowed(fs, text)
		if rawget(fs, "wuberEllipsis") then return true end
		for _, a in ipairs(ALLOW) do if text:find(a[1]) then return true end end
		return false
	end

	local function alphaOf(obj)
		local ok, a = pcall(function() return obj:GetEffectiveAlpha() end)
		return ok and tonumber(a) or 1
	end

	-- a name for a frame or region in a message: its text, its global name, or its type and texture
	local function label(obj)
		local s = S[obj]
		if s.text and s.text ~= "" then return ("%q"):format(tostring(s.text):sub(1, 40)) end
		if s.name then return s.name end
		local t = s.texture
		return (s.otype or "?") .. (type(t) == "string" and (" " .. (t:match("([^\\/]+)$") or t)) or "")
	end

	-- the frames from obj up to the root that clip their children, nearest first
	local function clippers(obj)
		local out = {}
		local p = S[obj].parent
		while p do
			if S[p].clips then out[#out + 1] = p end
			p = S[p].parent
		end
		return out
	end

	local function shows(obj)
		local s = S[obj]
		if s.kind ~= "region" then return false end
		if not H.visible(obj) or alphaOf(obj) < 0.05 then return false end
		if s.otype == "FontString" then return s.text ~= nil and tostring(s.text):match("%S") ~= nil end
		if s.otype == "Texture" then
			if s.texture == nil and s.color == nil then return false end
			local t = type(s.texture) == "string" and s.texture:lower() or ""
			for _, d in ipairs(DECOR) do if t:find(d, 1, true) then return false end end
			if s.blend == "ADD" then return false end
			return true
		end
		return false
	end

	local function fadeShown(view, edge)
		local fd = view.edgeFade
		if type(fd) ~= "table" or type(fd.Shown) ~= "function" then return false end
		if not H.visible(fd.holder) then return false end
		return fd:Shown(edge) and alphaOf(edge == "top" and fd.top or fd.bottom) > 0.05
	end

	return function(c, where)
		local bad, seen = {}, {}
		for _, obj in ipairs(c.widgets or {}) do
			if S[obj] and shows(obj) then
				local r = H.rect(obj)
				if r and r.h > 0 and r.w > 0 then
					-- what still shows of it: l, r, b, t, narrowed by each viewport in turn
					local L, R, B, Tp = r.l, r.l + r.w, r.b, r.b + r.h
					local hidden = false
					for _, v in ipairs(clippers(obj)) do
						if not H.visible(v) then hidden = true break end
						local vr = H.rect(v)
						if vr and vr.h > 0 and vr.w > 0 then
							local vl, vR, vb, vt = vr.l, vr.l + vr.w, vr.b, vr.b + vr.h
							if B >= vt - SLOP or Tp <= vb + SLOP or L >= vR - SLOP or R <= vl + SLOP then hidden = true break end -- hidden here
							if not v.noEdgeFade then
								for _, edge in ipairs({ "top", "bottom" }) do
									local cut = edge == "top" and (Tp - vt) or (vb - B)
									if cut > SLOP and not fadeShown(v, edge) then
										local key = tostring(v) .. edge .. label(obj)
										if not seen[key] then
											seen[key] = true
											bad[#bad + 1] = ("%s%s %s edge (%.0f px tall at y %.0f): %s cut %.0f px"):format(
												where and (where .. ": ") or "", label(v), edge, vr.h, vb, label(obj), cut)
											if rawget(_G, "LAST") then _G.LAST[v] = obj end
										end
									end
								end
							end
							L, R, B, Tp = math.max(L, vl), math.min(R, vR), math.max(B, vb), math.min(Tp, vt)
						end
					end
					-- (I18) its words cut short with "..."
					if not hidden and S[obj].otype == "FontString" then
						local cut = H.truncation(obj)
						local text = tostring(S[obj].text)
						if cut and not allowed(obj, text) then
							local key = "text" .. tostring(obj)
							if not seen[key] then
								seen[key] = true
								bad[#bad + 1] = ("%s%s is cut short with \"...\": needs %.0f px, has %.0f%s"):format(where and (where .. ": ") or "",
									label(obj), cut.need, cut.room, cut.max > 1 and (" (" .. cut.lines .. " lines, " .. cut.max .. " allowed)") or "")
							end
						end
					end
				end
			end
		end
		return bad
	end
end
