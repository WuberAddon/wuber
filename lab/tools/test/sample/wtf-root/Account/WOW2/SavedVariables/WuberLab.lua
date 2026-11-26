
WuberLabDB = {
	["chars"] = {
		["Hayley Cab"] = {
			["checks"] = {
				["t_provider"] = {
					["at"] = 1794943000,
					["by"] = "provider",
					["r"] = "auto",
					["sec"] = "Setup",
					["text"] = "Ritual Rides drives for Wuber",
				},
			},
			["dropped"] = 0,
			["lastLogin"] = 1794943000,
			["lines"] = {
				"1794943000.000|Hayley Cab|rr|says: Services only works in a capital city (or you have not joined it: /join services). Here the advert goes to LookingForGroup, and Trade when you are in a city.", -- [1]
				"1794943000.000|Hayley Cab|api|SetDriver Ritual Rides", -- [2]
				"1794943000.000|Hayley Cab|fire|PROVIDER Ritual Rides", -- [3]
				"1794943000.000|Hayley Cab|login|char=Hayley Cab realm=Forever role=team build=1.60.1/70938/Nov 12 2026/16001 lab=1.0.0 Wuber=1.0.0 RitualRides=1.4.0 OpenMap=off Moo=off !BugGrabber=off BugSack=off W.VERSION=1.1.0 RR.VERSION=1.4.1 channels=4 errhandler=replaced later buggrabber=no", -- [4]
				"1794943000.000|Hayley Cab|fire|provider at login: Ritual Rides", -- [5]
				"1794943000.000|Hayley Cab|check|t_provider;auto;by=provider;took=-;Ritual Rides drives for Wuber", -- [6]
				"1794943000.000|Hayley Cab|probe|channels=4 wuberIndex=nil (login)", -- [7]
				"1794943000.000|Hayley Cab|ev|PLAYER_ENTERING_WORLD login=true reload=false", -- [8]
				"1794943000.000|Hayley Cab|ev|ZONE_CHANGED_NEW_AREA zone=The Barrens sub=Ratchet", -- [9]
				"1794943000.000|Hayley Cab|ev|GROUP_ROSTER_UPDATE members=2 Anita Lift,Farra Way", -- [10]
				"1794943000.100|Hayley Cab|rr|says: heard Anita's Ritual Rides. With only your three Warlocks in the group, type /cffffd200/rr team/r in each window.", -- [11]
				"1794943001.000|Hayley Cab|prov|beacon off", -- [12]
				"1794943002.000|Hayley Cab|tool|test mode on (developer only). /lab opens the test plan. Role: team", -- [13]
				"1794943003.000|Hayley Cab|probe|font Poppins SetFont ok=true returned=true GetFont=Interface\\AddOns\\Wuber\\Media\\fonts\\Poppins-Regular.ttf T.poppins=true", -- [14]
				"1794943003.100|Hayley Cab|plan|s3_d1;auto;by=beacon_open;who=Anita Lift;src=sync", -- [15]
				"1794943006.000|Hayley Cab|probe|JoinTemporaryChannel(WuberNet) called combat=false", -- [16]
				"1794943006.000|Hayley Cab|probe|CheckChannel(true) -> false index=nil channels=4 fails=nil", -- [17]
				"1794943006.500|Hayley Cab|fire|NETWORK true", -- [18]
				"1794943006.500|Hayley Cab|msg>|Q C>5 Q~1", -- [19]
				"1794943006.500|Hayley Cab|ui|Ping ok=true nil", -- [20]
				"1794943006.500|Hayley Cab|probe|CheckChannel(false) -> true index=5 channels=5 fails=nil", -- [21]
				"1794943006.500|Hayley Cab|probe|channels=5 wuberIndex=5 (CHANNEL_UI_UPDATE)", -- [22]
				"1794943006.600|Hayley Cab|msg<|Q C<Anita Lift Q~1", -- [23]
				"1794943006.600|Hayley Cab|fire|DRIVERS n=1 anita lift", -- [24]
				"1794943006.600|Hayley Cab|msg<|D C<Anita Lift D~1~Ratchet~1413~627~370~50000~Ritual Rides~open~3~7~H~1.1.0~~0", -- [25]
				"1794943006.600|Hayley Cab|msg<|Q C<Farra Way Q~1", -- [26]
				"1794943006.600|Hayley Cab|msg<|Q C<Hayley Cab Q~1", -- [27]
				"1794943008.000|Hayley Cab|self|[login] 15 of 15 passed", -- [28]
				"1794943008.600|Hayley Cab|msg<|Q C<Wuber Rocks Q~1", -- [29]
				"1794943010.000|Hayley Cab|plan|s0_1@hayley cab;ok;by=probe:fresh;who=Hayley Cab;src=local", -- [30]
				"1794943010.000|Hayley Cab|probe|plan s0_1 (fresh) on Hayley Cab: ok", -- [31]
				"1794943010.000|Hayley Cab|plan|s0_2@hayley cab;ok;by=probe:addons;who=Hayley Cab;src=local", -- [32]
				"1794943010.000|Hayley Cab|probe|plan s0_2 (addons) on Hayley Cab: ok", -- [33]
				"1794943010.000|Hayley Cab|plan|s1_1@hayley cab;ok;by=probe:fresh;who=Hayley Cab;src=local", -- [34]
				"1794943010.000|Hayley Cab|probe|plan s1_1 (fresh) on Hayley Cab: ok", -- [35]
				"1794943010.600|Hayley Cab|plan|s0_2@anita lift;ok;by=probe:addons;who=Anita Lift;src=sync", -- [36]
				"1794943010.600|Hayley Cab|plan|s0_1@anita lift;ok;by=probe:fresh;who=Anita Lift;src=sync", -- [37]
				"1794943010.600|Hayley Cab|plan|s1_1@anita lift;ok;by=probe:fresh;who=Anita Lift;src=sync", -- [38]
				"1794943012.100|Hayley Cab|plan|s1_1@farra way;ok;by=probe:fresh;who=Farra Way;src=sync", -- [39]
				"1794943012.100|Hayley Cab|plan|s0_2@farra way;ok;by=probe:addons;who=Farra Way;src=sync", -- [40]
				"1794943012.100|Hayley Cab|plan|s0_1@farra way;ok;by=probe:fresh;who=Farra Way;src=sync", -- [41]
				"1794943013.600|Hayley Cab|plan|s0_1;auto;by=probe;who=Anita Lift;src=sync", -- [42]
				"1794943013.600|Hayley Cab|plan|s1_1;auto;by=probe;who=Anita Lift;src=sync", -- [43]
				"1794943015.600|Hayley Cab|plan|s0_2@wuber rocks;no;by=probe:addons;who=Wuber Rocks;src=sync", -- [44]
				"1794943015.600|Hayley Cab|plan|s1_1@wuber rocks;ok;by=probe:fresh;who=Wuber Rocks;src=sync", -- [45]
				"1794943015.600|Hayley Cab|plan|s0_1@wuber rocks;ok;by=probe:fresh;who=Wuber Rocks;src=sync", -- [46]
				"1794943027.700|Hayley Cab|msg<|D C<Anita Lift D~1~Ratchet~1413~627~370~50000~Ritual Rides~busy~3~7~H~1.1.0~~0", -- [47]
				"1794943027.700|Hayley Cab|ev|GROUP_ROSTER_UPDATE members=3 Anita Lift,Farra Way,Wuber Rocks", -- [48]
				"1794943029.100|Hayley Cab|plan|s3_r5;auto;by=auto_accept;who=Wuber Rocks;src=sync", -- [49]
				"1794943029.100|Hayley Cab|plan|s3_r2;auto;by=confirm_shown;who=Wuber Rocks;src=sync", -- [50]
				"1794943029.100|Hayley Cab|plan|s3_c2;auto;by=auto_accept;who=Wuber Rocks;src=sync", -- [51]
				"1794943029.100|Hayley Cab|plan|s3_r3;auto;by=whisper_wtb;who=Wuber Rocks;src=sync", -- [52]
				"1794943031.600|Hayley Cab|plan|s3_c1;auto;by=whisper_wtb_in;who=Anita Lift;src=sync", -- [53]
				"1794943032.700|Hayley Cab|msg<|D C<Anita Lift D~1~Ratchet~1413~627~370~50000~Ritual Rides~busy~3~6~H~1.1.0~~0", -- [54]
				"1794943035.100|Hayley Cab|plan|s2_1;auto;by=app_open;who=Wuber Rocks;src=sync", -- [55]
				"1794943038.600|Hayley Cab|rr|customer Wuber Rocks joined>summoning", -- [56]
				"1794943039.600|Hayley Cab|plan|s3_r4;auto;by=accept_msg;who=Wuber Rocks;src=sync", -- [57]
				"1794943042.600|Hayley Cab|rr|customer Wuber Rocks summoning>waiting", -- [58]
				"1794943044.000|Hayley Cab|rr|customer Wuber Rocks waiting>arrived", -- [59]
				"1794943044.100|Hayley Cab|plan|s3_c3;auto;by=ride_arrived+fx_arrival;who=Wuber Rocks;src=sync", -- [60]
				"1794943044.100|Hayley Cab|plan|s3_r6;auto;by=ride_arrived;who=Wuber Rocks;src=sync", -- [61]
				"1794943048.900|Hayley Cab|rr|customer Wuber Rocks arrived>paid", -- [62]
				"1794943048.999|Hayley Cab|msg<|D C<Anita Lift D~1~Ratchet~1413~627~370~50000~Ritual Rides~open~3~6~H~1.1.0~~0", -- [63]
				"1794943049.599|Hayley Cab|plan|s3_c7;auto;by=rr_logride;who=Anita Lift;src=sync", -- [64]
				"1794943050.099|Hayley Cab|plan|s3_c4;auto;by=pay_exact;who=Wuber Rocks;src=sync", -- [65]
				"1794943051.499|Hayley Cab|ev|GROUP_ROSTER_UPDATE members=2 Anita Lift,Farra Way", -- [66]
				"1794943053.999|Hayley Cab|msg<|D C<Anita Lift D~1~Ratchet~1413~627~370~50000~Ritual Rides~open~3~7~H~1.1.0~~0", -- [67]
				"1794943054.599|Hayley Cab|plan|s3_r8;auto;by=auto_left+rated+milestone_pop;who=Wuber Rocks;src=sync", -- [68]
				"1794943054.599|Hayley Cab|plan|s3_c6;auto;by=milestone_pop+rated;who=Wuber Rocks;src=sync", -- [69]
				"1794943054.599|Hayley Cab|plan|s3_c5;auto;by=auto_left;who=Wuber Rocks;src=sync", -- [70]
				"1794943055.599|Hayley Cab|plan|s5_6;auto;by=fx_paid+fx_coins;who=Anita Lift;src=sync", -- [71]
				"1794943060.000|Hayley Cab|rr|LogRivals 0", -- [72]
				"1794943120.600|Hayley Cab|plan|s5_1;fail;by=hand;who=Wuber Rocks;src=sync;note=crown too small", -- [73]
			},
			["realm"] = "Forever",
			["role"] = "team",
			["selftest"] = {
				["at"] = 1794943008,
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
					["id"] = "t_open",
					["sec"] = "Setup",
					["text"] = "App opens",
				}, -- [1]
				{
					["id"] = "t_check",
					["sec"] = "Setup",
					["text"] = "Check my game runs",
				}, -- [2]
				{
					["id"] = "t_provider",
					["sec"] = "Setup",
					["text"] = "Ritual Rides drives for Wuber",
				}, -- [3]
				{
					["id"] = "t_quiet",
					["manual"] = true,
					["sec"] = "Setup",
					["text"] = "No beacon from this window",
				}, -- [4]
				{
					["id"] = "t_summon",
					["manual"] = true,
					["sec"] = "Ride",
					["text"] = "Helps with the ritual",
				}, -- [5]
				{
					["id"] = "t_cashier",
					["sec"] = "Ride",
					["text"] = "Took a fare in trade",
				}, -- [6]
				{
					["id"] = "t_status",
					["manual"] = true,
					["sec"] = "Ride",
					["text"] = "No double stage messages",
				}, -- [7]
				{
					["id"] = "t_crown",
					["manual"] = true,
					["sec"] = "Looks",
					["text"] = "Crown over Anita (nameplates on)",
				}, -- [8]
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
