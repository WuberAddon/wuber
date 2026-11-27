-- Helper for tests/r54/u100_universal_checks_test.lua (#100); not a test itself (its name does not end in _test.lua).
-- Runs one case of the bug hunt in this process and prints one line: "<status>|<what the promise said>".
--   lua5.1 tests/r54/u100_probe.lua <case>
-- The cases named "dead_..." and "changed_..." break the game on purpose (a button that does nothing, a text that changes in a
-- /reload, a send with no click at all) to show that the checks still catch the real fault they are there for.
local here = ((arg and arg[0]) or ""):gsub("\\", "/"):match("^(.*)/[^/]*$") or "."
local Hunt = dofile(here .. "/../hunt/lib.lua")
Hunt.init({})
local S = Hunt.H.state
local which = arg[1]

local function run(promise, sit, seed)
	local res = Hunt.runPromise(promise, sit, seed, { always = false })
	print((res.status or "?") .. "|" .. tostring(res.seen or res.detail))
end

-- every world the hunt builds from now on gets this change once it is built
local function afterBuild(fn)
	local build = Hunt.build
	Hunt.build = function(...)
		local ctx = build(...)
		if ctx and ctx.me and ctx.W then fn(ctx) end
		return ctx
	end
end

if which == "close_window" then
	run("universal.button_does_something", { phone = "trips", sound = "off" }, 733197548)
elseif which == "dead_close_window" then
	-- the window's buttons do nothing at all: Close Wuber (UI.Toggle) is dead
	afterBuild(function(ctx) ctx.W.UI.Toggle = function() end end)
	run("universal.button_does_something", { phone = "trips", sound = "off" }, 733197548)
elseif which == "reload_in_combat" then
	run("universal.reload_same", { combat = "before", group = "raid", phone = "home", role = "warlock" }, 523840075)
elseif which == "reload_news_card" then
	run("universal.reload_same", { phone = "trips", ride = "ended" }, 809515039)
elseif which == "changed_reload" then
	-- after the /reload one of the texts on the window reads differently: out of combat that must still be found
	afterBuild(function(ctx)
		local reloaded = false
		-- (the What's new card has nothing to do with this case: it is already seen)
		pcall(function() ctx.W.db.newsSeen = ctx.W.UI.WhatsNew.Version() end)
		local reload, advance = ctx.reload, ctx.advance
		ctx.reload = function(self, ...) reloaded = true return reload(self, ...) end
		ctx.advance = function(self, ...)
			local r = advance(self, ...)
			if reloaded then
				for _, rr in ipairs(ctx.me.widgets) do
					local s = S[rr]
					if s.otype == "FontString" and Hunt.H.visible(rr) and type(s.text) == "string" and s.text == "Where to?" then
						pcall(function() rr:SetText("Changed after the reload by the probe") end)
						break
					end
				end
			end
			return r
		end
	end)
	run("universal.reload_same", { phone = "home" }, 11)
elseif which == "changed_reload_combat" then
	-- in combat: a text away from the big button (the "Where to?" heading) is gone after the /reload: still reported
	afterBuild(function(ctx)
		local reloaded = false
		pcall(function() ctx.W.db.newsSeen = ctx.W.UI.WhatsNew.Version() end)
		local reload, advance = ctx.reload, ctx.advance
		ctx.reload = function(self, ...) reloaded = true return reload(self, ...) end
		ctx.advance = function(self, ...)
			local r = advance(self, ...)
			if reloaded then
				for _, rr in ipairs(ctx.me.widgets) do
					local s = S[rr]
					if s.otype == "FontString" and Hunt.H.visible(rr) and s.text == "Where to?" then
						pcall(function() rr:SetText("Changed after the reload by the probe") end)
						break
					end
				end
			end
			return r
		end
	end)
	run("universal.reload_same", { combat = "before", phone = "home" }, 11)
elseif which == "boss_fight_send" then
	local res = Hunt.runCase({ promise = "universal.no_unclicked_send", after = "chatv.boss_fight_never_lost", sit = Hunt.full({}), seed = 454999349 })
	print((res.status or "?") .. "|" .. tostring(res.seen or res.detail))
elseif which == "dead_boss_fight_send" then
	-- the click is never counted (no hardware mark): the queued message leaving after the fight is a send with no click at all
	Hunt.promise({ id = "probe.boss_fight_no_click", kind = "scenario", text = "probe",
		check = function(ctx)
			local wu = ctx.w.huntU
			wu.lastHW = setmetatable({}, { __newindex = function() end })
			local q = Hunt.promises["chatv.boss_fight_never_lost"]
			q.check(ctx)
			Hunt.promises["universal.no_unclicked_send"].check(ctx)
		end })
	local res = Hunt.runCase({ promise = "probe.boss_fight_no_click", sit = Hunt.full({}), seed = 454999349 })
	print((res.status or "?") .. "|" .. tostring(res.seen or res.detail))
else
	print("broken|no such case " .. tostring(which))
end
