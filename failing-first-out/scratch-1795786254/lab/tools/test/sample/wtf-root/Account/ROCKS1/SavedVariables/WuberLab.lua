
WuberLabDB = {
	["chars"] = {
		["Wuber Rocks"] = {
			["checks"] = {
				["r_accepted"] = {
					["at"] = 1794943027.7,
					["by"] = "accept_msg",
					["r"] = "auto",
					["sec"] = "Ride",
					["text"] = "Driver accepted",
					["took"] = 0.20000004768372,
				},
				["r_arrived"] = {
					["at"] = 1794943043.5,
					["by"] = "ride_arrived",
					["r"] = "auto",
					["sec"] = "Ride",
					["text"] = "Arrived",
					["took"] = 2,
				},
				["r_booked"] = {
					["at"] = 1794943027.5,
					["by"] = "ride_requesting",
					["r"] = "auto",
					["sec"] = "Ride",
					["text"] = "Booked a ride",
				},
				["r_crown"] = {
					["at"] = 1794943139.5,
					["by"] = "hand",
					["note"] = "crown sits inside the cow",
					["r"] = "fail",
					["sec"] = "Looks",
					["text"] = "Crown over the team's heads",
				},
				["r_invite"] = {
					["at"] = 1794943027.6,
					["by"] = "auto_accept",
					["r"] = "auto",
					["sec"] = "Ride",
					["text"] = "Invite auto-accepted (no click)",
					["took"] = 0.099999904632568,
				},
				["r_left"] = {
					["at"] = 1794943051.499,
					["by"] = "auto_left",
					["r"] = "auto",
					["sec"] = "Ride",
					["text"] = "Left the group by itself",
					["took"] = 2.9990000724792,
				},
				["r_milestone"] = {
					["at"] = 1794943048.5,
					["by"] = "milestone_pop",
					["r"] = "auto",
					["sec"] = "Ride",
					["text"] = "Milestone pop",
					["took"] = 5,
				},
				["r_open"] = {
					["at"] = 1794943025,
					["by"] = "app_open",
					["r"] = "auto",
					["sec"] = "Basics",
					["text"] = "App opens",
				},
				["r_pay"] = {
					["at"] = 1794943048.5,
					["by"] = "pay_done",
					["r"] = "auto",
					["sec"] = "Ride",
					["text"] = "Fare paid, trade done",
					["took"] = 5,
				},
				["r_rated"] = {
					["at"] = 1794943053.499,
					["by"] = "rated",
					["r"] = "auto",
					["sec"] = "Ride",
					["text"] = "Rating sent",
					["took"] = 2,
				},
				["r_summon"] = {
					["at"] = 1794943041.5,
					["by"] = "ride_portal",
					["r"] = "auto",
					["sec"] = "Ride",
					["text"] = "Summon popup / portal",
					["took"] = 13.799999952316,
				},
				["r_whisper"] = {
					["at"] = 1794943027.5,
					["by"] = "whisper_wtb",
					["r"] = "auto",
					["sec"] = "Ride",
					["text"] = "Visible WTB whisper sent",
				},
			},
			["dropped"] = 0,
			["lastLogin"] = 1794943002,
			["lines"] = {
				"1794943002.000|Wuber Rocks|login|char=Wuber Rocks realm=Forever role=rider build=1.60.1/70938/Nov 12 2026/16001 lab=1.0.0 Wuber=1.0.0 RitualRides=off OpenMap=off Moo=off !BugGrabber=off BugSack=off W.VERSION=1.1.0 channels=4 errhandler=replaced later buggrabber=no", -- [1]
				"1794943002.000|Wuber Rocks|probe|channels=4 wuberIndex=nil (login)", -- [2]
				"1794943002.000|Wuber Rocks|ev|PLAYER_ENTERING_WORLD login=true reload=false", -- [3]
				"1794943002.000|Wuber Rocks|ev|ZONE_CHANGED_NEW_AREA zone=Orgrimmar sub=Valley of Strength", -- [4]
				"1794943004.000|Wuber Rocks|tool|test mode on (developer only). /lab opens the test plan. Role: rider", -- [5]
				"1794943005.000|Wuber Rocks|probe|font Poppins SetFont ok=true returned=true GetFont=Interface\\AddOns\\Wuber\\Media\\fonts\\Poppins-Regular.ttf T.poppins=true", -- [6]
				"1794943008.000|Wuber Rocks|probe|JoinTemporaryChannel(WuberNet) called combat=false", -- [7]
				"1794943008.000|Wuber Rocks|probe|CheckChannel(true) -> false index=nil channels=4 fails=nil", -- [8]
				"1794943008.500|Wuber Rocks|fire|NETWORK true", -- [9]
				"1794943008.500|Wuber Rocks|msg>|Q C>5 Q~1", -- [10]
				"1794943008.500|Wuber Rocks|ui|Ping ok=true nil", -- [11]
				"1794943008.500|Wuber Rocks|probe|CheckChannel(false) -> true index=5 channels=5 fails=nil", -- [12]
				"1794943008.500|Wuber Rocks|probe|channels=5 wuberIndex=5 (CHANNEL_UI_UPDATE)", -- [13]
				"1794943008.600|Wuber Rocks|msg<|Q C<Wuber Rocks Q~1", -- [14]
				"1794943009.100|Wuber Rocks|plan|s3_d1;auto;by=beacon_open;who=Anita Lift;src=sync", -- [15]
				"1794943010.000|Wuber Rocks|self|[login] 15 of 15 passed", -- [16]
				"1794943010.600|Wuber Rocks|plan|s1_1@farra way;ok;by=probe:fresh;who=Farra Way;src=sync", -- [17]
				"1794943010.600|Wuber Rocks|plan|s0_1@farra way;ok;by=probe:fresh;who=Farra Way;src=sync", -- [18]
				"1794943010.600|Wuber Rocks|plan|s0_2@farra way;ok;by=probe:addons;who=Farra Way;src=sync", -- [19]
				"1794943011.600|Wuber Rocks|fire|DRIVERS n=1 anita lift", -- [20]
				"1794943011.600|Wuber Rocks|msg<|D C<Anita Lift D~1~Ratchet~1413~627~370~50000~Ritual Rides~open~3~7~H~1.1.0~~0", -- [21]
				"1794943012.000|Wuber Rocks|plan|s0_1@wuber rocks;ok;by=probe:fresh;who=Wuber Rocks;src=local", -- [22]
				"1794943012.000|Wuber Rocks|probe|plan s0_1 (fresh) on Wuber Rocks: ok", -- [23]
				"1794943012.000|Wuber Rocks|plan|s0_2@wuber rocks;no;by=probe:addons;who=Wuber Rocks;src=local", -- [24]
				"1794943012.000|Wuber Rocks|probe|plan s0_2 (addons) on Wuber Rocks: no", -- [25]
				"1794943012.000|Wuber Rocks|plan|s1_1@wuber rocks;ok;by=probe:fresh;who=Wuber Rocks;src=local", -- [26]
				"1794943012.000|Wuber Rocks|probe|plan s1_1 (fresh) on Wuber Rocks: ok", -- [27]
				"1794943012.100|Wuber Rocks|plan|s0_2@anita lift;ok;by=probe:addons;who=Anita Lift;src=sync", -- [28]
				"1794943012.100|Wuber Rocks|plan|s0_1@anita lift;ok;by=probe:fresh;who=Anita Lift;src=sync", -- [29]
				"1794943012.100|Wuber Rocks|plan|s1_1@anita lift;ok;by=probe:fresh;who=Anita Lift;src=sync", -- [30]
				"1794943012.100|Wuber Rocks|plan|s0_2@hayley cab;ok;by=probe:addons;who=Hayley Cab;src=sync", -- [31]
				"1794943013.600|Wuber Rocks|plan|s0_1@hayley cab;ok;by=probe:fresh;who=Hayley Cab;src=sync", -- [32]
				"1794943013.600|Wuber Rocks|plan|s1_1@hayley cab;ok;by=probe:fresh;who=Hayley Cab;src=sync", -- [33]
				"1794943015.100|Wuber Rocks|plan|s0_1;auto;by=probe;who=Anita Lift;src=sync", -- [34]
				"1794943015.100|Wuber Rocks|plan|s1_1;auto;by=probe;who=Anita Lift;src=sync", -- [35]
				"1794943025.000|Wuber Rocks|ui|Show confirm anita lift", -- [36]
				"1794943025.000|Wuber Rocks|plan|s3_r2;auto;by=confirm_shown;who=Wuber Rocks;src=local", -- [37]
				"1794943025.000|Wuber Rocks|ui|window open", -- [38]
				"1794943025.000|Wuber Rocks|check|r_open;auto;by=app_open;took=-;App opens", -- [39]
				"1794943025.000|Wuber Rocks|plan|s2_1;auto;by=app_open;who=Wuber Rocks;src=local", -- [40]
				"1794943027.500|Wuber Rocks|whsp|> Anita Lift: WTB summon to Ratchet for 5g", -- [41]
				"1794943027.500|Wuber Rocks|check|r_whisper;auto;by=whisper_wtb;took=-;Visible WTB whisper sent", -- [42]
				"1794943027.500|Wuber Rocks|plan|s3_r3;auto;by=whisper_wtb;who=Wuber Rocks;src=local", -- [43]
				"1794943027.500|Wuber Rocks|msg>|R W>Anita Lift R~1~VKNhsP~Ratchet~50000~0~0", -- [44]
				"1794943027.500|Wuber Rocks|ride|VKNhsP;requesting;from=-;dt=0.0;tot=0.0;drv=Anita Lift;dest=Ratchet;price=50000;fake=no", -- [45]
				"1794943027.500|Wuber Rocks|check|r_booked;auto;by=ride_requesting;took=-;Booked a ride", -- [46]
				"1794943027.500|Wuber Rocks|ui|RequestRide anita lift -> ride combat=false", -- [47]
				"1794943027.600|Wuber Rocks|ride|VKNhsP;invited;from=requesting;dt=0.1;tot=0.1;drv=Anita Lift;dest=Ratchet;price=50000;fake=no", -- [48]
				"1794943027.600|Wuber Rocks|ridef|VKNhsP;inviter=anita lift", -- [49]
				"1794943027.600|Wuber Rocks|ui|toast [info] Anita invited you. Accept the invite.", -- [50]
				"1794943027.600|Wuber Rocks|probe|AcceptGroup() called combat=false", -- [51]
				"1794943027.600|Wuber Rocks|try|cap=accept ok=true result=nil combat=false", -- [52]
				"1794943027.600|Wuber Rocks|ridef|VKNhsP;autoAccepted=true", -- [53]
				"1794943027.600|Wuber Rocks|check|r_invite;auto;by=auto_accept;took=0.1;Invite auto-accepted (no click)", -- [54]
				"1794943027.600|Wuber Rocks|plan|s3_r5;auto;by=auto_accept;who=Wuber Rocks;src=local", -- [55]
				"1794943027.600|Wuber Rocks|plan|s3_c2;auto;by=auto_accept;who=Wuber Rocks;src=local", -- [56]
				"1794943027.600|Wuber Rocks|ev|PARTY_INVITE_REQUEST inviter='Anita Lift' type=string extra=7", -- [57]
				"1794943027.700|Wuber Rocks|msg<|D C<Anita Lift D~1~Ratchet~1413~627~370~50000~Ritual Rides~busy~3~7~H~1.1.0~~0", -- [58]
				"1794943027.700|Wuber Rocks|ride|VKNhsP;ingroup;from=invited;dt=0.1;tot=0.2;drv=Anita Lift;dest=Ratchet;price=50000;fake=no", -- [59]
				"1794943027.700|Wuber Rocks|ev|GROUP_ROSTER_UPDATE members=3 Anita Lift,Farra Way,Hayley Cab", -- [60]
				"1794943027.700|Wuber Rocks|ridef|VKNhsP;acceptedAt=1027.7", -- [61]
				"1794943027.700|Wuber Rocks|check|r_accepted;auto;by=accept_msg;took=0.2;Driver accepted", -- [62]
				"1794943027.700|Wuber Rocks|plan|s3_r4;auto;by=accept_msg;who=Wuber Rocks;src=local", -- [63]
				"1794943027.700|Wuber Rocks|msg<|A W<Anita Lift A~1~VKNhsP~50000~5", -- [64]
				"1794943027.700|Wuber Rocks|msg<|S W<Anita Lift S~1~VKNhsP~invited", -- [65]
				"1794943028.200|Wuber Rocks|probe|invite 0.6s later: wuberAutoAccepted=true inGroup=true rideState=ingroup autoAcceptSetting=true blocked=false", -- [66]
				"1794943030.100|Wuber Rocks|plan|s3_c1;auto;by=whisper_wtb_in;who=Anita Lift;src=sync", -- [67]
				"1794943032.700|Wuber Rocks|msg<|D C<Anita Lift D~1~Ratchet~1413~627~370~50000~Ritual Rides~busy~3~6~H~1.1.0~~0", -- [68]
				"1794943038.500|Wuber Rocks|whsp|< Anita Lift: Ritual Rides: summoning you to Ratchet now - please accept the summon! The ride is 5g; just open trade with any of us when you land.", -- [69]
				"1794943038.600|Wuber Rocks|ride|VKNhsP;summoning;from=ingroup;dt=10.9;tot=11.1;drv=Anita Lift;dest=Ratchet;price=50000;fake=no", -- [70]
				"1794943038.600|Wuber Rocks|msg<|S W<Anita Lift S~1~VKNhsP~summoning", -- [71]
				"1794943041.500|Wuber Rocks|ride|VKNhsP;portal;from=summoning;dt=2.9;tot=14.0;drv=Anita Lift;dest=Ratchet;price=50000;fake=no", -- [72]
				"1794943041.500|Wuber Rocks|check|r_summon;auto;by=ride_portal;took=13.8;Summon popup / portal", -- [73]
				"1794943041.500|Wuber Rocks|ridef|VKNhsP;summonUp=true", -- [74]
				"1794943041.500|Wuber Rocks|fx|Fullscreen portal_open played", -- [75]
				"1794943041.500|Wuber Rocks|ui|toast [summon] Accept the summon to Ratchet!", -- [76]
				"1794943041.500|Wuber Rocks|ev|CONFIRM_SUMMON summoner=Anita Lift area=Ratchet", -- [77]
				"1794943042.500|Wuber Rocks|probe|C_SummonInfo.ConfirmSummon() called combat=false", -- [78]
				"1794943042.500|Wuber Rocks|ui|AcceptSummon ok=true nil", -- [79]
				"1794943042.600|Wuber Rocks|ridef|VKNhsP;summonAccepted=true", -- [80]
				"1794943042.600|Wuber Rocks|msg<|S W<Anita Lift S~1~VKNhsP~portal", -- [81]
				"1794943043.500|Wuber Rocks|ride|VKNhsP;arrived;from=portal;dt=2.0;tot=16.0;drv=Anita Lift;dest=Ratchet;price=50000;fake=no", -- [82]
				"1794943043.500|Wuber Rocks|check|r_arrived;auto;by=ride_arrived;took=2.0;Arrived", -- [83]
				"1794943043.500|Wuber Rocks|plan|s3_r6;auto;by=ride_arrived;who=Wuber Rocks;src=local", -- [84]
				"1794943043.500|Wuber Rocks|ui|toast [found] You've arrived in Ratchet", -- [85]
				"1794943043.500|Wuber Rocks|ev|PLAYER_ENTERING_WORLD login=false reload=false", -- [86]
				"1794943043.500|Wuber Rocks|ev|ZONE_CHANGED_NEW_AREA zone=The Barrens sub=Ratchet", -- [87]
				"1794943043.500|Wuber Rocks|probe|summon box 1s after AcceptSummon: visible=false", -- [88]
				"1794943043.800|Wuber Rocks|fx|Fullscreen arrival played", -- [89]
				"1794943043.800|Wuber Rocks|plan|s3_c3;auto;by=ride_arrived+fx_arrival;who=Wuber Rocks;src=local", -- [90]
				"1794943044.100|Wuber Rocks|msg<|S W<Anita Lift S~1~VKNhsP~arrived", -- [91]
				"1794943047.000|Wuber Rocks|ride|VKNhsP;paying;from=arrived;dt=3.5;tot=19.5;drv=Anita Lift;dest=Ratchet;price=50000;fake=no", -- [92]
				"1794943047.000|Wuber Rocks|ui|toast [info] Trade Anita 5g", -- [93]
				"1794943047.000|Wuber Rocks|ev|TRADE_SHOW with=Anita Lift trade=hidden my=0 their=0", -- [94]
				"1794943048.500|Wuber Rocks|ev|TRADE_ACCEPT_UPDATE me=1 them=0 trade=hidden my=50000 their=0", -- [95]
				"1794943048.500|Wuber Rocks|ev|TRADE_ACCEPT_UPDATE me=1 them=1 trade=hidden my=50000 their=0", -- [96]
				"1794943048.500|Wuber Rocks|fire|MILESTONE main=first ids=first", -- [97]
				"1794943048.500|Wuber Rocks|ui|milestone pop first", -- [98]
				"1794943048.500|Wuber Rocks|check|r_milestone;auto;by=milestone_pop;took=5.0;Milestone pop", -- [99]
				"1794943048.500|Wuber Rocks|ride|VKNhsP;done;from=paying;dt=1.5;tot=21.0;drv=Anita Lift;dest=Ratchet;price=50000;fake=no", -- [100]
				"1794943048.500|Wuber Rocks|check|r_pay;auto;by=pay_done;took=5.0;Fare paid, trade done", -- [101]
				"1794943048.500|Wuber Rocks|plan|s3_c4;auto;by=pay_exact;who=Wuber Rocks;src=local", -- [102]
				"1794943048.500|Wuber Rocks|ridef|VKNhsP;paid=50000", -- [103]
				"1794943048.500|Wuber Rocks|ev|PLAYER_MONEY -50000 now=50000 (trade open)", -- [104]
				"1794943048.500|Wuber Rocks|ev|TRADE_CLOSED", -- [105]
				"1794943048.900|Wuber Rocks|msg<|S W<Anita Lift S~1~VKNhsP~paid", -- [106]
				"1794943048.999|Wuber Rocks|msg<|D C<Anita Lift D~1~Ratchet~1413~627~370~50000~Ritual Rides~open~3~6~H~1.1.0~~0", -- [107]
				"1794943049.599|Wuber Rocks|plan|s3_c7;auto;by=rr_logride;who=Anita Lift;src=sync", -- [108]
				"1794943051.499|Wuber Rocks|ev|GROUP_ROSTER_UPDATE members=0 ", -- [109]
				"1794943051.499|Wuber Rocks|probe|C_PartyInfo.LeaveParty() called combat=false", -- [110]
				"1794943051.499|Wuber Rocks|try|cap=leave ok=true result=nil combat=false", -- [111]
				"1794943051.499|Wuber Rocks|check|r_left;auto;by=auto_left;took=3.0;Left the group by itself", -- [112]
				"1794943051.499|Wuber Rocks|plan|s3_c5;auto;by=auto_left;who=Wuber Rocks;src=local", -- [113]
				"1794943051.499|Wuber Rocks|ridef|VKNhsP;autoLeft=true", -- [114]
				"1794943053.499|Wuber Rocks|msg>|T W>Anita Lift T~1~VKNhsP~5", -- [115]
				"1794943053.499|Wuber Rocks|ridef|VKNhsP;rated=true", -- [116]
				"1794943053.499|Wuber Rocks|check|r_rated;auto;by=rated;took=2.0;Rating sent", -- [117]
				"1794943053.499|Wuber Rocks|plan|s3_r8;auto;by=auto_left+rated+milestone_pop;who=Wuber Rocks;src=local", -- [118]
				"1794943053.499|Wuber Rocks|plan|s3_c6;auto;by=milestone_pop+rated;who=Wuber Rocks;src=local", -- [119]
				"1794943053.499|Wuber Rocks|ridef|VKNhsP;stars=5", -- [120]
				"1794943053.499|Wuber Rocks|ui|Rate 5 sent=true", -- [121]
				"1794943053.999|Wuber Rocks|msg<|D C<Anita Lift D~1~Ratchet~1413~627~370~50000~Ritual Rides~open~3~7~H~1.1.0~~0", -- [122]
				"1794943054.099|Wuber Rocks|plan|s5_6;auto;by=fx_paid+fx_coins;who=Anita Lift;src=sync", -- [123]
				"1794943062.000|Wuber Rocks|perf|fps=60.0 wuberKB=? labKB=?", -- [124]
				"1794943119.500|Wuber Rocks|plan|s5_1;fail;by=hand;who=Wuber Rocks;src=local", -- [125]
				"1794943119.500|Wuber Rocks|plan|s5_1;fail;by=hand;who=Wuber Rocks;src=local;note=crown too small", -- [126]
				"1794943122.000|Wuber Rocks|perf|fps=60.0 wuberKB=? labKB=?", -- [127]
				"1794943139.500|Wuber Rocks|check|r_crown;fail;took=-;Crown over the team's heads", -- [128]
				"1794943139.500|Wuber Rocks|check|r_crown;note;crown sits inside the cow", -- [129]
				"1794943139.500|Wuber Rocks|mark|ride one done", -- [130]
				"1794943139.500|Wuber Rocks|block|W BLOCKED cap=trade func=AcceptTrade()", -- [131]
				"1794943139.500|Wuber Rocks|block|ADDON_ACTION_BLOCKED addon=Wuber func=AcceptTrade() combat=false", -- [132]
			},
			["marks"] = 1,
			["realm"] = "Forever",
			["role"] = "rider",
			["selftest"] = {
				["at"] = 1794943010,
				["list"] = {
					{
						["name"] = "Pictures",
						["ok"] = true,
					}, -- [1]
					{
						["name"] = "Fonts",
						["ok"] = true,
					}, -- [2]
					{
						["name"] = "Animations",
						["ok"] = true,
					}, -- [3]
					{
						["name"] = "Your position on the map",
						["ok"] = true,
					}, -- [4]
					{
						["name"] = "Distances (time saved, map pins)",
						["ok"] = true,
					}, -- [5]
					{
						["name"] = "Wuber network",
						["ok"] = true,
					}, -- [6]
					{
						["name"] = "Network channel joined",
						["ok"] = true,
					}, -- [7]
					{
						["name"] = "Invites and groups",
						["ok"] = true,
					}, -- [8]
					{
						["name"] = "Summons",
						["ok"] = true,
					}, -- [9]
					{
						["name"] = "Money and where you are",
						["ok"] = true,
					}, -- [10]
					{
						["name"] = "Request buttons",
						["ok"] = true,
					}, -- [11]
					{
						["name"] = "Accept the driver's invite for you",
						["ok"] = true,
					}, -- [12]
					{
						["name"] = "Pay with one click",
						["ok"] = true,
					}, -- [13]
					{
						["name"] = "Leave the group after the ride",
						["ok"] = true,
					}, -- [14]
					{
						["name"] = "Crowns over heads (nameplates)",
						["ok"] = true,
					}, -- [15]
				},
				["source"] = "login",
			},
			["sessions"] = 1,
			["steps"] = {
				{
					["id"] = "r_open",
					["sec"] = "Basics",
					["text"] = "App opens",
				}, -- [1]
				{
					["id"] = "r_check",
					["sec"] = "Basics",
					["text"] = "Check my game runs",
				}, -- [2]
				{
					["id"] = "r_tips",
					["sec"] = "Basics",
					["text"] = "Tooltips show (3 different)",
				}, -- [3]
				{
					["id"] = "r_slider",
					["sec"] = "Basics",
					["text"] = "A slider works",
				}, -- [4]
				{
					["id"] = "r_minimap",
					["sec"] = "Basics",
					["text"] = "Minimap button works",
				}, -- [5]
				{
					["id"] = "r_booked",
					["sec"] = "Ride",
					["text"] = "Booked a ride",
				}, -- [6]
				{
					["id"] = "r_whisper",
					["sec"] = "Ride",
					["text"] = "Visible WTB whisper sent",
				}, -- [7]
				{
					["id"] = "r_accepted",
					["sec"] = "Ride",
					["text"] = "Driver accepted",
				}, -- [8]
				{
					["id"] = "r_queue",
					["sec"] = "Ride",
					["text"] = "Queue position shown",
				}, -- [9]
				{
					["id"] = "r_invite",
					["sec"] = "Ride",
					["text"] = "Invite auto-accepted (no click)",
				}, -- [10]
				{
					["id"] = "r_summon",
					["sec"] = "Ride",
					["text"] = "Summon popup / portal",
				}, -- [11]
				{
					["id"] = "r_arrived",
					["sec"] = "Ride",
					["text"] = "Arrived",
				}, -- [12]
				{
					["id"] = "r_payclick",
					["sec"] = "Ride",
					["text"] = "Pay button used",
				}, -- [13]
				{
					["id"] = "r_pay",
					["sec"] = "Ride",
					["text"] = "Fare paid, trade done",
				}, -- [14]
				{
					["id"] = "r_left",
					["sec"] = "Ride",
					["text"] = "Left the group by itself",
				}, -- [15]
				{
					["id"] = "r_rated",
					["sec"] = "Ride",
					["text"] = "Rating sent",
				}, -- [16]
				{
					["id"] = "r_milestone",
					["sec"] = "Ride",
					["text"] = "Milestone pop",
				}, -- [17]
				{
					["id"] = "r_cancel",
					["sec"] = "Edge",
					["text"] = "Cancel before accept",
				}, -- [18]
				{
					["id"] = "r_busy",
					["sec"] = "Edge",
					["text"] = "Book a busy driver -> queue",
				}, -- [19]
				{
					["id"] = "r_combat",
					["sec"] = "Edge",
					["text"] = "Request in combat",
				}, -- [20]
				{
					["id"] = "r_mapctrl",
					["sec"] = "Edge",
					["text"] = "Map: Ctrl-click a place",
				}, -- [21]
				{
					["id"] = "r_mapbtn",
					["sec"] = "Edge",
					["text"] = "Map: Ride here button",
				}, -- [22]
				{
					["id"] = "r_hide",
					["sec"] = "Edge",
					["text"] = "Hide a driver",
				}, -- [23]
				{
					["id"] = "r_fav",
					["sec"] = "Edge",
					["text"] = "Favourite online toast",
				}, -- [24]
				{
					["id"] = "r_decline",
					["sec"] = "Edge",
					["text"] = "Declined -> try another",
				}, -- [25]
				{
					["id"] = "r_timeout",
					["sec"] = "Edge",
					["text"] = "No answer -> timed out",
				}, -- [26]
				{
					["id"] = "r_spam",
					["sec"] = "Edge",
					["text"] = "Spammy service name hidden",
				}, -- [27]
				{
					["id"] = "r_crown",
					["manual"] = true,
					["sec"] = "Looks",
					["text"] = "Crown over the team's heads",
				}, -- [28]
				{
					["id"] = "r_badges",
					["manual"] = true,
					["sec"] = "Looks",
					["text"] = "Badges on cards, pins, heads",
				}, -- [29]
				{
					["id"] = "r_fx",
					["manual"] = true,
					["sec"] = "Looks",
					["text"] = "Effects play well",
				}, -- [30]
				{
					["id"] = "r_glow",
					["manual"] = true,
					["sec"] = "Looks",
					["text"] = "Founder card glows brightest",
				}, -- [31]
				{
					["id"] = "r_sort",
					["manual"] = true,
					["sec"] = "Looks",
					["text"] = "Sorting: open first, cheapest",
				}, -- [32]
			},
			["versions"] = {
				["lab"] = "1.0.0",
				["rr"] = "1.4.0",
				["wuber"] = "1.0.0",
			},
		},
	},
	["plan"] = {
		["s0_1"] = {
			["at"] = 1794943012.6,
			["by"] = "probe",
			["r"] = "auto",
			["who"] = "Anita Lift",
		},
		["s0_1@anita lift"] = {
			["at"] = 1794943010,
			["by"] = "probe:fresh",
			["r"] = "ok",
			["who"] = "Anita Lift",
		},
		["s0_1@farra way"] = {
			["at"] = 1794943010,
			["by"] = "probe:fresh",
			["r"] = "ok",
			["who"] = "Farra Way",
		},
		["s0_1@hayley cab"] = {
			["at"] = 1794943010,
			["by"] = "probe:fresh",
			["r"] = "ok",
			["who"] = "Hayley Cab",
		},
		["s0_1@wuber rocks"] = {
			["at"] = 1794943012,
			["by"] = "probe:fresh",
			["r"] = "ok",
			["who"] = "Wuber Rocks",
		},
		["s0_2@anita lift"] = {
			["at"] = 1794943010,
			["by"] = "probe:addons",
			["r"] = "ok",
			["who"] = "Anita Lift",
		},
		["s0_2@farra way"] = {
			["at"] = 1794943010,
			["by"] = "probe:addons",
			["r"] = "ok",
			["who"] = "Farra Way",
		},
		["s0_2@hayley cab"] = {
			["at"] = 1794943010,
			["by"] = "probe:addons",
			["r"] = "ok",
			["who"] = "Hayley Cab",
		},
		["s0_2@wuber rocks"] = {
			["at"] = 1794943012,
			["by"] = "probe:addons",
			["r"] = "no",
			["who"] = "Wuber Rocks",
		},
		["s1_1"] = {
			["at"] = 1794943012.6,
			["by"] = "probe",
			["r"] = "auto",
			["who"] = "Anita Lift",
		},
		["s1_1@anita lift"] = {
			["at"] = 1794943010,
			["by"] = "probe:fresh",
			["r"] = "ok",
			["who"] = "Anita Lift",
		},
		["s1_1@farra way"] = {
			["at"] = 1794943010,
			["by"] = "probe:fresh",
			["r"] = "ok",
			["who"] = "Farra Way",
		},
		["s1_1@hayley cab"] = {
			["at"] = 1794943010,
			["by"] = "probe:fresh",
			["r"] = "ok",
			["who"] = "Hayley Cab",
		},
		["s1_1@wuber rocks"] = {
			["at"] = 1794943012,
			["by"] = "probe:fresh",
			["r"] = "ok",
			["who"] = "Wuber Rocks",
		},
		["s2_1"] = {
			["at"] = 1794943025,
			["by"] = "app_open",
			["r"] = "auto",
			["who"] = "Wuber Rocks",
		},
		["s3_c1"] = {
			["at"] = 1794943027.5,
			["by"] = "whisper_wtb_in",
			["r"] = "auto",
			["who"] = "Anita Lift",
		},
		["s3_c2"] = {
			["at"] = 1794943027.6,
			["by"] = "auto_accept",
			["r"] = "auto",
			["who"] = "Wuber Rocks",
		},
		["s3_c3"] = {
			["at"] = 1794943043.8,
			["by"] = "ride_arrived+fx_arrival",
			["r"] = "auto",
			["who"] = "Wuber Rocks",
		},
		["s3_c4"] = {
			["at"] = 1794943048.5,
			["by"] = "pay_exact",
			["r"] = "auto",
			["who"] = "Wuber Rocks",
		},
		["s3_c5"] = {
			["at"] = 1794943051.499,
			["by"] = "auto_left",
			["r"] = "auto",
			["who"] = "Wuber Rocks",
		},
		["s3_c6"] = {
			["at"] = 1794943053.499,
			["by"] = "milestone_pop+rated",
			["r"] = "auto",
			["who"] = "Wuber Rocks",
		},
		["s3_c7"] = {
			["at"] = 1794943048.8,
			["by"] = "rr_logride",
			["r"] = "auto",
			["who"] = "Anita Lift",
		},
		["s3_d1"] = {
			["at"] = 1794943002.1,
			["by"] = "beacon_open",
			["r"] = "auto",
			["who"] = "Anita Lift",
		},
		["s3_r2"] = {
			["at"] = 1794943025,
			["by"] = "confirm_shown",
			["r"] = "auto",
			["who"] = "Wuber Rocks",
		},
		["s3_r3"] = {
			["at"] = 1794943027.5,
			["by"] = "whisper_wtb",
			["r"] = "auto",
			["who"] = "Wuber Rocks",
		},
		["s3_r4"] = {
			["at"] = 1794943027.7,
			["by"] = "accept_msg",
			["r"] = "auto",
			["who"] = "Wuber Rocks",
		},
		["s3_r5"] = {
			["at"] = 1794943027.6,
			["by"] = "auto_accept",
			["r"] = "auto",
			["who"] = "Wuber Rocks",
		},
		["s3_r6"] = {
			["at"] = 1794943043.5,
			["by"] = "ride_arrived",
			["r"] = "auto",
			["who"] = "Wuber Rocks",
		},
		["s3_r8"] = {
			["at"] = 1794943053.499,
			["by"] = "auto_left+rated+milestone_pop",
			["r"] = "auto",
			["who"] = "Wuber Rocks",
		},
		["s5_1"] = {
			["at"] = 1794943119.501,
			["by"] = "hand",
			["note"] = "crown too small",
			["r"] = "fail",
			["who"] = "Wuber Rocks",
		},
		["s5_6"] = {
			["at"] = 1794943053.599,
			["by"] = "fx_paid+fx_coins",
			["r"] = "auto",
			["who"] = "Anita Lift",
		},
	},
	["planSteps"] = {
		{
			["auto"] = true,
			["id"] = "s0_1",
			["sec"] = "Before you start",
			["text"] = "Close all WoW clients.",
			["who"] = "all four",
		}, -- [1]
		{
			["auto"] = true,
			["id"] = "s0_2",
			["sec"] = "Before you start",
			["text"] = "At the character screen on each account, open AddOns and set: Wuber ticked on all four; Ritual Rides ticked on Anita, Farra and Hayley, and left ticked on Wuber Rocks too (needed for the bell); Wuber Test unticked everywhere; Wuber Lab ticked on all four; OpenMap ticked if you use it.",
			["who"] = "all four",
		}, -- [2]
		{
			["auto"] = true,
			["id"] = "s0_3",
			["sec"] = "Before you start",
			["text"] = "Turn on System > Sound > Sound in Background on Wuber Rocks, so you hear the bell while Anita's window is in front.",
			["who"] = "Wuber Rocks",
		}, -- [3]
		{
			["auto"] = true,
			["id"] = "s0_4",
			["sec"] = "Before you start",
			["text"] = "Unbind F1 in Key Bindings on all four accounts, so the swap key does nothing inside WoW.",
			["who"] = "all four",
		}, -- [4]
		{
			["auto"] = true,
			["id"] = "s1_1",
			["sec"] = "Windows: three locks, Wuber Rocks on top, F1 to swap",
			["text"] = "In PowerShell: cd <the Lab scripts folder> then .\\start4.ps1. It opens the three Warlocks, then a fourth window exactly over Anita's, then the F1 swap key in a minimised window. Log in all four.",
			["who"] = "PC",
		}, -- [5]
		{
			["id"] = "s1_2",
			["sec"] = "Windows: three locks, Wuber Rocks on top, F1 to swap",
			["text"] = "Your three windows didn't move or shrink, and Wuber Rocks sits exactly over Anita.",
			["who"] = "PC",
		}, -- [6]
		{
			["id"] = "s1_3",
			["sec"] = "Windows: three locks, Wuber Rocks on top, F1 to swap",
			["text"] = "Press F1 to flip between Wuber Rocks and Anita, and again to flip back.",
			["who"] = "PC",
		}, -- [7]
		{
			["auto"] = {
				"bell_rang", -- [1]
			},
			["id"] = "s1_4",
			["sec"] = "Windows: three locks, Wuber Rocks on top, F1 to swap",
			["text"] = "On Wuber Rocks type /rr bell Wuber Rocks. On Anita type /rr bell test. Wuber Rocks should show a banner, ring and flash its taskbar icon.",
			["who"] = "Wuber Rocks + Anita",
		}, -- [8]
		{
			["check"] = true,
			["id"] = "s1_c1",
			["sec"] = "Windows: three locks, Wuber Rocks on top, F1 to swap",
			["text"] = "Wuber Rocks sits exactly over Anita",
			["who"] = "PC",
		}, -- [9]
		{
			["check"] = true,
			["id"] = "s1_c2",
			["sec"] = "Windows: three locks, Wuber Rocks on top, F1 to swap",
			["text"] = "The other two windows didn't move",
			["who"] = "PC",
		}, -- [10]
		{
			["check"] = true,
			["id"] = "s1_c3",
			["sec"] = "Windows: three locks, Wuber Rocks on top, F1 to swap",
			["text"] = "F1 swaps both ways",
			["who"] = "PC",
		}, -- [11]
		{
			["auto"] = {
				"bell_rang", -- [1]
			},
			["check"] = true,
			["id"] = "s1_c4",
			["sec"] = "Windows: three locks, Wuber Rocks on top, F1 to swap",
			["text"] = "The bell rings on Wuber Rocks",
			["who"] = "Wuber Rocks",
		}, -- [12]
		{
			["auto"] = {
				"app_open", -- [1]
			},
			["id"] = "s2_1",
			["sec"] = "Test 1: the app on Wuber Rocks (5 minutes)",
			["text"] = "Type /wuber. The app opens on Home with the logo top left and Ride, Trips and Drive tabs.",
			["who"] = "Wuber Rocks",
		}, -- [13]
		{
			["auto"] = {
				"selftest_ui", -- [1]
			},
			["id"] = "s2_2",
			["sec"] = "Test 1: the app on Wuber Rocks (5 minutes)",
			["text"] = "Click the gear, scroll to the bottom and click Check my game. Take a screenshot of the results.",
			["who"] = "Wuber Rocks",
		}, -- [14]
		{
			["auto"] = {
				"tip", -- [1]
			},
			["id"] = "s2_3",
			["sec"] = "Test 1: the app on Wuber Rocks (5 minutes)",
			["text"] = "In Settings, hover over a few options. Each should show a tooltip.",
			["who"] = "Wuber Rocks",
		}, -- [15]
		{
			["auto"] = {
				"slider", -- [1]
			},
			["id"] = "s2_4",
			["sec"] = "Test 1: the app on Wuber Rocks (5 minutes)",
			["text"] = "Drag the \"My time is worth\" slider and the window size slider. If they won't drag, try the mouse wheel.",
			["who"] = "Wuber Rocks",
		}, -- [16]
		{
			["auto"] = {
				"trips_tab", -- [1]
			},
			["id"] = "s2_5",
			["sec"] = "Test 1: the app on Wuber Rocks (5 minutes)",
			["text"] = "Open Trips: level, stats tiles and the milestone grid, all locked for now.",
			["who"] = "Wuber Rocks",
		}, -- [17]
		{
			["auto"] = {
				"minimap", -- [1]
			},
			["id"] = "s2_6",
			["sec"] = "Test 1: the app on Wuber Rocks (5 minutes)",
			["text"] = "Close the app and open it from the minimap button.",
			["who"] = "Wuber Rocks",
		}, -- [18]
		{
			["check"] = true,
			["id"] = "s2_c1",
			["sec"] = "Test 1: the app on Wuber Rocks (5 minutes)",
			["text"] = "No red Lua errors on login or opening the app",
			["who"] = "Wuber Rocks",
		}, -- [19]
		{
			["check"] = true,
			["id"] = "s2_c2",
			["sec"] = "Test 1: the app on Wuber Rocks (5 minutes)",
			["text"] = "Check my game screenshot taken",
			["who"] = "Wuber Rocks",
		}, -- [20]
		{
			["auto"] = {
				"tip", -- [1]
			},
			["check"] = true,
			["id"] = "s2_c3",
			["sec"] = "Test 1: the app on Wuber Rocks (5 minutes)",
			["text"] = "Tooltips show",
			["who"] = "Wuber Rocks",
		}, -- [21]
		{
			["auto"] = {
				"slider", -- [1]
			},
			["check"] = true,
			["id"] = "s2_c4",
			["sec"] = "Test 1: the app on Wuber Rocks (5 minutes)",
			["text"] = "Sliders drag (or only the wheel works)",
			["who"] = "Wuber Rocks",
		}, -- [22]
		{
			["auto"] = {
				"minimap", -- [1]
			},
			["check"] = true,
			["id"] = "s2_c5",
			["sec"] = "Test 1: the app on Wuber Rocks (5 minutes)",
			["text"] = "Minimap button opens the app",
			["who"] = "Wuber Rocks",
		}, -- [23]
		{
			["auto"] = {
				"beacon_open", -- [1]
			},
			["id"] = "s3_d1",
			["sec"] = "Test 2: a full ride, Wuber Rocks to your team",
			["text"] = "/rr price 50s (or your normal price, at least 50s) and /rr on. Don't type /rr on on Wuber Rocks.",
			["who"] = "Anita",
		}, -- [24]
		{
			["id"] = "s3_d2",
			["sec"] = "Test 2: a full ride, Wuber Rocks to your team",
			["text"] = "Team grouped with Anita as leader, or ungrouped with Anita as main caster.",
			["who"] = "Anita",
		}, -- [25]
		{
			["id"] = "s3_r1",
			["sec"] = "Test 2: a full ride, Wuber Rocks to your team",
			["text"] = "/wuber. Anita's card is at the top with the crown, Founder chip and the strongest glow.",
			["who"] = "Wuber Rocks",
		}, -- [26]
		{
			["auto"] = {
				"confirm_shown", -- [1]
				"ride_requesting", -- [2]
			},
			["id"] = "s3_r2",
			["sec"] = "Test 2: a full ride, Wuber Rocks to your team",
			["text"] = "Click Anita's card. The confirm screen shows price, destination and time saved.",
			["who"] = "Wuber Rocks",
		}, -- [27]
		{
			["auto"] = {
				"whisper_wtb", -- [1]
				"whisper_wtb_in", -- [2]
			},
			["id"] = "s3_r3",
			["sec"] = "Test 2: a full ride, Wuber Rocks to your team",
			["text"] = "Click Request. Wuber Rocks whispers Anita \"WTB summon to (place) for 50s\". Check Anita's chat.",
			["who"] = "Wuber Rocks",
		}, -- [28]
		{
			["auto"] = {
				"accept_msg", -- [1]
				"ride_accepted", -- [2]
			},
			["id"] = "s3_r4",
			["sec"] = "Test 2: a full ride, Wuber Rocks to your team",
			["text"] = "Anita's side accepts. Wuber Rocks shows Accepted and your place in line with a countdown.",
			["who"] = "Wuber Rocks",
		}, -- [29]
		{
			["auto"] = {
				"auto_accept", -- [1]
			},
			["id"] = "s3_r5",
			["sec"] = "Test 2: a full ride, Wuber Rocks to your team",
			["text"] = "The invite arrives and is accepted with no click, then the bell rings on Wuber Rocks.",
			["who"] = "Wuber Rocks",
		}, -- [30]
		{
			["auto"] = {
				"ride_arrived", -- [1]
			},
			["id"] = "s3_r6",
			["sec"] = "Test 2: a full ride, Wuber Rocks to your team",
			["text"] = "The team summons. Accept the summon box. The portal effect plays, then the arrival scene.",
			["who"] = "Wuber Rocks",
		}, -- [31]
		{
			["auto"] = {
				"pay_clicked", -- [1]
				"pay_exact", -- [2]
			},
			["id"] = "s3_r7",
			["sec"] = "Test 2: a full ride, Wuber Rocks to your team",
			["text"] = "A trade opens from the cashier. Click Pay 50s in Wuber: exactly the fare, and it accepts.",
			["who"] = "Wuber Rocks",
		}, -- [32]
		{
			["auto"] = {
				"auto_left", -- [1]
				"rated", -- [2]
				"milestone_pop", -- [3]
			},
			["id"] = "s3_r8",
			["sec"] = "Test 2: a full ride, Wuber Rocks to your team",
			["text"] = "A few seconds after paying, Wuber Rocks leaves the group by itself. Rate the ride. First Ride milestone pops.",
			["who"] = "Wuber Rocks",
		}, -- [33]
		{
			["auto"] = {
				"whisper_wtb_in", -- [1]
			},
			["check"] = true,
			["id"] = "s3_c1",
			["sec"] = "Test 2: a full ride, Wuber Rocks to your team",
			["text"] = "Visible WTB whisper reached Anita",
			["who"] = "Anita",
		}, -- [34]
		{
			["auto"] = {
				"auto_accept", -- [1]
			},
			["check"] = true,
			["id"] = "s3_c2",
			["sec"] = "Test 2: a full ride, Wuber Rocks to your team",
			["text"] = "Invite accepted with no click",
			["who"] = "Wuber Rocks",
		}, -- [35]
		{
			["auto"] = {
				"ride_arrived", -- [1]
				"fx_arrival", -- [2]
			},
			["check"] = true,
			["id"] = "s3_c3",
			["sec"] = "Test 2: a full ride, Wuber Rocks to your team",
			["text"] = "Summon arrived and the effects played",
			["who"] = "Wuber Rocks",
		}, -- [36]
		{
			["auto"] = {
				"pay_exact", -- [1]
			},
			["check"] = true,
			["id"] = "s3_c4",
			["sec"] = "Test 2: a full ride, Wuber Rocks to your team",
			["text"] = "Pay put in exactly the fare",
			["who"] = "Wuber Rocks",
		}, -- [37]
		{
			["auto"] = {
				"auto_left", -- [1]
			},
			["check"] = true,
			["id"] = "s3_c5",
			["sec"] = "Test 2: a full ride, Wuber Rocks to your team",
			["text"] = "Left the group by itself",
			["who"] = "Wuber Rocks",
		}, -- [38]
		{
			["auto"] = {
				"milestone_pop", -- [1]
				"rated", -- [2]
			},
			["check"] = true,
			["id"] = "s3_c6",
			["sec"] = "Test 2: a full ride, Wuber Rocks to your team",
			["text"] = "Milestone pop and rating worked",
			["who"] = "Wuber Rocks",
		}, -- [39]
		{
			["auto"] = {
				"rr_logride", -- [1]
			},
			["check"] = true,
			["id"] = "s3_c7",
			["sec"] = "Test 2: a full ride, Wuber Rocks to your team",
			["text"] = "Ritual Rides logged the ride (/rr log on Anita)",
			["who"] = "Anita",
		}, -- [40]
		{
			["id"] = "s4_1",
			["sec"] = "Test 3: shortcuts and things going wrong",
			["text"] = "Rebook: open /wuber after Test 2 -> a \"Your usual\" card with Ride again at the top of Home.",
			["who"] = "Wuber Rocks",
		}, -- [41]
		{
			["auto"] = {
				"cancel_early", -- [1]
			},
			["id"] = "s4_2",
			["sec"] = "Test 3: shortcuts and things going wrong",
			["text"] = "Cancel: Request, then Cancel ride before Anita accepts -> cancelled on both sides, no invite.",
			["who"] = "Wuber Rocks + Anita",
		}, -- [42]
		{
			["auto"] = {
				"busy_queue", -- [1]
			},
			["id"] = "s4_3",
			["sec"] = "Test 3: shortcuts and things going wrong",
			["text"] = "Driver busy: Lab Tools > Fake drivers, book the busy one -> you can book and see your place in the queue.",
			["who"] = "Wuber Rocks",
		}, -- [43]
		{
			["auto"] = {
				"combat_request", -- [1]
			},
			["id"] = "s4_4",
			["sec"] = "Test 3: shortcuts and things going wrong",
			["text"] = "Combat: Request while fighting a mob -> Wuber waits or tells you to finish the fight; no Lua error.",
			["who"] = "Wuber Rocks",
		}, -- [44]
		{
			["auto"] = {
				"map_ctrl", -- [1]
				"map_button", -- [2]
			},
			["id"] = "s4_5",
			["sec"] = "Test 3: shortcuts and things going wrong",
			["text"] = "Book from map: world map, hover the team's town, Ctrl-click (and try the Ride here button) -> booking screen for that place.",
			["who"] = "Wuber Rocks",
		}, -- [45]
		{
			["auto"] = {
				"driver_offline", -- [1]
			},
			["id"] = "s4_6",
			["sec"] = "Test 3: shortcuts and things going wrong",
			["text"] = "Driver offline: Request, then log Anita out -> Wuber Rocks says the driver went offline and lets you pick again.",
			["who"] = "Wuber Rocks + Anita",
		}, -- [46]
		{
			["auto"] = {
				"rr_lowfare", -- [1]
			},
			["id"] = "s4_7",
			["sec"] = "Test 3: shortcuts and things going wrong",
			["text"] = "Price below 50s: on Anita /rr price 30s -> Anita disappears from Wuber with a message to set 50s. Set it back.",
			["who"] = "Anita",
		}, -- [47]
		{
			["auto"] = {
				"hidden", -- [1]
			},
			["id"] = "s4_8",
			["sec"] = "Test 3: shortcuts and things going wrong",
			["text"] = "Hide a driver: right-click a card, Hide -> the card goes; Settings > Hidden drivers brings it back.",
			["who"] = "Wuber Rocks",
		}, -- [48]
		{
			["auto"] = {
				"fav_toast", -- [1]
			},
			["id"] = "s4_9",
			["sec"] = "Test 3: shortcuts and things going wrong",
			["text"] = "Favourite: heart on Anita's card, log Anita out and back in -> a toast on Wuber Rocks: Anita is online.",
			["who"] = "Wuber Rocks + Anita",
		}, -- [49]
		{
			["id"] = "s5_1",
			["sec"] = "Test 4: looks and fun (judged by eye)",
			["text"] = "On Wuber Rocks, Settings > Turn on friendly nameplates. Near the team: a spinning gold crown over Anita, Farra and Hayley.",
			["who"] = "Wuber Rocks",
		}, -- [50]
		{
			["id"] = "s5_2",
			["sec"] = "Test 4: looks and fun (judged by eye)",
			["text"] = "Mouse over Anita: tooltip says \"Wuber founder\".",
			["who"] = "Wuber Rocks",
		}, -- [51]
		{
			["id"] = "s5_3",
			["sec"] = "Test 4: looks and fun (judged by eye)",
			["text"] = "Anita's card on Home: gold-violet border, crown, Founder chip, shimmer every few seconds.",
			["who"] = "Wuber Rocks",
		}, -- [52]
		{
			["id"] = "s5_4",
			["sec"] = "Test 4: looks and fun (judged by eye)",
			["text"] = "World map: Anita's pin bigger, crowned, sparkling; dotted route line flowing to it during a ride.",
			["who"] = "Wuber Rocks",
		}, -- [53]
		{
			["id"] = "s5_5",
			["sec"] = "Test 4: looks and fun (judged by eye)",
			["text"] = "Settings > Effects: try Full, Light and Off during a ride.",
			["who"] = "Wuber Rocks",
		}, -- [54]
		{
			["auto"] = {
				"fx_paid", -- [1]
				"fx_coins", -- [2]
			},
			["id"] = "s5_6",
			["sec"] = "Test 4: looks and fun (judged by eye)",
			["text"] = "On Anita: a small burst when paid; a 5-star rating shows a coin shower.",
			["who"] = "Anita",
		}, -- [55]
		{
			["check"] = true,
			["id"] = "s5_c1",
			["sec"] = "Test 4: looks and fun (judged by eye)",
			["text"] = "Crowns over the team's heads",
			["who"] = "Wuber Rocks",
		}, -- [56]
		{
			["check"] = true,
			["id"] = "s5_c2",
			["sec"] = "Test 4: looks and fun (judged by eye)",
			["text"] = "Founder card shimmer and glow look right",
			["who"] = "Wuber Rocks",
		}, -- [57]
		{
			["check"] = true,
			["id"] = "s5_c3",
			["sec"] = "Test 4: looks and fun (judged by eye)",
			["text"] = "Map pin and route line",
			["who"] = "Wuber Rocks",
		}, -- [58]
		{
			["check"] = true,
			["id"] = "s5_c4",
			["sec"] = "Test 4: looks and fun (judged by eye)",
			["text"] = "Effects look good, not blocky or with dark edges",
			["who"] = "Wuber Rocks",
		}, -- [59]
		{
			["auto"] = true,
			["id"] = "s6_1",
			["sec"] = "When you're done",
			["text"] = "Log out of all four characters normally (not Alt-F4) so WoW saves the logs, then tell the person running the test \"done\".",
			["who"] = "all four",
		}, -- [60]
		{
			["id"] = "s6_2",
			["sec"] = "When you're done",
			["text"] = "Also send: the Check my game screenshot, screenshots of anything that looked wrong, any red Lua error text.",
			["who"] = "you",
		}, -- [61]
	},
	["v"] = 1,
}
