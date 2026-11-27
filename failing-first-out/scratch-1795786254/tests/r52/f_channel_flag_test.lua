-- r52 group F: C_ChatInfo.AreOutgoingAddonChatMessagesRestricted() and the whisper fallback.
-- Not fixed this round (see BUGS-NEXT R52-F1): the whisper path (W.WhisperRound, Net/Discovery.lua:338) already
-- runs for every known driver not heard on the channel, so there is no 3-minute wait to skip there; the only
-- 3-minute switches are CX.isolated (Net/Beacons.lua:500, community copy of every beacon), W.net.whisperOnly
-- (Net/Discovery.lua:628, a status flag) and chanFlag (Net/Beacons.lua:456). The fake game answers the flag
-- TRUE in every world (opts.restricted defaults on, tests/harness.lua:2836) while it still delivers channel
-- messages, so reading the flag would change most transcripts; it needs a separate fake flag first.
local T = ...
T.pending("restricted flag true: the channel counts as silent at once (community copies every beacon, whisperOnly set)",
	"BUGS-NEXT R52-F1: needs a fake-game flag apart from SendChatMessage's 'restricted' (tests/harness.lua:5782) first", function() end)
