-- tests/lib/files.lua: where the code of an OLD (Wuber 2.2.1) file lives now.
--
-- The restructure (REFACTOR.md, REFACTOR-MAP.md section 1.1) cuts the 25 old top-level files
-- into modules in folders. Tests that read addon source by file name use this instead of a
-- hard-coded "Net.lua", so they keep testing the same code before, during and after the move:
--   F.sources("Net")  -> { "Net.lua" } today; { "Net/Base.lua", ..., "Net/Provider.lua" } after
--   F.read("Net")     -> the texts of those files, joined with "\n" (nil if none)
--   F.has("Net")      -> the TOC lists that code and every one of its files exists
--   F.expected("UI")  -> the TOC lists at least one file holding that code (present or not)
-- Paths are relative to the Wuber folder, with "/" separators, in TOC order. Only files the
-- TOC lists count: a stray old file left on disk is not "the code".

local F = {}

-- old file (without .lua) -> the module files that hold its code after the move (map 1.1)
F.NEW = {
	Core = { "Core/Base.lua", "Core/Stats.lua", "Core/Runtime.lua" },
	Places = { "Core/Words.lua", "Core/Places.lua", "Core/Flights.lua" },
	Net = { "Net/Base.lua", "Net/Update.lua", "Net/Community.lua", "Net/Transport.lua", "Net/Beacons.lua", "Net/Requests.lua",
		"Net/Rides.lua", "Net/Favourites.lua", "Net/Discovery.lua", "Net/Outreach.lua", "Net/Flights.lua",
		"Net/Inbox.lua", "Net/Provider.lua" },
	Theme = { "Theme/Tokens.lua", "Theme/Anim.lua", "Theme/Widgets.lua", "Theme/Forms.lua" },
	FX = { "FX/Effects.lua", "FX/Moments.lua" },
	UI = { "UI/Kit.lua", "UI/Toasts.lua", "UI/Secure.lua", "UI/Window.lua", "UI/Rider/HomeMap.lua",
		"UI/Rider/Cards.lua", "UI/Rider/Home.lua", "UI/Rider/Confirm.lua", "UI/Rider/Pay.lua", "UI/Rider/Ride.lua",
		"UI/Rider/Done.lua", "UI/Moments.lua", "UI/Coach.lua", "UI/Phone.lua", "UI/Minimap.lua" },
	UI_Trips = { "UI/Rider/Trips.lua" },
	UI_Settings = { "UI/Settings/Rows.lua", "UI/Settings/Find.lua", "UI/Settings/Pages.lua", "UI/Settings/Panel.lua" },
	Map = { "UI/Map/Base.lua", "UI/Map/Pins.lua", "UI/Map/Route.lua", "UI/Map/Map.lua" },
	Drive_Core = { "Drive/Core.lua" },
	Drive_Places = { "Drive/Places.lua" },
	Drive_Team = { "Drive/Team.lua" },
	Drive_Queue = { "Drive/Queue.lua" },
	Drive_Chat = { "Drive/Chat.lua" },
	Drive_Trade = { "Drive/Trade.lua" },
	Drive_Service = { "Drive/Service.lua", "Drive/Ready.lua", "Drive/Raid.lua" },
	Drive_Log = { "Drive/Log.lua" },
	Drive_Button = { "Drive/Cast.lua", "Drive/Plan.lua", "Drive/Button.lua" },
	Drive_Net = { "Drive/Net.lua" },
	Drive_Bell = { "Drive/Bell.lua" },
	Drive_Commands = { "Drive/Commands.lua" },	Driver = { "UI/Driver/State.lua", "UI/Driver/Rows.lua", "UI/Driver/Build.lua", "UI/Driver/Draw.lua",
		"UI/Driver/Raid.lua", "UI/Driver/Console.lua" },
	UI_Drive = { "UI/Driver/Screens.lua", "UI/Driver/Wizard.lua", "UI/Driver/Crew.lua", "UI/Driver/Messages.lua",
		"UI/Driver/Earnings.lua", "UI/Driver/Sheets.lua", "UI/Driver/Mini.lua" },
	Nameplates = { "FX/Nameplates.lua" },
	Commands = { "UI/Commands.lua" },
}

