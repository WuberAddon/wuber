-- Hunt dial file (tests/hunt/README.md): the switches a player can flip. Owner: WORLD.
-- One dial per saved key that Settings (Wuber/UI/Settings/Panel.lua, Rows.lua) or a slash command changes. Values are
-- "default" (nothing saved: the addon's own default), "on" and "off" (what the game would have saved at the last
-- logout), written into ctx.saved in "pre" so they are there at login. The value says what is SAVED: "on" is the
-- literal true, so for minimapHidden "on" means the minimap button is hidden.
-- Names: the saved key (WuberDB.<key>); the driver's options (WuberDB.drive.opts.<key>) are "opt_<key>", the big
-- button's (WuberDB.drive.button.<key>) "button_<key>", this character's (WuberDB.chars[me].<key>) "char_<key>".
-- (WuberDB.autoAccept is the rider's switch, opt_autoAccept the driver's.)
-- Not here: the window size and place (phone.lua: size, pos), wide pages (phone.lua: fold), time (time.lua).
-- A first run ever (dial session = first) has no saved data, so every saved value is excluded from it; coach "done" too
-- (a first run has coach = false: its situation is coach = not_done).
-- Hunt.settingPairs at the end lists the pairs the briefs and reports name together.
return function(Hunt)
	-- WuberDB inside ctx.saved (the harness's form is { Wuber = WuberDB }; a bare WuberDB is taken too)
	local function wdb(ctx)
		local s = ctx.saved
		if type(s) ~= "table" then s = {} ctx.saved = s end
		if type(s.Wuber) == "table" then return s.Wuber end
		if s.chars ~= nil or s.rides ~= nil or s.fx ~= nil then return s end
		s.Wuber = {}
		return s.Wuber
	end
	local function sub(t, k)
		if type(t[k]) ~= "table" then t[k] = {} end
		return t[k]
	end
	local function myKey(ctx)
		local n = ctx.name or (ctx.clientOpts and ctx.clientOpts.name) or "Anita Lift"
		return (tostring(n):lower():gsub("[%s%-]+", " "))
	end
	-- where each kind of key lives in the saved data
	local PLACE = {
		db = function(ctx) return wdb(ctx) end,
		opt = function(ctx) return sub(sub(wdb(ctx), "drive"), "opts") end,
		button = function(ctx) return sub(sub(wdb(ctx), "drive"), "button") end,
		char = function(ctx) return sub(sub(wdb(ctx), "chars"), myKey(ctx)) end,
	}
	local PREFIX = { db = "", opt = "opt_", button = "button_", char = "char_" }

	-- one dial: kind, saved key, [id] = saved value (default = nothing saved), about, optional extra(ctx, id)
	local function dial(kind, key, about, values, extra)
		local list = { { id = "default", about = "nothing saved: the addon's own default" } }
		for _, v in ipairs(values) do
			local id, val = v[1], v[2]
			-- a first run ever has no saved data (session = first wipes it): a saved switch cannot exist there
			list[#list + 1] = { id = id, about = key .. " saved as " .. tostring(val), excludes = { session = { "first" } },
				pre = function(ctx)
					PLACE[kind](ctx)[key] = val
					if extra then extra(ctx, id) end
				end }
		end
		Hunt.dial{ name = PREFIX[kind] .. key, about = about, phase = 20, default = "default", values = list }
	end
	local ONOFF = { { "on", true }, { "off", false } }
	-- "Invite public chat buyers" turned on only through the warning: 2.3.2 clears a saved true unless the
	-- player chose it (db.drive.publicChosen); publicV marks the migration done
	local function public(ctx, id)
		local d = sub(wdb(ctx), "drive")
		d.publicV = 1
		d.publicChosen = (id == "on") or nil
	end

	-- Riding (db)
	dial("db", "autoAccept", "Auto-accept my driver's invite (Settings > Riding)", ONOFF)
	dial("db", "autoLeave", "Leave the group after the ride (Settings > Riding)", ONOFF)
	dial("db", "tipsOn", "Login tips (Settings > Riding; /wuber tips on|off)", ONOFF)
	dial("db", "birdTip", "Flight master tip (Settings > Riding; the card's Don't show again)", ONOFF)
	dial("db", "timeValue", "My time is worth (copper an hour; slider 1g to 100g)",
		{ { "low", 10000 }, { "high", 1000000 } })
	-- Map and heads
	dial("db", "mapPins", "Drivers on the world map (Settings > Map; /wuber map)", ONOFF)
	dial("db", "plates", "Crowns and badges over heads (Settings > Map)", ONOFF)
	dial("db", "emblems", "Pioneer emblems over heads (Settings > Map, only when a Pioneer list names someone)", ONOFF)
	dial("db", "myEmblem", "Show my Pioneer emblem (Settings > Map, only for a Pioneer)", ONOFF)
	dial("db", "minimapHidden", "Minimap button: on = hidden (Settings > Map; /wuber minimap)", ONOFF)
	-- Sound and effects
	dial("db", "sound", "Sounds (Settings > Sound)", ONOFF)
	dial("db", "fx", "Effects level (Settings > Sound and effects)", { { "full", "full" }, { "light", "light" }, { "off", "off" } })
	-- This window
	dial("db", "updateNotes", "Tell me about updates (Settings > This window)", ONOFF)
	dial("db", "advertOnline", "Post an advert when I go online (Settings > Driving)", ONOFF)

	-- Driving options (WuberDB.drive.opts)
	dial("opt", "autoInvite", "Invite riders who whisper me", ONOFF)
	dial("opt", "autoPublic", "Invite public chat buyers (off unless chosen through the warning)", ONOFF, public)
	dial("opt", "watchPublic", "Watch public chat for buyers", ONOFF)
	dial("opt", "oneAtATime", "One rider at a time", ONOFF)
	dial("opt", "autoAccept", "the driver's auto-accept option (Drive/Core.lua opts.autoAccept)", ONOFF)
	dial("opt", "autoTrade", "Open the trade when they land", ONOFF)
	dial("opt", "acceptUnder", "Count a smaller payment as paid", ONOFF)
	dial("opt", "remindPay", "Remind riders who haven't paid", ONOFF)
	dial("opt", "kickAfter", "Remove riders after the thanks", ONOFF)
	dial("opt", "autoBlock", "Block riders who leave without paying", ONOFF)
	dial("opt", "tellBlocked", "Tell blocked players why", ONOFF)
	dial("opt", "awayGuard", "Pause me if I'm away", ONOFF)
	dial("opt", "needShards", "Only cast with a Soul Shard", ONOFF)
	dial("opt", "watchBounty", "Show what riders want (bounties)", ONOFF)
	dial("opt", "showPass", "Show ride passphrase", ONOFF)
	dial("opt", "shareNotes", "Share notes with my own accounts", ONOFF)
	dial("opt", "raidsum", "Raid summons: whisper the raider", ONOFF)
	dial("opt", "raidclick", "Raid summons: the raid line 'click the portal'", ONOFF)
	dial("opt", "whisperMode", "How whispers are sent (Button, Chat box, Off)",
		{ { "box", "box" }, { "off", "off" }, { "auto", "auto" } })
	dial("opt", "cutRule", "How the shift's gold is split", { { "equal", "equal" }, { "clicks", "clicks" } })
	dial("opt", "adEvery", "Advert reminder in minutes (0 = never)", { { "never", 0 }, { "fifteen", 15 } })
	dial("opt", "adChannels", "Advert channels (Used in turn)",
		{ { "services_only", "services" }, { "services_trade", "services, trade" } })
	dial("opt", "lowShards", "Warn me at this many shards (0 = never)", { { "never", 0 }, { "ten", 10 } })
	-- the big button (WuberDB.drive.button) and this character
	dial("button", "locked", "Lock the big button", ONOFF)
	dial("button", "shown", "Show the big button", ONOFF)
	dial("button", "keepClosed", "Keep the big button on screen when closed", ONOFF)
	dial("char", "starter", "List me in Wuber's starter list (this character)", ONOFF)

	-- the first-open coach marks (W.db.coach: true once they were seen or skipped; a fresh player has false)
	Hunt.dial{
		name = "coach",
		about = "the first-open coach marks: finished (saved coach = true) or never finished (a fresh player)",
		phase = 20,
		default = "done",
		values = {
			{ id = "done", about = "saved coach = true (not on a first run ever: session = first)", excludes = { session = { "first" } },
				pre = function(ctx) wdb(ctx).coach = true end },
			{ id = "not_done", about = "saved coach = false: the coach marks run on the first open, tips wait for them",
				pre = function(ctx) wdb(ctx).coach = false end },
		},
	}

	-- pairs the briefs and reports name together:
	-- the core's pairwise set covers every pair already; this list is for the report and for extra weight
	Hunt.settingPairs = {
		{ "tipsOn", "coach" },              -- tips wait for the coach marks
		{ "tipsOn", "birdTip" },            -- both are tips, in Settings > Riding (REPORT26: re-arming)
		{ "birdTip", "coach" },
		{ "autoAccept", "autoLeave" },      -- the rider's two group switches (Settings > Riding)
		{ "advertOnline", "opt_adChannels" }, -- the advert and where it goes (REPORT26: services only)
		{ "advertOnline", "opt_adEvery" },
		{ "advertOnline", "opt_autoPublic" },
		{ "opt_autoInvite", "opt_autoPublic" }, -- whispers vs public chat
		{ "opt_oneAtATime", "opt_autoInvite" },
		{ "opt_oneAtATime", "opt_autoPublic" },
		{ "opt_oneAtATime", "opt_autoTrade" },
		{ "opt_autoPublic", "opt_watchPublic" },
		{ "opt_autoBlock", "opt_tellBlocked" },
		{ "opt_whisperMode", "opt_autoInvite" },
		{ "opt_whisperMode", "opt_remindPay" },
		{ "opt_showPass", "opt_shareNotes" },
		{ "opt_cutRule", "opt_shareNotes" },
		{ "button_shown", "button_keepClosed" },
		{ "plates", "emblems" },
		{ "plates", "mapPins" },
		{ "emblems", "myEmblem" },
		{ "sound", "fx" },
		{ "timeValue", "birdTip" },         -- the bird card compares what flying saves
		{ "minimapHidden", "coach" },       -- no minimap button: the first open comes by slash only
	}
end
