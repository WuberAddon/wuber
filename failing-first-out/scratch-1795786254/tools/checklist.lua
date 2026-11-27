-- tools/checklist.lua: the short real-game release checklist (PLAN-2.3.2 item 7), made from what changed.
-- Only what the fake game (tests/harness.lua) cannot prove: a real trade, a real portal click, a
-- session with no "blocked" popup (taint.log on), the photo tour, the passive lab, plus a few
-- quick looks picked from the modules that changed. About 10 minutes; at most 12 items.
--
--   lua5.1 tools/checklist.lua <from-commit> [to-commit, default HEAD] [--out FILE] [--max N]
--   (--max N: at most N items, 8 or fewer reads "about 5 minutes"; default C.MAX)
--   e.g. lua5.1 tools/checklist.lua 1c0fa02 HEAD --out RELEASE-CHECKLIST-2.3.2.md
--
-- Run it from the repo root (it runs git diff --name-status there). Without --out it prints the
-- markdown. A module is its file path with dots (Wuber/UI/Rider/Confirm.lua = UI.Rider.Confirm, as in
-- ARCHITECTURE.md); RULES below maps modules to the quick looks: add a rule when a new screen needs one.
-- Tests: tests/tools/checklist_test.lua (loadfile(...)("--lib") gives the API). Read-only apart from --out.

local C = {}
C.MAX = 12 -- items in all

-- what every release checks in game (the suite cannot)
C.ALWAYS = {
	"Before you play: type `/console taintLog 1`. Play the whole session: no \"blocked\" popup at any time. After it,"
		.. " in the repo run `lua5.1 tools/taint.lua \"C:\\Program Files (x86)\\World of Warcraft\\_forever_\\Logs\\taint.log\"`:"
		.. " it must find no blocked action (the game starts that file again at each start: copy it first).",
	"Passive lab: `/lab passive on` before selling, `/lab passive status` after: no fails.",
	"A real trade: a rider opens the trade and types the gold themselves; Wuber sees the payment and the ride is paid.",
	"A real portal click: summon a rider; they click the portal and arrive; the ride ends as done for both.",
	"Photo tour: lab Tools -> Start photo tour (or `/lab tour`); look through every shot.",
}

-- per change: { modules (Lua patterns on the module name, or on the path for non-Lua files), item }
-- in priority order (when there are too many, the last ones join one "also changed" line)
C.RULES = {
	{ { "^FX%.Nameplates$", "Emblem", "Pioneer" }, "Nameplates on (Ctrl+V): look at a Wuber user's nameplate,"
		.. " and a Pioneer's when the list has names; then in a dungeon: no error, nothing drawn." },
	{ { "^UI%.Rider%.Confirm$" }, "Open Confirm folded and unfolded: the driver card, the map and the verdict all readable." },
	{ { "^UI%.Fold$", "^UI%.Window$" }, "Fold and unfold the window twice: only its width changes (scale stays 1.00)." },
	{ { "^UI%.Secure$", "^Drive%.Button$", "^Drive%.Cast$" }, "Leave combat and click the summon button at once:"
		.. " it works on the first click, nothing blocked." },
	{ { "^Core%.Flights$", "^Core%.FlightTimes$", "^Core%.FlightPaths$", "^Net%.Flights$" },
		"Talk to a flight master: prices learned; Confirm then says \"Fly about ...\"." },
	{ { "^UI%.Map%.", "^UI%.Rider%.WorldMap$", "^UI%.Rider%.HomeMap$" },
		"Open the world map and the Ride map: pins, the route and their tooltips show." },
	{ { "^UI%.Rider%.Home$", "^UI%.Rider%.Cards$", "^UI%.Rider%.Booking$", "^UI%.Rider%.Ride$" },
		"As a rider: Home lists only [Wuber] drivers; book one; the Ride screen follows them." },
	{ { "^UI%.Driver%.", "^Drive%.Core$", "^Drive%.Queue$", "^Drive%.Service$", "^Drive%.Ready$", "^Drive%.Team$" },
		"Driver console: go online, take a rider from the queue, read the row tooltip, go offline." },
	{ { "^Drive%.Chat$", "^Drive%.Places$" }, "A chat buyer: someone whispers \"summon to <place>\": they join the queue." },
	{ { "^Drive%.Raid$" }, "Raid mode: 6 or more in the group, summon one; the raid list shows them." },
	{ { "^Drive%.Danger$" }, "In a contested zone: the PvP warning shows, no \"blocked\" popup." },
	{ { "^UI%.Rider%.Done$", "^UI%.Rider%.Trips$", "^UI%.Rider%.Wrapped$", "^UI%.Moments$", "^FX%.Moments$", "^FX%.Effects$" },
		"Finish a ride: the Done screen, Trips and the celebration show; no text grows or shrinks." },
	{ { "^UI%.Settings%." }, "Settings: search a word, open About, change one setting, /reload: it stays." },
	{ { "^Net%.Community$", "^Net%.Outreach$" }, "Log in: the community is joined, no invite popup." },
	{ { "^Net%.Base$", "^Net%.Transport$", "^Net%.Beacons$", "^Net%.Discovery$", "^Net%.Requests$", "^Net%.Rides$",
		"^Net%.Inbox$", "^Net%.Provider$", "^Net%.Update$", "^Net%.Favourites$" },
		"Two accounts: each sees the other within a minute; a request reaches the driver." },
	{ { "^UI%.Commands$", "^Drive%.Commands$" }, "Type `/wuber help`: the commands answer in chat." },
	{ { "^UI%.Minimap$" }, "Minimap button: drag it, hover it (tooltip), click it (Wuber opens)." },
	{ { "^UI%.Phone$", "^UI%.Toasts$", "^UI%.Coach$", "^UI%.Bird$", "^UI%.Share$" }, "Open the phone and see one toast and one tip." },
	{ { "^Core%.Runtime$", "^Core%.Registry$" }, "Log in, then /reload: no Lua error, nothing new in chat." },
	{ { "^Wuber/Media/" }, "New art: look at the changed images in game (no green squares)." },
}

