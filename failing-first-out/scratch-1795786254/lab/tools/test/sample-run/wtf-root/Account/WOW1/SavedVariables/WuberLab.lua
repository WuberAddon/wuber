
WuberLabDB = {
	["chars"] = {
		["Farra Way"] = {
			["checks"] = {
			},
			["dropped"] = 0,
			["lastLogin"] = 1794943000,
			["lines"] = {
				"1794943000.000|Farra Way|fire|ENGINE Wuber", -- [1]
				"1794943000.000|Farra Way|login|char=Farra Way realm=CAMWOW EU5 Realm 5 PvE role=team build=1.60.1/70938/Nov 12 2026/16001 lab=1.1.0 Wuber=1.0.0 RitualRides=off OpenMap=off Moo=off !BugGrabber=off BugSack=off W.VERSION=2.2.1 channels=4 errhandler=replaced later buggrabber=no", -- [2]
				"1794943000.000|Farra Way|probe|channels=4 wuberIndex=nil (login)", -- [3]
				"1794943000.000|Farra Way|ev|PLAYER_ENTERING_WORLD login=true reload=false", -- [4]
				"1794943000.000|Farra Way|ev|ZONE_CHANGED_NEW_AREA zone=Undercity sub=", -- [5]
				"1794943000.000|Farra Way|try|cap=comm ok=true result=0 combat=false", -- [6]
				"1794943000.000|Farra Way|ev|GROUP_ROSTER_UPDATE members=2 Anita Lift,Hayley Cab", -- [7]
				"1794943000.050|Farra Way|fire|DRIVE ", -- [8]
				"1794943000.100|Farra Way|fire|DRIVE_CREW ", -- [9]
				"1794943000.100|Farra Way|fire|DRIVE_CREW ", -- [10]
				"1794943000.150|Farra Way|fire|DRIVE ", -- [11]
				"1794943000.700|Farra Way|fire|DRIVE_STATIONS ", -- [12]
				"1794943000.700|Farra Way|fire|DRIVE_MODE sell", -- [13]
				"1794943000.700|Farra Way|fire|DRIVE_RAID ", -- [14]
				"1794943000.700|Farra Way|fire|SETTINGS drive={table}", -- [15]
				"1794943000.700|Farra Way|fire|DRIVE_CREW ", -- [16]
				"1794943000.750|Farra Way|fire|DRIVE ", -- [17]
				"1794943001.050|Farra Way|fire|DRIVE ", -- [18]
				"1794943002.000|Farra Way|tool|test mode on (developer only). /lab opens the test plan. Role: team", -- [19]
				"1794943003.000|Farra Way|probe|font Poppins SetFont ok=true returned=true GetFont=Interface\\AddOns\\Wuber\\Media\\fonts\\Poppins-Regular.ttf T.poppins=nil", -- [20]
				"1794943006.000|Farra Way|probe|JoinTemporaryChannel(WuberNet) called combat=false", -- [21]
				"1794943006.000|Farra Way|probe|CheckChannel(true) -> false index=nil channels=4 fails=nil", -- [22]
				"1794943006.050|Farra Way|fire|DRIVE ", -- [23]
				"1794943006.500|Farra Way|fire|NETWORK true", -- [24]
				"1794943006.500|Farra Way|msg>|Q C>5 Q~1", -- [25]
				"1794943006.500|Farra Way|probe|CheckChannel(false) -> true index=5 channels=5 fails=nil", -- [26]
				"1794943006.500|Farra Way|probe|channels=5 wuberIndex=5 (CHANNEL_UI_UPDATE)", -- [27]
				"1794943006.600|Farra Way|msg<|Q C<Anita Lift Q~1", -- [28]
				"1794943006.600|Farra Way|msg<|Q C<Farra Way Q~1", -- [29]
				"1794943006.600|Farra Way|msg<|Q C<Hayley Cab Q~1", -- [30]
				"1794943006.600|Farra Way|msg<|Q C<Wuber Rocks Q~1", -- [31]
				"1794943008.000|Farra Way|self|[login] 14 of 14 passed", -- [32]
				"1794943008.000|Farra Way|run|send RUN~V~2.2.1~1.1.0~1", -- [33]
				"1794943008.000|Farra Way|run|login login_wuber pass: Wuber 2.2.1, lab 1.1.0", -- [34]
				"1794943008.000|Farra Way|run|login login_old_addon pass: the old summoning addon is off", -- [35]
				"1794943008.000|Farra Way|run|login login_prefixes pass: WUBER, WUBERT and WLAB registered", -- [36]
				"1794943008.000|Farra Way|run|login login_channel pass: on Wuber's channel (/5)", -- [37]
				"1794943008.000|Farra Way|run|login login_flights pass: flight prices loaded (Orgrimmar to Thunder Bluff: 50c)", -- [38]
				"1794943008.000|Farra Way|run|login login_settings pass: settings look sane (price 50s)", -- [39]
				"1794943008.000|Farra Way|run|login login_selftest pass: Wuber's self-test: all 14 passed", -- [40]
				"1794943008.000|Farra Way|run|login login_f1 skip: this client can't tell", -- [41]
				"1794943008.000|Farra Way|run|login checks: 13 started", -- [42]
				"1794943008.500|Farra Way|run|login login_versions pass: same versions as Anita, Hayley, Wuber Rocks (2.2.1/1.1.0/1)", -- [43]
				"1794943010.000|Farra Way|plan|s0_1@farra way;ok;by=probe:fresh;who=Farra Way;src=local", -- [44]
				"1794943010.000|Farra Way|probe|plan s0_1 (fresh) on Farra Way: ok", -- [45]
				"1794943010.000|Farra Way|plan|s0_2@farra way;no;by=probe:addons;who=Farra Way;src=local", -- [46]
				"1794943010.000|Farra Way|probe|plan s0_2 (addons) on Farra Way: no", -- [47]
				"1794943010.000|Farra Way|plan|s1_1@farra way;ok;by=probe:fresh;who=Farra Way;src=local", -- [48]
				"1794943010.000|Farra Way|probe|plan s1_1 (fresh) on Farra Way: ok", -- [49]
				"1794943010.000|Farra Way|msg>|Q W>Anita Lift Q~1~1", -- [50]
				"1794943010.100|Farra Way|msg<|Q W<Anita Lift Q~1~1", -- [51]
				"1794943010.600|Farra Way|plan|s0_2@wuber rocks;no;by=probe:addons;who=Wuber Rocks;src=sync", -- [52]
				"1794943010.600|Farra Way|plan|s1_1@wuber rocks;ok;by=probe:fresh;who=Wuber Rocks;src=sync", -- [53]
				"1794943010.600|Farra Way|plan|s0_1@wuber rocks;ok;by=probe:fresh;who=Wuber Rocks;src=sync", -- [54]
				"1794943011.050|Farra Way|fire|DRIVE ", -- [55]
				"1794943011.162|Farra Way|msg<|Q W<Hayley Cab Q~1~1", -- [56]
				"1794943011.207|Farra Way|msg>|Q W>Hayley Cab Q~1~1", -- [57]
				"1794943011.291|Farra Way|msg<|Q W<Wuber Rocks Q~1~1", -- [58]
				"1794943012.100|Farra Way|plan|s0_2@anita lift;no;by=probe:addons;who=Anita Lift;src=sync", -- [59]
				"1794943012.100|Farra Way|plan|s0_1@anita lift;ok;by=probe:fresh;who=Anita Lift;src=sync", -- [60]
				"1794943012.100|Farra Way|plan|s1_1@anita lift;ok;by=probe:fresh;who=Anita Lift;src=sync", -- [61]
				"1794943012.100|Farra Way|plan|s0_2@hayley cab;no;by=probe:addons;who=Hayley Cab;src=sync", -- [62]
				"1794943012.100|Farra Way|plan|s0_1@hayley cab;ok;by=probe:fresh;who=Hayley Cab;src=sync", -- [63]
				"1794943012.100|Farra Way|plan|s1_1@hayley cab;ok;by=probe:fresh;who=Hayley Cab;src=sync", -- [64]
				"1794943012.127|Farra Way|msg>|Q W>Wuber Rocks Q~1~1", -- [65]
				"1794943013.000|Farra Way|run|login login_button pass: the big button is hidden (closed)", -- [66]
				"1794943015.000|Farra Way|comm|not available (no C_Club)", -- [67]
				"1794943015.000|Farra Way|fire|COMMUNITY none", -- [68]
				"1794943015.000|Farra Way|try|cap=comm ok=true result=0 combat=false", -- [69]
				"1794943015.100|Farra Way|fire|DRIVE_CREW ", -- [70]
				"1794943015.100|Farra Way|fire|DRIVE_CREW ", -- [71]
				"1794943015.150|Farra Way|fire|DRIVE ", -- [72]
				"1794943016.050|Farra Way|fire|DRIVE ", -- [73]
				"1794943016.600|Farra Way|plan|s0_1;auto;by=probe;who=Anita Lift;src=sync", -- [74]
				"1794943016.600|Farra Way|plan|s1_1;auto;by=probe;who=Anita Lift;src=sync", -- [75]
				"1794943021.050|Farra Way|fire|DRIVE ", -- [76]
				"1794943022.000|Farra Way|comm|status: Community: not available in this game. state=none index=nil off=false sent=0 heard=0", -- [77]
				"1794943026.050|Farra Way|fire|DRIVE ", -- [78]
				"1794943030.000|Farra Way|try|cap=comm ok=true result=0 combat=false", -- [79]
				"1794943030.100|Farra Way|fire|DRIVE_CREW ", -- [80]
				"1794943030.100|Farra Way|fire|DRIVE_CREW ", -- [81]
				"1794943030.150|Farra Way|fire|DRIVE ", -- [82]
				"1794943031.050|Farra Way|fire|DRIVE ", -- [83]
				"1794943033.000|Farra Way|run|login login_errors pass: no Lua errors since login", -- [84]
				"1794943033.000|Farra Way|run|login login_community skip: Community: not available in this game.", -- [85]
				"1794943033.000|Farra Way|run|login login_saved skip: WuberLabDB came back empty and no other window remembers this one: a first start here", -- [86]
				"1794943036.050|Farra Way|fire|DRIVE ", -- [87]
				"1794943036.100|Farra Way|fire|DRIVE_CREW ", -- [88]
				"1794943036.150|Farra Way|fire|DRIVE ", -- [89]
				"1794943037.100|Farra Way|run|joined run 6afca83b37 by Anita Lift: 37 checks", -- [90]
				"1794943037.100|Farra Way|sim|send Wuber Rocks: SIM~hello", -- [91]
				"1794943037.100|Farra Way|sim|pretend-to-summon ON (no shards needed; nobody is really summoned)", -- [92]
				"1794943037.100|Farra Way|run|step 1/37 ride_open on Anita Lift: open Wuber (/wuber), Drive tab, choose Sell summons and press Open", -- [93]
				"1794943037.150|Farra Way|fire|DRIVE ", -- [94]
				"1794943037.200|Farra Way|sim|peer (test mode on there too): Hayley Cab", -- [95]
				"1794943037.200|Farra Way|sim|send Hayley Cab: SIM~hi", -- [96]
				"1794943037.250|Farra Way|fire|DRIVE ", -- [97]
				"1794943037.300|Farra Way|sim|peer (test mode on there too): Anita Lift", -- [98]
				"1794943037.300|Farra Way|sim|peer (test mode on there too): Wuber Rocks", -- [99]
				"1794943037.350|Farra Way|fire|DRIVE ", -- [100]
				"1794943038.000|Farra Way|try|cap=comm ok=true result=0 combat=false", -- [101]
				"1794943038.100|Farra Way|fire|DRIVE_CREW ", -- [102]
				"1794943038.150|Farra Way|fire|DRIVE ", -- [103]
				"1794943040.100|Farra Way|fire|SETTINGS drive={table}", -- [104]
				"1794943040.100|Farra Way|fire|DRIVE_STATIONS ", -- [105]
				"1794943040.150|Farra Way|fire|DRIVE ", -- [106]
				"1794943041.050|Farra Way|fire|DRIVE ", -- [107]
				"1794943041.100|Farra Way|msg<|D W<Anita Lift D~1~Undercity~1458~500~500~5000~Anita Lift~open~3~7~H~2.2.1~~0~1~CAMWOW EU5 Realm 5 PvE~1", -- [108]
				"1794943041.100|Farra Way|run|ride_open pass Anita Lift: open, selling at 50s (5.5 s)", -- [109]
				"1794943041.100|Farra Way|run|step 2/37 ride_beacon on Anita Lift: Wuber tells riders Anita is open", -- [110]
				"1794943041.200|Farra Way|fire|DRIVERS n=1 anita lift", -- [111]
				"1794943042.050|Farra Way|fire|DRIVE ", -- [112]
				"1794943042.100|Farra Way|plan|s2_1;auto;by=app_open;who=Wuber Rocks;src=sync", -- [113]
				"1794943042.200|Farra Way|run|ride_seen pass Wuber Rocks: Anita listed (open, 50s) (0.0 s)", -- [114]
				"1794943042.200|Farra Way|run|step 4/37 ride_confirm on Wuber Rocks: tap Anita's card", -- [115]
				"1794943043.050|Farra Way|fire|DRIVE ", -- [116]
				"1794943043.100|Farra Way|run|ride_beacon pass Anita Lift: beacon open: 50s to Undercity (0.0 s)", -- [117]
				"1794943043.100|Farra Way|run|ride_confirm pass Wuber Rocks: the confirm screen for Anita (0.9 s)", -- [118]
				"1794943043.100|Farra Way|run|step 5/37 ride_request on Wuber Rocks: press Request summon", -- [119]
				"1794943044.050|Farra Way|fire|DRIVE ", -- [120]
				"1794943045.050|Farra Way|fire|DRIVE ", -- [121]
				"1794943046.050|Farra Way|fire|DRIVE ", -- [122]
				"1794943046.100|Farra Way|fire|DRIVE_STATE Wuber Rocks nil", -- [123]
				"1794943046.100|Farra Way|fire|DRIVE_STATE Wuber Rocks queued", -- [124]
				"1794943046.150|Farra Way|fire|DRIVE ", -- [125]
				"1794943046.200|Farra Way|fire|DRIVE_STATE Wuber Rocks invited", -- [126]
				"1794943046.200|Farra Way|ev|GROUP_ROSTER_UPDATE members=3 Anita Lift,Hayley Cab,Wuber Rocks", -- [127]
				"1794943046.250|Farra Way|fire|DRIVE ", -- [128]
				"1794943046.300|Farra Way|msg<|B W<Wuber Rocks B~1", -- [129]
				"1794943046.600|Farra Way|run|ride_request pass Wuber Rocks: booked; whispered 'WTB summon to Undercity for 50s' (3.5 s)", -- [130]
				"1794943046.600|Farra Way|run|step 6/37 ride_taken on Anita Lift: Anita's Wuber takes the request", -- [131]
				"1794943046.700|Farra Way|run|ride_taken pass Anita Lift: Wuber Rocks is in Anita's queue (joined) (0.0 s)", -- [132]
				"1794943046.700|Farra Way|run|step 7/37 ride_invited on Wuber Rocks: the invite arrives and is taken with no click", -- [133]
				"1794943047.050|Farra Way|fire|DRIVE ", -- [134]
				"1794943047.100|Farra Way|msg<|D W<Anita Lift D~1~Undercity~1458~500~500~5000~Anita Lift~busy~3~6~H~2.2.1~~0~1~CAMWOW EU5 Realm 5 PvE~1", -- [135]
				"1794943047.100|Farra Way|run|ride_invited pass Wuber Rocks: joined Anita's group with no click (0.0 s)", -- [136]
				"1794943047.100|Farra Way|run|step 8/37 ride_button on Anita Lift: the big button offers the summon", -- [137]
				"1794943047.200|Farra Way|run|ride_button pass Anita Lift: it says 'Summon Wuber' (floating, MEDIUM) (0.0 s)", -- [138]
				"1794943047.200|Farra Way|run|step 9/37 ride_cast on Anita Lift: click the big button (it says {button})", -- [139]
				"1794943047.600|Farra Way|fire|DRIVE_STATE Wuber Rocks joined", -- [140]
				"1794943047.600|Farra Way|fire|DRIVE_ALERT Click the summoning portal - Wuber is on the way! portal", -- [141]
				"1794943047.600|Farra Way|ui|toast [portal] Click the summoning portal - Wuber is on the way!", -- [142]
				"1794943047.650|Farra Way|fire|DRIVE ", -- [143]
				"1794943047.941|Farra Way|msg>|K W>Wuber Rocks K~1~Anita Lift", -- [144]
				"1794943048.050|Farra Way|fire|DRIVE ", -- [145]
				"1794943048.100|Farra Way|plan|s3_r3;auto;by=whisper_wtb;who=Wuber Rocks;src=sync", -- [146]
				"1794943048.100|Farra Way|plan|s3_c2;auto;by=auto_accept;who=Wuber Rocks;src=sync", -- [147]
				"1794943048.100|Farra Way|plan|s3_r2;auto;by=confirm_shown;who=Wuber Rocks;src=sync", -- [148]
				"1794943048.100|Farra Way|plan|s3_r5;auto;by=auto_accept;who=Wuber Rocks;src=sync", -- [149]
				"1794943048.100|Farra Way|run|ride_cast pass Anita Lift: the ritual started on Wuber Rocks (pretend) (0.9 s)", -- [150]
				"1794943048.100|Farra Way|run|step 10/37 ride_portal1 on Farra Way: function: 0x56275d8a6780", -- [151]
				"1794943048.100|Farra Way|run|ride_portal1 skip Farra Way: test mode: the pretend ritual needs no portal clicks (0.0 s)", -- [152]
				"1794943048.100|Farra Way|run|send RUN~R~6afca83b37~10~ride_portal1~skip~0.0~Farra Way~test mode: the pretend ritual needs no portal clicks", -- [153]
				"1794943048.100|Farra Way|run|step 11/37 ride_portal2 on Hayley Cab: function: 0x56275d8a6780", -- [154]
				"1794943048.300|Farra Way|run|ride_portal2 skip Hayley Cab: test mode: the pretend ritual needs no portal clicks (0.0 s)", -- [155]
				"1794943048.300|Farra Way|run|step 12/37 ride_arrive on Wuber Rocks: function: 0x56275d875b40", -- [156]
				"1794943049.050|Farra Way|fire|DRIVE ", -- [157]
				"1794943049.488|Farra Way|msg<|K W<Wuber Rocks K~1~Anita Lift", -- [158]
				"1794943050.050|Farra Way|fire|DRIVE ", -- [159]
				"1794943051.050|Farra Way|fire|DRIVE ", -- [160]
				"1794943051.100|Farra Way|fire|DRIVE_CREW ", -- [161]
				"1794943051.150|Farra Way|fire|DRIVE ", -- [162]
				"1794943052.050|Farra Way|fire|DRIVE ", -- [163]
				"1794943052.100|Farra Way|fire|DRIVE_STATE Wuber Rocks summoning", -- [164]
				"1794943052.150|Farra Way|fire|DRIVE ", -- [165]
				"1794943052.700|Farra Way|sim|arrived (pretend): wuber rocks", -- [166]
				"1794943053.000|Farra Way|try|cap=comm ok=true result=0 combat=false", -- [167]
				"1794943053.000|Farra Way|fire|DRIVE_STATE Wuber Rocks waiting", -- [168]
				"1794943053.050|Farra Way|fire|DRIVE ", -- [169]
				"1794943053.100|Farra Way|fire|DRIVE_CREW ", -- [170]
				"1794943053.150|Farra Way|fire|DRIVE ", -- [171]
				"1794943053.600|Farra Way|run|ride_arrive pass Wuber Rocks: arrived (arrived) (5.2 s)", -- [172]
				"1794943053.600|Farra Way|run|step 13/37 ride_landed on Anita Lift: Anita's Wuber sees Wuber Rocks arrive", -- [173]
				"1794943053.700|Farra Way|run|ride_landed pass Anita Lift: Wuber Rocks counts as here (arrived) (0.0 s)", -- [174]
				"1794943053.700|Farra Way|run|step 14/37 ride_trade on Wuber Rocks: function: 0x56275d8af390", -- [175]
				"1794943054.050|Farra Way|fire|DRIVE ", -- [176]
				"1794943055.050|Farra Way|fire|DRIVE ", -- [177]
				"1794943055.600|Farra Way|plan|s3_r4;auto;by=accept_msg;who=Wuber Rocks;src=sync", -- [178]
				"1794943056.050|Farra Way|fire|DRIVE ", -- [179]
				"1794943056.100|Farra Way|run|ride_trade pass Wuber Rocks: put in 50s and pressed Trade (2.3 s)", -- [180]
				"1794943056.100|Farra Way|run|step 15/37 ride_paid on Anita Lift: click the big button (it says {button})", -- [181]
				"1794943057.050|Farra Way|fire|DRIVE ", -- [182]
				"1794943057.100|Farra Way|plan|s3_c1;auto;by=whisper_wtb_in;who=Anita Lift;src=sync", -- [183]
				"1794943057.100|Farra Way|plan|s3_c3;auto;by=ride_arrived+fx_arrival;who=Wuber Rocks;src=sync", -- [184]
				"1794943057.100|Farra Way|plan|s3_r6;auto;by=ride_arrived;who=Wuber Rocks;src=sync", -- [185]
				"1794943057.400|Farra Way|run|ride_paid pass Anita Lift: paid 50s by Wuber Rocks (1.2 s)", -- [186]
				"1794943057.400|Farra Way|run|step 16/37 ride_done on Wuber Rocks: Wuber Rocks' Wuber marks the ride paid", -- [187]
				"1794943057.400|Farra Way|fire|DRIVE_PAID Wuber Rocks 5000 0", -- [188]
				"1794943057.400|Farra Way|fire|DRIVE_LOG ", -- [189]
				"1794943057.400|Farra Way|fire|DRIVE_STATE Wuber Rocks arrived", -- [190]
				"1794943057.400|Farra Way|fire|DRIVE_LOG ", -- [191]
				"1794943057.450|Farra Way|fire|DRIVE ", -- [192]
				"1794943058.050|Farra Way|fire|DRIVE ", -- [193]
				"1794943058.100|Farra Way|msg<|D W<Anita Lift D~1~Undercity~1458~500~500~5000~Anita Lift~open~3~6~H~2.2.1~~0~1~CAMWOW EU5 Realm 5 PvE~1", -- [194]
				"1794943058.100|Farra Way|run|ride_done pass Wuber Rocks: done, paid 50s (0.0 s)", -- [195]
				"1794943058.100|Farra Way|run|step 17/37 ride_left on Wuber Rocks: Wuber Rocks leaves the group by itself", -- [196]
				"1794943058.600|Farra Way|plan|s3_c4;auto;by=pay_exact;who=Wuber Rocks;src=sync", -- [197]
				"1794943059.050|Farra Way|fire|DRIVE ", -- [198]
				"1794943060.000|Farra Way|ev|GROUP_ROSTER_UPDATE members=2 Anita Lift,Hayley Cab", -- [199]
				"1794943060.050|Farra Way|fire|DRIVE ", -- [200]
				"1794943060.100|Farra Way|sim|send Anita Lift: SIM~hi", -- [201]
				"1794943060.100|Farra Way|plan|s3_c5;auto;by=auto_left;who=Wuber Rocks;src=sync", -- [202]
				"1794943061.000|Farra Way|fire|DRIVE_LOG ", -- [203]
				"1794943061.050|Farra Way|fire|DRIVE ", -- [204]
				"1794943062.050|Farra Way|fire|DRIVE ", -- [205]
				"1794943063.050|Farra Way|fire|DRIVE ", -- [206]
				"1794943063.100|Farra Way|msg<|D W<Anita Lift D~1~Undercity~1458~500~500~5000~Anita Lift~open~3~7~H~2.2.1~~0~1~CAMWOW EU5 Realm 5 PvE~1", -- [207]
				"1794943064.050|Farra Way|fire|DRIVE ", -- [208]
				"1794943065.050|Farra Way|fire|DRIVE ", -- [209]
				"1794943066.050|Farra Way|fire|DRIVE ", -- [210]
				"1794943066.100|Farra Way|plan|s3_r8;auto;by=auto_left+rated+milestone_pop;who=Wuber Rocks;src=sync", -- [211]
				"1794943066.100|Farra Way|plan|s3_c6;auto;by=milestone_pop+rated;who=Wuber Rocks;src=sync", -- [212]
				"1794943066.100|Farra Way|fire|DRIVE_CREW ", -- [213]
				"1794943066.150|Farra Way|fire|DRIVE ", -- [214]
				"1794943067.050|Farra Way|fire|DRIVE ", -- [215]
				"1794943067.100|Farra Way|run|ride_left pass Wuber Rocks: left the group with no click (2.6 s)", -- [216]
				"1794943067.100|Farra Way|run|step 18/37 ride_rate on Wuber Rocks: tap 5 stars on the Done screen", -- [217]
				"1794943067.600|Farra Way|plan|s5_6;auto;by=fx_paid+fx_coins;who=Anita Lift;src=sync", -- [218]
				"1794943068.000|Farra Way|try|cap=comm ok=true result=0 combat=false", -- [219]
				"1794943068.050|Farra Way|fire|DRIVE ", -- [220]
				"1794943068.100|Farra Way|fire|DRIVE_CREW ", -- [221]
				"1794943068.150|Farra Way|fire|DRIVE ", -- [222]
				"1794943069.050|Farra Way|fire|DRIVE ", -- [223]
				"1794943070.050|Farra Way|fire|DRIVE ", -- [224]
				"1794943070.600|Farra Way|run|ride_thanks pass Anita Lift: thank-you whisper sent to Wuber Rocks (0.4 s)", -- [225]
				"1794943070.600|Farra Way|run|step 20/37 ride_earnings on Anita Lift: Drive tab: open Earnings, then click Snap (below)", -- [226]
				"1794943070.600|Farra Way|fire|DRIVE_STATE Wuber Rocks paid", -- [227]
				"1794943070.600|Farra Way|run|ride_earnings look Anita Lift: screenshot 1: Earnings with today's ride (0.0 s)", -- [228]
				"1794943070.600|Farra Way|run|step 21/37 raid_invite on Anita Lift: type /invite Wuber Rocks", -- [229]
				"1794943070.650|Farra Way|fire|DRIVE ", -- [230]
				"1794943071.000|Farra Way|fire|DRIVE_REMOVED Wuber Rocks done", -- [231]
				"1794943071.050|Farra Way|fire|DRIVE ", -- [232]
				"1794943072.050|Farra Way|fire|DRIVE ", -- [233]
				"1794943072.100|Farra Way|run|ride_rate pass Wuber Rocks: rated 5 stars (5.0 s)", -- [234]
				"1794943073.050|Farra Way|fire|DRIVE ", -- [235]
				"1794943073.600|Farra Way|fire|DRIVE_STATE Wuber Rocks nil", -- [236]
				"1794943073.600|Farra Way|ev|GROUP_ROSTER_UPDATE members=3 Anita Lift,Hayley Cab,Wuber Rocks", -- [237]
				"1794943073.650|Farra Way|fire|DRIVE ", -- [238]
				"1794943074.000|Farra Way|fire|DRIVE_STATE Wuber Rocks joined", -- [239]
				"1794943074.050|Farra Way|fire|DRIVE ", -- [240]
				"1794943074.100|Farra Way|msg<|D W<Anita Lift D~1~Undercity~1458~500~500~5000~Anita Lift~busy~3~6~H~2.2.1~~0~1~CAMWOW EU5 Realm 5 PvE~1", -- [241]
				"1794943075.050|Farra Way|fire|DRIVE ", -- [242]
				"1794943076.050|Farra Way|fire|DRIVE ", -- [243]
				"1794943076.100|Farra Way|run|raid_invite pass Anita Lift: the invite reached Wuber Rocks (0.0 s)", -- [244]
				"1794943076.100|Farra Way|run|step 22/37 raid_join on Wuber Rocks: click Accept on the group invite", -- [245]
				"1794943077.050|Farra Way|fire|DRIVE ", -- [246]
				"1794943077.100|Farra Way|run|raid_join pass Wuber Rocks: in Anita's group (3.0 s)", -- [247]
				"1794943077.100|Farra Way|run|step 23/37 raid_convert on Anita Lift: right-click your portrait, Convert to Raid", -- [248]
				"1794943077.500|Farra Way|sys|Party converted to Raid", -- [249]
				"1794943077.500|Farra Way|ev|GROUP_ROSTER_UPDATE members=4 Anita Lift,Farra Way,Hayley Cab,Wuber Rocks", -- [250]
				"1794943077.550|Farra Way|fire|DRIVE ", -- [251]
				"1794943078.050|Farra Way|fire|DRIVE ", -- [252]
				"1794943078.100|Farra Way|run|raid_convert pass Anita Lift: a raid (0.9 s)", -- [253]
				"1794943078.100|Farra Way|run|step 24/37 raid_start on Anita Lift: Drive tab: Raid summons, tick Anita, Farra and Hayley as summoners, press Start", -- [254]
				"1794943078.100|Farra Way|fire|SETTINGS drive={table}", -- [255]
				"1794943078.100|Farra Way|fire|DRIVE_STATIONS ", -- [256]
				"1794943078.100|Farra Way|fire|DRIVE_MODE raid", -- [257]
				"1794943078.100|Farra Way|fire|DRIVE_RAID ", -- [258]
				"1794943078.100|Farra Way|fire|SETTINGS drive={table}", -- [259]
				"1794943078.100|Farra Way|fire|DRIVE_CREW ", -- [260]
				"1794943078.150|Farra Way|fire|DRIVE ", -- [261]
				"1794943079.050|Farra Way|fire|DRIVE ", -- [262]
				"1794943079.150|Farra Way|fire|DRIVE ", -- [263]
				"1794943080.100|Farra Way|fire|DRIVE_STATIONS ", -- [264]
				"1794943080.100|Farra Way|fire|DRIVE_MODE raid", -- [265]
				"1794943080.100|Farra Way|fire|DRIVE_RAID ", -- [266]
				"1794943080.100|Farra Way|fire|SETTINGS drive={table}", -- [267]
				"1794943080.100|Farra Way|fire|DRIVE_RAID ", -- [268]
				"1794943080.100|Farra Way|fire|DRIVE_CREW ", -- [269]
				"1794943080.150|Farra Way|fire|DRIVE ", -- [270]
				"1794943080.600|Farra Way|run|raid_start pass Anita Lift: raid summons on, 3 summoners (2.5 s)", -- [271]
				"1794943080.600|Farra Way|run|step 25/37 raid_window on Anita Lift: keep Wuber's window open on the Drive tab (open it if it closed)", -- [272]
				"1794943081.050|Farra Way|fire|DRIVE ", -- [273]
				"1794943082.050|Farra Way|fire|DRIVE ", -- [274]
				"1794943083.000|Farra Way|try|cap=comm ok=true result=0 combat=false", -- [275]
				"1794943083.050|Farra Way|fire|DRIVE ", -- [276]
				"1794943083.100|Farra Way|fire|DRIVE_RAID ", -- [277]
				"1794943083.100|Farra Way|fire|DRIVE_CREW ", -- [278]
				"1794943083.150|Farra Way|fire|DRIVE ", -- [279]
				"1794943083.600|Farra Way|run|raid_window pass Anita Lift: window open, big button docked on top (FULLSCREEN_DIALOG over HIGH) (3.0 s)", -- [280]
				"1794943083.600|Farra Way|run|step 26/37 raid_away on Wuber Rocks: take Wuber Rocks out of Anita's zone (hearth or walk out), staying in the raid", -- [281]
				"1794943084.050|Farra Way|fire|DRIVE ", -- [282]
				"1794943084.600|Farra Way|run|raid_away pass Wuber Rocks: Wuber Rocks is away from the spot (Orgrimmar) (1.0 s)", -- [283]
				"1794943084.600|Farra Way|run|step 27/37 raid_tap on Wuber Rocks: type /wuber and tap Request a summon", -- [284]
				"1794943084.700|Farra Way|fire|DRIVE_RAID ", -- [285]
				"1794943084.750|Farra Way|fire|DRIVE ", -- [286]
				"1794943085.050|Farra Way|fire|DRIVE ", -- [287]
				"1794943085.100|Farra Way|run|raid_tap pass Wuber Rocks: queued from the app (Request a summon) (0.5 s)", -- [288]
				"1794943085.100|Farra Way|run|step 28/37 raid_nvm on Wuber Rocks: type nvm in raid chat", -- [289]
				"1794943085.100|Farra Way|fire|DRIVE_RAID ", -- [290]
				"1794943085.150|Farra Way|fire|DRIVE ", -- [291]
				"1794943085.600|Farra Way|run|raid_nvm pass Wuber Rocks: dropped from the list (0.5 s)", -- [292]
				"1794943085.600|Farra Way|run|step 29/37 raid_ask on Wuber Rocks: type 123 in raid chat", -- [293]
				"1794943085.600|Farra Way|fire|DRIVE_RAID ", -- [294]
				"1794943085.650|Farra Way|fire|DRIVE ", -- [295]
				"1794943086.050|Farra Way|fire|DRIVE ", -- [296]
				"1794943086.100|Farra Way|run|raid_ask pass Wuber Rocks: Wuber Rocks queued (queued) (0.5 s)", -- [297]
				"1794943086.100|Farra Way|run|step 30/37 raid_button on Anita Lift: the big button offers the summon", -- [298]
				"1794943086.100|Farra Way|run|raid_button pass Anita Lift: it says 'Summon Wuber' (docked on top (FULLSCREEN_DIALOG over HIGH)) (0.0 s)", -- [299]
				"1794943086.100|Farra Way|run|step 31/37 raid_cast on Anita Lift: click the big button (it says {button})", -- [300]
				"1794943086.100|Farra Way|fire|DRIVE_ALERT Click the summoning portal - Wuber is on the way! portal", -- [301]
				"1794943086.100|Farra Way|ui|toast [portal] Click the summoning portal - Wuber is on the way!", -- [302]
				"1794943086.100|Farra Way|fire|DRIVE_RAID ", -- [303]
				"1794943086.100|Farra Way|fire|DRIVE_RAID ", -- [304]
				"1794943086.150|Farra Way|fire|DRIVE ", -- [305]
				"1794943086.600|Farra Way|run|raid_cast pass Anita Lift: Anita's ritual started on Wuber Rocks (pretend) (0.5 s)", -- [306]
				"1794943086.600|Farra Way|run|step 32/37 raid_portal1 on Farra Way: function: 0x56275d8a6780", -- [307]
				"1794943086.600|Farra Way|run|raid_portal1 skip Farra Way: test mode: the pretend ritual needs no portal clicks (0.0 s)", -- [308]
				"1794943086.600|Farra Way|run|send RUN~R~6afca83b37~32~raid_portal1~skip~0.0~Farra Way~test mode: the pretend ritual needs no portal clicks", -- [309]
				"1794943086.600|Farra Way|run|step 33/37 raid_portal2 on Hayley Cab: function: 0x56275d8a6780", -- [310]
				"1794943086.800|Farra Way|run|raid_portal2 skip Hayley Cab: test mode: the pretend ritual needs no portal clicks (0.0 s)", -- [311]
				"1794943086.800|Farra Way|run|step 34/37 raid_arrive on Wuber Rocks: function: 0x56275d8b6e90", -- [312]
				"1794943087.050|Farra Way|fire|DRIVE ", -- [313]
				"1794943088.050|Farra Way|fire|DRIVE ", -- [314]
				"1794943089.050|Farra Way|fire|DRIVE ", -- [315]
				"1794943090.050|Farra Way|fire|DRIVE ", -- [316]
				"1794943090.600|Farra Way|fire|DRIVE_RAID ", -- [317]
				"1794943090.650|Farra Way|fire|DRIVE ", -- [318]
				"1794943091.050|Farra Way|fire|DRIVE ", -- [319]
				"1794943091.200|Farra Way|sim|arrived (pretend): wuber rocks", -- [320]
				"1794943092.000|Farra Way|fire|DRIVE_RAID_DONE Wuber Rocks anita lift", -- [321]
				"1794943092.000|Farra Way|fire|DRIVE_LOG ", -- [322]
				"1794943092.000|Farra Way|fire|DRIVE_RAID ", -- [323]
				"1794943092.050|Farra Way|fire|DRIVE ", -- [324]
				"1794943092.100|Farra Way|run|raid_arrive pass Wuber Rocks: summoned, counted, off the list (5.2 s)", -- [325]
				"1794943092.100|Farra Way|run|step 35/37 raid_one on Anita Lift: Farra's and Hayley's Wuber left Wuber Rocks to Anita", -- [326]
				"1794943092.100|Farra Way|run|send RUN~F~6afca83b37~35~Farra Way~clear", -- [327]
				"1794943092.300|Farra Way|run|raid_one pass Anita Lift: Farra's and Hayley's buttons and rituals left Wuber Rocks alone (0.2 s)", -- [328]
				"1794943092.300|Farra Way|run|step 36/37 raid_stop on Anita Lift: press Stop on the Drive tab", -- [329]
				"1794943092.600|Farra Way|fire|DRIVE_STATIONS ", -- [330]
				"1794943092.600|Farra Way|fire|DRIVE_MODE raid", -- [331]
				"1794943092.600|Farra Way|fire|DRIVE_RAID ", -- [332]
				"1794943092.600|Farra Way|fire|SETTINGS drive={table}", -- [333]
				"1794943092.600|Farra Way|fire|DRIVE_RAID ", -- [334]
				"1794943092.600|Farra Way|fire|DRIVE_CREW ", -- [335]
				"1794943092.650|Farra Way|fire|DRIVE ", -- [336]
				"1794943093.050|Farra Way|fire|DRIVE ", -- [337]
				"1794943093.100|Farra Way|run|raid_stop pass Anita Lift: raid summons stopped (0.8 s)", -- [338]
				"1794943093.100|Farra Way|run|step 37/37 photo_tour on Anita Lift: press Close on the Drive tab if open, then click Start photo tour (below): hands off for a minute", -- [339]
				"1794943098.000|Farra Way|try|cap=comm ok=true result=0 combat=false", -- [340]
				"1794943098.050|Farra Way|fire|DRIVE ", -- [341]
				"1794943098.100|Farra Way|fire|DRIVE_RAID ", -- [342]
				"1794943098.100|Farra Way|fire|DRIVE_CREW ", -- [343]
				"1794943098.150|Farra Way|fire|DRIVE ", -- [344]
				"1794943103.050|Farra Way|fire|DRIVE ", -- [345]
				"1794943108.050|Farra Way|fire|DRIVE ", -- [346]
				"1794943113.000|Farra Way|try|cap=comm ok=true result=0 combat=false", -- [347]
				"1794943113.050|Farra Way|fire|DRIVE ", -- [348]
				"1794943113.100|Farra Way|fire|DRIVE_CREW ", -- [349]
				"1794943113.150|Farra Way|fire|DRIVE ", -- [350]
				"1794943118.050|Farra Way|fire|DRIVE ", -- [351]
				"1794943120.100|Farra Way|sim|send Anita Lift: SIM~hi", -- [352]
				"1794943120.100|Farra Way|sim|send Hayley Cab: SIM~hi", -- [353]
				"1794943120.100|Farra Way|sim|send Wuber Rocks: SIM~hi", -- [354]
				"1794943121.000|Farra Way|fire|DRIVE_LOG ", -- [355]
				"1794943123.050|Farra Way|fire|DRIVE ", -- [356]
				"1794943128.000|Farra Way|try|cap=comm ok=true result=0 combat=false", -- [357]
				"1794943128.050|Farra Way|fire|DRIVE ", -- [358]
				"1794943128.100|Farra Way|fire|DRIVE_CREW ", -- [359]
				"1794943128.150|Farra Way|fire|DRIVE ", -- [360]
				"1794943133.050|Farra Way|fire|DRIVE ", -- [361]
				"1794943136.100|Farra Way|fire|DRIVE_CREW ", -- [362]
				"1794943136.100|Farra Way|run|photo_tour pass Anita Lift: 25 screenshots (43.0 s)", -- [363]
				"1794943136.100|Farra Way|run|end 6afca83b37 (done): 37 of 37 checked, 0 failed", -- [364]
				"1794943136.100|Farra Way|tool|test run done: log out or /reload, then tell the person running the test \"done\".", -- [365]
				"1794943136.150|Farra Way|fire|DRIVE ", -- [366]
				"1794943138.050|Farra Way|fire|DRIVE ", -- [367]
			},
			["realm"] = "CAMWOW EU5 Realm 5 PvE",
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
				["lab"] = "1.1.0",
				["rr"] = "1.4.0",
				["wuber"] = "1.0.0",
			},
		},
	},
	["login"] = {
		["Farra Way"] = {
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
				"login_f1|skip|this client can't tell|1794943008.000|0.0", -- [8]
				"login_versions|pass|same versions as Anita, Hayley, Wuber Rocks (2.2.1/1.1.0/1)|1794943008.500|0.5", -- [9]
				"login_button|pass|the big button is hidden (closed)|1794943013.000|5.0", -- [10]
				"login_errors|pass|no Lua errors since login|1794943033.000|25.0", -- [11]
				"login_community|skip|Community: not available in this game.|1794943033.000|25.0", -- [12]
				"login_saved|skip|WuberLabDB came back empty and no other window remembers this one: a first start here|1794943033.000|25.0", -- [13]
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
			["at"] = 1794943076.1,
			["r"] = "pass",
			["sid"] = "6afca83b37",
			["ver"] = "2.2.1",
			["w"] = "Anita Lift",
			["why"] = "the invite reached Wuber Rocks",
		},
		["raid_join"] = {
			["at"] = 1794943077.1,
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
			["at"] = 1794943086.6,
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
			["at"] = 1794943053.6,
			["r"] = "pass",
			["sid"] = "6afca83b37",
			["ver"] = "2.2.1",
			["w"] = "Wuber Rocks",
			["why"] = "arrived (arrived)",
		},
		["ride_beacon"] = {
			["at"] = 1794943043.1,
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
			["at"] = 1794943043.1,
			["r"] = "pass",
			["sid"] = "6afca83b37",
			["ver"] = "2.2.1",
			["w"] = "Wuber Rocks",
			["why"] = "the confirm screen for Anita",
		},
		["ride_done"] = {
			["at"] = 1794943058.1,
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
			["at"] = 1794943047.1,
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
			["at"] = 1794943067.1,
			["r"] = "pass",
			["sid"] = "6afca83b37",
			["ver"] = "2.2.1",
			["w"] = "Wuber Rocks",
			["why"] = "left the group with no click",
		},
		["ride_open"] = {
			["at"] = 1794943041.1,
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
			["at"] = 1794943048.1,
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
			["at"] = 1794943072.1,
			["r"] = "pass",
			["sid"] = "6afca83b37",
			["ver"] = "2.2.1",
			["w"] = "Wuber Rocks",
			["why"] = "rated 5 stars",
		},
		["ride_request"] = {
			["at"] = 1794943046.6,
			["r"] = "pass",
			["sid"] = "6afca83b37",
			["ver"] = "2.2.1",
			["w"] = "Wuber Rocks",
			["why"] = "booked; whispered 'WTB summon to Undercity for 50s'",
		},
		["ride_seen"] = {
			["at"] = 1794943042.2,
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
			["at"] = 1794943056.1,
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
				["at"] = 1794943076.1,
				["judge"] = "Wuber Rocks",
				["r"] = "pass",
				["took"] = 0,
				["who"] = "Anita Lift",
				["why"] = "the invite reached Wuber Rocks",
			},
			["raid_join"] = {
				["at"] = 1794943077.1,
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
				["at"] = 1794943086.6,
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
				["at"] = 1794943053.6,
				["judge"] = "Wuber Rocks",
				["r"] = "pass",
				["took"] = 5.2,
				["who"] = "Wuber Rocks",
				["why"] = "arrived (arrived)",
			},
			["ride_beacon"] = {
				["at"] = 1794943043.1,
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
				["at"] = 1794943043.1,
				["judge"] = "Wuber Rocks",
				["r"] = "pass",
				["took"] = 0.9,
				["who"] = "Wuber Rocks",
				["why"] = "the confirm screen for Anita",
			},
			["ride_done"] = {
				["at"] = 1794943058.1,
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
				["at"] = 1794943047.1,
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
				["at"] = 1794943067.1,
				["judge"] = "Wuber Rocks",
				["r"] = "pass",
				["took"] = 2.6,
				["who"] = "Wuber Rocks",
				["why"] = "left the group with no click",
			},
			["ride_open"] = {
				["at"] = 1794943041.1,
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
				["at"] = 1794943048.1,
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
				["at"] = 1794943072.1,
				["judge"] = "Wuber Rocks",
				["r"] = "pass",
				["took"] = 5,
				["who"] = "Wuber Rocks",
				["why"] = "rated 5 stars",
			},
			["ride_request"] = {
				["at"] = 1794943046.6,
				["judge"] = "Wuber Rocks",
				["r"] = "pass",
				["took"] = 3.5,
				["who"] = "Wuber Rocks",
				["why"] = "booked; whispered 'WTB summon to Undercity for 50s'",
			},
			["ride_seen"] = {
				["at"] = 1794943042.2,
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
				["at"] = 1794943056.1,
				["judge"] = "Wuber Rocks",
				["r"] = "pass",
				["took"] = 2.3,
				["who"] = "Wuber Rocks",
				["why"] = "put in 50s and pressed Trade",
			},
		},
		["sid"] = "6afca83b37",
		["sim"] = true,
		["started"] = 1794943037.1,
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
				"ride_open|Anita Lift|pass|open, selling at 50s|1794943041.100|5.5|Anita Lift|Anita open", -- [1]
				"ride_beacon|Anita Lift|pass|beacon open: 50s to Undercity|1794943043.100|0.0|Anita Lift|Beacon open", -- [2]
				"ride_seen|Wuber Rocks|pass|Anita listed (open, 50s)|1794943042.200|0.0|Wuber Rocks|Anita on Home", -- [3]
				"ride_confirm|Wuber Rocks|pass|the confirm screen for Anita|1794943043.100|0.9|Wuber Rocks|Confirm screen", -- [4]
				"ride_request|Wuber Rocks|pass|booked; whispered 'WTB summon to Undercity for 50s'|1794943046.600|3.5|Wuber Rocks|Request", -- [5]
				"ride_taken|Anita Lift|pass|Wuber Rocks is in Anita's queue (joined)|1794943046.700|0.0|Anita Lift|Request reaches Anita", -- [6]
				"ride_invited|Wuber Rocks|pass|joined Anita's group with no click|1794943047.100|0.0|Wuber Rocks|Invite taken", -- [7]
				"ride_button|Anita Lift|pass|it says 'Summon Wuber' (floating, MEDIUM)|1794943047.200|0.0|Anita Lift|Big button: Summon", -- [8]
				"ride_cast|Anita Lift|pass|the ritual started on Wuber Rocks (pretend)|1794943048.100|0.9|Anita Lift|The summon starts", -- [9]
				"ride_portal1|Farra Way|skip|test mode: the pretend ritual needs no portal clicks|1794943048.100|0.0|Farra Way|Farra clicks", -- [10]
				"ride_portal2|Hayley Cab|skip|test mode: the pretend ritual needs no portal clicks|1794943048.300|0.0|Hayley Cab|Hayley clicks", -- [11]
				"ride_arrive|Wuber Rocks|pass|arrived (arrived)|1794943053.600|5.2|Wuber Rocks|Summon accepted", -- [12]
				"ride_landed|Anita Lift|pass|Wuber Rocks counts as here (arrived)|1794943053.700|0.0|Anita Lift|Anita sees the arrival", -- [13]
				"ride_trade|Wuber Rocks|pass|put in 50s and pressed Trade|1794943056.100|2.3|Wuber Rocks|Rider pays", -- [14]
				"ride_paid|Anita Lift|pass|paid 50s by Wuber Rocks|1794943057.400|1.2|Anita Lift|Anita takes the fare", -- [15]
				"ride_done|Wuber Rocks|pass|done, paid 50s|1794943058.100|0.0|Wuber Rocks|Rider's ride paid", -- [16]
				"ride_left|Wuber Rocks|pass|left the group with no click|1794943067.100|2.6|Wuber Rocks|Left the group", -- [17]
				"ride_rate|Wuber Rocks|pass|rated 5 stars|1794943072.100|5.0|Wuber Rocks|Rating", -- [18]
				"ride_thanks|Anita Lift|pass|thank-you whisper sent to Wuber Rocks|1794943070.600|0.4|Anita Lift|Thank-you whisper", -- [19]
				"ride_earnings|Anita Lift|look|screenshot 1: Earnings with today's ride|1794943070.600|0.0|Anita Lift|Earnings (look)", -- [20]
				"raid_invite|Anita Lift|pass|the invite reached Wuber Rocks|1794943076.100|0.0|Wuber Rocks|Invite the rider", -- [21]
				"raid_join|Wuber Rocks|pass|in Anita's group|1794943077.100|3.0|Wuber Rocks|Rider joins", -- [22]
				"raid_convert|Anita Lift|pass|a raid|1794943078.100|0.9|Anita Lift|Make it a raid", -- [23]
				"raid_start|Anita Lift|pass|raid summons on, 3 summoners|1794943080.600|2.5|Anita Lift|Raid summons on", -- [24]
				"raid_window|Anita Lift|pass|window open, big button docked on top (FULLSCREEN_DIALOG over HIGH)|1794943083.600|3.0|Anita Lift|Window open, button on top", -- [25]
				"raid_away|Wuber Rocks|pass|Wuber Rocks is away from the spot (Orgrimmar)|1794943084.600|1.0|Anita Lift|Rider away from the spot", -- [26]
				"raid_tap|Wuber Rocks|pass|queued from the app (Request a summon)|1794943085.100|0.5|Anita Lift|Request from the app", -- [27]
				"raid_nvm|Wuber Rocks|pass|dropped from the list|1794943085.600|0.5|Anita Lift|nvm drops", -- [28]
				"raid_ask|Wuber Rocks|pass|Wuber Rocks queued (queued)|1794943086.100|0.5|Anita Lift|123 in raid chat", -- [29]
				"raid_button|Anita Lift|pass|it says 'Summon Wuber' (docked on top (FULLSCREEN_DIALOG over HIGH))|1794943086.100|0.0|Anita Lift|Big button: Summon", -- [30]
				"raid_cast|Anita Lift|pass|Anita's ritual started on Wuber Rocks (pretend)|1794943086.600|0.5|Anita Lift|Anita summons the raider", -- [31]
				"raid_portal1|Farra Way|skip|test mode: the pretend ritual needs no portal clicks|1794943086.600|0.0|Farra Way|Farra clicks", -- [32]
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
			["started"] = 1794943037.1,
			["todo"] = 0,
			["why"] = "done",
			["wuber"] = "2.2.1",
		}, -- [1]
	},
	["seenLab"] = {
		["anita lift"] = 1794943008.2,
		["hayley cab"] = 1794943008.2,
		["wuber rocks"] = 1794943008.2,
	},
	["v"] = 1,
}
