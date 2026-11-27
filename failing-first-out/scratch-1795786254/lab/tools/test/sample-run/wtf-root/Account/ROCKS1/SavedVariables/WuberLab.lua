
WuberLabDB = {
	["chars"] = {
		["Wuber Rocks"] = {
			["checks"] = {
				["r_accepted"] = {
					["at"] = 1794943046.2,
					["by"] = "accept_msg",
					["r"] = "auto",
					["sec"] = "Ride",
					["text"] = "Driver accepted",
					["took"] = 0.20000004768372,
				},
				["r_arrived"] = {
					["at"] = 1794943053.1,
					["by"] = "ride_arrived",
					["r"] = "auto",
					["sec"] = "Ride",
					["text"] = "Arrived",
					["took"] = 1,
				},
				["r_booked"] = {
					["at"] = 1794943046,
					["by"] = "ride_requesting",
					["r"] = "auto",
					["sec"] = "Ride",
					["text"] = "Booked a ride",
				},
				["r_invite"] = {
					["at"] = 1794943046.1,
					["by"] = "auto_accept",
					["r"] = "auto",
					["sec"] = "Ride",
					["text"] = "Invite auto-accepted (no click)",
					["took"] = 0.099999904632568,
				},
				["r_left"] = {
					["at"] = 1794943060,
					["by"] = "auto_left",
					["r"] = "auto",
					["sec"] = "Ride",
					["text"] = "Left the group by itself",
					["took"] = 3,
				},
				["r_milestone"] = {
					["at"] = 1794943057,
					["by"] = "milestone_pop",
					["r"] = "auto",
					["sec"] = "Ride",
					["text"] = "Milestone pop",
					["took"] = 3.9000000953674,
				},
				["r_open"] = {
					["at"] = 1794943040.5,
					["by"] = "app_open",
					["r"] = "auto",
					["sec"] = "Basics",
					["text"] = "App opens",
				},
				["r_pay"] = {
					["at"] = 1794943057,
					["by"] = "pay_done",
					["r"] = "auto",
					["sec"] = "Ride",
					["text"] = "Fare paid, trade done",
					["took"] = 0,
				},
				["r_payclick"] = {
					["at"] = 1794943057,
					["by"] = "pay_done",
					["r"] = "auto",
					["sec"] = "Ride",
					["text"] = "Paid by typing the fare",
					["took"] = 3.9000000953674,
				},
				["r_rated"] = {
					["at"] = 1794943064.5,
					["by"] = "rated",
					["r"] = "auto",
					["sec"] = "Ride",
					["text"] = "Rating sent",
					["took"] = 4.5,
				},
				["r_summon"] = {
					["at"] = 1794943052.1,
					["by"] = "ride_portal",
					["r"] = "auto",
					["sec"] = "Ride",
					["text"] = "Summon popup / portal",
					["took"] = 5.8999998569489,
				},
				["r_whisper"] = {
					["at"] = 1794943046,
					["by"] = "whisper_wtb",
					["r"] = "auto",
					["sec"] = "Ride",
					["text"] = "Visible WTB whisper sent",
				},
			},
			["dropped"] = 0,
			["lastLogin"] = 1794943000,
			["lines"] = {
				"1794943000.000|Wuber Rocks|login|char=Wuber Rocks realm=CAMWOW EU5 Realm 5 PvE role=rider build=1.60.1/70938/Nov 12 2026/16001 lab=1.1.0 Wuber=1.0.0 RitualRides=off OpenMap=off Moo=off !BugGrabber=off BugSack=off W.VERSION=2.2.1 channels=4 errhandler=replaced later buggrabber=no", -- [1]
				"1794943000.000|Wuber Rocks|probe|channels=4 wuberIndex=nil (login)", -- [2]
				"1794943000.000|Wuber Rocks|ev|PLAYER_ENTERING_WORLD login=true reload=false", -- [3]
				"1794943000.000|Wuber Rocks|ev|ZONE_CHANGED_NEW_AREA zone=Orgrimmar sub=Valley of Strength", -- [4]
				"1794943000.050|Wuber Rocks|fire|DRIVE ", -- [5]
				"1794943002.000|Wuber Rocks|tool|test mode on (developer only). /lab opens the test plan. Role: rider", -- [6]
				"1794943003.000|Wuber Rocks|probe|font Poppins SetFont ok=true returned=true GetFont=Interface\\AddOns\\Wuber\\Media\\fonts\\Poppins-Regular.ttf T.poppins=nil", -- [7]
				"1794943006.000|Wuber Rocks|probe|JoinTemporaryChannel(WuberNet) called combat=false", -- [8]
				"1794943006.000|Wuber Rocks|probe|CheckChannel(true) -> false index=nil channels=4 fails=nil", -- [9]
				"1794943006.500|Wuber Rocks|fire|NETWORK true", -- [10]
				"1794943006.500|Wuber Rocks|msg>|Q C>5 Q~1", -- [11]
				"1794943006.500|Wuber Rocks|probe|CheckChannel(false) -> true index=5 channels=5 fails=nil", -- [12]
				"1794943006.500|Wuber Rocks|probe|channels=5 wuberIndex=5 (CHANNEL_UI_UPDATE)", -- [13]
				"1794943006.600|Wuber Rocks|msg<|Q C<Anita Lift Q~1", -- [14]
				"1794943006.600|Wuber Rocks|msg<|Q C<Farra Way Q~1", -- [15]
				"1794943006.600|Wuber Rocks|msg<|Q C<Hayley Cab Q~1", -- [16]
				"1794943006.600|Wuber Rocks|msg<|Q C<Wuber Rocks Q~1", -- [17]
				"1794943008.000|Wuber Rocks|self|[login] 14 of 14 passed", -- [18]
				"1794943008.000|Wuber Rocks|run|send RUN~V~2.2.1~1.1.0~1", -- [19]
				"1794943008.000|Wuber Rocks|run|login login_wuber pass: Wuber 2.2.1, lab 1.1.0", -- [20]
				"1794943008.000|Wuber Rocks|run|login login_old_addon pass: the old summoning addon is off", -- [21]
				"1794943008.000|Wuber Rocks|run|login login_prefixes pass: WUBER, WUBERT and WLAB registered", -- [22]
				"1794943008.000|Wuber Rocks|run|login login_channel pass: on Wuber's channel (/5)", -- [23]
				"1794943008.000|Wuber Rocks|run|login login_flights pass: flight prices loaded (Orgrimmar to Thunder Bluff: 50c)", -- [24]
				"1794943008.000|Wuber Rocks|run|login login_settings pass: settings look sane (price 50s)", -- [25]
				"1794943008.000|Wuber Rocks|run|login login_selftest pass: Wuber's self-test: all 14 passed", -- [26]
				"1794943008.000|Wuber Rocks|run|login login_sound skip: this client can't tell", -- [27]
				"1794943008.000|Wuber Rocks|run|login login_f1 skip: this client can't tell", -- [28]
				"1794943008.000|Wuber Rocks|run|login checks: 14 started", -- [29]
				"1794943008.500|Wuber Rocks|run|login login_versions pass: same versions as Anita, Farra, Hayley (2.2.1/1.1.0/1)", -- [30]
				"1794943010.000|Wuber Rocks|plan|s0_1@wuber rocks;ok;by=probe:fresh;who=Wuber Rocks;src=local", -- [31]
				"1794943010.000|Wuber Rocks|probe|plan s0_1 (fresh) on Wuber Rocks: ok", -- [32]
				"1794943010.000|Wuber Rocks|plan|s0_2@wuber rocks;no;by=probe:addons;who=Wuber Rocks;src=local", -- [33]
				"1794943010.000|Wuber Rocks|probe|plan s0_2 (addons) on Wuber Rocks: no", -- [34]
				"1794943010.000|Wuber Rocks|plan|s1_1@wuber rocks;ok;by=probe:fresh;who=Wuber Rocks;src=local", -- [35]
				"1794943010.000|Wuber Rocks|probe|plan s1_1 (fresh) on Wuber Rocks: ok", -- [36]
				"1794943010.000|Wuber Rocks|msg>|Q W>Anita Lift Q~1~1", -- [37]
				"1794943010.600|Wuber Rocks|plan|s0_2@anita lift;no;by=probe:addons;who=Anita Lift;src=sync", -- [38]
				"1794943010.600|Wuber Rocks|plan|s0_1@anita lift;ok;by=probe:fresh;who=Anita Lift;src=sync", -- [39]
				"1794943010.600|Wuber Rocks|plan|s1_1@anita lift;ok;by=probe:fresh;who=Anita Lift;src=sync", -- [40]
				"1794943010.600|Wuber Rocks|plan|s1_1@farra way;ok;by=probe:fresh;who=Farra Way;src=sync", -- [41]
				"1794943010.600|Wuber Rocks|plan|s0_2@farra way;no;by=probe:addons;who=Farra Way;src=sync", -- [42]
				"1794943010.600|Wuber Rocks|plan|s0_1@farra way;ok;by=probe:fresh;who=Farra Way;src=sync", -- [43]
				"1794943010.600|Wuber Rocks|plan|s0_2@hayley cab;no;by=probe:addons;who=Hayley Cab;src=sync", -- [44]
				"1794943010.600|Wuber Rocks|plan|s0_1@hayley cab;ok;by=probe:fresh;who=Hayley Cab;src=sync", -- [45]
				"1794943010.600|Wuber Rocks|plan|s1_1@hayley cab;ok;by=probe:fresh;who=Hayley Cab;src=sync", -- [46]
				"1794943011.191|Wuber Rocks|msg>|Q W>Farra Way Q~1~1", -- [47]
				"1794943012.175|Wuber Rocks|msg<|Q W<Hayley Cab Q~1~1", -- [48]
				"1794943012.199|Wuber Rocks|msg<|Q W<Anita Lift Q~1~1", -- [49]
				"1794943012.227|Wuber Rocks|msg<|Q W<Farra Way Q~1~1", -- [50]
				"1794943012.259|Wuber Rocks|msg>|Q W>Hayley Cab Q~1~1", -- [51]
				"1794943013.000|Wuber Rocks|run|login login_button pass: the big button is hidden (closed)", -- [52]
				"1794943015.000|Wuber Rocks|comm|not available (no C_Club)", -- [53]
				"1794943015.000|Wuber Rocks|fire|COMMUNITY none", -- [54]
				"1794943015.100|Wuber Rocks|plan|s0_1;auto;by=probe;who=Anita Lift;src=sync", -- [55]
				"1794943015.100|Wuber Rocks|plan|s1_1;auto;by=probe;who=Anita Lift;src=sync", -- [56]
				"1794943022.000|Wuber Rocks|comm|status: Community: not available in this game. state=none index=nil off=false sent=0 heard=0", -- [57]
				"1794943033.000|Wuber Rocks|run|login login_community skip: Community: not available in this game.", -- [58]
				"1794943033.000|Wuber Rocks|run|login login_saved skip: WuberLabDB came back empty and no other window remembers this one: a first start here", -- [59]
				"1794943033.000|Wuber Rocks|run|login login_errors pass: no Lua errors since login", -- [60]
				"1794943035.100|Wuber Rocks|run|joined run 6afca83b37 by Anita Lift: 37 checks", -- [61]
				"1794943035.100|Wuber Rocks|sim|send Farra Way: SIM~hello", -- [62]
				"1794943035.100|Wuber Rocks|sim|send Hayley Cab: SIM~hello", -- [63]
				"1794943035.100|Wuber Rocks|sim|send Anita Lift: SIM~hello", -- [64]
				"1794943035.100|Wuber Rocks|sim|pretend-to-summon ON (no shards needed; nobody is really summoned)", -- [65]
				"1794943035.100|Wuber Rocks|run|step 1/37 ride_open on Anita Lift: open Wuber (/wuber), Drive tab, choose Sell summons and press Open", -- [66]
				"1794943035.150|Wuber Rocks|fire|DRIVE ", -- [67]
				"1794943035.300|Wuber Rocks|sim|peer (test mode on there too): Anita Lift", -- [68]
				"1794943035.350|Wuber Rocks|fire|DRIVE ", -- [69]
				"1794943037.200|Wuber Rocks|sim|peer (test mode on there too): Farra Way", -- [70]
				"1794943037.200|Wuber Rocks|sim|send Farra Way: SIM~hi", -- [71]
				"1794943037.200|Wuber Rocks|sim|peer (test mode on there too): Hayley Cab", -- [72]
				"1794943037.200|Wuber Rocks|sim|send Hayley Cab: SIM~hi", -- [73]
				"1794943037.250|Wuber Rocks|fire|DRIVE ", -- [74]
				"1794943040.500|Wuber Rocks|ui|window open", -- [75]
				"1794943040.500|Wuber Rocks|check|r_open;auto;by=app_open;took=-;App opens", -- [76]
				"1794943040.500|Wuber Rocks|plan|s2_1;auto;by=app_open;who=Wuber Rocks;src=local", -- [77]
				"1794943040.600|Wuber Rocks|run|ride_open pass Anita Lift: open, selling at 50s (5.5 s)", -- [78]
				"1794943040.600|Wuber Rocks|run|step 2/37 ride_beacon on Anita Lift: Wuber tells riders Anita is open", -- [79]
				"1794943041.100|Wuber Rocks|msg<|D W<Anita Lift D~1~Undercity~1458~500~500~5000~Anita Lift~open~3~7~H~2.2.1~~0~1~CAMWOW EU5 Realm 5 PvE~1", -- [80]
				"1794943041.200|Wuber Rocks|fire|DRIVERS n=1 anita lift", -- [81]
				"1794943042.100|Wuber Rocks|run|ride_beacon pass Anita Lift: beacon open: 50s to Undercity (0.0 s)", -- [82]
				"1794943042.100|Wuber Rocks|run|step 3/37 ride_seen on Wuber Rocks: type /wuber: Anita's card is on Home", -- [83]
				"1794943042.100|Wuber Rocks|run|ride_seen pass Wuber Rocks: Anita listed (open, 50s) (0.0 s)", -- [84]
				"1794943042.100|Wuber Rocks|run|send RUN~R~6afca83b37~3~ride_seen~pass~0.0~Wuber Rocks~Anita listed (open, 50s)", -- [85]
				"1794943042.100|Wuber Rocks|run|step 4/37 ride_confirm on Wuber Rocks: tap Anita's card", -- [86]
				"1794943042.500|Wuber Rocks|ui|Show confirm anita lift", -- [87]
				"1794943042.500|Wuber Rocks|plan|s3_r2;auto;by=confirm_shown;who=Wuber Rocks;src=local", -- [88]
				"1794943042.500|Wuber Rocks|ui|window open", -- [89]
				"1794943042.500|Wuber Rocks|msg>|F W>Anita Lift F~1~H~?~orgrimmar:undercity", -- [90]
				"1794943043.000|Wuber Rocks|run|ride_confirm pass Wuber Rocks: the confirm screen for Anita (0.9 s)", -- [91]
				"1794943043.000|Wuber Rocks|run|send RUN~R~6afca83b37~4~ride_confirm~pass~0.9~Wuber Rocks~the confirm screen for Anita", -- [92]
				"1794943043.000|Wuber Rocks|run|step 5/37 ride_request on Wuber Rocks: press Request summon", -- [93]
				"1794943046.000|Wuber Rocks|whsp|> Anita Lift: WTB summon to Undercity for 50s", -- [94]
				"1794943046.000|Wuber Rocks|check|r_whisper;auto;by=whisper_wtb;took=-;Visible WTB whisper sent", -- [95]
				"1794943046.000|Wuber Rocks|plan|s3_r3;auto;by=whisper_wtb;who=Wuber Rocks;src=local", -- [96]
				"1794943046.000|Wuber Rocks|msg>|R W>Anita Lift R~1~BSnQHF~Undercity~5000~0~0", -- [97]
				"1794943046.000|Wuber Rocks|ride|BSnQHF;requesting;from=-;dt=0.0;tot=0.0;drv=Anita Lift;dest=Undercity;price=5000;fake=no", -- [98]
				"1794943046.000|Wuber Rocks|check|r_booked;auto;by=ride_requesting;took=-;Booked a ride", -- [99]
				"1794943046.000|Wuber Rocks|ui|RequestRide anita lift -> ride combat=false", -- [100]
				"1794943046.100|Wuber Rocks|ride|BSnQHF;invited;from=requesting;dt=0.1;tot=0.1;drv=Anita Lift;dest=Undercity;price=5000;fake=no", -- [101]
				"1794943046.100|Wuber Rocks|ridef|BSnQHF;inviter=anita lift", -- [102]
				"1794943046.100|Wuber Rocks|ui|toast [info] Anita invited you. Accept the invite.", -- [103]
				"1794943046.100|Wuber Rocks|probe|AcceptGroup() called combat=false", -- [104]
				"1794943046.100|Wuber Rocks|try|cap=accept ok=true result=nil combat=false", -- [105]
				"1794943046.100|Wuber Rocks|ridef|BSnQHF;autoAccepted=true", -- [106]
				"1794943046.100|Wuber Rocks|check|r_invite;auto;by=auto_accept;took=0.1;Invite auto-accepted (no click)", -- [107]
				"1794943046.100|Wuber Rocks|plan|s3_r5;auto;by=auto_accept;who=Wuber Rocks;src=local", -- [108]
				"1794943046.100|Wuber Rocks|plan|s3_c2;auto;by=auto_accept;who=Wuber Rocks;src=local", -- [109]
				"1794943046.100|Wuber Rocks|ev|PARTY_INVITE_REQUEST inviter='Anita Lift' type=string extra=7", -- [110]
				"1794943046.200|Wuber Rocks|ride|BSnQHF;ingroup;from=invited;dt=0.1;tot=0.2;drv=Anita Lift;dest=Undercity;price=5000;fake=no", -- [111]
				"1794943046.200|Wuber Rocks|ev|GROUP_ROSTER_UPDATE members=3 Anita Lift,Farra Way,Hayley Cab", -- [112]
				"1794943046.200|Wuber Rocks|msg>|B W>Farra Way B~1", -- [113]
				"1794943046.200|Wuber Rocks|msg>|B W>Hayley Cab B~1", -- [114]
				"1794943046.200|Wuber Rocks|ridef|BSnQHF;acceptedAt=1046.2", -- [115]
				"1794943046.200|Wuber Rocks|check|r_accepted;auto;by=accept_msg;took=0.2;Driver accepted", -- [116]
				"1794943046.200|Wuber Rocks|plan|s3_r4;auto;by=accept_msg;who=Wuber Rocks;src=local", -- [117]
				"1794943046.200|Wuber Rocks|msg<|A W<Anita Lift A~1~BSnQHF~5000~5", -- [118]
				"1794943046.200|Wuber Rocks|msg<|S W<Anita Lift S~1~BSnQHF~invited~~Farra Way~Hayley Cab", -- [119]
				"1794943046.250|Wuber Rocks|fire|DRIVE ", -- [120]
				"1794943046.500|Wuber Rocks|run|ride_request pass Wuber Rocks: booked; whispered 'WTB summon to Undercity for 50s' (3.5 s)", -- [121]
				"1794943046.500|Wuber Rocks|run|send RUN~R~6afca83b37~5~ride_request~pass~3.5~Wuber Rocks~booked; whispered 'WTB summon to Undercity for 50s'", -- [122]
				"1794943046.500|Wuber Rocks|run|step 6/37 ride_taken on Anita Lift: Anita's Wuber takes the request", -- [123]
				"1794943046.600|Wuber Rocks|plan|s3_c1;auto;by=whisper_wtb_in;who=Anita Lift;src=sync", -- [124]
				"1794943046.700|Wuber Rocks|probe|invite 0.6s later: wuberAutoAccepted=true inGroup=true rideState=ingroup autoAcceptSetting=true blocked=false", -- [125]
				"1794943046.700|Wuber Rocks|run|ride_taken pass Anita Lift: Wuber Rocks is in Anita's queue (joined) (0.0 s)", -- [126]
				"1794943046.700|Wuber Rocks|run|step 7/37 ride_invited on Wuber Rocks: the invite arrives and is taken with no click", -- [127]
				"1794943046.700|Wuber Rocks|run|ride_invited pass Wuber Rocks: joined Anita's group with no click (0.0 s)", -- [128]
				"1794943046.700|Wuber Rocks|run|send RUN~R~6afca83b37~7~ride_invited~pass~0.0~Wuber Rocks~joined Anita's group with no click", -- [129]
				"1794943046.700|Wuber Rocks|run|step 8/37 ride_button on Anita Lift: the big button offers the summon", -- [130]
				"1794943047.023|Wuber Rocks|msg<|K W<Hayley Cab K~1~Anita Lift", -- [131]
				"1794943047.100|Wuber Rocks|msg<|D W<Anita Lift D~1~Undercity~1458~500~500~5000~Anita Lift~busy~3~6~H~2.2.1~~0~1~CAMWOW EU5 Realm 5 PvE~1", -- [132]
				"1794943047.200|Wuber Rocks|run|ride_button pass Anita Lift: it says 'Summon Wuber' (floating, MEDIUM) (0.0 s)", -- [133]
				"1794943047.200|Wuber Rocks|run|step 9/37 ride_cast on Anita Lift: click the big button (it says {button})", -- [134]
				"1794943047.500|Wuber Rocks|whsp|< Anita Lift: Anita Lift: summoning you to Undercity now - please accept the summon! The ride is 50s; just open trade with any of us when you land.", -- [135]
				"1794943048.041|Wuber Rocks|msg<|K W<Farra Way K~1~Anita Lift", -- [136]
				"1794943048.100|Wuber Rocks|run|ride_cast pass Anita Lift: the ritual started on Wuber Rocks (pretend) (0.9 s)", -- [137]
				"1794943048.100|Wuber Rocks|run|step 10/37 ride_portal1 on Farra Way: function: 0x56275fbf6db0", -- [138]
				"1794943048.200|Wuber Rocks|ride|BSnQHF;summoning;from=ingroup;dt=2.0;tot=2.2;drv=Anita Lift;dest=Undercity;price=5000;fake=no", -- [139]
				"1794943048.200|Wuber Rocks|msg<|S W<Anita Lift S~1~BSnQHF~summoning~~Farra Way~Hayley Cab", -- [140]
				"1794943048.200|Wuber Rocks|run|ride_portal1 skip Farra Way: test mode: the pretend ritual needs no portal clicks (0.0 s)", -- [141]
				"1794943048.200|Wuber Rocks|run|step 11/37 ride_portal2 on Hayley Cab: function: 0x56275fbf6db0", -- [142]
				"1794943048.300|Wuber Rocks|run|ride_portal2 skip Hayley Cab: test mode: the pretend ritual needs no portal clicks (0.0 s)", -- [143]
				"1794943048.300|Wuber Rocks|run|step 12/37 ride_arrive on Wuber Rocks: function: 0x56275fc108b0", -- [144]
				"1794943048.349|Wuber Rocks|msg>|K W>Hayley Cab K~1~Anita Lift", -- [145]
				"1794943049.388|Wuber Rocks|msg>|K W>Farra Way K~1~Anita Lift", -- [146]
				"1794943051.100|Wuber Rocks|sim|card: Anita Lift -> Undercity", -- [147]
				"1794943052.100|Wuber Rocks|ride|BSnQHF;portal;from=summoning;dt=3.9;tot=6.1;drv=Anita Lift;dest=Undercity;price=5000;fake=no", -- [148]
				"1794943052.100|Wuber Rocks|check|r_summon;auto;by=ride_portal;took=5.9;Summon popup / portal", -- [149]
				"1794943052.100|Wuber Rocks|fx|Fullscreen portal_open played", -- [150]
				"1794943052.100|Wuber Rocks|ui|toast [summon] Accept the summon to Undercity!", -- [151]
				"1794943052.100|Wuber Rocks|msg<|S W<Anita Lift S~1~BSnQHF~portal~~Farra Way~Hayley Cab", -- [152]
				"1794943052.500|Wuber Rocks|sim|send Anita Lift: SIM~accept~Wuber Rocks", -- [153]
				"1794943052.500|Wuber Rocks|sim|accepted Anita Lift", -- [154]
				"1794943052.700|Wuber Rocks|sim|arrived (pretend): wuber rocks", -- [155]
				"1794943053.100|Wuber Rocks|ride|BSnQHF;arrived;from=portal;dt=1.0;tot=7.1;drv=Anita Lift;dest=Undercity;price=5000;fake=no", -- [156]
				"1794943053.100|Wuber Rocks|check|r_arrived;auto;by=ride_arrived;took=1.0;Arrived", -- [157]
				"1794943053.100|Wuber Rocks|plan|s3_r6;auto;by=ride_arrived;who=Wuber Rocks;src=local", -- [158]
				"1794943053.100|Wuber Rocks|ui|toast [found] You've arrived in Undercity", -- [159]
				"1794943053.100|Wuber Rocks|msg<|S W<Anita Lift S~1~BSnQHF~arrived~~Farra Way~Hayley Cab", -- [160]
				"1794943053.150|Wuber Rocks|fx|Fullscreen arrival played", -- [161]
				"1794943053.150|Wuber Rocks|plan|s3_c3;auto;by=ride_arrived+fx_arrival;who=Wuber Rocks;src=local", -- [162]
				"1794943053.500|Wuber Rocks|run|ride_arrive pass Wuber Rocks: arrived (arrived) (5.2 s)", -- [163]
				"1794943053.500|Wuber Rocks|run|send RUN~R~6afca83b37~12~ride_arrive~pass~5.2~Wuber Rocks~arrived (arrived)", -- [164]
				"1794943053.500|Wuber Rocks|run|step 13/37 ride_landed on Anita Lift: Anita's Wuber sees Wuber Rocks arrive", -- [165]
				"1794943053.700|Wuber Rocks|run|ride_landed pass Anita Lift: Wuber Rocks counts as here (arrived) (0.0 s)", -- [166]
				"1794943053.700|Wuber Rocks|run|step 14/37 ride_trade on Wuber Rocks: function: 0x56275fc12400", -- [167]
				"1794943054.000|Wuber Rocks|ev|ZONE_CHANGED_NEW_AREA zone=Undercity sub=", -- [168]
				"1794943056.000|Wuber Rocks|ride|BSnQHF;paying;from=arrived;dt=2.9;tot=10.0;drv=Anita Lift;dest=Undercity;price=5000;fake=no", -- [169]
				"1794943056.000|Wuber Rocks|ui|toast [info] Trade Anita 50s", -- [170]
				"1794943056.000|Wuber Rocks|ev|TRADE_SHOW with=Anita Lift trade=hidden my=0 their=0", -- [171]
				"1794943056.000|Wuber Rocks|ev|TRADE_ACCEPT_UPDATE me=1 them=0 trade=hidden my=5000 their=0", -- [172]
				"1794943056.000|Wuber Rocks|run|ride_trade pass Wuber Rocks: put in 50s and pressed Trade (2.3 s)", -- [173]
				"1794943056.000|Wuber Rocks|run|send RUN~R~6afca83b37~14~ride_trade~pass~2.3~Wuber Rocks~put in 50s and pressed Trade", -- [174]
				"1794943056.000|Wuber Rocks|run|step 15/37 ride_paid on Anita Lift: click the big button (it says {button})", -- [175]
				"1794943056.050|Wuber Rocks|fire|DRIVE ", -- [176]
				"1794943057.000|Wuber Rocks|ev|TRADE_ACCEPT_UPDATE me=1 them=1 trade=hidden my=5000 their=0", -- [177]
				"1794943057.000|Wuber Rocks|fire|MILESTONE main=first ids=first", -- [178]
				"1794943057.000|Wuber Rocks|ui|milestone pop first", -- [179]
				"1794943057.000|Wuber Rocks|check|r_milestone;auto;by=milestone_pop;took=3.9;Milestone pop", -- [180]
				"1794943057.000|Wuber Rocks|ride|BSnQHF;done;from=paying;dt=1.0;tot=11.0;drv=Anita Lift;dest=Undercity;price=5000;fake=no", -- [181]
				"1794943057.000|Wuber Rocks|check|r_payclick;auto;by=pay_done;took=3.9;Paid by typing the fare", -- [182]
				"1794943057.000|Wuber Rocks|check|r_pay;auto;by=pay_done;took=0.0;Fare paid, trade done", -- [183]
				"1794943057.000|Wuber Rocks|plan|s3_c4;auto;by=pay_exact;who=Wuber Rocks;src=local", -- [184]
				"1794943057.000|Wuber Rocks|ridef|BSnQHF;paid=5000", -- [185]
				"1794943057.000|Wuber Rocks|ev|PLAYER_MONEY -5000 now=95000 (trade open)", -- [186]
				"1794943057.000|Wuber Rocks|ev|TRADE_CLOSED", -- [187]
				"1794943057.050|Wuber Rocks|fire|DRIVE ", -- [188]
				"1794943057.400|Wuber Rocks|run|ride_paid pass Anita Lift: paid 50s by Wuber Rocks (1.2 s)", -- [189]
				"1794943057.400|Wuber Rocks|run|step 16/37 ride_done on Wuber Rocks: Wuber Rocks' Wuber marks the ride paid", -- [190]
				"1794943057.400|Wuber Rocks|run|ride_done pass Wuber Rocks: done, paid 50s (0.0 s)", -- [191]
				"1794943057.400|Wuber Rocks|run|send RUN~R~6afca83b37~16~ride_done~pass~0.0~Wuber Rocks~done, paid 50s", -- [192]
				"1794943057.400|Wuber Rocks|run|step 17/37 ride_left on Wuber Rocks: Wuber Rocks leaves the group by itself", -- [193]
				"1794943057.400|Wuber Rocks|msg<|S W<Anita Lift S~1~BSnQHF~paid~~Farra Way~Hayley Cab", -- [194]
				"1794943058.100|Wuber Rocks|msg<|D W<Anita Lift D~1~Undercity~1458~500~500~5000~Anita Lift~open~3~6~H~2.2.1~~0~1~CAMWOW EU5 Realm 5 PvE~1", -- [195]
				"1794943060.000|Wuber Rocks|perf|fps=60.0 wuberKB=? labKB=?", -- [196]
				"1794943060.000|Wuber Rocks|ev|GROUP_ROSTER_UPDATE members=0 ", -- [197]
				"1794943060.000|Wuber Rocks|probe|C_PartyInfo.LeaveParty() called combat=false", -- [198]
				"1794943060.000|Wuber Rocks|try|cap=leave ok=true result=nil combat=false", -- [199]
				"1794943060.000|Wuber Rocks|check|r_left;auto;by=auto_left;took=3.0;Left the group by itself", -- [200]
				"1794943060.000|Wuber Rocks|plan|s3_c5;auto;by=auto_left;who=Wuber Rocks;src=local", -- [201]
				"1794943060.000|Wuber Rocks|ridef|BSnQHF;autoLeft=true", -- [202]
				"1794943060.000|Wuber Rocks|run|ride_left pass Wuber Rocks: left the group with no click (2.6 s)", -- [203]
				"1794943060.000|Wuber Rocks|run|send RUN~R~6afca83b37~17~ride_left~pass~2.6~Wuber Rocks~left the group with no click", -- [204]
				"1794943060.000|Wuber Rocks|run|step 18/37 ride_rate on Wuber Rocks: tap 5 stars on the Done screen", -- [205]
				"1794943060.050|Wuber Rocks|fire|DRIVE ", -- [206]
				"1794943063.100|Wuber Rocks|msg<|D W<Anita Lift D~1~Undercity~1458~500~500~5000~Anita Lift~open~3~7~H~2.2.1~~0~1~CAMWOW EU5 Realm 5 PvE~1", -- [207]
				"1794943064.500|Wuber Rocks|msg>|T W>Anita Lift T~1~BSnQHF~5", -- [208]
				"1794943064.500|Wuber Rocks|ridef|BSnQHF;rated=true", -- [209]
				"1794943064.500|Wuber Rocks|check|r_rated;auto;by=rated;took=4.5;Rating sent", -- [210]
				"1794943064.500|Wuber Rocks|plan|s3_r8;auto;by=auto_left+rated+milestone_pop;who=Wuber Rocks;src=local", -- [211]
				"1794943064.500|Wuber Rocks|plan|s3_c6;auto;by=milestone_pop+rated;who=Wuber Rocks;src=local", -- [212]
				"1794943064.500|Wuber Rocks|ridef|BSnQHF;stars=5", -- [213]
				"1794943064.500|Wuber Rocks|ui|Rate 5 sent=true", -- [214]
				"1794943065.000|Wuber Rocks|run|ride_rate pass Wuber Rocks: rated 5 stars (5.0 s)", -- [215]
				"1794943065.000|Wuber Rocks|run|send RUN~R~6afca83b37~18~ride_rate~pass~5.0~Wuber Rocks~rated 5 stars", -- [216]
				"1794943065.000|Wuber Rocks|run|step 19/37 ride_thanks on Anita Lift: click the big button (it says {button})", -- [217]
				"1794943066.100|Wuber Rocks|plan|s5_6;auto;by=fx_paid+fx_coins;who=Anita Lift;src=sync", -- [218]
				"1794943070.500|Wuber Rocks|whsp|< Anita Lift: Thank you, Wuber! Enjoy Undercity - Anita Lift is here whenever you need a lift.", -- [219]
				"1794943070.600|Wuber Rocks|run|ride_thanks pass Anita Lift: thank-you whisper sent to Wuber Rocks (0.4 s)", -- [220]
				"1794943070.600|Wuber Rocks|run|step 20/37 ride_earnings on Anita Lift: Drive tab: open Earnings, then click Snap (below)", -- [221]
				"1794943070.600|Wuber Rocks|msg<|S W<Anita Lift S~1~BSnQHF~done~~Farra Way~Hayley Cab", -- [222]
				"1794943070.600|Wuber Rocks|run|ride_earnings look Anita Lift: screenshot 1: Earnings with today's ride (0.0 s)", -- [223]
				"1794943070.600|Wuber Rocks|run|step 21/37 raid_invite on Anita Lift: type /invite Wuber Rocks", -- [224]
				"1794943070.600|Wuber Rocks|ev|PARTY_INVITE_REQUEST inviter='Anita Lift' type=string extra=7", -- [225]
				"1794943070.600|Wuber Rocks|run|raid_invite pass Anita Lift: the invite reached Wuber Rocks (0.0 s)", -- [226]
				"1794943070.600|Wuber Rocks|run|send RUN~R~6afca83b37~21~raid_invite~pass~0.0~Wuber Rocks~the invite reached Wuber Rocks", -- [227]
				"1794943070.600|Wuber Rocks|run|step 22/37 raid_join on Wuber Rocks: click Accept on the group invite", -- [228]
				"1794943071.200|Wuber Rocks|probe|invite 0.6s later: wuberAutoAccepted=true inGroup=false rideState=done autoAcceptSetting=true blocked=false", -- [229]
				"1794943073.500|Wuber Rocks|probe|AcceptGroup() called combat=false", -- [230]
				"1794943073.600|Wuber Rocks|ev|GROUP_ROSTER_UPDATE members=3 Anita Lift,Farra Way,Hayley Cab", -- [231]
				"1794943073.600|Wuber Rocks|run|raid_join pass Wuber Rocks: in Anita's group (3.0 s)", -- [232]
				"1794943073.600|Wuber Rocks|run|send RUN~R~6afca83b37~22~raid_join~pass~3.0~Wuber Rocks~in Anita's group", -- [233]
				"1794943073.600|Wuber Rocks|run|step 23/37 raid_convert on Anita Lift: right-click your portrait, Convert to Raid", -- [234]
				"1794943073.650|Wuber Rocks|fire|DRIVE ", -- [235]
				"1794943074.100|Wuber Rocks|msg<|D W<Anita Lift D~1~Undercity~1458~500~500~5000~Anita Lift~busy~3~6~H~2.2.1~~0~1~CAMWOW EU5 Realm 5 PvE~1", -- [236]
				"1794943077.500|Wuber Rocks|sys|Party converted to Raid", -- [237]
				"1794943077.500|Wuber Rocks|ev|GROUP_ROSTER_UPDATE members=4 Anita Lift,Farra Way,Hayley Cab,Wuber Rocks", -- [238]
				"1794943077.550|Wuber Rocks|fire|DRIVE ", -- [239]
				"1794943078.100|Wuber Rocks|run|raid_convert pass Anita Lift: a raid (0.9 s)", -- [240]
				"1794943078.100|Wuber Rocks|run|step 24/37 raid_start on Anita Lift: Drive tab: Raid summons, tick Anita, Farra and Hayley as summoners, press Start", -- [241]
				"1794943080.100|Wuber Rocks|fire|DRIVE_RAID ", -- [242]
				"1794943080.600|Wuber Rocks|run|raid_start pass Anita Lift: raid summons on, 3 summoners (2.5 s)", -- [243]
				"1794943080.600|Wuber Rocks|run|step 25/37 raid_window on Anita Lift: keep Wuber's window open on the Drive tab (open it if it closed)", -- [244]
				"1794943083.100|Wuber Rocks|fire|DRIVE_RAID ", -- [245]
				"1794943083.100|Wuber Rocks|fire|DRIVE_RAID ", -- [246]
				"1794943083.600|Wuber Rocks|run|raid_window pass Anita Lift: window open, big button docked on top (FULLSCREEN_DIALOG over HIGH) (3.0 s)", -- [247]
				"1794943083.600|Wuber Rocks|run|step 26/37 raid_away on Wuber Rocks: take Wuber Rocks out of Anita's zone (hearth or walk out), staying in the raid", -- [248]
				"1794943084.000|Wuber Rocks|ev|ZONE_CHANGED_NEW_AREA zone=Orgrimmar sub=Valley of Strength", -- [249]
				"1794943084.000|Wuber Rocks|sim|send Anita Lift: SIM~moved~Wuber Rocks", -- [250]
				"1794943084.000|Wuber Rocks|sim|moved: told Anita Lift", -- [251]
				"1794943084.500|Wuber Rocks|try|cap=comm ok=true result=0 combat=false", -- [252]
				"1794943084.600|Wuber Rocks|run|raid_away pass Wuber Rocks: Wuber Rocks is away from the spot (Orgrimmar) (1.0 s)", -- [253]
				"1794943084.600|Wuber Rocks|run|step 27/37 raid_tap on Wuber Rocks: type /wuber and tap Request a summon", -- [254]
				"1794943084.700|Wuber Rocks|fire|DRIVE_RAID ", -- [255]
				"1794943084.750|Wuber Rocks|fire|DRIVE ", -- [256]
				"1794943085.100|Wuber Rocks|run|raid_tap pass Wuber Rocks: queued from the app (Request a summon) (0.5 s)", -- [257]
				"1794943085.100|Wuber Rocks|run|step 28/37 raid_nvm on Wuber Rocks: type nvm in raid chat", -- [258]
				"1794943085.100|Wuber Rocks|fire|DRIVE_RAID ", -- [259]
				"1794943085.150|Wuber Rocks|fire|DRIVE ", -- [260]
				"1794943085.600|Wuber Rocks|run|raid_nvm pass Wuber Rocks: dropped from the list (0.5 s)", -- [261]
				"1794943085.600|Wuber Rocks|run|step 29/37 raid_ask on Wuber Rocks: type 123 in raid chat", -- [262]
				"1794943085.600|Wuber Rocks|fire|DRIVE_RAID ", -- [263]
				"1794943085.650|Wuber Rocks|fire|DRIVE ", -- [264]
				"1794943086.000|Wuber Rocks|whsp|< Anita Lift: Summon coming from Anita - accept it when it pops", -- [265]
				"1794943086.100|Wuber Rocks|run|raid_ask pass Wuber Rocks: Wuber Rocks queued (queued) (0.5 s)", -- [266]
				"1794943086.100|Wuber Rocks|run|step 30/37 raid_button on Anita Lift: the big button offers the summon", -- [267]
				"1794943086.100|Wuber Rocks|run|raid_button pass Anita Lift: it says 'Summon Wuber' (docked on top (FULLSCREEN_DIALOG over HIGH)) (0.0 s)", -- [268]
				"1794943086.100|Wuber Rocks|run|step 31/37 raid_cast on Anita Lift: click the big button (it says {button})", -- [269]
				"1794943086.100|Wuber Rocks|fire|DRIVE_ALERT Click the summoning portal - Wuber is on the way! portal", -- [270]
				"1794943086.100|Wuber Rocks|ui|toast [portal] Click the summoning portal - Wuber is on the way!", -- [271]
				"1794943086.100|Wuber Rocks|fire|DRIVE_RAID ", -- [272]
				"1794943086.100|Wuber Rocks|fire|DRIVE_RAID ", -- [273]
				"1794943086.150|Wuber Rocks|fire|DRIVE ", -- [274]
				"1794943086.600|Wuber Rocks|run|raid_cast pass Anita Lift: Anita's ritual started on Wuber Rocks (pretend) (0.5 s)", -- [275]
				"1794943086.600|Wuber Rocks|run|step 32/37 raid_portal1 on Farra Way: function: 0x56275fbf6db0", -- [276]
				"1794943086.700|Wuber Rocks|run|raid_portal1 skip Farra Way: test mode: the pretend ritual needs no portal clicks (0.0 s)", -- [277]
				"1794943086.700|Wuber Rocks|run|step 33/37 raid_portal2 on Hayley Cab: function: 0x56275fbf6db0", -- [278]
				"1794943086.800|Wuber Rocks|run|raid_portal2 skip Hayley Cab: test mode: the pretend ritual needs no portal clicks (0.0 s)", -- [279]
				"1794943086.800|Wuber Rocks|run|step 34/37 raid_arrive on Wuber Rocks: function: 0x56275fc19ef0", -- [280]
				"1794943089.600|Wuber Rocks|sim|card: Anita Lift -> Undercity", -- [281]
				"1794943090.600|Wuber Rocks|fire|DRIVE_RAID ", -- [282]
				"1794943090.650|Wuber Rocks|fire|DRIVE ", -- [283]
				"1794943091.000|Wuber Rocks|sim|send Anita Lift: SIM~accept~Wuber Rocks", -- [284]
				"1794943091.000|Wuber Rocks|sim|accepted Anita Lift", -- [285]
				"1794943091.200|Wuber Rocks|sim|arrived (pretend): wuber rocks", -- [286]
				"1794943092.100|Wuber Rocks|run|raid_arrive pass Wuber Rocks: summoned, counted, off the list (5.2 s)", -- [287]
				"1794943092.100|Wuber Rocks|run|step 35/37 raid_one on Anita Lift: Farra's and Hayley's Wuber left Wuber Rocks to Anita", -- [288]
				"1794943092.300|Wuber Rocks|run|raid_one pass Anita Lift: Farra's and Hayley's buttons and rituals left Wuber Rocks alone (0.2 s)", -- [289]
				"1794943092.300|Wuber Rocks|run|step 36/37 raid_stop on Anita Lift: press Stop on the Drive tab", -- [290]
				"1794943092.600|Wuber Rocks|fire|DRIVE_RAID ", -- [291]
				"1794943093.100|Wuber Rocks|run|raid_stop pass Anita Lift: raid summons stopped (0.8 s)", -- [292]
				"1794943093.100|Wuber Rocks|run|step 37/37 photo_tour on Anita Lift: press Close on the Drive tab if open, then click Start photo tour (below): hands off for a minute", -- [293]
				"1794943098.100|Wuber Rocks|fire|DRIVE_RAID ", -- [294]
				"1794943098.100|Wuber Rocks|fire|DRIVE_RAID ", -- [295]
				"1794943120.000|Wuber Rocks|perf|fps=60.0 wuberKB=? labKB=?", -- [296]
				"1794943120.100|Wuber Rocks|sim|send Anita Lift: SIM~hi", -- [297]
				"1794943120.100|Wuber Rocks|sim|send Farra Way: SIM~hi", -- [298]
				"1794943120.100|Wuber Rocks|sim|send Hayley Cab: SIM~hi", -- [299]
				"1794943136.100|Wuber Rocks|run|photo_tour pass Anita Lift: 25 screenshots (43.0 s)", -- [300]
				"1794943136.100|Wuber Rocks|run|end 6afca83b37 (done): 37 of 37 checked, 0 failed", -- [301]
				"1794943136.100|Wuber Rocks|tool|test run done: log out or /reload, then tell the person running the test \"done\".", -- [302]
			},
			["realm"] = "CAMWOW EU5 Realm 5 PvE",
			["role"] = "rider",
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
						["name"] = "Leave the group after the ride",
						["ok"] = true,
					}, -- [13]
					{
						["name"] = "Crowns over heads (nameplates)",
						["ok"] = true,
					}, -- [14]
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
					["text"] = "Paid by typing the fare",
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
				["lab"] = "1.1.0",
				["rr"] = "1.4.0",
				["wuber"] = "1.0.0",
			},
		},
	},
	["login"] = {
		["Wuber Rocks"] = {
			["at"] = 1794943008,
			["lab"] = "1.1.0",
			["lines"] = {
				"login_wuber|pass|Wuber 2.2.1, lab 1.1.0|1794943008.000|0.0", -- [1]
				"login_old_addon|pass|the old summoning addon is off|1794943008.000|0.0", -- [2]
				"login_prefixes|pass|WUBER, WUBERT and WLAB registered|1794943008.000|0.0", -- [3]
				"login_channel|pass|on Wuber's channel (/5)|1794943008.000|0.0", -- [4]
				"login_flights|pass|flight prices loaded (Orgrimmar to Thunder Bluff: 50c)|1794943008.000|0.0", -- [5]
				"login_settings|pass|settings look sane (price 50s)|1794943008.000|0.0", -- [6]
				"login_selftest|pass|Wuber's self-test: all 14 passed|1794943008.000|0.0", -- [7]
				"login_sound|skip|this client can't tell|1794943008.000|0.0", -- [8]
				"login_f1|skip|this client can't tell|1794943008.000|0.0", -- [9]
				"login_versions|pass|same versions as Anita, Farra, Hayley (2.2.1/1.1.0/1)|1794943008.500|0.5", -- [10]
				"login_button|pass|the big button is hidden (closed)|1794943013.000|5.0", -- [11]
				"login_community|skip|Community: not available in this game.|1794943033.000|25.0", -- [12]
				"login_saved|skip|WuberLabDB came back empty and no other window remembers this one: a first start here|1794943033.000|25.0", -- [13]
				"login_errors|pass|no Lua errors since login|1794943033.000|25.0", -- [14]
			},
			["session"] = 1,
			["wuber"] = "2.2.1",
		},
	},
	["plan"] = {
		["s0_1"] = {
			["at"] = 1794943013.6,
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
			["at"] = 1794943010,
			["by"] = "probe:fresh",
			["r"] = "ok",
			["who"] = "Wuber Rocks",
		},
		["s0_2@anita lift"] = {
			["at"] = 1794943010,
			["by"] = "probe:addons",
			["r"] = "no",
			["who"] = "Anita Lift",
		},
		["s0_2@farra way"] = {
			["at"] = 1794943010,
			["by"] = "probe:addons",
			["r"] = "no",
			["who"] = "Farra Way",
		},
		["s0_2@hayley cab"] = {
			["at"] = 1794943010,
			["by"] = "probe:addons",
			["r"] = "no",
			["who"] = "Hayley Cab",
		},
		["s0_2@wuber rocks"] = {
			["at"] = 1794943010,
			["by"] = "probe:addons",
			["r"] = "no",
			["who"] = "Wuber Rocks",
		},
		["s1_1"] = {
			["at"] = 1794943013.6,
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
			["at"] = 1794943010,
			["by"] = "probe:fresh",
			["r"] = "ok",
			["who"] = "Wuber Rocks",
		},
		["s2_1"] = {
			["at"] = 1794943040.5,
			["by"] = "app_open",
			["r"] = "auto",
			["who"] = "Wuber Rocks",
		},
		["s3_c1"] = {
			["at"] = 1794943046,
			["by"] = "whisper_wtb_in",
			["r"] = "auto",
			["who"] = "Anita Lift",
		},
		["s3_c2"] = {
			["at"] = 1794943046.1,
			["by"] = "auto_accept",
			["r"] = "auto",
			["who"] = "Wuber Rocks",
		},
		["s3_c3"] = {
			["at"] = 1794943053.15,
			["by"] = "ride_arrived+fx_arrival",
			["r"] = "auto",
			["who"] = "Wuber Rocks",
		},
		["s3_c4"] = {
			["at"] = 1794943057,
			["by"] = "pay_exact",
			["r"] = "auto",
			["who"] = "Wuber Rocks",
		},
		["s3_c5"] = {
			["at"] = 1794943060,
			["by"] = "auto_left",
			["r"] = "auto",
			["who"] = "Wuber Rocks",
		},
		["s3_c6"] = {
			["at"] = 1794943064.5,
			["by"] = "milestone_pop+rated",
			["r"] = "auto",
			["who"] = "Wuber Rocks",
		},
		["s3_r2"] = {
			["at"] = 1794943042.5,
			["by"] = "confirm_shown",
			["r"] = "auto",
			["who"] = "Wuber Rocks",
		},
		["s3_r3"] = {
			["at"] = 1794943046,
			["by"] = "whisper_wtb",
			["r"] = "auto",
			["who"] = "Wuber Rocks",
		},
		["s3_r4"] = {
			["at"] = 1794943046.2,
			["by"] = "accept_msg",
			["r"] = "auto",
			["who"] = "Wuber Rocks",
		},
		["s3_r5"] = {
			["at"] = 1794943046.1,
			["by"] = "auto_accept",
			["r"] = "auto",
			["who"] = "Wuber Rocks",
		},
		["s3_r6"] = {
			["at"] = 1794943053.1,
			["by"] = "ride_arrived",
			["r"] = "auto",
			["who"] = "Wuber Rocks",
		},
		["s3_r8"] = {
			["at"] = 1794943064.5,
			["by"] = "auto_left+rated+milestone_pop",
			["r"] = "auto",
			["who"] = "Wuber Rocks",
		},
		["s5_6"] = {
			["at"] = 1794943064.6,
			["by"] = "fx_paid+fx_coins",
			["r"] = "auto",
			["who"] = "Anita Lift",
		},
	},
	["planSteps"] = {
		{
			["id"] = "v22_1",
			["sec"] = "Wuber 2.2: today's tests (no shards needed)",
			["text"] = "Drive tab on each Warlock: if it says your old summoning addon is still on, switch it off and let it reload.",
			["who"] = "Warlocks",
		}, -- [1]
		{
			["id"] = "v22_2",
			["sec"] = "Wuber 2.2: today's tests (no shards needed)",
			["text"] = "Anita: Set up driving > My own characters > send offers; Yes on Farra and Hayley; Done; press Open.",
			["who"] = "Anita",
		}, -- [2]
		{
			["id"] = "v22_3",
			["sec"] = "Wuber 2.2: today's tests (no shards needed)",
			["text"] = "Wuber Rocks next to Anita: tap Anita's card. The confirm screen is one clean sheet with a 'Flying here costs' line.",
			["who"] = "Wuber Rocks",
		}, -- [3]
		{
			["id"] = "v22_4",
			["sec"] = "Wuber 2.2: today's tests (no shards needed)",
			["text"] = "Tip slider to 10%: it says 'type 55s'. Press Request summon; Anita invites by herself.",
			["who"] = "Wuber Rocks",
		}, -- [4]
		{
			["id"] = "v22_5",
			["sec"] = "Wuber 2.2: today's tests (no shards needed)",
			["text"] = "Anita: click the big button (Summon Wuber Rocks). Farra and Hayley turn red CLICK THE PORTAL: /lab simclick on each.",
			["who"] = "Anita, Farra, Hayley",
		}, -- [5]
		{
			["id"] = "v22_6",
			["sec"] = "Wuber 2.2: today's tests (no shards needed)",
			["text"] = "Wuber Rocks: Accept the pretend summon card. Then open a trade with Anita, type 55s, click Trade.",
			["who"] = "Wuber Rocks",
		}, -- [6]
		{
			["check"] = true,
			["id"] = "v22_7",
			["sec"] = "Wuber 2.2: today's tests (no shards needed)",
			["text"] = "Anita: thank-you whisper sent, gold coin effect, the ride on Earnings (heatmap) and the payment counted once.",
			["who"] = "Anita",
		}, -- [7]
		{
			["check"] = true,
			["id"] = "v22_8",
			["sec"] = "Wuber 2.2: today's tests (no shards needed)",
			["text"] = "Second ride: Anita's queue shows '2nd ride with you'.",
			["who"] = "Anita",
		}, -- [8]
		{
			["check"] = true,
			["id"] = "v22_9",
			["sec"] = "Wuber 2.2: today's tests (no shards needed)",
			["text"] = "Stranger check: mid-ride, Farra opens a trade with Wuber Rocks: Wuber Rocks gets a warning and no 'type the fare' strip.",
			["who"] = "Farra, Wuber Rocks",
		}, -- [9]
		{
			["check"] = true,
			["id"] = "v22_10",
			["sec"] = "Wuber 2.2: today's tests (no shards needed)",
			["text"] = "Raid summons: make a raid, Drive tab > Raid summons, tick Anita, Start. Wuber Rocks types 123 in raid chat: queued; Anita's button summons; 'nvm' drops them.",
			["who"] = "all four",
		}, -- [10]
		{
			["check"] = true,
			["id"] = "v22_11",
			["sec"] = "Wuber 2.2: today's tests (no shards needed)",
			["text"] = "Any class: on a non-Warlock set up driving with Anita as summoner: the rider's pay strip says Pay Anita.",
			["who"] = "any",
		}, -- [11]
		{
			["check"] = true,
			["id"] = "v22_12",
			["sec"] = "Wuber 2.2: today's tests (no shards needed)",
			["text"] = "Close the service on Anita: the end-of-shift card shows. Trips: time saved counts up. Settings: Replay tips works.",
			["who"] = "Anita, Wuber Rocks",
		}, -- [12]
		{
			["check"] = true,
			["id"] = "v22_13",
			["sec"] = "Wuber 2.2: today's tests (no shards needed)",
			["text"] = "Toasts never cover the Ride/Trips/Drive tabs; unpaid ride end shows a grey coin, not a tick.",
			["who"] = "Wuber Rocks",
		}, -- [13]
		{
			["auto"] = true,
			["id"] = "s0_1",
			["sec"] = "Before you start",
			["text"] = "Close all WoW clients.",
			["who"] = "all four",
		}, -- [14]
		{
			["auto"] = true,
			["id"] = "s0_2",
			["sec"] = "Before you start",
			["text"] = "At the character screen on each account, open AddOns and set: Wuber ticked on all four; Ritual Rides ticked on Anita, Farra and Hayley, and left ticked on Wuber Rocks too (needed for the bell); Wuber Test unticked everywhere; Wuber Lab ticked on all four; OpenMap ticked if you use it.",
			["who"] = "all four",
		}, -- [15]
		{
			["auto"] = true,
			["id"] = "s0_3",
			["sec"] = "Before you start",
			["text"] = "Turn on System > Sound > Sound in Background on Wuber Rocks, so you hear the bell while Anita's window is in front.",
			["who"] = "Wuber Rocks",
		}, -- [16]
		{
			["auto"] = true,
			["id"] = "s0_4",
			["sec"] = "Before you start",
			["text"] = "Unbind F1 in Key Bindings on all four accounts, so the swap key does nothing inside WoW.",
			["who"] = "all four",
		}, -- [17]
		{
			["auto"] = true,
			["id"] = "s1_1",
			["sec"] = "Windows: three locks, Wuber Rocks on top, F1 to swap",
			["text"] = "In PowerShell: cd <the Lab scripts folder> then .\\start4.ps1. It opens the three Warlocks, then a fourth window exactly over Anita's, then the F1 swap key in a minimised window. Log in all four.",
			["who"] = "PC",
		}, -- [18]
		{
			["id"] = "s1_2",
			["sec"] = "Windows: three locks, Wuber Rocks on top, F1 to swap",
			["text"] = "Your three windows didn't move or shrink, and Wuber Rocks sits exactly over Anita.",
			["who"] = "PC",
		}, -- [19]
		{
			["id"] = "s1_3",
			["sec"] = "Windows: three locks, Wuber Rocks on top, F1 to swap",
			["text"] = "Press F1 to flip between Wuber Rocks and Anita, and again to flip back.",
			["who"] = "PC",
		}, -- [20]
		{
			["auto"] = {
				"bell_rang", -- [1]
			},
			["id"] = "s1_4",
			["sec"] = "Windows: three locks, Wuber Rocks on top, F1 to swap",
			["text"] = "On Anita (a Warlock window, not Wuber Rocks) type /rr bell Wuber Rocks, then /rr bell test. Wuber Rocks, not Anita, should show the banner, ring and flash its taskbar icon.",
			["who"] = "Anita, then Wuber Rocks",
		}, -- [21]
		{
			["check"] = true,
			["id"] = "s1_c1",
			["sec"] = "Windows: three locks, Wuber Rocks on top, F1 to swap",
			["text"] = "Wuber Rocks sits exactly over Anita",
			["who"] = "PC",
		}, -- [22]
		{
			["check"] = true,
			["id"] = "s1_c2",
			["sec"] = "Windows: three locks, Wuber Rocks on top, F1 to swap",
			["text"] = "The other two windows didn't move",
			["who"] = "PC",
		}, -- [23]
		{
			["check"] = true,
			["id"] = "s1_c3",
			["sec"] = "Windows: three locks, Wuber Rocks on top, F1 to swap",
			["text"] = "F1 swaps both ways",
			["who"] = "PC",
		}, -- [24]
		{
			["auto"] = {
				"bell_rang", -- [1]
			},
			["check"] = true,
			["id"] = "s1_c4",
			["sec"] = "Windows: three locks, Wuber Rocks on top, F1 to swap",
			["text"] = "The bell rings on Wuber Rocks",
			["who"] = "Wuber Rocks",
		}, -- [25]
		{
			["auto"] = {
				"app_open", -- [1]
			},
			["id"] = "s2_1",
			["sec"] = "Test 1: the app on Wuber Rocks (5 minutes)",
			["text"] = "Type /wuber. The app opens on Home with the logo top left and Ride, Trips and Drive tabs.",
			["who"] = "Wuber Rocks",
		}, -- [26]
		{
			["auto"] = {
				"selftest_ui", -- [1]
			},
			["id"] = "s2_2",
			["sec"] = "Test 1: the app on Wuber Rocks (5 minutes)",
			["text"] = "Click the gear, scroll to the bottom and click Check my game. Take a screenshot of the results.",
			["who"] = "Wuber Rocks",
		}, -- [27]
		{
			["auto"] = {
				"tip", -- [1]
			},
			["id"] = "s2_3",
			["sec"] = "Test 1: the app on Wuber Rocks (5 minutes)",
			["text"] = "In Settings, hover over a few options. Each should show a tooltip.",
			["who"] = "Wuber Rocks",
		}, -- [28]
		{
			["auto"] = {
				"slider", -- [1]
			},
			["id"] = "s2_4",
			["sec"] = "Test 1: the app on Wuber Rocks (5 minutes)",
			["text"] = "Drag the \"My time is worth\" slider and the window size slider. If they won't drag, try the mouse wheel.",
			["who"] = "Wuber Rocks",
		}, -- [29]
		{
			["auto"] = {
				"trips_tab", -- [1]
			},
			["id"] = "s2_5",
			["sec"] = "Test 1: the app on Wuber Rocks (5 minutes)",
			["text"] = "Open Trips: level, stats tiles and the milestone grid, all locked for now.",
			["who"] = "Wuber Rocks",
		}, -- [30]
		{
			["auto"] = {
				"minimap", -- [1]
			},
			["id"] = "s2_6",
			["sec"] = "Test 1: the app on Wuber Rocks (5 minutes)",
			["text"] = "Close the app and open it from the minimap button.",
			["who"] = "Wuber Rocks",
		}, -- [31]
		{
			["check"] = true,
			["id"] = "s2_c1",
			["sec"] = "Test 1: the app on Wuber Rocks (5 minutes)",
			["text"] = "No red Lua errors on login or opening the app",
			["who"] = "Wuber Rocks",
		}, -- [32]
		{
			["check"] = true,
			["id"] = "s2_c2",
			["sec"] = "Test 1: the app on Wuber Rocks (5 minutes)",
			["text"] = "Check my game screenshot taken",
			["who"] = "Wuber Rocks",
		}, -- [33]
		{
			["auto"] = {
				"tip", -- [1]
			},
			["check"] = true,
			["id"] = "s2_c3",
			["sec"] = "Test 1: the app on Wuber Rocks (5 minutes)",
			["text"] = "Tooltips show",
			["who"] = "Wuber Rocks",
		}, -- [34]
		{
			["auto"] = {
				"slider", -- [1]
			},
			["check"] = true,
			["id"] = "s2_c4",
			["sec"] = "Test 1: the app on Wuber Rocks (5 minutes)",
			["text"] = "Sliders drag (or only the wheel works)",
			["who"] = "Wuber Rocks",
		}, -- [35]
		{
			["auto"] = {
				"minimap", -- [1]
			},
			["check"] = true,
			["id"] = "s2_c5",
			["sec"] = "Test 1: the app on Wuber Rocks (5 minutes)",
			["text"] = "Minimap button opens the app",
			["who"] = "Wuber Rocks",
		}, -- [36]
		{
			["auto"] = {
				"beacon_open", -- [1]
			},
			["id"] = "s3_d1",
			["sec"] = "Test 2: a full ride, Wuber Rocks to your team",
			["text"] = "/rr price 50s (or your normal price, at least 50s) and /rr on. Don't type /rr on on Wuber Rocks.",
			["who"] = "Anita",
		}, -- [37]
		{
			["id"] = "s3_d2",
			["sec"] = "Test 2: a full ride, Wuber Rocks to your team",
			["text"] = "Team grouped with Anita as leader, or ungrouped with Anita as main caster.",
			["who"] = "Anita",
		}, -- [38]
		{
			["id"] = "s3_r1",
			["sec"] = "Test 2: a full ride, Wuber Rocks to your team",
			["text"] = "/wuber. Anita's card is at the top with the crown, Founder chip and the strongest glow.",
			["who"] = "Wuber Rocks",
		}, -- [39]
		{
			["auto"] = {
				"confirm_shown", -- [1]
				"ride_requesting", -- [2]
			},
			["id"] = "s3_r2",
			["sec"] = "Test 2: a full ride, Wuber Rocks to your team",
			["text"] = "Click Anita's card. The confirm screen shows price, destination and time saved.",
			["who"] = "Wuber Rocks",
		}, -- [40]
		{
			["auto"] = {
				"whisper_wtb", -- [1]
				"whisper_wtb_in", -- [2]
			},
			["id"] = "s3_r3",
			["sec"] = "Test 2: a full ride, Wuber Rocks to your team",
			["text"] = "Click Request. Wuber Rocks whispers Anita \"WTB summon to (place) for 50s\". Check Anita's chat.",
			["who"] = "Wuber Rocks",
		}, -- [41]
		{
			["auto"] = {
				"accept_msg", -- [1]
				"ride_accepted", -- [2]
			},
			["id"] = "s3_r4",
			["sec"] = "Test 2: a full ride, Wuber Rocks to your team",
			["text"] = "Anita's side accepts. Wuber Rocks shows Accepted and your place in line with a countdown.",
			["who"] = "Wuber Rocks",
		}, -- [42]
		{
			["auto"] = {
				"auto_accept", -- [1]
			},
			["id"] = "s3_r5",
			["sec"] = "Test 2: a full ride, Wuber Rocks to your team",
			["text"] = "The invite arrives and is accepted with no click, then the bell rings on Wuber Rocks.",
			["who"] = "Wuber Rocks",
		}, -- [43]
		{
			["auto"] = {
				"ride_arrived", -- [1]
			},
			["id"] = "s3_r6",
			["sec"] = "Test 2: a full ride, Wuber Rocks to your team",
			["text"] = "The team summons. Accept the summon box. The portal effect plays, then the arrival scene.",
			["who"] = "Wuber Rocks",
		}, -- [44]
		{
			["auto"] = {
				"pay_clicked", -- [1]
				"pay_exact", -- [2]
			},
			["id"] = "s3_r7",
			["sec"] = "Test 2: a full ride, Wuber Rocks to your team",
			["text"] = "A trade opens from the cashier. Wuber shows what to type under the trade window: type 50 in silver, click Trade. Wuber sees the payment.",
			["who"] = "Wuber Rocks",
		}, -- [45]
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
		}, -- [46]
		{
			["auto"] = {
				"whisper_wtb_in", -- [1]
			},
			["check"] = true,
			["id"] = "s3_c1",
			["sec"] = "Test 2: a full ride, Wuber Rocks to your team",
			["text"] = "Visible WTB whisper reached Anita",
			["who"] = "Anita",
		}, -- [47]
		{
			["auto"] = {
				"auto_accept", -- [1]
			},
			["check"] = true,
			["id"] = "s3_c2",
			["sec"] = "Test 2: a full ride, Wuber Rocks to your team",
			["text"] = "Invite accepted with no click",
			["who"] = "Wuber Rocks",
		}, -- [48]
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
		}, -- [49]
		{
			["auto"] = {
				"pay_exact", -- [1]
			},
			["check"] = true,
			["id"] = "s3_c4",
			["sec"] = "Test 2: a full ride, Wuber Rocks to your team",
			["text"] = "Paid the fare by typing it; Wuber marked the ride paid",
			["who"] = "Wuber Rocks",
		}, -- [50]
		{
			["auto"] = {
				"auto_left", -- [1]
			},
			["check"] = true,
			["id"] = "s3_c5",
			["sec"] = "Test 2: a full ride, Wuber Rocks to your team",
			["text"] = "Left the group by itself",
			["who"] = "Wuber Rocks",
		}, -- [51]
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
		}, -- [52]
		{
			["auto"] = {
				"rr_logride", -- [1]
			},
			["check"] = true,
			["id"] = "s3_c7",
			["sec"] = "Test 2: a full ride, Wuber Rocks to your team",
			["text"] = "Ritual Rides logged the ride (/rr log on Anita)",
			["who"] = "Anita",
		}, -- [53]
		{
			["id"] = "s4_1",
			["sec"] = "Test 3: shortcuts and things going wrong",
			["text"] = "Rebook: open /wuber after Test 2 -> a \"Your usual\" card with Ride again at the top of Home.",
			["who"] = "Wuber Rocks",
		}, -- [54]
		{
			["auto"] = {
				"cancel_early", -- [1]
			},
			["id"] = "s4_2",
			["sec"] = "Test 3: shortcuts and things going wrong",
			["text"] = "Cancel: Request, then Cancel ride before Anita accepts -> cancelled on both sides, no invite.",
			["who"] = "Wuber Rocks + Anita",
		}, -- [55]
		{
			["auto"] = {
				"busy_queue", -- [1]
			},
			["id"] = "s4_3",
			["sec"] = "Test 3: shortcuts and things going wrong",
			["text"] = "Driver busy: Lab Tools > Fake drivers, book the busy one -> you can book and see your place in the queue.",
			["who"] = "Wuber Rocks",
		}, -- [56]
		{
			["auto"] = {
				"combat_request", -- [1]
			},
			["id"] = "s4_4",
			["sec"] = "Test 3: shortcuts and things going wrong",
			["text"] = "Combat: Request while fighting a mob -> Wuber waits or tells you to finish the fight; no Lua error.",
			["who"] = "Wuber Rocks",
		}, -- [57]
		{
			["auto"] = {
				"map_ctrl", -- [1]
				"map_button", -- [2]
			},
			["id"] = "s4_5",
			["sec"] = "Test 3: shortcuts and things going wrong",
			["text"] = "Book from map: world map, hover the team's town, Ctrl-click (and try the Ride here button) -> booking screen for that place.",
			["who"] = "Wuber Rocks",
		}, -- [58]
		{
			["auto"] = {
				"driver_offline", -- [1]
			},
			["id"] = "s4_6",
			["sec"] = "Test 3: shortcuts and things going wrong",
			["text"] = "Driver offline: Request, then log Anita out -> Wuber Rocks says the driver went offline and lets you pick again.",
			["who"] = "Wuber Rocks + Anita",
		}, -- [59]
		{
			["auto"] = {
				"rr_lowfare", -- [1]
			},
			["id"] = "s4_7",
			["sec"] = "Test 3: shortcuts and things going wrong",
			["text"] = "Price below 50s: on Anita /rr price 30s -> Anita disappears from Wuber with a message to set 50s. Set it back.",
			["who"] = "Anita",
		}, -- [60]
		{
			["auto"] = {
				"hidden", -- [1]
			},
			["id"] = "s4_8",
			["sec"] = "Test 3: shortcuts and things going wrong",
			["text"] = "Hide a driver: right-click a card, Hide -> the card goes; Settings > Hidden drivers brings it back.",
			["who"] = "Wuber Rocks",
		}, -- [61]
		{
			["auto"] = {
				"fav_toast", -- [1]
			},
			["id"] = "s4_9",
			["sec"] = "Test 3: shortcuts and things going wrong",
			["text"] = "Favourite: heart on Anita's card, log Anita out and back in -> a toast on Wuber Rocks: Anita is online.",
			["who"] = "Wuber Rocks + Anita",
		}, -- [62]
		{
			["id"] = "s5_1",
			["sec"] = "Test 4: looks and fun (judged by eye)",
			["text"] = "On Wuber Rocks, Settings > Turn on friendly nameplates. Near the team: a spinning gold crown over Anita, Farra and Hayley.",
			["who"] = "Wuber Rocks",
		}, -- [63]
		{
			["id"] = "s5_2",
			["sec"] = "Test 4: looks and fun (judged by eye)",
			["text"] = "Mouse over Anita: tooltip says \"Wuber founder\".",
			["who"] = "Wuber Rocks",
		}, -- [64]
		{
			["id"] = "s5_3",
			["sec"] = "Test 4: looks and fun (judged by eye)",
			["text"] = "Anita's card on Home: gold-violet border, crown, Founder chip, shimmer every few seconds.",
			["who"] = "Wuber Rocks",
		}, -- [65]
		{
			["id"] = "s5_4",
			["sec"] = "Test 4: looks and fun (judged by eye)",
			["text"] = "World map: Anita's pin bigger, crowned, sparkling; dotted route line flowing to it during a ride.",
			["who"] = "Wuber Rocks",
		}, -- [66]
		{
			["id"] = "s5_5",
			["sec"] = "Test 4: looks and fun (judged by eye)",
			["text"] = "Settings > Effects: try Full, Light and Off during a ride.",
			["who"] = "Wuber Rocks",
		}, -- [67]
		{
			["auto"] = {
				"fx_paid", -- [1]
				"fx_coins", -- [2]
			},
			["id"] = "s5_6",
			["sec"] = "Test 4: looks and fun (judged by eye)",
			["text"] = "On Anita: a small burst when paid; a 5-star rating shows a coin shower.",
			["who"] = "Anita",
		}, -- [68]
		{
			["check"] = true,
			["id"] = "s5_c1",
			["sec"] = "Test 4: looks and fun (judged by eye)",
			["text"] = "Crowns over the team's heads",
			["who"] = "Wuber Rocks",
		}, -- [69]
		{
			["check"] = true,
			["id"] = "s5_c2",
			["sec"] = "Test 4: looks and fun (judged by eye)",
			["text"] = "Founder card shimmer and glow look right",
			["who"] = "Wuber Rocks",
		}, -- [70]
		{
			["check"] = true,
			["id"] = "s5_c3",
			["sec"] = "Test 4: looks and fun (judged by eye)",
			["text"] = "Map pin and route line",
			["who"] = "Wuber Rocks",
		}, -- [71]
		{
			["check"] = true,
			["id"] = "s5_c4",
			["sec"] = "Test 4: looks and fun (judged by eye)",
			["text"] = "Effects look good, not blocky or with dark edges",
			["who"] = "Wuber Rocks",
		}, -- [72]
		{
			["auto"] = true,
			["id"] = "s6_1",
			["sec"] = "When you're done",
			["text"] = "Log out of all four characters normally (not Alt-F4) so WoW saves the logs, then tell the person running the test \"done\".",
			["who"] = "all four",
		}, -- [73]
		{
			["id"] = "s6_2",
			["sec"] = "When you're done",
			["text"] = "Also send: the Check my game screenshot, screenshots of anything that looked wrong, any red Lua error text.",
			["who"] = "you",
		}, -- [74]
	},
	["results"] = {
		["photo_tour"] = {
			["at"] = 1794943136.1,
			["r"] = "pass",
			["sid"] = "6afca83b37",
			["ver"] = "2.2.1",
			["w"] = "Anita Lift",
			["why"] = "25 screenshots",
		},
		["raid_arrive"] = {
			["at"] = 1794943092.1,
			["r"] = "pass",
			["sid"] = "6afca83b37",
			["ver"] = "2.2.1",
			["w"] = "Wuber Rocks",
			["why"] = "summoned, counted, off the list",
		},
		["raid_ask"] = {
			["at"] = 1794943086.1,
			["r"] = "pass",
			["sid"] = "6afca83b37",
			["ver"] = "2.2.1",
			["w"] = "Wuber Rocks",
			["why"] = "Wuber Rocks queued (queued)",
		},
		["raid_away"] = {
			["at"] = 1794943084.6,
			["r"] = "pass",
			["sid"] = "6afca83b37",
			["ver"] = "2.2.1",
			["w"] = "Wuber Rocks",
			["why"] = "Wuber Rocks is away from the spot (Orgrimmar)",
		},
		["raid_button"] = {
			["at"] = 1794943086.1,
			["r"] = "pass",
			["sid"] = "6afca83b37",
			["ver"] = "2.2.1",
			["w"] = "Anita Lift",
			["why"] = "it says 'Summon Wuber' (docked on top (FULLSCREEN_DIALOG over HIGH))",
		},
		["raid_cast"] = {
			["at"] = 1794943086.6,
			["r"] = "pass",
			["sid"] = "6afca83b37",
			["ver"] = "2.2.1",
			["w"] = "Anita Lift",
			["why"] = "Anita's ritual started on Wuber Rocks (pretend)",
		},
		["raid_convert"] = {
			["at"] = 1794943078.1,
			["r"] = "pass",
			["sid"] = "6afca83b37",
			["ver"] = "2.2.1",
			["w"] = "Anita Lift",
			["why"] = "a raid",
		},
		["raid_invite"] = {
			["at"] = 1794943070.6,
			["r"] = "pass",
			["sid"] = "6afca83b37",
			["ver"] = "2.2.1",
			["w"] = "Anita Lift",
			["why"] = "the invite reached Wuber Rocks",
		},
		["raid_join"] = {
			["at"] = 1794943073.6,
			["r"] = "pass",
			["sid"] = "6afca83b37",
			["ver"] = "2.2.1",
			["w"] = "Wuber Rocks",
			["why"] = "in Anita's group",
		},
		["raid_nvm"] = {
			["at"] = 1794943085.6,
			["r"] = "pass",
			["sid"] = "6afca83b37",
			["ver"] = "2.2.1",
			["w"] = "Wuber Rocks",
			["why"] = "dropped from the list",
		},
		["raid_one"] = {
			["at"] = 1794943092.3,
			["r"] = "pass",
			["sid"] = "6afca83b37",
			["ver"] = "2.2.1",
			["w"] = "Anita Lift",
			["why"] = "Farra's and Hayley's buttons and rituals left Wuber Rocks alone",
		},
		["raid_portal1"] = {
			["at"] = 1794943086.7,
			["r"] = "skip",
			["sid"] = "6afca83b37",
			["ver"] = "2.2.1",
			["w"] = "Farra Way",
			["why"] = "test mode: the pretend ritual needs no portal clicks",
		},
		["raid_portal2"] = {
			["at"] = 1794943086.8,
			["r"] = "skip",
			["sid"] = "6afca83b37",
			["ver"] = "2.2.1",
			["w"] = "Hayley Cab",
			["why"] = "test mode: the pretend ritual needs no portal clicks",
		},
		["raid_start"] = {
			["at"] = 1794943080.6,
			["r"] = "pass",
			["sid"] = "6afca83b37",
			["ver"] = "2.2.1",
			["w"] = "Anita Lift",
			["why"] = "raid summons on, 3 summoners",
		},
		["raid_stop"] = {
			["at"] = 1794943093.1,
			["r"] = "pass",
			["sid"] = "6afca83b37",
			["ver"] = "2.2.1",
			["w"] = "Anita Lift",
			["why"] = "raid summons stopped",
		},
		["raid_tap"] = {
			["at"] = 1794943085.1,
			["r"] = "pass",
			["sid"] = "6afca83b37",
			["ver"] = "2.2.1",
			["w"] = "Wuber Rocks",
			["why"] = "queued from the app (Request a summon)",
		},
		["raid_window"] = {
			["at"] = 1794943083.6,
			["r"] = "pass",
			["sid"] = "6afca83b37",
			["ver"] = "2.2.1",
			["w"] = "Anita Lift",
			["why"] = "window open, big button docked on top (FULLSCREEN_DIALOG over HIGH)",
		},
		["ride_arrive"] = {
			["at"] = 1794943053.5,
			["r"] = "pass",
			["sid"] = "6afca83b37",
			["ver"] = "2.2.1",
			["w"] = "Wuber Rocks",
			["why"] = "arrived (arrived)",
		},
		["ride_beacon"] = {
			["at"] = 1794943042.1,
			["r"] = "pass",
			["sid"] = "6afca83b37",
			["ver"] = "2.2.1",
			["w"] = "Anita Lift",
			["why"] = "beacon open: 50s to Undercity",
		},
		["ride_button"] = {
			["at"] = 1794943047.2,
			["r"] = "pass",
			["sid"] = "6afca83b37",
			["ver"] = "2.2.1",
			["w"] = "Anita Lift",
			["why"] = "it says 'Summon Wuber' (floating, MEDIUM)",
		},
		["ride_cast"] = {
			["at"] = 1794943048.1,
			["r"] = "pass",
			["sid"] = "6afca83b37",
			["ver"] = "2.2.1",
			["w"] = "Anita Lift",
			["why"] = "the ritual started on Wuber Rocks (pretend)",
		},
		["ride_confirm"] = {
			["at"] = 1794943043,
			["r"] = "pass",
			["sid"] = "6afca83b37",
			["ver"] = "2.2.1",
			["w"] = "Wuber Rocks",
			["why"] = "the confirm screen for Anita",
		},
		["ride_done"] = {
			["at"] = 1794943057.4,
			["r"] = "pass",
			["sid"] = "6afca83b37",
			["ver"] = "2.2.1",
			["w"] = "Wuber Rocks",
			["why"] = "done, paid 50s",
		},
		["ride_earnings"] = {
			["at"] = 1794943070.6,
			["r"] = "look",
			["sid"] = "6afca83b37",
			["ver"] = "2.2.1",
			["w"] = "Anita Lift",
			["why"] = "screenshot 1: Earnings with today's ride",
		},
		["ride_invited"] = {
			["at"] = 1794943046.7,
			["r"] = "pass",
			["sid"] = "6afca83b37",
			["ver"] = "2.2.1",
			["w"] = "Wuber Rocks",
			["why"] = "joined Anita's group with no click",
		},
		["ride_landed"] = {
			["at"] = 1794943053.7,
			["r"] = "pass",
			["sid"] = "6afca83b37",
			["ver"] = "2.2.1",
			["w"] = "Anita Lift",
			["why"] = "Wuber Rocks counts as here (arrived)",
		},
		["ride_left"] = {
			["at"] = 1794943060,
			["r"] = "pass",
			["sid"] = "6afca83b37",
			["ver"] = "2.2.1",
			["w"] = "Wuber Rocks",
			["why"] = "left the group with no click",
		},
		["ride_open"] = {
			["at"] = 1794943040.6,
			["r"] = "pass",
			["sid"] = "6afca83b37",
			["ver"] = "2.2.1",
			["w"] = "Anita Lift",
			["why"] = "open, selling at 50s",
		},
		["ride_paid"] = {
			["at"] = 1794943057.4,
			["r"] = "pass",
			["sid"] = "6afca83b37",
			["ver"] = "2.2.1",
			["w"] = "Anita Lift",
			["why"] = "paid 50s by Wuber Rocks",
		},
		["ride_portal1"] = {
			["at"] = 1794943048.2,
			["r"] = "skip",
			["sid"] = "6afca83b37",
			["ver"] = "2.2.1",
			["w"] = "Farra Way",
			["why"] = "test mode: the pretend ritual needs no portal clicks",
		},
		["ride_portal2"] = {
			["at"] = 1794943048.3,
			["r"] = "skip",
			["sid"] = "6afca83b37",
			["ver"] = "2.2.1",
			["w"] = "Hayley Cab",
			["why"] = "test mode: the pretend ritual needs no portal clicks",
		},
		["ride_rate"] = {
			["at"] = 1794943065,
			["r"] = "pass",
			["sid"] = "6afca83b37",
			["ver"] = "2.2.1",
			["w"] = "Wuber Rocks",
			["why"] = "rated 5 stars",
		},
		["ride_request"] = {
			["at"] = 1794943046.5,
			["r"] = "pass",
			["sid"] = "6afca83b37",
			["ver"] = "2.2.1",
			["w"] = "Wuber Rocks",
			["why"] = "booked; whispered 'WTB summon to Undercity for 50s'",
		},
		["ride_seen"] = {
			["at"] = 1794943042.1,
			["r"] = "pass",
			["sid"] = "6afca83b37",
			["ver"] = "2.2.1",
			["w"] = "Wuber Rocks",
			["why"] = "Anita listed (open, 50s)",
		},
		["ride_taken"] = {
			["at"] = 1794943046.7,
			["r"] = "pass",
			["sid"] = "6afca83b37",
			["ver"] = "2.2.1",
			["w"] = "Anita Lift",
			["why"] = "Wuber Rocks is in Anita's queue (joined)",
		},
		["ride_thanks"] = {
			["at"] = 1794943070.6,
			["r"] = "pass",
			["sid"] = "6afca83b37",
			["ver"] = "2.2.1",
			["w"] = "Anita Lift",
			["why"] = "thank-you whisper sent to Wuber Rocks",
		},
		["ride_trade"] = {
			["at"] = 1794943056,
			["r"] = "pass",
			["sid"] = "6afca83b37",
			["ver"] = "2.2.1",
			["w"] = "Wuber Rocks",
			["why"] = "put in 50s and pressed Trade",
		},
	},
	["run"] = {
		["by"] = "Anita Lift",
		["ended"] = 1794943136.1,
		["index"] = 38,
		["results"] = {
			["photo_tour"] = {
				["at"] = 1794943136.1,
				["judge"] = "Anita Lift",
				["r"] = "pass",
				["took"] = 43,
				["who"] = "Anita Lift",
				["why"] = "25 screenshots",
			},
			["raid_arrive"] = {
				["at"] = 1794943092.1,
				["judge"] = "Anita Lift",
				["r"] = "pass",
				["took"] = 5.2,
				["who"] = "Wuber Rocks",
				["why"] = "summoned, counted, off the list",
			},
			["raid_ask"] = {
				["at"] = 1794943086.1,
				["judge"] = "Anita Lift",
				["r"] = "pass",
				["took"] = 0.5,
				["who"] = "Wuber Rocks",
				["why"] = "Wuber Rocks queued (queued)",
			},
			["raid_away"] = {
				["at"] = 1794943084.6,
				["judge"] = "Anita Lift",
				["r"] = "pass",
				["took"] = 1,
				["who"] = "Wuber Rocks",
				["why"] = "Wuber Rocks is away from the spot (Orgrimmar)",
			},
			["raid_button"] = {
				["at"] = 1794943086.1,
				["judge"] = "Anita Lift",
				["r"] = "pass",
				["took"] = 0,
				["who"] = "Anita Lift",
				["why"] = "it says 'Summon Wuber' (docked on top (FULLSCREEN_DIALOG over HIGH))",
			},
			["raid_cast"] = {
				["at"] = 1794943086.6,
				["judge"] = "Anita Lift",
				["r"] = "pass",
				["took"] = 0.5,
				["who"] = "Anita Lift",
				["why"] = "Anita's ritual started on Wuber Rocks (pretend)",
			},
			["raid_convert"] = {
				["at"] = 1794943078.1,
				["judge"] = "Anita Lift",
				["r"] = "pass",
				["took"] = 0.9,
				["who"] = "Anita Lift",
				["why"] = "a raid",
			},
			["raid_invite"] = {
				["at"] = 1794943070.6,
				["judge"] = "Wuber Rocks",
				["r"] = "pass",
				["took"] = 0,
				["who"] = "Anita Lift",
				["why"] = "the invite reached Wuber Rocks",
			},
			["raid_join"] = {
				["at"] = 1794943073.6,
				["judge"] = "Wuber Rocks",
				["r"] = "pass",
				["took"] = 3,
				["who"] = "Wuber Rocks",
				["why"] = "in Anita's group",
			},
			["raid_nvm"] = {
				["at"] = 1794943085.6,
				["judge"] = "Anita Lift",
				["r"] = "pass",
				["took"] = 0.5,
				["who"] = "Wuber Rocks",
				["why"] = "dropped from the list",
			},
			["raid_one"] = {
				["at"] = 1794943092.3,
				["judge"] = "Anita Lift",
				["r"] = "pass",
				["took"] = 0.2,
				["who"] = "Anita Lift",
				["why"] = "Farra's and Hayley's buttons and rituals left Wuber Rocks alone",
			},
			["raid_portal1"] = {
				["at"] = 1794943086.7,
				["judge"] = "Farra Way",
				["r"] = "skip",
				["took"] = 0,
				["who"] = "Farra Way",
				["why"] = "test mode: the pretend ritual needs no portal clicks",
			},
			["raid_portal2"] = {
				["at"] = 1794943086.8,
				["judge"] = "Hayley Cab",
				["r"] = "skip",
				["took"] = 0,
				["who"] = "Hayley Cab",
				["why"] = "test mode: the pretend ritual needs no portal clicks",
			},
			["raid_start"] = {
				["at"] = 1794943080.6,
				["judge"] = "Anita Lift",
				["r"] = "pass",
				["took"] = 2.5,
				["who"] = "Anita Lift",
				["why"] = "raid summons on, 3 summoners",
			},
			["raid_stop"] = {
				["at"] = 1794943093.1,
				["judge"] = "Anita Lift",
				["r"] = "pass",
				["took"] = 0.8,
				["who"] = "Anita Lift",
				["why"] = "raid summons stopped",
			},
			["raid_tap"] = {
				["at"] = 1794943085.1,
				["judge"] = "Anita Lift",
				["r"] = "pass",
				["took"] = 0.5,
				["who"] = "Wuber Rocks",
				["why"] = "queued from the app (Request a summon)",
			},
			["raid_window"] = {
				["at"] = 1794943083.6,
				["judge"] = "Anita Lift",
				["r"] = "pass",
				["took"] = 3,
				["who"] = "Anita Lift",
				["why"] = "window open, big button docked on top (FULLSCREEN_DIALOG over HIGH)",
			},
			["ride_arrive"] = {
				["at"] = 1794943053.5,
				["judge"] = "Wuber Rocks",
				["r"] = "pass",
				["took"] = 5.2000000000003,
				["who"] = "Wuber Rocks",
				["why"] = "arrived (arrived)",
			},
			["ride_beacon"] = {
				["at"] = 1794943042.1,
				["judge"] = "Anita Lift",
				["r"] = "pass",
				["took"] = 0,
				["who"] = "Anita Lift",
				["why"] = "beacon open: 50s to Undercity",
			},
			["ride_button"] = {
				["at"] = 1794943047.2,
				["judge"] = "Anita Lift",
				["r"] = "pass",
				["took"] = 0,
				["who"] = "Anita Lift",
				["why"] = "it says 'Summon Wuber' (floating, MEDIUM)",
			},
			["ride_cast"] = {
				["at"] = 1794943048.1,
				["judge"] = "Anita Lift",
				["r"] = "pass",
				["took"] = 0.9,
				["who"] = "Anita Lift",
				["why"] = "the ritual started on Wuber Rocks (pretend)",
			},
			["ride_confirm"] = {
				["at"] = 1794943043,
				["judge"] = "Wuber Rocks",
				["r"] = "pass",
				["took"] = 0.90000000000009,
				["who"] = "Wuber Rocks",
				["why"] = "the confirm screen for Anita",
			},
			["ride_done"] = {
				["at"] = 1794943057.4,
				["judge"] = "Wuber Rocks",
				["r"] = "pass",
				["took"] = 0,
				["who"] = "Wuber Rocks",
				["why"] = "done, paid 50s",
			},
			["ride_earnings"] = {
				["at"] = 1794943070.6,
				["judge"] = "Anita Lift",
				["r"] = "look",
				["took"] = 0,
				["who"] = "Anita Lift",
				["why"] = "screenshot 1: Earnings with today's ride",
			},
			["ride_invited"] = {
				["at"] = 1794943046.7,
				["judge"] = "Wuber Rocks",
				["r"] = "pass",
				["took"] = 0,
				["who"] = "Wuber Rocks",
				["why"] = "joined Anita's group with no click",
			},
			["ride_landed"] = {
				["at"] = 1794943053.7,
				["judge"] = "Anita Lift",
				["r"] = "pass",
				["took"] = 0,
				["who"] = "Anita Lift",
				["why"] = "Wuber Rocks counts as here (arrived)",
			},
			["ride_left"] = {
				["at"] = 1794943060,
				["judge"] = "Wuber Rocks",
				["r"] = "pass",
				["took"] = 2.6000000000001,
				["who"] = "Wuber Rocks",
				["why"] = "left the group with no click",
			},
			["ride_open"] = {
				["at"] = 1794943040.6,
				["judge"] = "Anita Lift",
				["r"] = "pass",
				["took"] = 5.5,
				["who"] = "Anita Lift",
				["why"] = "open, selling at 50s",
			},
			["ride_paid"] = {
				["at"] = 1794943057.4,
				["judge"] = "Anita Lift",
				["r"] = "pass",
				["took"] = 1.2,
				["who"] = "Anita Lift",
				["why"] = "paid 50s by Wuber Rocks",
			},
			["ride_portal1"] = {
				["at"] = 1794943048.2,
				["judge"] = "Farra Way",
				["r"] = "skip",
				["took"] = 0,
				["who"] = "Farra Way",
				["why"] = "test mode: the pretend ritual needs no portal clicks",
			},
			["ride_portal2"] = {
				["at"] = 1794943048.3,
				["judge"] = "Hayley Cab",
				["r"] = "skip",
				["took"] = 0,
				["who"] = "Hayley Cab",
				["why"] = "test mode: the pretend ritual needs no portal clicks",
			},
			["ride_rate"] = {
				["at"] = 1794943065,
				["judge"] = "Wuber Rocks",
				["r"] = "pass",
				["took"] = 5,
				["who"] = "Wuber Rocks",
				["why"] = "rated 5 stars",
			},
			["ride_request"] = {
				["at"] = 1794943046.5,
				["judge"] = "Wuber Rocks",
				["r"] = "pass",
				["took"] = 3.5,
				["who"] = "Wuber Rocks",
				["why"] = "booked; whispered 'WTB summon to Undercity for 50s'",
			},
			["ride_seen"] = {
				["at"] = 1794943042.1,
				["judge"] = "Wuber Rocks",
				["r"] = "pass",
				["took"] = 0,
				["who"] = "Wuber Rocks",
				["why"] = "Anita listed (open, 50s)",
			},
			["ride_taken"] = {
				["at"] = 1794943046.7,
				["judge"] = "Anita Lift",
				["r"] = "pass",
				["took"] = 0,
				["who"] = "Anita Lift",
				["why"] = "Wuber Rocks is in Anita's queue (joined)",
			},
			["ride_thanks"] = {
				["at"] = 1794943070.6,
				["judge"] = "Anita Lift",
				["r"] = "pass",
				["took"] = 0.4,
				["who"] = "Anita Lift",
				["why"] = "thank-you whisper sent to Wuber Rocks",
			},
			["ride_trade"] = {
				["at"] = 1794943056,
				["judge"] = "Wuber Rocks",
				["r"] = "pass",
				["took"] = 2.3000000000002,
				["who"] = "Wuber Rocks",
				["why"] = "put in 50s and pressed Trade",
			},
		},
		["sid"] = "6afca83b37",
		["sim"] = true,
		["started"] = 1794943035.1,
		["steps"] = {
			"ride_open", -- [1]
			"ride_beacon", -- [2]
			"ride_seen", -- [3]
			"ride_confirm", -- [4]
			"ride_request", -- [5]
			"ride_taken", -- [6]
			"ride_invited", -- [7]
			"ride_button", -- [8]
			"ride_cast", -- [9]
			"ride_portal1", -- [10]
			"ride_portal2", -- [11]
			"ride_arrive", -- [12]
			"ride_landed", -- [13]
			"ride_trade", -- [14]
			"ride_paid", -- [15]
			"ride_done", -- [16]
			"ride_left", -- [17]
			"ride_rate", -- [18]
			"ride_thanks", -- [19]
			"ride_earnings", -- [20]
			"raid_invite", -- [21]
			"raid_join", -- [22]
			"raid_convert", -- [23]
			"raid_start", -- [24]
			"raid_window", -- [25]
			"raid_away", -- [26]
			"raid_tap", -- [27]
			"raid_nvm", -- [28]
			"raid_ask", -- [29]
			"raid_button", -- [30]
			"raid_cast", -- [31]
			"raid_portal1", -- [32]
			"raid_portal2", -- [33]
			"raid_arrive", -- [34]
			"raid_one", -- [35]
			"raid_stop", -- [36]
			"photo_tour", -- [37]
		},
		["why"] = "done",
	},
	["runs"] = {
		{
			["by"] = "Anita Lift",
			["ended"] = 1794943136.1,
			["fail"] = 0,
			["lab"] = "1.1.0",
			["lines"] = {
				"ride_open|Anita Lift|pass|open, selling at 50s|1794943040.600|5.5|Anita Lift|Anita open", -- [1]
				"ride_beacon|Anita Lift|pass|beacon open: 50s to Undercity|1794943042.100|0.0|Anita Lift|Beacon open", -- [2]
				"ride_seen|Wuber Rocks|pass|Anita listed (open, 50s)|1794943042.100|0.0|Wuber Rocks|Anita on Home", -- [3]
				"ride_confirm|Wuber Rocks|pass|the confirm screen for Anita|1794943043.000|0.9|Wuber Rocks|Confirm screen", -- [4]
				"ride_request|Wuber Rocks|pass|booked; whispered 'WTB summon to Undercity for 50s'|1794943046.500|3.5|Wuber Rocks|Request", -- [5]
				"ride_taken|Anita Lift|pass|Wuber Rocks is in Anita's queue (joined)|1794943046.700|0.0|Anita Lift|Request reaches Anita", -- [6]
				"ride_invited|Wuber Rocks|pass|joined Anita's group with no click|1794943046.700|0.0|Wuber Rocks|Invite taken", -- [7]
				"ride_button|Anita Lift|pass|it says 'Summon Wuber' (floating, MEDIUM)|1794943047.200|0.0|Anita Lift|Big button: Summon", -- [8]
				"ride_cast|Anita Lift|pass|the ritual started on Wuber Rocks (pretend)|1794943048.100|0.9|Anita Lift|The summon starts", -- [9]
				"ride_portal1|Farra Way|skip|test mode: the pretend ritual needs no portal clicks|1794943048.200|0.0|Farra Way|Farra clicks", -- [10]
				"ride_portal2|Hayley Cab|skip|test mode: the pretend ritual needs no portal clicks|1794943048.300|0.0|Hayley Cab|Hayley clicks", -- [11]
				"ride_arrive|Wuber Rocks|pass|arrived (arrived)|1794943053.500|5.2|Wuber Rocks|Summon accepted", -- [12]
				"ride_landed|Anita Lift|pass|Wuber Rocks counts as here (arrived)|1794943053.700|0.0|Anita Lift|Anita sees the arrival", -- [13]
				"ride_trade|Wuber Rocks|pass|put in 50s and pressed Trade|1794943056.000|2.3|Wuber Rocks|Rider pays", -- [14]
				"ride_paid|Anita Lift|pass|paid 50s by Wuber Rocks|1794943057.400|1.2|Anita Lift|Anita takes the fare", -- [15]
				"ride_done|Wuber Rocks|pass|done, paid 50s|1794943057.400|0.0|Wuber Rocks|Rider's ride paid", -- [16]
				"ride_left|Wuber Rocks|pass|left the group with no click|1794943060.000|2.6|Wuber Rocks|Left the group", -- [17]
				"ride_rate|Wuber Rocks|pass|rated 5 stars|1794943065.000|5.0|Wuber Rocks|Rating", -- [18]
				"ride_thanks|Anita Lift|pass|thank-you whisper sent to Wuber Rocks|1794943070.600|0.4|Anita Lift|Thank-you whisper", -- [19]
				"ride_earnings|Anita Lift|look|screenshot 1: Earnings with today's ride|1794943070.600|0.0|Anita Lift|Earnings (look)", -- [20]
				"raid_invite|Anita Lift|pass|the invite reached Wuber Rocks|1794943070.600|0.0|Wuber Rocks|Invite the rider", -- [21]
				"raid_join|Wuber Rocks|pass|in Anita's group|1794943073.600|3.0|Wuber Rocks|Rider joins", -- [22]
				"raid_convert|Anita Lift|pass|a raid|1794943078.100|0.9|Anita Lift|Make it a raid", -- [23]
				"raid_start|Anita Lift|pass|raid summons on, 3 summoners|1794943080.600|2.5|Anita Lift|Raid summons on", -- [24]
				"raid_window|Anita Lift|pass|window open, big button docked on top (FULLSCREEN_DIALOG over HIGH)|1794943083.600|3.0|Anita Lift|Window open, button on top", -- [25]
				"raid_away|Wuber Rocks|pass|Wuber Rocks is away from the spot (Orgrimmar)|1794943084.600|1.0|Anita Lift|Rider away from the spot", -- [26]
				"raid_tap|Wuber Rocks|pass|queued from the app (Request a summon)|1794943085.100|0.5|Anita Lift|Request from the app", -- [27]
				"raid_nvm|Wuber Rocks|pass|dropped from the list|1794943085.600|0.5|Anita Lift|nvm drops", -- [28]
				"raid_ask|Wuber Rocks|pass|Wuber Rocks queued (queued)|1794943086.100|0.5|Anita Lift|123 in raid chat", -- [29]
				"raid_button|Anita Lift|pass|it says 'Summon Wuber' (docked on top (FULLSCREEN_DIALOG over HIGH))|1794943086.100|0.0|Anita Lift|Big button: Summon", -- [30]
				"raid_cast|Anita Lift|pass|Anita's ritual started on Wuber Rocks (pretend)|1794943086.600|0.5|Anita Lift|Anita summons the raider", -- [31]
				"raid_portal1|Farra Way|skip|test mode: the pretend ritual needs no portal clicks|1794943086.700|0.0|Farra Way|Farra clicks", -- [32]
				"raid_portal2|Hayley Cab|skip|test mode: the pretend ritual needs no portal clicks|1794943086.800|0.0|Hayley Cab|Hayley clicks", -- [33]
				"raid_arrive|Wuber Rocks|pass|summoned, counted, off the list|1794943092.100|5.2|Anita Lift|Raider summoned", -- [34]
				"raid_one|Anita Lift|pass|Farra's and Hayley's buttons and rituals left Wuber Rocks alone|1794943092.300|0.2|Anita Lift|Nobody else took the raider", -- [35]
				"raid_stop|Anita Lift|pass|raid summons stopped|1794943093.100|0.8|Anita Lift|Stop", -- [36]
				"photo_tour|Anita Lift|pass|25 screenshots|1794943136.100|43.0|Anita Lift|Photo tour", -- [37]
			},
			["look"] = 1,
			["n"] = 37,
			["pass"] = 32,
			["sid"] = "6afca83b37",
			["sim"] = true,
			["skip"] = 4,
			["started"] = 1794943035.1,
			["todo"] = 0,
			["why"] = "done",
			["wuber"] = "2.2.1",
		}, -- [1]
	},
	["seenLab"] = {
		["anita lift"] = 1794943008.2,
		["farra way"] = 1794943008.2,
		["hayley cab"] = 1794943008.2,
	},
	["v"] = 1,
}
