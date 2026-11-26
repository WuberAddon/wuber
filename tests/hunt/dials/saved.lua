-- tests/hunt/dials/saved.lua: the saved data Wuber wakes up with (dial "saved", phase 10).
-- Owner: FIXTURES. The fixtures are tests/hunt/fixtures/saved/*.lua, made by tools/hunt/anonymise.lua from the
-- real files of the author's four accounts (other players' names are Tester01.., free text blanked).
-- Each value loads a fresh copy of its fixture into ctx.saved as the harness client option "saved" takes it:
-- { Wuber = <WuberDB> }. The data holds no class, so the value also sets the class the character really is
-- (ctx.clientOpts.class, ctx.name and ctx.facts.savedClass / savedName) and excludes the role values that
-- cannot go with it (the role dial: rider, warlock, friend, crew).
return function(Hunt)
	local here = (debug.getinfo(1, "S").source or ""):gsub("^@", ""):gsub("\\", "/"):match("^(.*)/[^/]*$") or "."
	local DIR = here .. "/../fixtures/saved/"

	local function fixture(file)
		local fn, err = loadfile(DIR .. file .. ".lua")
		if not fn then error("saved fixture " .. file .. ": " .. tostring(err)) end
		return fn() -- a fresh table every call: the addon writes into it
	end

	-- one value for a fixture: the character that logs in, its class, what is special
	local function value(id, file, name, class, about, excludes)
		return {
			id = id, about = about, excludes = excludes,
			pre = function(ctx)
				ctx.saved = ctx.saved or {}
				ctx.saved.Wuber = fixture(file)
				ctx.name = name
				ctx.clientOpts = ctx.clientOpts or {}
				ctx.clientOpts.class = class
				ctx.facts = ctx.facts or {}
				ctx.facts.savedClass, ctx.facts.savedName, ctx.facts.savedFixture = class, name, file
			end,
		}
	end
	local NOT_LOCK = { role = { "warlock" } }        -- a Mage's data: not the Warlock role (a crew member can be any class)
	local LOCK_CREW = { role = { "rider", "friend", "warlock" } } -- acct1/acct2: the saved drive data puts the character in another driver's crew, so role=warlock cannot be built
	local LOCK = { role = { "rider", "friend" } }     -- a Warlock's data: the rider role is another class, the friend runner is by definition not a Warlock

	Hunt.dial{
		name = "saved",
		about = "the saved data Wuber starts with: nothing (a new install) or one of the author's real characters (anonymised)",
		phase = 10,
		default = "fresh",
		values = {
			{ id = "fresh", about = "no saved data: what a new install has",
				pre = function(ctx) ctx.saved = {} end },
			value("acct1_warlock", "acct1", "Farra Way", "WARLOCK",
				"a Warlock alt on a young account: coach on, no tips seen (holdTip set), no trips, a Wuber driver setup with a crew and 4 paid queue rows", LOCK_CREW),
			value("acct2_nocoach", "acct2", "Hayley Cab", "WARLOCK",
				"a Warlock alt with coach = false (the coach marks switched off), no tips seen, no holdTip, a crew and 4 paid queue rows", LOCK_CREW),
			value("acct3_rider", "acct3", "Wuber Rocks", "MAGE",
				"the long-used rider: 20 trips, totals and 7 milestones, a learned map (2 calibrations), World map view, fold pages, 1 tip seen, 2 characters (both not summoners), a blocked build, tipPct 0", NOT_LOCK),
			value("acct4_main", "acct4", "Anita Lift", "WARLOCK",
				"the Warlock main: 10 of 14 tips seen, coach on, ads switched off, holdTip, community and message-seen state, 16 drive log rows and 25 logged asks, 7 flights learned, a crew and a badge", LOCK),
			value("old", "old1", "Wuber Rocks", "MAGE",
				"saved data from an older Wuber (no totals, milestones, tips, fold, learned map or drive log; no progressReady or scaleV): the addon must upgrade it silently", NOT_LOCK),
		},
	}
end
