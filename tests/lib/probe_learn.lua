-- tests/lib/probe_learn.lua: how the fake game (tests/harness.lua) learns a WuberProbe fixture (tools/rec/probe-import.lua).
--   local L = dofile(T.dir .. "/lib/probe_learn.lua")
--   local fx = L.load("tests/fixtures/probe/<file>.lua")
--   L.apply(H, fx)  -- file ids, text widths, key rules, secrets (and nothing else is touched)
--   L.reset(H)      -- back to the harness's own guesses
--   local saved = L.save(H) ... L.restore(H, saved)  -- a test that resets or applies puts back what the run had (tests/harness.lua loads a
--                      real tests/fixtures/probe/game-*.lua at start; a test must not leave the run without it)
--   L.hitRules(fx)  -- the fixture's hit-order answers as a list { scenario, cell, winner } for a conformance test
-- What each part feeds:
--   fx.labels   -> H.measuredCut (L.cutFn: "this string in this box was cut: yes/no" for the strings the probe measured; nil, never a guess, for the
--                  others; L.coverageLine says how many current strings are unmeasured; L.band the width band to carry for those) -- job 2893
--   fx.fileIds  -> H.fileIds (harness mediaId(): Texture:GetTexture / GetTextureFileID answer the client's number for an addon path)
--   fx.widths   -> H.measuredWidths (harness textWidth(): FontString:GetStringWidth / GetUnboundedStringWidth)
--   fx.keys     -> H.keyRules (L.keyRules: IsKeyboardEnabled / IsMouseEnabled / GetPropagateKeyboardInput answer what the client answered
--                  for a frame that went through exactly the probe's call sequence; harness Frame methods)
--   fx.secretAccessors -> H.setSecretAccessors (a named Blizzard frame answers that accessor with secret values)
--   fx.secretApi -> H.secretApi (a new fake client starts with that call answering a secret; harness client.secrets)
--   fx.hit      -> the conformance list (the harness's own ranking is checked against it, see hit_conform in probe_test.lua)
--   fx.events   -> L.eventFacts(fx): which events never fire (the fake must not fire TAXIMAP_OPENED)
--   fx.env      -> L.envFacts(fx): realm name, project id, build the fake must answer
local L = {}

-- (evidence ledger, job 2882) every fixture the fake game learns from is noted in tests/lib/evidence.lua: a fixture with source = "game" makes the
-- rules it feeds "measured" with its build; "sim" and "synthetic" fixtures never do. L.note(fx, label) is the same for a table not from a file.
local function ledger()
	local chunk = loadfile((debug.getinfo(1, "S").source:gsub("^@", ""):gsub("\\", "/"):match("^(.*)/[^/]*$") or ".") .. "/evidence.lua")
	return chunk and chunk()
end
function L.note(fx, label)
	local E = ledger()
	if E then E.note(fx, label) end
	return fx
end

function L.load(path)
	local chunk, err = loadfile(path)
	if not chunk then return nil, err end
	local fx = chunk()
	if type(fx) == "table" then L.note(fx, path) end
	return fx
end

local function baseName(p) return (tostring(p or ""):gsub("\\", "/"):match("([^/]+)$") or ""):lower() end

-- the width of text in a font at a size, from the measured advances; nil = not measured (the harness's own metric answers)
function L.widthFn(fx)
	local W = fx.widths or {}
	local sizes = {}
	for font, bySize in pairs(W) do
		local list = {}
		for size in pairs(bySize) do if type(size) == "number" then list[#list + 1] = size end end
		table.sort(list)
		sizes[font] = list
	end
	return function(path, size, text)
		local font = W[baseName(path)]
		if not font then return nil end
		size = tonumber(size) or 12
		local row = font[size]
		local scale = 1
		if not row then -- a size nobody measured: the nearest measured one, scaled (advances are linear in size)
			local best
			for _, s in ipairs(sizes[baseName(path)] or {}) do if not best or math.abs(s - size) < math.abs(best - size) then best = s end end
			if not best then return nil end
			row, scale = font[best], size / best
		end
		text = tostring(text or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("||", "\1")
		if text:find("|", 1, true) then return nil end -- an escape the probe did not measure (|T..|t, |H..|h)
		local widest = 0
		for line in (text .. "\n"):gmatch("(.-)\n") do
			local w = row.strings and row.strings[line:gsub("\1", "|")]
			if type(w) ~= "number" then
				w = 0
				for i = 1, #line do
					local a = row.adv[line:byte(i)]
					if not a then return nil end -- a character the probe did not measure
					w = w + a
				end
			end
			if w > widest then widest = w end
		end
		return widest * scale
	end
end

-- The call sequences the probe's keysAuto run asked about, in the harness's vocabulary (tests/harness.lua H.keyOp): fixture key -> { object type, calls }
L.KEY_CASES = {
	defaultFrame = { "Frame", {} }, defaultButton = { "Button", {} }, defaultEditBox = { "EditBox", {} },
	keyDownAfterDisable = { "Frame", { "kb:false", "OnKeyDown" } }, disableAfterKeyDown = { "Frame", { "OnKeyDown", "kb:false" } },
	keyUp = { "Frame", { "OnKeyUp" } }, char = { "Frame", { "OnChar" } }, keyDownPropagate = { "Frame", { "OnKeyDown", "prop:true" } },
	mouseDown = { "Frame", { "OnMouseDown" } }, enter = { "Frame", { "OnEnter" } }, wheel = { "Frame", { "OnMouseWheel" } },
	onClick = { "Button", { "OnClick" } }, mouseOffThenClick = { "Button", { "mouse:false", "OnClick" } },
	mouseToggle = { "Frame", { "mouse:true", "mouse:false" } },
}

-- the rules table the harness reads: [ "<type>|<calls>" ] = { kb, mouse, prop } (nil when the fixture has no keys part)
function L.keyRules(fx)
	local rules, n = {}, 0
	for name, case in pairs(L.KEY_CASES) do
		local r = fx.keys and fx.keys[name]
		if type(r) == "table" and (r.kb ~= nil or r.mouse ~= nil or r.prop ~= nil) then
			rules[case[1] .. "|" .. table.concat(case[2], ",")] = { kb = r.kb, mouse = r.mouse, prop = r.prop }
			n = n + 1
		end
	end
	if n > 0 then return rules end
end

---------------------------------------------------------------------------
-- labels (job 2893): Wuber's real label strings, each in its own font, size and box, measured by the probe at 2-3 effective scales.
--   fx.labels = { hash = "<hash of Wuber's words when the probe was made>", scales = { 0.71, 1, 1.5 }, caps = { GetStringWidth = true, ... },
--                 rows = { { text, font = "<lower-case file name>", size, box = <box width in the string's units>, maxLines, wrap = true|false,
--                            raw = <the font's raw advance width>, w = {per scale}, uw = {per scale}, trunc = {per scale: true|false|nil},
--                            lines = {per scale} } } }
--   a row's trunc[i] is nil when the build has no IsTruncated (the probe pcalls each method): the string then counts as unmeasured.
---------------------------------------------------------------------------
-- a small hash of a list of words (Lua 5.1: no bit operators): the same text in the game's probe and here
function L.hash(words)
	local list = {}
	for i, w in ipairs(words) do list[i] = tostring(w) end
	table.sort(list)
	local h = 5381
	for _, w in ipairs(list) do
		for i = 1, #w do h = (h * 33 + w:byte(i)) % 4294967291 end
		h = (h * 33 + 10) % 4294967291
	end
	return ("%08x"):format(h)
end

local function plainText(text) return (tostring(text or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("||", "|")) end
function L.labelKey(font, size, text, box, maxLines, wrap)
	return table.concat({ baseName(font), tostring(tonumber(size) or 12), ("%.1f"):format(tonumber(box) or 0), tostring(tonumber(maxLines) or 0), wrap == false and "n" or "y", plainText(text) }, "\1")
end

local indexOf = setmetatable({}, { __mode = "k" })
function L.labelIndex(fx)
	local lab = fx and fx.labels
	if type(lab) ~= "table" or type(lab.rows) ~= "table" then return nil end
	if indexOf[lab] then return indexOf[lab] end
	local idx = {}
	for _, r in ipairs(lab.rows) do idx[L.labelKey(r.font, r.size, r.text, r.box, r.maxLines, r.wrap)] = r end
	indexOf[lab] = idx
	return idx
end

local function nearestScale(scales, eff)
	local best, bd
	for i, s in ipairs(scales or {}) do
		local d = math.abs(math.log((tonumber(eff) or 1) / s))
		if not bd or d < bd then best, bd = i, d end
	end
	return best
end

-- the width ratio (what the game drew over the font's raw advances) the probe saw for strings of this font and size: min, max, count.
-- The error band of a string nobody measured: its raw width times min .. max. nil when the probe saw no string of that font and size.
function L.band(fx, font, size)
	local lab = fx and fx.labels
	if type(lab) ~= "table" then return nil end
	local lo, hi, n = nil, nil, 0
	for _, r in ipairs(lab.rows or {}) do
		if baseName(r.font) == baseName(font) and tonumber(r.size) == tonumber(size) and type(r.raw) == "number" and r.raw > 0 then
			for _, u in pairs(r.uw or {}) do
				if type(u) == "number" then
					local q = u / r.raw
					if not lo or q < lo then lo = q end
					if not hi or q > hi then hi = q end
					n = n + 1
				end
			end
		end
	end
	if n > 0 then return lo, hi, n end
end

-- H.measuredCut for a fixture: true / false for a string the probe measured in this box (at the probed scale nearest the string's own effective
-- scale); nil for every other string, which stays on the metric. `seen` (an optional table) collects { measured, font, size, text } per key.
function L.cutFn(fx, seen)
	local idx = L.labelIndex(fx)
	if not idx then return nil end
	local scales = fx.labels.scales
	return function(path, size, text, box, maxLines, wrap, eff)
		local key = L.labelKey(path, size, text, box, maxLines, wrap)
		local row = idx[key]
		local verdict
		if row and type(row.trunc) == "table" then
			local i = nearestScale(scales, eff)
			if i then verdict = row.trunc[i] end
			if verdict == nil then for j = 1, #scales do if row.trunc[j] ~= nil then verdict = row.trunc[j] break end end end
		end
		if seen then seen[key] = { measured = verdict ~= nil, font = baseName(path), size = size, text = plainText(text) } end
		return verdict
	end
end

-- "N of M current strings unmeasured (words changed since the probe)": the strings a run drew (cutFn's `seen`) that the probe never measured
function L.coverageLine(seen)
	local m, n = 0, 0
	for _, s in pairs(seen or {}) do
		m = m + 1
		if not s.measured then n = n + 1 end
	end
	if m == 0 then return "probe labels: no string drawn in this run" end
	if n == 0 then return ("probe labels: all %d current strings measured"):format(m) end
	return ("probe labels: %d of %d current strings unmeasured (words changed since the probe): the metric answers them, with an error band, never a verdict"):format(n, m)
end

local function nonEmpty(t) return type(t) == "table" and next(t) ~= nil end

-- (job 2893, B4) the probe saves an accessor with its argument: "GetPoint(1)", "IsEventRegistered(PLAYER_LOGIN)". The fake game's classes have only the method
-- name, so a row under the long name was silently never applied and the measured frame answered plainly. Same method, one list.
function L.accessorMap(map)
	local out = {}
	for acc, frames in pairs(map or {}) do
		local name = tostring(acc):gsub("%(.*$", "")
		local list = out[name] or {}
		local seen = {}
		for _, f in ipairs(list) do seen[f] = true end
		for _, f in ipairs(frames) do if not seen[f] then seen[f] = true list[#list + 1] = f end end
		table.sort(list)
		out[name] = list
	end
	return out
end

-- (job 2908) the protection rule a fixture's propagation rows (S secure button, kid parented to S, tied anchored to S, ctl alone, box = parent of S)
-- answer: { child, anchored, parent } = whether a plain frame under / anchored to / holding a secure frame is protected (IsProtected true). nil without rows.
function L.protectRule(fx)
	local r = fx.protect
	if type(r) ~= "table" or type(r.S) ~= "table" or r.S.prot ~= true then return nil end
	local function prot(row) return type(row) == "table" and row.prot == true end
	local out = { child = prot(r.kid), anchored = prot(r.tied), parent = prot(r.box), control = prot(r.ctl) }
	-- CreateFrame under a protected frame in a fight: refused when the dummy step's S:CreateFrame failed (N25-F: under the world map in a fight)
	for _, row in ipairs(type(fx.dummy) == "table" and fx.dummy.fight or {}) do
		if row.op == "S:CreateFrame" and (row.ok == false or row.took == false) then out.createUnder = true end
	end
	return out
end

function L.apply(H, fx)
	local pr = L.protectRule(fx)
	if pr and pr.control == false then H.protectRule = pr end
	if nonEmpty(fx.fileIds) then H.fileIds = fx.fileIds end
	if fx.labels then H.measuredCut = L.cutFn(fx) end
	if nonEmpty(fx.widths) then H.measuredWidths = L.widthFn(fx) end
	local rules = L.keyRules(fx)
	if rules then H.keyRules = rules end
	if nonEmpty(fx.secretAccessors) then H.setSecretAccessors(L.accessorMap(fx.secretAccessors)) end
	if nonEmpty(fx.secretApi) then H.secretApi = fx.secretApi end
end

function L.reset(H)
	H.fileIds, H.fileIdFn, H.measuredWidths = nil, nil, nil
	H.keyRules, H.secretApi, H.protectRule = nil, nil, nil
	H.measuredCut = nil
	H.setSecretAccessors(nil)
end

-- what a run has loaded now (so a test can reset or apply and put it back)
function L.save(H)
	return { fileIds = H.fileIds, fileIdFn = H.fileIdFn, measuredWidths = H.measuredWidths, keyRules = H.keyRules, secretApi = H.secretApi, measuredCut = H.measuredCut,
		secretAccessors = H.secretAccessorsMap, protectRule = H.protectRule }
end

function L.restore(H, saved)
	L.reset(H)
	H.fileIds, H.fileIdFn, H.measuredWidths, H.keyRules, H.secretApi = saved.fileIds, saved.fileIdFn, saved.measuredWidths, saved.keyRules, saved.secretApi
	H.measuredCut = saved.measuredCut
	H.protectRule = saved.protectRule
	if saved.secretAccessors then H.setSecretAccessors(saved.secretAccessors) end
end

function L.hitRules(fx)
	local out = {}
	for id, cells in pairs(fx.hit or {}) do
		for cell, winner in pairs(cells) do out[#out + 1] = { scenario = id, cell = cell, winner = winner } end
	end
	table.sort(out, function(a, b) if a.scenario ~= b.scenario then return a.scenario < b.scenario end return a.cell < b.cell end)
	return out
end

function L.eventFacts(fx)
	local never = {}
	for e, r in pairs(fx.events or {}) do if r.fired == 0 then never[#never + 1] = e end end
	table.sort(never)
	return never
end

function L.envFacts(fx)
	local e = fx.env or {}
	return { realm = e.realm and e.realm.name, project = e.project and e.project.id, build = e.build and e.build[2] }
end

return L