-- Wuber/UI/Rider/Confirm.lua -> UI.Rider.Confirm (nil for anything that is not a Wuber Lua file)
function C.modOf(path)
	local rel = path:gsub("\\", "/"):match("^Wuber/(.+)%.lua$")
	return rel and (rel:gsub("/", ".")) or nil
end

-- changes: { { status = "A"|"M"|"D", path = "..." }, ... }; opts: version, from, to.
-- Returns the markdown and the list of items.
function C.build(changes, opts)
	opts = opts or {}
	local items, used, restart, names, other = {}, {}, false, {}, {}
	for _, ch in ipairs(changes) do
		local path = ch.path:gsub("\\", "/")
		if path:match("^Wuber/") and (ch.status == "A" or ch.status == "D") then restart = true end
		local m = C.modOf(path)
		if m then names[#names + 1] = m elseif path:match("^Wuber/") then names[#names + 1] = path end
	end
	-- the quick looks, in rule order; a module no rule names is left to the tour and the passive lab
	local looks, matched = {}, {}
	for i, rule in ipairs(C.RULES) do
		for _, n in ipairs(names) do
			for _, pat in ipairs(rule[1]) do
				if n:match(pat) and not (used[i] and used[i].seen[n]) then
					matched[n] = true
					if not used[i] then
						used[i] = { rule = rule, mods = {}, seen = {} }
						looks[#looks + 1] = used[i]
					end
					used[i].seen[n] = true
					used[i].mods[#used[i].mods + 1] = n
				end
			end
		end
	end
	for _, n in ipairs(names) do if not matched[n] and not other[n] then other[n] = true other[#other + 1] = n end end
	if restart then
		items[#items + 1] = "**Quit the game and start it again** (not /reload): this release adds or removes files."
	end
	for _, a in ipairs(C.ALWAYS) do items[#items + 1] = a end
	local room = (opts.max or C.MAX) - #items
	local extra = {}
	for i, look in ipairs(looks) do
		if i < room or (i == room and #looks == room) then
			items[#items + 1] = look.rule[2]
		else
			for _, n in ipairs(look.mods) do extra[#extra + 1] = n end
		end
	end
	if #extra > 0 then
		items[#items + 1] = "Also changed, a quick look if time allows: " .. table.concat(extra, ", ") .. "."
	end
	local out = {}
	out[#out + 1] = ("# Release checklist: Wuber %s (%s..%s)"):format(opts.version or "?", opts.from or "?", opts.to or "HEAD")
	out[#out + 1] = ""
	out[#out + 1] = "In game, about " .. ((opts.max or C.MAX) <= 8 and "5" or "10") .. " minutes: only what the test suite cannot prove. Made by `tools/checklist.lua`"
		.. " from the files that changed; tick each one."
	out[#out + 1] = ""
	for _, it in ipairs(items) do out[#out + 1] = "- [ ] " .. it end
	out[#out + 1] = ""
	table.sort(other)
	out[#out + 1] = ("Changed in Wuber: %d file%s%s."):format(#names, #names == 1 and "" or "s",
		#other > 0 and ("; covered by the tour and the passive lab only: " .. table.concat(other, ", ")) or "")
	return table.concat(out, "\n") .. "\n", items
end

-- git diff --name-status --no-renames from to, as changes
function C.parseStatus(text)
	local out = {}
	for line in (text or ""):gmatch("[^\r\n]+") do
		local st, path = line:match("^(%u)%d*%s+(.+)$")
		if st then out[#out + 1] = { status = st, path = path } end
	end
	return out
end

local function sh(cmd)
	local p = io.popen(cmd)
	if not p then return nil end
	local s = p:read("*a")
	p:close()
	return s
end

if ... == "--lib" then return C end

local from, to, outPath, maxItems
local i = 1
while arg and arg[i] do
	local a = arg[i]
	if a == "--out" then outPath = arg[i + 1] i = i + 1
	elseif a == "--max" then maxItems = tonumber(arg[i + 1]) i = i + 1
	elseif not from then from = a
	elseif not to then to = a end
	i = i + 1
end
if not from or not from:match("^[%w%._/%-^~]+$") or (to and not to:match("^[%w%._/%-^~]+$")) then
	print("usage: lua5.1 tools/checklist.lua <from-commit> [to-commit] [--out FILE] [--max N]  (from the repo root)")
	os.exit(2)
end
to = to or "HEAD"
local status = sh("git diff --name-status --no-renames " .. from .. " " .. to)
if not status then print("tools/checklist.lua: git did not run") os.exit(2) end
local short = (sh("git rev-parse --short " .. to) or to):gsub("%s+", "")
local fromShort = (sh("git rev-parse --short " .. from) or from):gsub("%s+", "")
local toc = sh("git show " .. to .. ":Wuber/Wuber.toc") or ""
local version = toc:match("## Version:%s*([^\r\n]+)")
local text = C.build(C.parseStatus(status), { version = version, from = fromShort, to = short ~= "" and short or to, max = maxItems })
if outPath then
	local f = assert(io.open(outPath, "wb"))
	f:write(text)
	f:close()
	print("tools/checklist.lua: wrote " .. outPath)
else
	io.write(text)
end
os.exit(0)
