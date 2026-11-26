-- Layout scenes for the tab bar that hides during a ride (design round 4, group C: UI.Window's syncBar, UI.TabsHidden,
-- the ride page's back chevron in UI.Rider.Ride). Installed by tests/layout/extra_screens.lua (X.install calls this
-- file's install), so the scenes work alone (--screen d4c_) and inside a whole sweep.
--   d4c_ride_tabs   the ride page with the portal up (the tour's own "portal" shot): the tab bar is away, the main button
--                   stands at the phone's foot, the back chevron is at the top left. The scene fails if the bar still
--                   shows or the button did not come down (a shot of the old layout would prove nothing).
--   d4c_ride_pay    the same for the pay look (the tour's "pay" shot): the chevron, then the title
--   d4c_ride_stranger  the pay look with the warning card beside the chevron (the tour's "stranger" shot)
--   d4c_home_ride   Home during that ride, after Back: the tab bar is there, the black pill is alive
-- The look at Home (ui.peek) is put away again by a wrapper of L.PhotoReset, which the tour calls before every screen.
-- Returns install(L, W): adds the screens, returns the ids it added.
local X = {}

function X.install(L, W)
	local added = {}
	local UI = W.UI
	if not (type(UI) == "table" and type(UI.TabsHidden) == "function" and type(UI.state) == "table") then return added end
	local function screen(id)
		for i, s in ipairs(L.PHOTO_SCREENS) do if s.id == id then return s, i end end
	end
	local function addAfter(base, s)
		local _, at = screen(base)
		table.insert(L.PHOTO_SCREENS, (at or #L.PHOTO_SCREENS) + 1, s)
		added[#added + 1] = s.id
	end
	local reset = L.PhotoReset
	L.PhotoReset = function(w, ...)
		if type(reset) == "function" then reset(w, ...) end
		if type(w) == "table" and type(w.UI) == "table" and type(w.UI.state) == "table" then w.UI.state.peek = nil end
	end
	local function refresh(w)
		if type(w.UI.RefreshNow) == "function" then w.UI.RefreshNow() end
	end
	-- the ride page as the round wants it, or why not
	-- early: the setup of a shot runs while the tab bar is still gliding away and the button still coming down; only the
	-- page itself is checked then, the bar and the button once the tour has let the screen settle (post)
	local function rideLook(w, early)
		local ui = w.UI.state
		local s = type(ui.screens) == "table" and ui.screens.found
		if ui.screen ~= "found" or type(s) ~= "table" then return "the ride page is not up: " .. tostring(ui.screen) end
		if not w.UI.TabsHidden() then return "the tab bar is not hidden on the ride page" end
		if early then return true end
		if ui.tabbar:IsShown() and (ui.tabbar:GetAlpha() or 1) > 0.01 and ui.barP ~= 1 then return "the tab bar still shows" end
		if not (s.back and s.back:IsVisible()) then return "the ride page has no back chevron" end
		local foot = s.action:GetBottom() - ui.win:GetBottom()
		if math.abs(foot - w.Theme.MAIN.foot) > 1 then return "the main button is not at the phone's foot: " .. tostring(foot) end
		return true
	end
	for _, v in ipairs({
		{ "d4c_ride_stranger", "stranger", "Ride, tabs hidden: a stranger's trade, the warning beside the back chevron" },
		{ "d4c_ride_pay", "pay", "Ride, tabs hidden: time to pay, the back chevron and the title" },
		{ "d4c_ride_tabs", "portal", "Ride, tabs hidden: the portal is up, the main button at the phone's foot" },
	}) do
		local base = screen(v[2])
		if base and type(base.run) == "function" then
			addAfter(v[2], { id = v[1], side = "rider", unfold = false, title = v[3], wait = base.wait, maxWait = base.maxWait,
				ready = base.ready, afterShot = base.afterShot,
				run = function(w, view)
					local r = base.run(w, view)
					if r ~= true then return r end
					refresh(w)
					return rideLook(w, true)
				end,
				post = function(w, view)
					if type(base.post) == "function" then
						local r = base.post(w, view)
						if r ~= true then return r end
					end
					return rideLook(w)
				end })
		end
	end
	local portal = screen("portal")
	if portal and type(portal.run) == "function" then
		addAfter("d4c_ride_tabs", { id = "d4c_home_ride", side = "rider", unfold = true, title = "Home during a ride (after Back): the tabs are there, the pill is alive",
			wait = portal.wait, maxWait = portal.maxWait,
			run = function(w, view)
				local r = portal.run(w, view)
				if r ~= true then return r end
				refresh(w)
				local ui = w.UI.state
				local s = ui.screens.found
				if not (s and s.back) then return "the ride page has no back chevron" end
				local click = s.back:GetScript("OnClick")
				if type(click) ~= "function" then return "the back chevron takes no click" end
				click(s.back, "LeftButton")
				refresh(w)
				if ui.screen ~= "home" then return "Back did not show Home: " .. tostring(ui.screen) end
				if w.UI.TabsHidden() then return "the tab bar is hidden on Home" end
				if type(w.ride) ~= "table" then return "the ride is gone" end
				return true
			end,
			post = function(w)
				local ui = w.UI.state
				if ui.screen ~= "home" then return "Home did not stay: " .. tostring(ui.screen) end
				if not (ui.tabbar:IsVisible() and (ui.tabbar:GetAlpha() or 0) > 0.99) then return "the tab bar is not back" end
				return true
			end })
	end
	return added
end

return X
