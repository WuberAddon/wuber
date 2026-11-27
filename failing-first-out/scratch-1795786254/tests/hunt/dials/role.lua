-- The hunt's ROLE dial (owner RIDE): who the player is when the check starts.
--   rider    (default) not a Warlock: books rides, never drives
--   warlock  a Warlock driver, on his own ("Just me" on the welcome), open for business
--   friend   any class that runs the service with a Warlock friend who summons (the wizard's "A Warlock
--            friend", Drive.Core's runner: DR.Role() "driver", DR.IsRunner()); the friend is a second
--            window (ctx.peers.summoner) in my crew and my group, the shop is open
--   crew     a Priest in a Warlock driver's crew (the wizard's "My friends help"; DR.Role() "helper"): the
--            captain is a second window (ctx.peers.captain = ctx.peers.driver), his shop is open, we are grouped.
--            With a Warlock's saved data (the author's alts) I am a Warlock member instead (DR.Role() "driver",
--            captain set), and the captain is the one my saved data names when it names one
--   (a saved crew membership makes "warlock" cannot-build; a Warlock's saved data makes "friend" cannot-build)
-- The crews are made the player's way: the captain's "Add by name" (DR.OfferCrew), the crew card's Yes on the
-- other window, the wizard's summoner order (DR.SetSummoners), then Open (W.Driver.SetOnline).
-- Facts: role, roleShown (DR.Role()), mode (D.Mode()), open, team = { service, caster, inviter, payee, clickers },
-- price (copper, the shop's), driverName (the shop's name), summonerName / captainName.
return function(Hunt)

local SPOT = "Ratchet" -- where drivers stand (a place riders book: never Orgrimmar, where the riders stand)
local RIDER_SPOT = "Orgrimmar"
local NAMES = { "Bea Jones", "Cal Brown", "Eve Stone", "Fay Moss", "Gus Hart", "Hal Reed", "Ivy Lane", "Jon Park" }

local function key(n) return (tostring(n):lower():gsub("[%s%-]+", " ")) end

-- a name nobody in the world has yet, never mine
local function freeName(ctx)
	for _, n in ipairs(NAMES) do
		if key(n) ~= key(ctx.name) and not (ctx.w and ctx.w:player(n)) then return n end
	end
	error("role: no free name left")
end

-- runs the clock in small steps until pred() is true (at most max seconds); returns whether it came
local function waitFor(ctx, pred, max, step)
	step = step or 0.25
	local t = 0
	while not pred() do
		if t >= max then return false end
		ctx:advance(step)
		t = t + step
	end
	return true
end

local function client(ctx, name) return name and ctx.w:clientOf(name) end

-- the crew card's Yes on a window (UI.CrewOffer), else its handler (DR.AnswerOffer) when the card isn't drawn
local function sayYes(ctx, c, captainName)
	local DR = c.W.Drive
	local pend = DR.pendingOffers and DR.pendingOffers[key(captainName)]
	if not pend then return false end
	local f = c:findText("^Yes$")
	if f and #f > 0 then
		local okc = pcall(c.clickText, c, "^Yes$", { pattern = true })
		if okc and not DR.pendingOffers[key(captainName)] then return true end
	end
	return DR.AnswerOffer(captainName, true)
end

-- the captain (window cap) adds the member (window mem) by name and the member says yes
local function joinCrew(ctx, cap, mem)
	local capName, memName = cap.player.name, mem.player.name
	-- already in that crew (both windows' saved data say so): nothing to click
	if key(mem.W.Drive.char().captain) == key(capName) and cap.W.Drive.CrewEntry(key(memName)) then return end
	local okO, why = cap.W.Drive.OfferCrew(memName)
	if not okO then ctx:cannot("role: the crew offer to " .. memName .. " was refused (" .. tostring(why) .. ")") end
	if not waitFor(ctx, function() local p = mem.W.Drive.pendingOffers return p and p[key(capName)] ~= nil end, 5) then
		ctx:cannot("role: the crew card never reached " .. memName)
	end
	sayYes(ctx, mem, capName)
	if not waitFor(ctx, function() return cap.W.Drive.CrewEntry(key(memName)) ~= nil and mem.W.Drive.char().captain ~= "" end, 5) then
		ctx:cannot("role: " .. memName .. " said yes but is not in " .. capName .. "'s crew")
	end
end

local function open(ctx, c)
	local Ch = c.W.Char and c.W.Char()
	if Ch and c.player.class == "WARLOCK" then Ch.welcomed = true end -- the welcome's "Just open the console"
	local okc, why = c.W.Driver.SetOnline(true)
	if okc == false then ctx:cannot("role: " .. c.player.name .. " could not open: " .. tostring(why)) end
	ctx:advance(1)
	if not c.W.Drive.IsOpen() then ctx:cannot("role: " .. c.player.name .. " pressed Open but is not open") end
end

local function shopFacts(ctx, shop)
	local DR = shop.W.Drive
	ctx.facts.driverName = shop.player.name
	ctx.facts.price = DR.char().price
	ctx.facts.open = DR.IsOpen() == true
end

local function myFacts(ctx)
	local DR = ctx.W and ctx.W.Drive
	ctx.facts.roleShown = DR and DR.Role() or nil
	local D = ctx.W and ctx.W.Driver
	ctx.facts.mode = D and type(D.Mode) == "function" and D.Mode() or nil
end

Hunt.dial{
	name = "role",
	about = "who the player is: a rider, a Warlock driver, a non-Warlock running a Warlock friend's summons, or a crew member",
	phase = 30,
	default = "rider",
	values = {
		{ id = "rider", about = "a Mage with gold who books rides and never drives",
			pre = function(ctx)
				ctx.clientOpts.class = (ctx.clientOpts.class and ctx.clientOpts.class ~= "WARLOCK") and ctx.clientOpts.class or "MAGE"
				ctx.clientOpts.spot = ctx.clientOpts.spot or RIDER_SPOT
				ctx.clientOpts.money = math.max(ctx.clientOpts.money or 0, 1000000)
				ctx.facts.role = "rider"
			end,
			apply = function(ctx) myFacts(ctx) end,
		},
		{ id = "warlock", about = "a Warlock driving on his own at Ratchet, open for business, nobody in his group",
			pre = function(ctx)
				ctx.clientOpts.class = "WARLOCK"
				ctx.clientOpts.spot = SPOT -- (the core's default spot is the riders' Orgrimmar; the world dial may move me later)
				ctx.clientOpts.shards = ctx.clientOpts.shards or 10
				ctx.facts.role = "warlock"
			end,
			apply = function(ctx)
				local cap = ctx.W.Drive and ctx.W.Drive.char().captain
				if cap and cap ~= "" then
					ctx:cannot("role: the saved data puts me in " .. tostring(cap) .. "'s crew: a member, not a driver on his own")
				end
				open(ctx, ctx.me)
				local n = ctx.name
				ctx.facts.team = { service = n, caster = n, inviter = n, payee = n, clickers = {} }
				shopFacts(ctx, ctx.me)
				myFacts(ctx)
			end,
		},
		{ id = "friend", about = "a Mage who runs the service; a Warlock friend (another window, in my crew and group) summons",
			pre = function(ctx)
				if ctx.facts.savedClass == "WARLOCK" then ctx:cannot("role: a Warlock's saved data; the friend runner is another class") end
				ctx.clientOpts.class = "MAGE"
				ctx.clientOpts.spot = SPOT
				ctx.clientOpts.money = math.max(ctx.clientOpts.money or 0, 100000)
				ctx.facts.role = "friend"
			end,
			world = function(ctx)
				local n = freeName(ctx)
				ctx.w:addClient(n, { spot = ctx.clientOpts.spot or SPOT, class = "WARLOCK", shards = 10, money = 100000 })
				ctx.facts.summonerName = n
			end,
			apply = function(ctx)
				local me, friend = ctx.me, client(ctx, ctx.facts.summonerName)
				ctx.peers.summoner = friend
				-- the wizard: "A Warlock friend", Add by name, the friend's Yes, then the summoner order
				joinCrew(ctx, me, friend)
				me.W.Drive.SetSummoners({ key(friend.player.name) })
				me.W.Char().wizard = true
				ctx.w:group({ ctx.name, friend.player.name }) -- (the fake: an invite both accept)
				waitFor(ctx, function() return friend.W.Drive.Summoners and #friend.W.Drive.Summoners() > 0 end, 4)
				open(ctx, me)
				local f = friend.player.name
				ctx.facts.team = { service = ctx.name, caster = f, inviter = ctx.name, payee = f, clickers = { ctx.name } }
				shopFacts(ctx, me)
				myFacts(ctx)
				if ctx.facts.roleShown ~= "driver" or not me.W.Drive.IsRunner() then
					ctx:cannot("role: the Mage runner is not a runner (DR.Role() " .. tostring(ctx.facts.roleShown) .. ")")
				end
			end,
		},
		{ id = "crew", about = "a Priest (a Warlock with a Warlock's saved data) in a Warlock driver's crew (another window, the captain), grouped with him; his shop is open",
			pre = function(ctx)
				-- a Warlock's saved data (the author's alts are Warlocks in his main's crew): a Warlock member; else a Priest
				ctx.clientOpts.class = ctx.facts.savedClass == "WARLOCK" and "WARLOCK" or "PRIEST"
				ctx.clientOpts.spot = SPOT
				ctx.clientOpts.money = math.max(ctx.clientOpts.money or 0, 100000)
				ctx.facts.role = "crew"
			end,
			world = function(ctx)
				-- the captain my saved data names (online now), else a new one
				local W = ctx.saved and ctx.saved.Wuber
				local ch = type(W) == "table" and type(W.chars) == "table" and W.chars[key(ctx.name)] or nil
				local n = type(ch) == "table" and type(ch.captain) == "string" and ch.captain ~= "" and ch.captain or nil
				local saved
				if n and key(n) ~= key(ctx.name) and not ctx.w:player(n) then
					-- his own saved data has me (and the rest of my saved crew) in his crew, as it would on his disk
					local crew = { { name = ctx.name, role = ctx.clientOpts.class == "WARLOCK" and "lock" or "helper", app = true } }
					for _, m in ipairs(type(ch.crew) == "table" and ch.crew or {}) do
						if type(m) == "table" and type(m.name) == "string" and key(m.name) ~= key(n) and key(m.name) ~= key(ctx.name) and #crew < 8 then
							crew[#crew + 1] = { name = m.name, role = m.role == "lock" and "lock" or "helper", app = m.app ~= false }
						end
					end
					saved = { Wuber = { chars = { [key(n)] = { crew = crew, captain = "", wizard = true } } } }
				else
					n = freeName(ctx)
				end
				ctx.w:addClient(n, { spot = ctx.clientOpts.spot or SPOT, class = "WARLOCK", shards = 10, money = 100000, saved = saved })
				ctx.facts.captainName = n
			end,
			apply = function(ctx)
				local cap = client(ctx, ctx.facts.captainName)
				ctx.peers.captain, ctx.peers.driver = cap, cap
				cap.W.Char().wizard = true -- the captain's wizard: "My friends help"
				joinCrew(ctx, cap, ctx.me)
				ctx.w:group({ cap.player.name, ctx.name }) -- the captain leads
				open(ctx, cap)
				local c = cap.player.name
				ctx.facts.team = { service = c, caster = c, inviter = c, payee = c, clickers = { ctx.name } }
				shopFacts(ctx, cap)
				myFacts(ctx)
				local mine = ctx.W.Drive.char().captain
				if key(mine) ~= key(c) or (ctx.me.player.class ~= "WARLOCK" and ctx.facts.roleShown ~= "helper") then
					ctx:cannot("role: not in " .. c .. "'s crew (captain " .. tostring(mine) .. ", DR.Role() " .. tostring(ctx.facts.roleShown) .. ")")
				end
			end,
		},
	},
}

end
