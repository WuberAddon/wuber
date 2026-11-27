-- Reusable "topmost at the button" check for the fake game (tests/harness.lua), loaded by tests/bs/*_test.lua with
-- dofile(H.root .. "/tests/lib/topmost.lua").  (job 206, blind-spot check BS1)
-- Unlike Client:clickOn (which only finds the frame that TAKES the click), this reports any visible frame drawn above the button there,
-- mouse-enabled or not, so a covering card or dim that takes no click is named too.
-- Checks strata order, frame level, effective alpha, shown parent chain, and bounding rect
-- at a widget's centre (cx, cy). Reports/fails when another visible frame (e.g. WuberTipCard
-- at FULLSCREEN_DIALOG, a coach ring, or a DIALOG Options panel) covers the button's centre.

local M = {}

local function isDescendant(S, f, ancestor)
	local cur = f
	while cur do
		if cur == ancestor then return true end
		local s = S[cur]
		cur = s and s.parent or nil
	end
	return false
end

local function orderKey(H, f, idx)
	local strata = H.STRATA_RANK(f:GetFrameStrata())
	local level = tonumber(f:GetFrameLevel()) or 0
	return strata * 1e8 + level * 1e4 + (idx or 0), strata, level
end

function M.describe(H, f)
	if not f then return "<nil>" end
	local S = H.state
	local s = S[f]
	local name = (s and s.name) or tostring(f)
	local strata = f.GetFrameStrata and f:GetFrameStrata() or "?"
	local level = f.GetFrameLevel and f:GetFrameLevel() or "?"
	local alpha = f.GetEffectiveAlpha and f:GetEffectiveAlpha() or 1
	local mouse = f.IsMouseEnabled and f:IsMouseEnabled() or false
	local r = H.rect(f)
	local rstr = r and ("(%.1f,%.1f %.1fx%.1f)"):format(r.l, r.b, r.w, r.h) or "(no-rect)"
	return ("%s strata=%s level=%s alpha=%.2f mouse=%s rect=%s"):format(
		tostring(name), tostring(strata), tostring(level), tonumber(alpha) or 0, tostring(mouse), rstr)
end

-- Returns { ok, reason, cx, cy, targetKey, blockers, topBlocker }
-- opts:
--   mouseOnly (bool, default false): if true, only consider frames with IsMouseEnabled() == true
--   minAlpha (number, default 0.01): minimum effective alpha for a covering frame to count
--   includeChildren (bool, default false): if true, children of btn can also count as blockers
--   ignore (table [frame]=true): frames to ignore
function M.checkButton(H, client, btn, opts)
	opts = opts or {}
	local S = H.state
	local minAlpha = opts.minAlpha or 0.01
	if not btn then
		return { ok = false, reason = "button is nil" }
	end
	if not btn:IsVisible() then
		return { ok = false, reason = "button is not visible (IsVisible() == false): " .. M.describe(H, btn) }
	end
	local effAlpha = btn:GetEffectiveAlpha() or 0
	if effAlpha <= minAlpha then
		return { ok = false, reason = ("button effective alpha %.2f <= %.2f: %s"):format(effAlpha, minAlpha, M.describe(H, btn)) }
	end
	local r = H.rect(btn)
	if not r or r.w <= 0 or r.h <= 0 then
		return { ok = false, reason = "button has empty or invalid rect: " .. M.describe(H, btn) }
	end

	local cx = r.l + r.w / 2
	local cy = r.b + r.h / 2

	local btnIdx = 0
	for i, f in ipairs(client.frames) do
		if f == btn then btnIdx = i break end
	end
	local btnKey = orderKey(H, btn, btnIdx)

	local blockers = {}
	for i, f in ipairs(client.frames) do
		local s = S[f]
		if f ~= btn and s and not s.isUIParent and not (opts.ignore and opts.ignore[f]) then
			local take = (not opts.mouseOnly) or (f:IsMouseEnabled() == true)
			if take and f:IsVisible() and (f:GetEffectiveAlpha() or 0) > minAlpha then
				if opts.includeChildren or not isDescendant(S, f, btn) then
					local fr = H.rect(f)
					if fr and fr.w > 0 and fr.h > 0 and cx >= fr.l and cx <= fr.l + fr.w and cy >= fr.b and cy <= fr.b + fr.h then
						local fk = orderKey(H, f, i)
						if fk > btnKey then
							blockers[#blockers + 1] = { frame = f, key = fk, idx = i }
						end
					end
				end
			end
		end
	end

	table.sort(blockers, function(a, b) return a.key > b.key end)
	if #blockers > 0 then
		local top = blockers[1].frame
		return {
			ok = false,
			cx = cx,
			cy = cy,
			targetKey = btnKey,
			blockers = blockers,
			topBlocker = top,
			reason = ("covered at (%.1f, %.1f) by %s [target: %s]"):format(
				cx, cy, M.describe(H, top), M.describe(H, btn)),
		}
	end

	return {
		ok = true,
		cx = cx,
		cy = cy,
		targetKey = btnKey,
		blockers = {},
	}
end

function M.assertTopmost(H, client, btn, label, opts)
	local res = M.checkButton(H, client, btn, opts)
	if not res.ok then
		error((label or "button") .. ": not topmost: " .. tostring(res.reason), 2)
	end
	return res
end

return M