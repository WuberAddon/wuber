-- tests/lib/rec_addon.lua: where the flight recorder addon is, and whether these tests are for it.
--
-- The recorder (developer only, never shipped) lives OUTSIDE this repo, in
-- the folder the environment variable WUBER_REC_DIR names. The tests in tests/rec that load it are
-- written for ONE version of it (A.WANT, the TOC's "## Version"). When the folder is missing, or holds
-- another version (the addon moved on, or this branch is older than the addon), those tests are
-- skipped with one passing note each instead of failing for a reason that is not this branch's.
-- When the addon changes: bump its version (WuberRec.toc and R.VERSION in Rec.lua) and A.WANT here in
-- the same piece of work.
--
--   local A = dofile(T.dir .. "/lib/rec_addon.lua")
--   if not A.have() then test("rec: ... skipped (" .. A.why() .. ")", function() end) return end

local A = {}
A.WANT = "1.1.0"

-- The copy made for THIS tree (Data.lua from tools/rec/gen-data.lua, the policy lines of the Decisions round):
-- an older recorder copy makes three rec: tests fail on v2.4 (the recorder keeps the first name
-- "Bob" of a G message, the sample fixtures read stale, the replay misses WuberFlightPins). Used when it exists.

function A.dir()
	local d = os.getenv("WUBER_REC_DIR")
	if d and d ~= "" then return (d:gsub("\\", "/"):gsub("/+$", "")) end
	return "WuberRec" -- (the recorder is not in this repo: WUBER_REC_DIR names it; this relative name is never there)
end

-- the TOC's "## Version", or nil when there is no TOC there
function A.version(dir)
	local f = io.open((dir or A.dir()) .. "/WuberRec.toc", "rb")
	if not f then return nil end
	local text = f:read("*a")
	f:close()
	return text:match("##%s*Version:%s*([^\r\n]-)%s*[\r\n]") or "?"
end

-- "ok", "missing" or "other"
function A.state()
	local v = A.version()
	if not v then return "missing" end
	if v ~= A.WANT then return "other", v end
	return "ok", v
end

function A.have() return (A.state()) == "ok" end

function A.why()
	local s, v = A.state()
	if s == "missing" then return "no recorder addon at " .. A.dir() end
	if s == "other" then return "the recorder addon at " .. A.dir() .. " is version " .. tostring(v) .. ", these tests are for " .. A.WANT end
	return "the recorder addon is version " .. A.WANT
end

return A
