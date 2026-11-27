-- Hunt dial file (tests/hunt/README.md): the date. Owner: WORLD.
-- What Wuber keys on the date, found by reading the code: the rider's Wrapped card (due in the first 10 days of a
-- month for the month before, Core/Wrapped.lua, UI/Rider/Wrapped.lua: date("*t")), the driver's earnings by hour,
-- weekday and day (Drive/Log.lua, UI/Driver/Earnings.lua), the day key of rain checks and their expiry
-- (Drive/Raincheck.lua), the gifted stamp per customer (Drive/Book.lua), shared flight prices older than 90 days
-- (Core/Flights.lua), the phone's own clock, and every "at" stamp in the saved data.
-- The date is the fake clock: time() = H.EPOCH + world time, and H.EPOCH is 17 Nov 2026 19:00 local time. A situation
-- moves the world clock forward BEFORE any client exists, so the saved data (whoever wrote it) is older by that much:
-- it is exactly "the saved data was written a while ago". No random numbers: the target times are fixed dates.
-- Facts: ctx.facts.clockShift (seconds), .today ("YYYY-MM-DD" when the build ended its clock move), .newDay,
-- .newMonth, .newYear (against 17 Nov 2026).
return function(Hunt)
	local function at(y, m, d, h, mi)
		return os.time({ year = y, month = m, day = d, hour = h, min = mi, sec = 0 })
	end

	-- moves the world clock so that time() reads `target` (a local time); no client exists yet
	local function moveTo(ctx, target, name)
		local w = ctx.w
		local now = ctx.H.EPOCH + math.floor(w.time)
		local shift = target - now
		if shift < 0 then ctx:cannot("the clock cannot go back: " .. name) return end
		w.time = w.time + shift
		w.lastFrame = w.lastFrame + shift
		ctx.facts.clockShift = shift
		ctx.facts.today = os.date("%Y-%m-%d", target)
		ctx.facts.newDay = os.date("%Y%m%d", target) ~= os.date("%Y%m%d", ctx.H.EPOCH)
		ctx.facts.newMonth = os.date("%Y%m", target) ~= os.date("%Y%m", ctx.H.EPOCH)
		ctx.facts.newYear = os.date("%Y", target) ~= os.date("%Y", ctx.H.EPOCH)
	end
	local function value(id, about, y, m, d, h, mi)
		return { id = id, about = about, world = function(ctx) moveTo(ctx, at(y, m, d, h, mi), id) end }
	end

	Hunt.dial{
		name = "day",
		about = "the date when the game starts, against the day the saved data was written (the start is 17 Nov 2026, 19:00)",
		phase = 15,
		default = "same",
		values = {
			{ id = "same", about = "the same evening: nothing moves", world = function(ctx) moveTo(ctx, ctx.H.EPOCH + math.floor(ctx.w.time), "same") end },
			value("midnight_soon", "17 Nov 23:58: midnight comes two minutes into the session", 2026, 11, 17, 23, 58),
			value("next_day", "the next morning, 18 Nov 10:00: a new day since the saved data was written", 2026, 11, 18, 10, 0),
			value("next_month", "2 Dec 10:00: a new month; last month's Wrapped is due (first 10 days)", 2026, 12, 2, 10, 0),
			value("month_end_soon", "30 Nov 23:58: the month ends two minutes into the session", 2026, 11, 30, 23, 58),
			value("year_end_soon", "31 Dec 23:58: the year ends two minutes into the session", 2026, 12, 31, 23, 58),
			value("long_away", "20 Feb 2027, 95 days on: shared prices (90 days) and old rain checks have expired", 2027, 2, 20, 12, 0),
		},
	}
end
