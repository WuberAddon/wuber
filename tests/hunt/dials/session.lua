-- Dial "session" (owner CORE, tests/hunt/README.md): how this session of the game began.
--   first   the first run ever: no saved data at all, whatever the saved dial says (ctx.facts.firstRun)
--   login   a real login (PLAYER_ENTERING_WORLD(true, false)), 2 s ago (the default)
--   reload  a real login, about 60 s pass, then a /reload BEFORE anything else happens (PLAYER_LOGOUT, the saved
--           data kept as on disk, a new window with PLAYER_ENTERING_WORLD(false, true)); ctx.facts.reloaded
-- ctx:reload() and ctx:relog() (tests/hunt/lib.lua) are the same machinery, for promises and actions later.
return function(Hunt)
	Hunt.dial{
		name = "session",
		about = "how the session began: first run ever, a login, a /reload after a login",
		phase = 40,
		default = "login",
		values = {
			{ id = "first", about = "the first run ever: no saved data at all (whatever the saved dial says)",
				pre = function(ctx)
					ctx.saved = {}
					ctx.facts.firstRun = true
					ctx.facts.session = "first"
				end,
				login = function(ctx)
					ctx:login()
					ctx:advance(2)
				end },
			{ id = "login", about = "a real login, 2 s ago",
				pre = function(ctx) ctx.facts.session = "login" end,
				login = function(ctx)
					ctx:login()
					ctx:advance(2)
				end },
			{ id = "reload", about = "a real login, about 60 s, then a /reload before anything else happens",
				pre = function(ctx) ctx.facts.session = "reload" end,
				login = function(ctx)
					ctx:login()
					ctx:advance(60)
					ctx:reload()
					ctx.facts.reloaded = true
					ctx:advance(2)
				end },
		},
	}
end
