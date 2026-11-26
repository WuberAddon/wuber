-- The layout sweep for one screen at one setting, from inside a test (job 2885, #238 fix PRs): the fake game with the
-- measured text widths (tools/preview/textlayout.lua) lays out the tour's screen(s), and the problems whose frame name matches
-- come back, whatever the allow-list says (a "known" entry only keeps the sweep gate green, it does not make the text fit).
--   local probe = assert(loadfile(H.root .. "/tests/layout/probe.lua"))(H)
--   local hits = probe("1920x1080@1.15,ui0.71", { "earnings" }, "^Earnings%.lua:%d+", "cut")   -- a list of { shot, key, what, kind, detail }
--   the pattern is matched against the frame's key (file:line), or against its "what" (file:line, role and the text: Rows.lua:255 label "Replay");
--   a table of patterns takes a hit that matches ANY of them in its key or its what
local H = ...
--   probe(cfg, screens, pattern, kind, { textRule = "flat", probe = "<fixture path>" })   (job 2893) the flat 6% rule, and/or a probe fixture's "was it cut" answers
return function(cfgText, screens, keyPattern, kind, extra)
	extra = extra or {}
	local w, h, sc, ui = cfgText:match("^(%d+)x(%d+)@([%d.]+),ui([%d.]+)$")
	assert(w, "config WxH@scale,uiN, e.g. 1920x1080@1.15,ui0.71")
	local cfg = { w = tonumber(w), h = tonumber(h), scale = tonumber(sc), ui = tonumber(ui), id = cfgText }
	local lab = H.root .. "/lab/WuberLab"
	local oldLab = H.ADDONS.WuberLab
	H.ADDONS.WuberLab = lab
	local E = assert(loadfile(H.root .. "/tests/layout/engine.lua"))(H)
	local Run = assert(loadfile(H.root .. "/tests/layout/run.lua"))(H, E, H.root)
	local ok, res = pcall(Run.config, cfg, { screens = screens, scenes = true, textRule = extra.textRule, probe = extra.probe })
	H.ADDONS.WuberLab = oldLab
	H.measuredCut = nil -- (job 2893) a run that threw leaves no learned rule behind
	if not ok then error(res, 0) end
	local out = {}
	local pats = type(keyPattern) == "table" and keyPattern or { keyPattern }
	for _, hit in ipairs(res.hits) do
		if not kind or hit.kind == kind then
			for _, p in ipairs(pats) do
				if tostring(hit.key):find(p) or tostring(hit.what):find(p) then
					out[#out + 1] = { shot = hit.shot, key = hit.key, what = hit.what, kind = hit.kind, detail = hit.detail }
					break
				end
			end
		end
	end
	return out
end
