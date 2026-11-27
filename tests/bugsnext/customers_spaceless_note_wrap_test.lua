-- Regression test for #78: a long customer note without spaces on the Customers list wraps instead of truncating.
-- Loaded by tests/run.lua with its helper table T.
local T = ...
local test, ok = T.test, T.ok

test("bugsnext: long spaceless customer note wraps on Customers list without truncation", function()
	local w = T.newWorld()
	local a = T.driver(w, T.ANITA, { spot = "Undercity" })
	w:advance(15)
	local W, DR = a.W, a.W.Drive
	DR.IsOpen = function() return true end
	T.openDrive(a)
	local long = string.rep("x", 120)
	DR.Log().rides[1] = table.concat({ a.env.time() - 600, 5000, "Dan Rider", "Orgrimmar", "t", 5000 }, ",")
	DR.SetNote("Dan Rider", long)
	W.UI.ShowDrive("console")
	W.Driver.ShowScreen("customers")
	w:advance(1)
	local s = W.Driver.ui.subs.customers
	local row
	for i = 1, s.rowsShown or 0 do
		local r = s.pool.list[i]
		if r.e and r.e.name == "Dan Rider" then
			row = r
			break
		end
	end
	ok(row, "Dan Rider row is shown on Customers")
	local text = row.sub:GetText() or ""
	ok(text:find("xxxxxxxxxx", 1, true), "long spaceless note is shown")
	ok(not row.sub:IsTruncated(), "long spaceless note is not truncated")
	ok(row:GetHeight() > 54, "row grew to hold wrapped lines: " .. tostring(row:GetHeight()))
	T.clean(w)
end)
