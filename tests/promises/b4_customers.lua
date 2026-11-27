-- Promises about the Driver Customers and Crew pages (Wuber/UI/Driver/Customers.lua, Crew.lua).
return function(Hunt)
	local function strip(t)
		return (tostring(t or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|H.-|h(.-)|h", "%1"))
	end

	local function find(ctx, pat)
		for _, t in ipairs(ctx:texts()) do
			local p = strip(t)
			if p:find(pat) then return p, t end
		end
		return nil
	end

	local function dr(ctx) return ctx.W.Drive end
	local function D(ctx) return ctx.W.Driver end

	local function noCombat(ctx)
		if ctx.me.player.combat then ctx:na("in combat") end
	end

	local function customersUp(ctx)
		if not find(ctx, "^Customers$") then ctx:cannot("the Customers screen is not up") end
	end

	local function crewUp(ctx)
		if not find(ctx, "^Your crew$") then ctx:cannot("the Crew screen is not up") end
	end

	local function boxesOf(ctx)
		local boxes = {}
		for _, obj in ipairs(ctx.me:findText("")) do
			local okT, ty = pcall(obj.GetObjectType, obj)
			if okT and ty == "EditBox" then boxes[#boxes + 1] = obj end
		end
		return boxes
	end

	local function searchBox(ctx)
		return boxesOf(ctx)[1]
	end

	local function noteBox(ctx)
		local boxes = boxesOf(ctx)
		return boxes[#boxes]
	end

	local function pickCustomer(ctx, name)
		local ok = pcall(ctx.me.clickText, ctx.me, "^" .. name:gsub("%p", "%%%0") .. "$", { pattern = true })
		if not ok then ctx:cannot("customer " .. name .. " is not listed") end
		ctx:advance(0.4)
		ctx:note("click " .. name)
	end

	local function clickSave(ctx)
		local ok = pcall(ctx.me.clickText, ctx.me, "^Save$", { pattern = true })
		if not ok then ctx:cannot("no Save button on screen") end
		ctx:advance(0.4)
		ctx:note("click Save")
	end

	local function addPaidRide(ctx, name, place, agoSecs, price)
		local l = ctx.W.db and ctx.W.db.drive and ctx.W.db.drive.log
		if not (l and l.rides) then ctx:cannot("no drive log") end
		local t = ctx.me.env.time() - (agoSecs or 600)
		table.insert(l.rides, t .. "," .. tostring(price or 5000) .. "," .. name .. "," .. (place or "Ratchet") .. ",t," .. tostring(price or 5000))
		ctx:note("log paid ride for " .. name .. " (" .. (place or "Ratchet") .. ")")
	end

	local function refreshCustomers(ctx)
		if D(ctx) and D(ctx).Refresh then
			pcall(D(ctx).Refresh, true)
			ctx:advance(0.3)
		end
	end

	-- 1. Empty Customers message
	Hunt.promise{
		id = "b4customers.empty_message",
		area = "Customers",
		text = "On the Customers screen with no paying riders yet, Wuber tells you that riders who pay you show here, latest first, with your notes and gifts.",
		source = "Wuber/UI/Driver/Customers.lua:882",
		kind = "scenario",
		needs = { phone = "drive_customers", ride = "none" },
		when = function(sit) return sit.role == "warlock" and (sit.saved == nil or sit.saved == "fresh") end,
		check = function(ctx)
			noCombat(ctx)
			customersUp(ctx)
			local list = dr(ctx).Customers("") or {}
			if #list > 0 then ctx:na("saved data already has customers") end
			if not find(ctx, "Nobody yet%. Riders who pay you show here") then
				ctx:fail("The empty Customers screen does not tell you that riders who pay you show here.")
			end
		end,
	}

	-- 2. Search filters and shows "Nobody by that name."
	Hunt.promise{
		id = "b4customers.search_filters_and_missing",
		area = "Customers",
		text = "Typing part of a customer's name in Search on Customers shows matching customers and hides others; typing a name nobody has shows 'Nobody by that name.'.",
		source = "Wuber/UI/Driver/Customers.lua:832-834,882",
		kind = "scenario",
		needs = { phone = "drive_customers", ride = "none" },
		when = function(sit) return sit.role == "warlock" end,
		check = function(ctx)
			noCombat(ctx)
			customersUp(ctx)
			addPaidRide(ctx, "Zara Swift", "Ratchet", 300, 5000)
			addPaidRide(ctx, "Bram Stone", "Booty Bay", 900, 5000)
			refreshCustomers(ctx)
			local sb = searchBox(ctx)
			if not sb then ctx:cannot("no Search box on Customers") end
			ctx.me:type(sb, "zara", false)
			ctx:advance(0.3)
			ctx:note("search 'zara'")
			if not find(ctx, "^Zara Swift$") then
				ctx:fail("Searching 'zara' on Customers does not show Zara Swift.")
			end
			if find(ctx, "^Bram Stone$") then
				ctx:fail("Searching 'zara' on Customers still shows Bram Stone.")
			end
			ctx.me:type(sb, "zzzznobody", false)
			ctx:advance(0.3)
			ctx:note("search 'zzzznobody'")
			if not find(ctx, "Nobody by that name%.") then
				ctx:fail("Searching for a name nobody has on Customers does not show 'Nobody by that name.'.")
			end
		end,
	}

	-- 3. Empty note Save says "Nothing to save: the note is empty"
	Hunt.promise{
		id = "b4customers.empty_note_nothing_to_save",
		area = "Customers",
		text = "Clicking Save when the note box is empty and the customer has no saved note says 'Nothing to save: the note is empty'.",
		source = "Wuber/UI/Driver/Customers.lua:406-409",
		kind = "scenario",
		needs = { phone = "drive_customers", ride = "paid" },
		when = function(sit) return sit.role == "warlock" end,
		check = function(ctx)
			noCombat(ctx)
			local name = ctx.facts.riderName
			if not name then ctx:cannot("no riderName") end
			customersUp(ctx)
			dr(ctx).SetNote(name, "")
			ctx:advance(0.2)
			pickCustomer(ctx, name)
			local box = noteBox(ctx)
			if not box then ctx:cannot("no note box") end
			ctx.me:type(box, "", false)
			clickSave(ctx)
			if not find(ctx, "Nothing to save: the note is empty") then
				ctx:fail("Clicking Save on an empty note box with no saved note does not say 'Nothing to save: the note is empty'.")
			end
		end,
	}

	-- 4. Unchanged note Save says "No changes to save"
	Hunt.promise{
		id = "b4customers.unchanged_note_no_changes",
		area = "Customers",
		text = "Clicking Save without changing a customer's existing note says 'No changes to save'.",
		source = "Wuber/UI/Driver/Customers.lua:406-409",
		kind = "scenario",
		needs = { phone = "drive_customers", ride = "paid" },
		when = function(sit) return sit.role == "warlock" end,
		check = function(ctx)
			noCombat(ctx)
			local name = ctx.facts.riderName
			if not name then ctx:cannot("no riderName") end
			customersUp(ctx)
			if not dr(ctx).SetNote(name, "Quick payer") then ctx:cannot("could not set initial note") end
			ctx:advance(0.3)
			pickCustomer(ctx, name)
			clickSave(ctx)
			if not find(ctx, "No changes to save") then
				ctx:fail("Clicking Save without changing an existing note does not say 'No changes to save'.")
			end
		end,
	}

	-- 5. Note capped at 200 bytes
	Hunt.promise{
		id = "b4customers.note_capped_at_200",
		area = "Customers",
		text = "Typing more than 200 characters into a customer's note box caps the kept note at 200 bytes.",
		source = "Wuber/UI/Driver/Customers.lua:509,514",
		kind = "scenario",
		needs = { phone = "drive_customers", ride = "paid" },
		when = function(sit) return sit.role == "warlock" end,
		check = function(ctx)
			noCombat(ctx)
			local name = ctx.facts.riderName
			if not name then ctx:cannot("no riderName") end
			customersUp(ctx)
			pickCustomer(ctx, name)
			local box = noteBox(ctx)
			if not box then ctx:cannot("no note box") end
			local long = string.rep("word ", 46)
			ctx.me:type(box, long, false)
			ctx:advance(0.2)
			clickSave(ctx)
			local rec = dr(ctx).BookEntry(name)
			local saved = rec and rec.note or ""
			if #saved > 200 or #saved == 0 then
				ctx:fail(("Typing 230 characters into a customer's note kept %d bytes instead of capping at 200."):format(#saved))
			end
		end,
	}

	-- 6. Remove note ask expires after 5s
	Hunt.promise{
		id = "b4customers.note_remove_ask_expires",
		area = "Customers",
		text = "Emptying a saved note and clicking Save once asks 'Remove note?'; waiting five seconds without a second click returns the button to 'Save' and keeps the note.",
		source = "Wuber/UI/Driver/Customers.lua:415,429 (inferred)",
		kind = "scenario",
		needs = { phone = "drive_customers", ride = "paid" },
		when = function(sit) return sit.role == "warlock" end,
		check = function(ctx)
			noCombat(ctx)
			local name = ctx.facts.riderName
			if not name then ctx:cannot("no riderName") end
			customersUp(ctx)
			if not dr(ctx).SetNote(name, "Keep me") then ctx:cannot("could not set note") end
			ctx:advance(0.3)
			pickCustomer(ctx, name)
			local box = noteBox(ctx)
			if not box then ctx:cannot("no note box") end
			ctx.me:type(box, "", false)
			clickSave(ctx)
			if not find(ctx, "^Remove note%?$") then
				ctx:fail("Emptying a note and clicking Save once does not show 'Remove note?'.")
			end
			ctx:advance(5.5)
			if not find(ctx, "^Save$") then
				ctx:fail("Five seconds after 'Remove note?' appeared, the button did not return to 'Save'.")
			end
			local rec = dr(ctx).BookEntry(name)
			if not (rec and rec.note == "Keep me") then
				ctx:fail("The note was removed even though you did not click 'Remove note?' a second time.")
			end
		end,
	}

	-- 7. Serve hold pill for owing rider (Advanced mode)
	Hunt.promise{
		id = "b4customers.serve_hold_for_owing_rider",
		area = "Customers",
		text = "In Advanced mode, a rider who left owing shows 'Don't serve again until <date>' on their note pane, and clicking it sets and lifts the hold.",
		source = "Wuber/UI/Driver/Customers.lua:447-475,657",
		kind = "scenario",
		needs = { phone = "drive_customers", ride = "none" },
		when = function(sit) return sit.role == "warlock" end,
		check = function(ctx)
			noCombat(ctx)
			if ctx.W.Advanced and not ctx.W.Advanced() then ctx:na("requires Advanced mode") end
			customersUp(ctx)
			local name = "Owe Rider"
			addPaidRide(ctx, name, "Ratchet", 400, 5000)
			if dr(ctx).MailOwes then
				dr(ctx).MailOwes({ name = name }, 5000)
			end
			if not (dr(ctx).OwesFare and dr(ctx).OwesFare(name) == true) then
				ctx:cannot("could not mark rider as owing")
			end
			refreshCustomers(ctx)
			pickCustomer(ctx, name)
			if not find(ctx, "^Don't serve again until ") then
				ctx:fail("A rider who left owing does not show the 'Don't serve again until <date>' button.")
			end
			local ok = pcall(ctx.me.clickText, ctx.me, "^Don't serve again until ", { pattern = true })
			if not ok then ctx:cannot("could not click Don't serve again") end
			ctx:advance(0.3)
			if not (dr(ctx).ServeHold and dr(ctx).ServeHold(name)) then
				ctx:fail("Clicking 'Don't serve again until <date>' did not set a serve hold.")
			end
			pcall(ctx.me.clickText, ctx.me, "^Don't serve again until ", { pattern = true })
			ctx:advance(0.3)
			if dr(ctx).ServeHold and dr(ctx).ServeHold(name) then
				ctx:fail("Clicking 'Don't serve again until <date>' a second time did not lift the serve hold.")
			end
		end,
	}

	-- 8. Unfolded side pane switches when clicking another customer
	Hunt.promise{
		id = "b4customers.unfolded_side_pane_switches",
		area = "Customers",
		text = "When Customers is unfolded, clicking another customer on the left switches the right pane to show their name and facts.",
		source = "Wuber/UI/Driver/Customers.lua:653-690,735-737,861-867",
		kind = "scenario",
		needs = { phone = "drive_customers", fold = "unfolded", ride = "none" },
		when = function(sit) return sit.role == "warlock" end,
		check = function(ctx)
			noCombat(ctx)
			if not (D(ctx).Wide and D(ctx).Wide("customers")) then ctx:na("Customers is not unfolded at this window size") end
			customersUp(ctx)
			addPaidRide(ctx, "First Rider", "Ratchet", 120, 5000)
			addPaidRide(ctx, "Second Rider", "Booty Bay", 600, 5000)
			refreshCustomers(ctx)
			pickCustomer(ctx, "Second Rider")
			if not find(ctx, "last %d+ %a+ · Booty Bay") then
				ctx:fail("Clicking Second Rider on unfolded Customers did not show their Booty Bay ride facts on the right pane.")
			end
		end,
	}

	-- 9. Latest ride first ordering
	Hunt.promise{
		id = "b4customers.latest_ride_first",
		area = "Customers",
		text = "When two customers paid you at different times, Customers lists the one who paid more recently first.",
		source = "Wuber/UI/Driver/Customers.lua:882",
		kind = "scenario",
		needs = { phone = "drive_customers", ride = "none" },
		when = function(sit) return sit.role == "warlock" end,
		check = function(ctx)
			noCombat(ctx)
			customersUp(ctx)
			addPaidRide(ctx, "Older Rider", "Ratchet", 3600, 5000)
			addPaidRide(ctx, "Newer Rider", "Ratchet", 100, 5000)
			local list = dr(ctx).Customers("") or {}
			local newerIdx, olderIdx
			for i, e in ipairs(list) do
				if e.name == "Newer Rider" then newerIdx = i end
				if e.name == "Older Rider" then olderIdx = i end
			end
			if not (newerIdx and olderIdx) then ctx:cannot("riders missing from Customers list") end
			if newerIdx > olderIdx then
				ctx:fail(("Newer Rider appeared at row %d behind Older Rider at row %d instead of latest first."):format(newerIdx, olderIdx))
			end
		end,
	}

	-- 10. Invite to Wuber pill for live stranger in queue on unfolded Customers
	Hunt.promise{
		id = "b4customers.invite_to_wuber_for_live_stranger",
		area = "Customers",
		text = "When a customer is in your queue without Wuber and whispers are on, the unfolded Customers right pane offers 'Invite to Wuber', and clicking it changes the button to 'Next click sends'.",
		source = "Wuber/UI/Driver/Customers.lua:608-621,658-671",
		kind = "scenario",
		needs = { phone = "drive_customers", fold = "unfolded", ride = "none" },
		when = function(sit) return sit.role == "warlock" and sit.opt_whisperMode ~= "off" end,
		check = function(ctx)
			noCombat(ctx)
			if not (D(ctx).Wide and D(ctx).Wide("customers")) then ctx:na("Customers is not unfolded at this window size") end
			if dr(ctx).ChatMode and dr(ctx).ChatMode() == "off" then ctx:na("whispers are off") end
			customersUp(ctx)
			local name = "Live Stran"
			addPaidRide(ctx, name, "Ratchet", 120, 5000)
			if not ctx.w:player(name) then ctx.w:addBot(name, {}) end
			ctx.w:botWhisper(name, ctx.me, "summon ratchet please")
			ctx:advance(1)
			refreshCustomers(ctx)
			pickCustomer(ctx, name)
			local state = dr(ctx).GetAppState and dr(ctx).GetAppState({ name = name, key = ctx.W.Key(name) }, true)
			if state ~= "ok" then ctx:na("GetAppState is " .. tostring(state)) end
			if not find(ctx, "^Invite to Wuber$") then
				ctx:fail("Unfolded Customers does not offer 'Invite to Wuber' for a live stranger in the queue.")
			end
			local ok = pcall(ctx.me.clickText, ctx.me, "^Invite to Wuber$", { pattern = true })
			if not ok then ctx:cannot("could not click Invite to Wuber") end
			ctx:advance(0.3)
			if not find(ctx, "^Next click sends$") then
				ctx:fail("Clicking 'Invite to Wuber' on Customers did not change the button to 'Next click sends'.")
			end
		end,
	}

	-- 11. Non-captain crew member sees Leave this crew, hides adder and Fair split
	Hunt.promise{
		id = "b4customers.non_captain_sees_leave_not_add",
		area = "Crew",
		text = "When you are in another driver's crew, the Crew screen names the captain, shows 'Leave this crew', and hides the add-by-name box and Fair split.",
		source = "Wuber/UI/Driver/Crew.lua:252-271,376-388",
		kind = "scenario",
		needs = { phone = "drive_crew", ride = "none" },
		when = function(sit) return sit.role == "crew" end,
		check = function(ctx)
			noCombat(ctx)
			crewUp(ctx)
			if dr(ctx).IsCaptain and dr(ctx).IsCaptain() ~= false then ctx:na("player is captain") end
			if not find(ctx, "crew: you get the call to click the portal") then
				ctx:fail("A non-captain crew member's Crew screen does not name their captain.")
			end
			if not find(ctx, "^Leave this crew$") then
				ctx:fail("A non-captain crew member's Crew screen does not show 'Leave this crew'.")
			end
			if find(ctx, "^Fair split$") then
				ctx:fail("A non-captain crew member's Crew screen still shows Fair split.")
			end
		end,
	}

	-- 12. Fair split Equal hides Casters' part slider
	Hunt.promise{
		id = "b4customers.fair_split_equal_hides_caster_slider",
		area = "Crew",
		text = "In Advanced mode on the Crew screen, switching Fair split to Equal hides the Casters' part slider, and switching back to By clicks shows it again.",
		source = "Wuber/UI/Driver/Crew.lua:224-247,346-370",
		kind = "scenario",
		needs = { phone = "drive_crew", ride = "none" },
		when = function(sit) return sit.role == "warlock" or sit.role == "friend" end,
		check = function(ctx)
			noCombat(ctx)
			if ctx.W.Advanced and not ctx.W.Advanced() then ctx:na("requires Advanced mode") end
			crewUp(ctx)
			local okE = pcall(ctx.me.clickText, ctx.me, "^Equal$", { pattern = true })
			if not okE then ctx:cannot("could not click Equal") end
			ctx:advance(0.3)
			if find(ctx, "^Casters' part$") then
				ctx:fail("Switching Fair split to Equal still shows the Casters' part slider.")
			end
			local okC = pcall(ctx.me.clickText, ctx.me, "^By clicks$", { pattern = true })
			if not okC then ctx:cannot("could not click By clicks") end
			ctx:advance(0.3)
			if not find(ctx, "^Casters' part$") then
				ctx:fail("Switching Fair split back to By clicks does not show the Casters' part slider.")
			end
		end,
	}

	-- 13. Crew "my window" toggle
	Hunt.promise{
		id = "b4customers.crew_my_window_toggle",
		area = "Crew",
		text = "When a crew mate uses Wuber and note sharing with your own accounts is on, toggling 'my window' on their Crew card tells you whether notes go to them.",
		source = "Wuber/UI/Driver/Customers.lua:300-316",
		kind = "scenario",
		needs = { phone = "drive_crew", ride = "none" },
		when = function(sit) return sit.role == "friend" and sit.opt_shareNotes ~= "off" end,
		check = function(ctx)
			noCombat(ctx)
			crewUp(ctx)
			if dr(ctx).BookShareOn and dr(ctx).BookShareOn() == false then ctx:na("note sharing is off") end
			local lbls = ctx.me:findText("^my window$", { pattern = true })
			local card = lbls and lbls[1] and lbls[1]:GetParent()
			local toggle = card and card.own
			if not toggle then
				ctx:fail("A crew mate with Wuber does not show the 'my window' switch on the Crew screen.")
			end
			ctx.me:clickOn(toggle)
			ctx:note("click my window toggle")
			local okToast = false
			for _ = 1, 24 do
				ctx:advance(0.25)
				if find(ctx, "Notes go to ") or find(ctx, "Notes no longer go to ") then
					okToast = true
					break
				end
			end
			if not okToast then
				ctx:fail("Toggling 'my window' on a crew card did not tell you whether notes go to them.")
			end
		end,
	}

	-- 14. Long spaceless note on Customers row is never cut with "..."
	Hunt.promise{
		id = "b4customers.long_spaceless_note_not_cut",
		area = "Customers",
		text = "A long customer note without spaces wraps onto more lines on the Customers list and is never cut short.",
		source = "docs/PLAYER-GUIDE.md:139",
		kind = "scenario",
		needs = { phone = "drive_customers", ride = "paid" },
		when = function(sit) return sit.role == "warlock" end,
		check = function(ctx)
			noCombat(ctx)
			local name = ctx.facts.riderName
			if not name then ctx:cannot("no riderName") end
			customersUp(ctx)
			local long = string.rep("x", 120)
			if not dr(ctx).SetNote(name, long) then ctx:cannot("could not set long note") end
			refreshCustomers(ctx)
			local _, raw = find(ctx, "xxxxxxxxxx")
			if not raw then ctx:cannot("long note not shown on Customers") end
			for _, obj in ipairs(ctx.me:findText("xxxxxxxxxx")) do
				local okT, trunc = pcall(obj.IsTruncated, obj)
				if okT and trunc then
					ctx:fail("A long customer note without spaces is cut short on the Customers list instead of wrapping.")
				end
			end
		end,
	}
end
