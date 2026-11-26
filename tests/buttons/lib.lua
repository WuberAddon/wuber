-- tests/buttons/lib.lua: the shared walker of the "every button works" suite (tests/buttons/*_test.lua).
-- Not a test file (no _test suffix): each test file loads it with  local Lib = dofile(T.dir .. "/buttons/lib.lua")(T).
-- It reuses the layout checker's own screens: the Wuber Lab's photo-tour screen list (L.PHOTO_SCREENS, each screen's run(W, view)
-- sets the state up) plus tests/layout/extra_screens.lua, in the layout checker's own game (1920x1080 at scale 1), and its
-- E.tag (which widgets are Wuber's, and where they were made). Nothing of those is copied here.
-- Clicks go the real way: Client:clickOn(region) = the frame on top at the centre (frameAt, ranked as the game ranks it), then
-- OnMouseDown/OnMouseUp/OnClick of whatever is on top.
local T = ...
local H = T.H
local S = H.state
local root = T.dir .. "/.."
local Lib = {}

local CFG = { w = 1920, h = 1080, ui = 1, scale = 1 }
local function norm(s) local r = (tostring(s):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", ""):gsub("^%s+", ""):gsub("%s+$", "")) if #r > 40 then r = "(long text)" end return r end

-- the screens (shots) the tour knows, by id
function Lib.newWorld()
	local E = assert(loadfile(root .. "/tests/layout/engine.lua"))(H)
	H.ADDONS.WuberLab = H.ADDONS.WuberLab or (root .. "/lab/WuberLab")
	if not H._buttonsTagged then
		H._buttonsTagged = true
		E.tag({ Wuber = H.ADDONS.Wuber, WuberLab = H.ADDONS.WuberLab })
	end
	local TL = dofile(root .. "/tools/preview/textlayout.lua")
	local unitH = 768 / CFG.ui
	local unitW = CFG.w / CFG.h * unitH
	H.textMetrics = TL
	TL.PX = CFG.h / unitH
	TL.SNAP, TL.SIZE_SNAP = "round", "round"
	local w = H.NewWorld({})
	w:addClient("Mia Runner", { spot = "Undercity", class = "WARLOCK" })
	local c = w:addClient("Anita Lift", { spot = "Undercity", class = "WARLOCK", money = 100000, addons = { "Wuber", "WuberLab" },
		screenW = unitW, screenH = unitH, physW = CFG.w, physH = CFG.h })
	local chat = c.env.DEFAULT_CHAT_FRAME
	if chat then chat:ClearAllPoints() chat:SetPoint("BOTTOMLEFT", c.env.UIParent, "BOTTOMLEFT", 32, 95) chat:SetSize(430, 120) end
	w:advance(15)
	local W, L = c.W, c.ns.WuberLab
	W.db.rides[#W.db.rides + 1] = { dest = "Ratchet", driver = "Real Driver", price = 5000, at = 1700000000, stars = 4 }
	W.db.favs["real driver"] = true
	W.db.tipPct = 10
	W.db.fx = W.db.fx or "full"
	W.db.scale = CFG.scale
	pcall(W.UI.ApplyScale)
	local X
	local ch = loadfile(root .. "/tests/layout/extra_screens.lua")
	if ch then
		local okx, x = pcall(ch)
		if okx and type(x) == "table" then
			X = x
			if x.stubWorld then pcall(x.stubWorld, c) end
			pcall(x.install, L, W)
		end
	end
	local ctx = { w = w, c = c, W = W, L = L, screenW = unitW, screenH = unitH, clicked = {} }
	ctx.errors0 = #w.errors
	return ctx
end

-- every screen of the tour (not the gated ones that need the game's own windows), in tour order: { id, side, run }
function Lib.screens(ctx)
	local out = {}
	for _, s in ipairs(ctx.L.PHOTO_SCREENS or {}) do if not s.need and s.run then out[#out + 1] = s end end
	return out
end

-- put the screen up the way the tour does; false (and why) when this screen can't be shown here
function Lib.show(ctx, s, view)
	local L, W, w = ctx.L, ctx.W, ctx.w
	if L.PhotoReset then pcall(L.PhotoReset, W) end
	local ok, res = pcall(s.run, W, view or "folded")
	w:advance(1.5)
	if not ok or res ~= true then return false, tostring(res) end
	return true
end

local function chain(f) local out = {} while f do out[#out + 1] = f f = S[f] and S[f].parent end return out end
local function isUnder(f, anc) while f do if f == anc then return true end f = S[f] and S[f].parent end return false end
Lib.isUnder = isUnder

-- the text a control shows (its own, a font string of it or of its children), else its texture's file name
local function labelOf(f, depth)
	depth = depth or 0
	if f.GetText then local ok, t = pcall(f.GetText, f) if ok and type(t) == "string" and norm(t) ~= "" then return norm(t) end end
	local tex
	for _, r in ipairs({ f:GetRegions() }) do
		local ot = r:GetObjectType()
		if ot == "FontString" and r:IsVisible() then
			local t = norm(r:GetText() or "")
			if t ~= "" then return t end
		elseif ot == "Texture" and not tex then
			local ok, p = pcall(r.GetTextureFilePath, r)
			if ok and type(p) == "string" and p ~= "" then tex = p:gsub("\\", "/"):match("([^/]+)$") end
		end
	end
	if depth < 3 then
		for _, ch in ipairs({ f:GetChildren() }) do
			if ch:IsVisible() then local t = labelOf(ch, depth + 1) if t and not t:match("^%[") then return t end end
		end
	end
	return tex and ("[" .. tex .. "]") or nil
end

local function owns(f) local sc = S[f].scripts or {} return sc.OnClick or sc.OnMouseUp or sc.OnMouseDown end

-- the clickable things drawn now: Wuber's Button / CheckButton / EditBox and frames with OnClick / OnMouseUp / OnMouseDown,
-- shown, drawn (alpha), centre on the screen and not cut off by a clipping ancestor. { f, id, cx, cy, src }
function Lib.controls(ctx)
	local c = ctx.c
	local list, seen, perSite = {}, {}, {}
	for i, f in ipairs(c.frames) do
		local s = S[f]
		if s.kind == "frame" and s.lcTag == "Wuber" and s.mouse and f:IsVisible() then
			local ot = s.otype
			if ot == "Button" or ot == "CheckButton" or ot == "EditBox" or owns(f) then
				local r = H.rect(f)
				if r and r.w > 0 and r.h > 0 and (f:GetEffectiveAlpha() or 0) > 0.01 then
					local cx, cy = r.l + r.w / 2, r.b + r.h / 2
					local clipped = false
					for _, p in ipairs(chain(S[f].parent)) do
						if S[p].clips then
							local pr = H.rect(p)
							if not pr or cx < pr.l or cx > pr.l + pr.w or cy < pr.b or cy > pr.b + pr.h then clipped = true break end
						end
					end
					if not clipped and cx >= 0 and cx <= ctx.screenW and cy >= 0 and cy <= ctx.screenH then
						local label = labelOf(f)
						local file = tostring(s.lcSrc or "?"):match("^([^:(]+)") or "?"
						local id = label or ("(no label) " .. file)
						id = id .. " <" .. ot .. "> @" .. file
						perSite[id .. tostring(s.lcSrc)] = (perSite[id .. tostring(s.lcSrc)] or 0) + 1
						if perSite[id .. tostring(s.lcSrc)] <= 4 then -- (speed) a heatmap's 180 cells: the first four of one id and place stand for all
						list[#list + 1] = { f = f, protected = s.secure == true, id = id, cx = cx, cy = cy, src = tostring(s.lcSrc), otype = ot, order = i }
						end
					end
				end
			end
		end
	end
	return list
end

-- who took the click at the control's centre: ok only when it is the control or something inside it. Every control here takes the
-- mouse itself, so an ANCESTOR taking the click (even one with a click handler of its own) is a lost click.
function Lib.judgeTaker(ctx, ctl)
	local t = ctx.c:frameAt(ctl.cx, ctl.cy)
	if t == ctl.f or (t and isUnder(t, ctl.f)) then return true, t end
	return false, t
end

function Lib.describe(f)
	if not f then return "nothing" end
	local s = S[f]
	local lab = labelOf(f) or "?"
	return ("%s %q (%s level %s, made at %s)"):format(s.otype or "?", lab, f:GetFrameStrata(), tostring(f:GetFrameLevel()), tostring(s.lcSrc or "?"))
end

-- what is visible now: the screen's texts, which frames are shown, check states, edit texts; for "did something change"
function Lib.signature(ctx)
	local c = ctx.c
	local parts, shown = {}, 0
	for _, t in ipairs(c:visibleTexts()) do parts[#parts + 1] = t end
	local ids = {}
	for i, f in ipairs(c.frames) do
		local s = S[f]
		if s.kind == "frame" and f:IsVisible() then
			shown = shown + 1
			ids[#ids + 1] = i
			if s.otype == "CheckButton" and f.GetChecked then parts[#parts + 1] = "chk" .. i .. tostring(f:GetChecked()) end
			if s.otype == "EditBox" and f.GetText then parts[#parts + 1] = "edit" .. i .. tostring(f:GetText()) end
		end
	end
	return table.concat(parts, "\1") .. "\2" .. table.concat(ids, ",")
end

-- what the fake game has recorded as sent so far, one counter per channel the harness keeps: addon messages, whispers, public chat,
-- invites, macros run, chat lines the game blocked, chat lines typed, open trades. A click's "sends" is what grew.
local function sentCounts(w)
	local n = function(t) return type(t) == "table" and #t or 0 end
	local trades = 0
	for _, p in pairs(w.players or {}) do if type(p) == "table" and p.trade then trades = trades + 1 end end
	return { ["addon message"] = n(w.addonLog), whisper = n(w.whispers), ["chat post"] = n(w.chatPosts), invite = n(w.invites), macro = n(w.macros),
		["blocked chat line"] = n(w.blocked), ["failed whisper"] = w.failedWhispers or 0, ["typed chat line"] = n(w.typedLines), ["open trade"] = trades }
end

-- one real click on the control (never a protected one: the walk skips those). Records what the fake saw sent.
function Lib.click(ctx, ctl)
	local w, c = ctx.w, ctx.c
	local before = { sig = Lib.signature(ctx), viol = #w.errors + #(w.violations or {}), sent = sentCounts(w) }
	local t = c:clickOn(ctl.f)
	ctx.clicked[#ctx.clicked + 1] = ctl.id
	-- what the click itself sent, read before time passes: the world's own timers (heartbeats, toasts) send things too
	local sends = {}
	for k, v in pairs(sentCounts(w)) do if v > before.sent[k] then sends[#sends + 1] = k end end
	w:advance(1)
	table.sort(sends)
	return { taker = t, changed = Lib.signature(ctx) ~= before.sig, errors = #w.errors + #(w.violations or {}) - before.viol, sends = sends,
		text = table.concat(c:visibleTexts(), " | ") }
end

-- which group (page set) a screen belongs to; one test file per group so the shards spread the work
local GROUPS = {
	rider1 = { "home", "chat_home", "worldmap" }, rider2 = { "confirm", "portal", "tracker", "pass_rider", "pay", "stranger", "done_", "raincheck", "d4c_" },
	driver1 = { "console", "button_", "menu_chat", "note", "row_marks", "pass_driver", "wizard" },
	driver2 = { "customers", "crew" }, driver3 = { "demand", "pvp", "raid", "shift", "messages" },
	earnings = { "earnings" }, earnings2 = { "earnings_tips" }, earnings3 = { "earnings_heatmap" }, earnings4 = { "earnings_empty" },
	rider4 = { "rank_row", "rank_card", "rank_own", "tip_edge", "tip_long", "tip_whole", "tip_chip" },
	rider5 = { "sheet_places", "sheet_fm_unknown", "sheet_done", "sheet_home_online" },
	rider6 = { "inflight", "pay_part", "finding_grouped", "blocked_off", "blocked_full", "crew_noanswer_long" },
	settings1 = { "settings", "settings_driving", "settings_search", "settings_nomatch" },
	simple = { "simple_" }, settings3 = { "settings_" }, settings2 = { "settings_opened", "settings_invite", "help", "wuber_test", "bug_window" }, floats = { "float_", "chat_float" },
}
Lib.GROUP_NAMES = { "rider1", "rider2", "rider3", "rider4", "driver1", "driver2", "driver3", "earnings", "earnings2", "earnings3", "earnings4", "rider5", "rider6", "settings1", "settings2", "settings3", "simple", "floats" }
function Lib.groupOf(id)
	local best, bl = "rider3", 0
	for g, list in pairs(GROUPS) do
		for _, p in ipairs(list) do
			local exact = (p == id)
			local pre = (p:sub(-1) == "_" or p == "home" or p == "console" or p == "wizard" or p == "customers" or p == "messages" or p == "help" or p == "confirm" or p == "portal" or p == "button_" or p == "float_")
			if (exact or (pre and id:sub(1, #p) == p)) and #p > bl then best, bl = g, #p end
		end
	end
	return best
end

-- the plain hit rank of a frame (strata, level): what the game would use WITHOUT the clipping rule
local function plainKey(f) return (H.STRATA_RANK(f:GetFrameStrata()) or 3) * 1e5 + f:GetFrameLevel() end
Lib.plainKey = plainKey

-- the whole walk of one group: every screen of the group shown, every control hit-tested at its centre, and every control
-- (once per id, in the first screen it shows) clicked the real way. mode "record" returns what a click did, for writing the table.
-- Returns { seen = { [id] = { screen, order } }, misses = {...}, clicks = { [id] = result }, errors = {...}, screens = n }
-- the header, tab bar and minimap controls are the same on every screen: they are clicked on rider1's home only (the other groups'
-- rows say elsewhere = "rider1"), which keeps each group's walk short
local function isChrome(id) local f = id:match("@(%a+)%.lua$") return f == "Phone" or f == "Window" or f == "Minimap" end
Lib.isChrome = isChrome
function Lib.pass(group, skipIds)
	local ctx = Lib.newWorld()
	local R = { seen = {}, order = {}, misses = {}, covered = {}, protected = {}, clicks = {}, errors = {}, screens = 0, skippedScreens = {}, clicked = ctx.clicked }
	local Eff = dofile(T.dir .. "/buttons/effects.lua")
	local rows = Eff.rowsFor(group)
	for _, s in ipairs(Lib.screens(ctx)) do
		if Lib.groupOf(s.id) == group then
			local ok, why = Lib.show(ctx, s)
			if not ok then R.skippedScreens[s.id] = why else
				R.screens = R.screens + 1
				local todo = {}
				for _, ctl in ipairs(Lib.controls(ctx)) do
					local good, taker = Lib.judgeTaker(ctx, ctl)
					if not R.seen[ctl.id] then R.seen[ctl.id] = s.id R.order[#R.order + 1] = ctl.id end
					if ctl.protected then R.protected[ctl.id] = true end
					if not good then
						-- lost to another frame: the game's clip rule (a frame that is plainly below the control wins) is the #36 pattern;
						-- a frame plainly above it is a sheet or dialog drawn over it (the layout checker's covered kind owns those)
						local cls = (taker and (plainKey(taker) <= plainKey(ctl.f) or isUnder(ctl.f, taker))) and "lost" or "covered"
						local line = ("%s: %s: %s took the click: %s"):format(s.id, ctl.id, cls == "lost" and "a frame BELOW it" or "a frame above it", Lib.describe(taker))
						if cls == "lost" then R.misses[#R.misses + 1] = line else R.covered[#R.covered + 1] = line end
					elseif not R.clicks[ctl.id] then
						local row = rows[ctl.id]
						if not ctl.protected and (group == "rider1" or not isChrome(ctl.id)) and not (row and row.skip) and not (skipIds and skipIds[ctl.id]) then -- (a protected button is never clicked: what it IS decides, not its label)
							todo[#todo + 1] = ctl.id
						end
					end
				end
				local dirty = false
				for _, id in ipairs(todo) do
					if dirty then Lib.show(ctx, s) dirty = false end -- (speed) put the screen back only after a click that changed it
					local fresh
					for _, ctl in ipairs(Lib.controls(ctx)) do if ctl.id == id then fresh = ctl break end end
					if fresh and not fresh.protected and (Lib.judgeTaker(ctx, fresh)) then
						local okc, res = pcall(Lib.click, ctx, fresh)
						if okc then res.screen = s.id R.clicks[id] = res dirty = res.changed else dirty = true R.errors[#R.errors + 1] = s.id .. ": " .. id .. ": " .. tostring(res) R.clicks[id] = { screen = s.id, error = true } end
					end
				end
			end
		end
	end
	return R
end

-- the four tests of one page group; the walk runs once per process and the tests read its result
function Lib.groupTests(T, group)
	local R
	local function walk() R = R or Lib.pass(group) return R end
	local Eff = dofile(T.dir .. "/buttons/effects.lua")
	local rows = Eff.rowsFor(group)
	local function join(t) return table.concat(t, "\n  ") end
	T.test("buttons " .. group .. ": a click on a control lands on that control, never on another frame (#36)", function()
		local r = walk()
		T.ok(r.screens > 0, "no screen of group " .. group .. " could be shown")
		T.ok(#r.misses == 0, #r.misses .. " control(s) lost the click to a frame below them:\n  " .. join(r.misses))
	end)
	T.test("buttons " .. group .. ": every control does what its row in the effects table says", function()
		local r = walk()
		local bad = {}
		for id, row in pairs(rows) do
			local c = r.clicks[id]
			if row.skip then
				if c then bad[#bad + 1] = id .. ": a skip row was clicked" end
			elseif row.elsewhere then
				T.ok(Lib.isChrome(id), id .. ": only header, tab bar and minimap controls may say elsewhere")
			elseif r.seen[id] then
				if not c then bad[#bad + 1] = id .. ": never clicked (the click did not reach it, see the first test) on " .. r.seen[id]
				elseif c.error or c.errors > 0 then bad[#bad + 1] = id .. ": the click raised a Lua error or the game flagged it (a violation)"
				elseif row.expect == "changed" and not c.changed then bad[#bad + 1] = id .. ": nothing visible changed on " .. c.screen
				elseif row.expect == "same" and c.changed then bad[#bad + 1] = id .. ": the row says nothing visible changes, but something did on " .. c.screen end
			end
		end
		for _, e in ipairs(r.errors) do bad[#bad + 1] = e end
		table.sort(bad)
		T.ok(#bad == 0, #bad .. " problem(s):\n  " .. join(bad))
	end)
	T.test("buttons " .. group .. ": every visible control has a row in the effects table and every row has its control", function()
		local r = walk()
		local missing, stale = {}, {}
		for _, id in ipairs(r.order) do if not rows[id] then missing[#missing + 1] = id .. " (on " .. r.seen[id] .. ")" end end
		for id in pairs(rows) do if not r.seen[id] then stale[#stale + 1] = id end end
		table.sort(stale)
		T.ok(#missing == 0, #missing .. " visible control(s) with no row in tests/buttons/effects.lua (" .. group .. "):\n  " .. join(missing))
		local badTodo = {}
		local allowed = Eff.ALLOWED_TODO or {}
		for id, row in pairs(rows) do
			if row.todo and not allowed[id] then badTodo[#badTodo + 1] = id end
		end
		table.sort(badTodo)
		T.ok(#badTodo == 0, #badTodo .. " row(s) with an unallowed todo in tests/buttons/effects.lua (" .. group .. "):\n  " .. join(badTodo))
		T.ok(#stale == 0, #stale .. " row(s) whose control is not on any screen of " .. group .. " any more:\n  " .. join(stale))
	end)
	T.test("buttons " .. group .. ": protected buttons and skip rows are never clicked, and a click that sends something says so in its row", function()
		local r = walk()
		local clicked, bad = {}, {}
		for _, id in ipairs(r.clicked) do clicked[id] = true end
		for id in pairs(r.protected) do
			if not (rows[id] and rows[id].skip) then bad[#bad + 1] = id .. ": a protected (secure) button needs a skip row" end
			if clicked[id] then bad[#bad + 1] = id .. ": a protected button was clicked" end
		end
		for id, row in pairs(rows) do
			if row.skip and clicked[id] then bad[#bad + 1] = id .. ": skip row clicked (" .. row.skip .. ")" end
			if row.skip == "" then bad[#bad + 1] = id .. ": a skip row needs its reason" end
			local c = r.clicks[id]
			if c and #c.sends > 0 and not row.sends then bad[#bad + 1] = id .. ": the click sent [" .. table.concat(c.sends, ", ") .. "] and the row has no sends = \"<what, why fine offline>\"" end
			if c and #c.sends == 0 and row.sends then bad[#bad + 1] = id .. ": the row says it sends, but nothing was seen sent" end
		end
		table.sort(bad)
		T.ok(#bad == 0, #bad .. " problem(s):\n  " .. join(bad))
	end)
end

return Lib
