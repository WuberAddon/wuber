-- tests/lib/probe_learn.lua: how the fake game (tests/harness.lua) learns a WuberProbe fixture (tools/rec/probe-import.lua).
--   local L = dofile(T.dir .. "/lib/probe_learn.lua")
--   local fx = L.load("tests/fixtures/probe/<file>.lua")
--   L.apply(H, fx)  -- file ids, text widths, key rules, secrets (and nothing else is touched)
--   L.reset(H)      -- back to the harness's own guesses
--   local saved = L.save(H) ... L.restore(H, saved)  -- a test that resets or applies puts back what the run had (tests/harness.lua loads a
--                      real tests/fixtures/probe/game-*.lua at start; a test must not leave the run without it)
--   L.hitRules(fx)  -- the fixture's hit-order answers as a list { scenario, cell, winner } for a conformance test
-- What each part feeds:
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

local function nonEmpty(t) return type(t) == "table" and next(t) ~= nil end

function L.apply(H, fx)
	if nonEmpty(fx.fileIds) then H.fileIds = fx.fileIds end
	if nonEmpty(fx.widths) then H.measuredWidths = L.widthFn(fx) end
	local rules = L.keyRules(fx)
	if rules then H.keyRules = rules end
	if nonEmpty(fx.secretAccessors) then H.setSecretAccessors(fx.secretAccessors) end
	if nonEmpty(fx.secretApi) then H.secretApi = fx.secretApi end
end

function L.reset(H)
	H.fileIds, H.fileIdFn, H.measuredWidths = nil, nil, nil
	H.keyRules, H.secretApi = nil, nil
	H.setSecretAccessors(nil)
end

-- what a run has loaded now (so a test can reset or apply and put it back)
function L.save(H)
	return { fileIds = H.fileIds, fileIdFn = H.fileIdFn, measuredWidths = H.measuredWidths, keyRules = H.keyRules, secretApi = H.secretApi,
		secretAccessors = H.secretAccessorsMap }
end

function L.restore(H, saved)
	L.reset(H)
	H.fileIds, H.fileIdFn, H.measuredWidths, H.keyRules, H.secretApi = saved.fileIds, saved.fileIdFn, saved.measuredWidths, saved.keyRules, saved.secretApi
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