-- files the restructure (and later rounds) add that hold no old file's code
F.ADDED = { "Core/Registry.lua",
	-- round 8 (Wuber 2.3.0, SPEC7 section 1): new modules, no old file's code
	"Core/FlightPaths.lua", "Core/FlightTimes.lua", "Core/Wrapped.lua", "Net/Portal.lua", "Net/Raincheck.lua",
	"Net/Bounty.lua", "Drive/Danger.lua", "Drive/Kitchen.lua", "Drive/Cut.lua", "Drive/Raincheck.lua", "UI/Fold.lua",
	"UI/Share.lua", "UI/Rider/WorldMap.lua", "UI/Rider/Booking.lua", "UI/Rider/Wrapped.lua", "UI/Bird.lua",
	"UI/Driver/Demand.lua",
	-- round 9 (fix round, agent D): the customer book
	"Drive/Book.lua", "UI/Driver/Customers.lua",
	-- 2.3.2 (BRIEF15, agent B): the Pioneers' emblem
	"FX/Emblem.lua",
	-- 2.3.2 (BRIEF19 R3): the bug report
	"UI/Bug.lua",
	-- 2.3.3 (BRIEF25): login tips, the sea route arrow
	"UI/TipTexts.lua", "UI/Rider/SeaRoute.lua", "UI/Tips.lua",
	-- 2.4 (part 4): flight map summon price tags
	"UI/FlightPins.lua",
	-- 2.4 (part 6): mid-flight summon offer
	"UI/InFlight.lua",
	-- 2.4 (FIX3 J): the What's new card
	"UI/WhatsNew.lua",
	-- 2.4 (p2): careful auto-invite gate
	"Drive/Careful.lua",
	-- 2.4 (p7): auto-reply whisper
	"Drive/AutoReply.lua",
	-- 2.4 (decisions round, group Q): payment by mail
	"Drive/Mail.lua",
	-- 2.4 (the decisions round, group R): the greeting and the pay reminder sent by themselves
	"Drive/AutoLines.lua",
	-- 2.4 (p4): driver ranks
	"Drive/Rank.lua",
	-- 2.5: the Group Finder listing (decision draft)
	"Net/GroupFinder.lua" }

local H -- set by F.init (the harness: H.tocFiles, H.ADDONS, H.exists)

function F.init(harness)
	H = harness
	return F
end

local function norm(old) return (tostring(old):gsub("%.lua$", "")) end

function F.dir() return H.ADDONS.Wuber end

-- old -> the TOC files holding its code, in TOC order (relative, "/" paths)
function F.sources(old)
	old = norm(old)
	local want = { [old .. ".lua"] = true }
	for _, p in ipairs(F.NEW[old] or {}) do want[p] = true end
	local out = {}
	for _, file in ipairs(H.tocFiles("Wuber") or {}) do
		if want[file] then out[#out + 1] = file end
	end
	return out
end

-- full paths of F.sources(old)
function F.paths(old)
	local out = {}
	for i, file in ipairs(F.sources(old)) do out[i] = F.dir() .. "/" .. file end
	return out
end

function F.expected(old) return #F.sources(old) > 0 end

function F.has(old)
	local src = F.sources(old)
	if #src == 0 then return false end
	for _, file in ipairs(src) do
		if not H.exists(F.dir() .. "/" .. file) then return false end
	end
	return true
end

function F.read(old)
	local parts = {}
	for _, path in ipairs(F.paths(old)) do
		local f = io.open(path, "rb")
		if not f then return nil end
		parts[#parts + 1] = f:read("*a")
		f:close()
	end
	if #parts == 0 then return nil end
	return table.concat(parts, "\n")
end

return F
