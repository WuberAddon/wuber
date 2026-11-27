local T = ...
local test, ok = T.test, T.ok
local root = T.dir .. "/.."
-- 2.4.4 words page, group D: Login tips, Skip the bird off line, auto-reply reasons, Crew is full, "my window".

local function src(p)
	local f = assert(io.open(root .. "/" .. p, "rb"))
	local s = f:read("*a")
	f:close()
	return s
end
local function has(p, s) ok(src(p):find(s, 1, true) ~= nil, p .. " has: " .. s) end
local function hasnt(p, s) ok(src(p):find(s, 1, true) == nil, p .. " still has: " .. s) end

test("words244 d: the Settings row is called Login tips, tooltip unchanged", function()
	has("Wuber/UI/Settings/Rows.lua", '"tips", "Login tips", "A short tip inside Wuber the next time you open it."')
end)

test("words244 d: the tips-off line names Login tips (card and /wuber tips off)", function()
	local new = "Tips are off. Turn Login tips back on in Settings > Riding, or type /wuber tips."
	has("Wuber/UI/Tips.lua", new)
	has("Wuber/UI/Commands.lua", new)
	hasnt("Wuber/UI/Tips.lua", "Riding > Tips, or type")
	hasnt("Wuber/UI/Commands.lua", "Riding > Tips, or type")
end)

test("words244 d: Skip the bird off line", function()
	has("Wuber/UI/Bird.lua", "Skip the bird: off. Turn Flight offers on in Settings, Riding.")
	hasnt("Wuber/UI/Bird.lua", "off in Settings (Riding, Flight offers)")
end)

test("words244 d: auto-reply reasons read as sentences", function()
	local p = "Wuber/Drive/AutoReply.lua"
	has(p, '"Inviting riders who whisper you or ask in the app is off"')
	has(p, '"Listing people who ask for a summon in public chat is off"')
	has(p, '"Whisper back to public requests is off"')
	hasnt(p, '"auto mode is off"')
	hasnt(p, '"public chat is off"')
	hasnt(p, 'return false, "switched off"')
end)

test("words244 d: Crew is full says players, in all three places", function()
	for _, p in ipairs({ "Wuber/UI/Driver/Crew.lua", "Wuber/UI/Driver/Wizard.lua", "Wuber/UI/Driver/Sheets.lua" }) do
		has(p, '" players)", "warn")')
		hasnt(p, '.. ")", "warn")')
	end
end)

test("words244 d: the Crew card says my window", function()
	local p = "Wuber/UI/Driver/Customers.lua"
	has(p, 'T.Tip(r.own, "My own window"')
	has(p, 'SetText("my window")')
	hasnt(p, 'SetText("my account")')
	hasnt(p, 'T.Tip(r.own, "My own account"')
end)
