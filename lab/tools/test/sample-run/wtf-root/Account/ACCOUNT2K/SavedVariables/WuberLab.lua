
WuberLabDB = {
	["chars"] = {
		["Anita Lift"] = {
			["checks"] = {
				["d_coins"] = {
					["at"] = 1794943064.6,
					["by"] = "fx_coins",
					["r"] = "auto",
					["sec"] = "Looks",
					["text"] = "Coin shower on 5 stars",
					["took"] = 7.2999999523163,
				},
				["d_paidfx"] = {
					["at"] = 1794943057.3,
					["by"] = "fx_paid",
					["r"] = "auto",
					["sec"] = "Looks",
					["text"] = "Paid burst plays",
				},
			},
			["dropped"] = 0,
			["lastLogin"] = 1794943000,
			["lines"] = {
				"1794943000.000|Anita Lift|fire|ENGINE Wuber", -- [1]
				"1794943000.000|Anita Lift|login|char=Anita Lift realm=CAMWOW EU5 Realm 5 PvE role=driver build=1.60.1/70938/Nov 12 2026/16001 lab=1.1.0 Wuber=1.0.0 RitualRides=off OpenMap=off Moo=off !BugGrabber=off BugSack=off W.VERSION=2.2.1 channels=4 errhandler=replaced later buggrabber=no", -- [2]
				"1794943000.000|Anita Lift|probe|channels=4 wuberIndex=nil (login)", -- [3]
				"1794943000.000|Anita Lift|ev|PLAYER_ENTERING_WORLD login=true reload=false", -- [4]
				"1794943000.000|Anita Lift|ev|ZONE_CHANGED_NEW_AREA zone=Undercity sub=", -- [5]
				"1794943000.000|Anita Lift|try|cap=comm ok=true result=0 combat=false", -- [6]
				"1794943000.000|Anita Lift|ev|GROUP_ROSTER_UPDATE members=2 Farra Way,Hayley Cab", -- [7]
				"1794943000.050|Anita Lift|fire|DRIVE ", -- [8]
				"1794943000.100|Anita Lift|fire|DRIVE_CREW ", -- [9]
				"1794943000.100|Anita Lift|fire|DRIVE_CREW ", -- [10]
				"1794943000.150|Anita Lift|fire|DRIVE ", -- [11]
				"1794943000.600|Anita Lift|try|cap=comm ok=true result=0 combat=false", -- [12]
				"1794943000.600|Anita Lift|try|cap=comm ok=true result=0 combat=false", -- [13]
				"1794943000.600|Anita Lift|try|cap=comm ok=true result=0 combat=false", -- [14]
				"1794943000.600|Anita Lift|try|cap=comm ok=true result=0 combat=false", -- [15]
				"1794943001.050|Anita Lift|fire|DRIVE ", -- [16]
				"1794943002.000|Anita Lift|tool|test mode on (developer only). /lab opens the test plan. Role: driver", -- [17]
				"1794943003.000|Anita Lift|probe|font Poppins SetFont ok=true returned=true GetFont=Interface\\AddOns\\Wuber\\Media\\fonts\\Poppins-Regular.ttf T.poppins=nil", -- [18]
				"1794943006.000|Anita Lift|probe|JoinTemporaryChannel(WuberNet) called combat=false", -- [19]
				"1794943006.000|Anita Lift|probe|CheckChannel(true) -> false index=nil channels=4 fails=nil", -- [20]
				"1794943006.050|Anita Lift|fire|DRIVE ", -- [21]
				"1794943006.500|Anita Lift|fire|NETWORK true", -- [22]
				"1794943006.500|Anita Lift|msg>|Q C>5 Q~1", -- [23]
				"1794943006.500|Anita Lift|probe|CheckChannel(false) -> true index=5 channels=5 fails=nil", -- [24]
				"1794943006.500|Anita Lift|probe|channels=5 wuberIndex=5 (CHANNEL_UI_UPDATE)", -- [25]
				"1794943006.600|Anita Lift|msg<|Q C<Anita Lift Q~1", -- [26]
				"1794943006.600|Anita Lift|msg<|Q C<Farra Way Q~1", -- [27]
				"1794943006.600|Anita Lift|msg<|Q C<Hayley Cab Q~1", -- [28]
				"1794943006.600|Anita Lift|msg<|Q C<Wuber Rocks Q~1", -- [29]
				"1794943008.000|Anita Lift|self|[login] 14 of 14 passed", -- [30]
				"1794943008.000|Anita Lift|run|send RUN~V~2.2.1~1.1.0~1", -- [31]
				"1794943008.000|Anita Lift|run|login login_wuber pass: Wuber 2.2.1, lab 1.1.0", -- [32]
				"1794943008.000|Anita Lift|run|login login_old_addon pass: the old summoning addon is off", -- [33]
				"1794943008.000|Anita Lift|run|login login_prefixes pass: WUBER, WUBERT and WLAB registered", -- [34]
				"1794943008.000|Anita Lift|run|login login_channel pass: on Wuber's channel (/5)", -- [35]
				"1794943008.000|Anita Lift|run|login login_flights pass: flight prices loaded (Orgrimmar to Thunder Bluff: 50c)", -- [36]
				"1794943008.000|Anita Lift|run|login login_settings pass: settings look sane (price 50s)", -- [37]
				"1794943008.000|Anita Lift|run|login login_selftest pass: Wuber's self-test: all 14 passed", -- [38]
				"1794943008.000|Anita Lift|run|login login_f1 skip: this client can't tell", -- [39]
				"1794943008.000|Anita Lift|run|login checks: 13 started", -- [40]
				"1794943008.500|Anita Lift|run|login login_versions pass: same versions as Farra, Hayley, Wuber Rocks (2.2.1/1.1.0/1)", -- [41]
				"1794943010.000|Anita Lift|plan|s0_1@anita lift;ok;by=probe:fresh;who=Anita Lift;src=local", -- [42]
				"1794943010.000|Anita Lift|probe|plan s0_1 (fresh) on Anita Lift: ok", -- [43]
				"1794943010.000|Anita Lift|plan|s0_2@anita lift;no;by=probe:addons;who=Anita Lift;src=local", -- [44]
				"1794943010.000|Anita Lift|probe|plan s0_2 (addons) on Anita Lift: no", -- [45]
				"1794943010.000|Anita Lift|plan|s1_1@anita lift;ok;by=probe:fresh;who=Anita Lift;src=local", -- [46]
				"1794943010.000|Anita Lift|probe|plan s1_1 (fresh) on Anita Lift: ok", -- [47]
				"1794943010.000|Anita Lift|msg>|Q W>Farra Way Q~1~1", -- [48]
				"1794943010.100|Anita Lift|msg<|Q W<Farra Way Q~1~1", -- [49]
				"1794943010.100|Anita Lift|msg<|Q W<Hayley Cab Q~1~1", -- [50]
				"1794943010.100|Anita Lift|msg<|Q W<Wuber Rocks Q~1~1", -- [51]
				"1794943011.010|Anita Lift|msg>|Q W>Hayley Cab Q~1~1", -- [52]
				"1794943011.050|Anita Lift|fire|DRIVE ", -- [53]
				"1794943012.099|Anita Lift|msg>|Q W>Wuber Rocks Q~1~1", -- [54]
				"1794943012.100|Anita Lift|plan|s1_1@farra way;ok;by=probe:fresh;who=Farra Way;src=sync", -- [55]
				"1794943012.100|Anita Lift|plan|s0_2@farra way;no;by=probe:addons;who=Farra Way;src=sync", -- [56]
				"1794943012.100|Anita Lift|plan|s0_1@farra way;ok;by=probe:fresh;who=Farra Way;src=sync", -- [57]
				"1794943012.100|Anita Lift|plan|s0_2@hayley cab;no;by=probe:addons;who=Hayley Cab;src=sync", -- [58]
				"1794943012.100|Anita Lift|plan|s0_1@hayley cab;ok;by=probe:fresh;who=Hayley Cab;src=sync", -- [59]
				"1794943012.100|Anita Lift|plan|s1_1@hayley cab;ok;by=probe:fresh;who=Hayley Cab;src=sync", -- [60]
				"1794943013.000|Anita Lift|run|login login_button pass: the big button is hidden (closed)", -- [61]
				"1794943013.600|Anita Lift|plan|s0_2@wuber rocks;no;by=probe:addons;who=Wuber Rocks;src=sync", -- [62]
				"1794943013.600|Anita Lift|plan|s1_1@wuber rocks;ok;by=probe:fresh;who=Wuber Rocks;src=sync", -- [63]
				"1794943013.600|Anita Lift|plan|s1_1;auto;by=probe;who=Anita Lift;src=local", -- [64]
				"1794943013.600|Anita Lift|plan|s0_1@wuber rocks;ok;by=probe:fresh;who=Wuber Rocks;src=sync", -- [65]
				"1794943013.600|Anita Lift|plan|s0_1;auto;by=probe;who=Anita Lift;src=local", -- [66]
				"1794943015.000|Anita Lift|comm|not available (no C_Club)", -- [67]
				"1794943015.000|Anita Lift|fire|COMMUNITY none", -- [68]
				"1794943015.000|Anita Lift|try|cap=comm ok=true result=0 combat=false", -- [69]
				"1794943015.100|Anita Lift|fire|DRIVE_CREW ", -- [70]
				"1794943015.100|Anita Lift|fire|DRIVE_CREW ", -- [71]
				"1794943015.150|Anita Lift|fire|DRIVE ", -- [72]
				"1794943016.050|Anita Lift|fire|DRIVE ", -- [73]
				"1794943021.050|Anita Lift|fire|DRIVE ", -- [74]
				"1794943022.000|Anita Lift|comm|status: Community: not available in this game. state=none index=nil off=false sent=0 heard=0", -- [75]
				"1794943026.050|Anita Lift|fire|DRIVE ", -- [76]
				"1794943030.000|Anita Lift|try|cap=comm ok=true result=0 combat=false", -- [77]
				"1794943030.100|Anita Lift|fire|DRIVE_CREW ", -- [78]
				"1794943030.100|Anita Lift|fire|DRIVE_CREW ", -- [79]
				"1794943030.150|Anita Lift|fire|DRIVE ", -- [80]
				"1794943031.050|Anita Lift|fire|DRIVE ", -- [81]
				"1794943033.000|Anita Lift|run|login login_errors pass: no Lua errors since login", -- [82]
				"1794943033.000|Anita Lift|run|login login_saved skip: WuberLabDB came back empty and no other window remembers this one: a first start here", -- [83]
				"1794943033.000|Anita Lift|run|login login_community skip: Community: not available in this game.", -- [84]
				"1794943035.000|Anita Lift|sim|send Wuber Rocks: SIM~hello", -- [85]
				"1794943035.000|Anita Lift|sim|pretend-to-summon ON (no shards needed; nobody is really summoned)", -- [86]
				"1794943035.000|Anita Lift|run|start 6afca83b37 by Anita Lift: 37 checks, about 10 min, 16 swaps, test mode (no shards)", -- [87]
				"1794943035.000|Anita Lift|run|send RUN~S~6afca83b37~Anita Lift~1~3~1~ride_open,ride_beacon,ride_seen,ride_confirm,ride_request,ride_taken,ride_invited,ride", -- [88]
				"1794943035.000|Anita Lift|run|send RUN~S~6afca83b37~Anita Lift~1~3~2~ride_done,ride_left,ride_rate,ride_thanks,ride_earnings,raid_invite,raid_join,raid_con", -- [89]
				"1794943035.000|Anita Lift|run|send RUN~S~6afca83b37~Anita Lift~1~3~3~raid_portal1,raid_portal2,raid_arrive,raid_one,raid_stop,photo_tour", -- [90]
				"1794943035.000|Anita Lift|run|step 1/37 ride_open on Anita Lift: open Wuber (/wuber), Drive tab, choose Sell summons and press Open", -- [91]
				"1794943035.050|Anita Lift|fire|DRIVE ", -- [92]
				"1794943035.200|Anita Lift|sim|peer (test mode on there too): Wuber Rocks", -- [93]
				"1794943035.200|Anita Lift|sim|send Wuber Rocks: SIM~hi", -- [94]
				"1794943035.250|Anita Lift|fire|DRIVE ", -- [95]
				"1794943036.000|Anita Lift|try|cap=comm ok=true result=0 combat=false", -- [96]
				"1794943036.050|Anita Lift|fire|DRIVE ", -- [97]
				"1794943037.200|Anita Lift|sim|peer (test mode on there too): Farra Way", -- [98]
				"1794943037.200|Anita Lift|sim|send Farra Way: SIM~hi", -- [99]
				"1794943037.200|Anita Lift|sim|peer (test mode on there too): Hayley Cab", -- [100]
				"1794943037.200|Anita Lift|sim|send Hayley Cab: SIM~hi", -- [101]
				"1794943037.250|Anita Lift|fire|DRIVE ", -- [102]
				"1794943038.100|Anita Lift|fire|DRIVE_CREW ", -- [103]
				"1794943038.100|Anita Lift|fire|DRIVE_CREW ", -- [104]
				"1794943038.150|Anita Lift|fire|DRIVE ", -- [105]
				"1794943040.000|Anita Lift|try|cap=comm ok=true result=0 combat=false", -- [106]
				"1794943040.000|Anita Lift|fire|SETTINGS drive={table}", -- [107]
				"1794943040.050|Anita Lift|fire|DRIVE ", -- [108]
				"1794943040.500|Anita Lift|run|ride_open pass Anita Lift: open, selling at 50s (5.5 s)", -- [109]
				"1794943040.500|Anita Lift|run|send RUN~R~6afca83b37~1~ride_open~pass~5.5~Anita Lift~open, selling at 50s", -- [110]
				"1794943040.500|Anita Lift|run|step 2/37 ride_beacon on Anita Lift: Wuber tells riders Anita is open", -- [111]
				"1794943040.500|Anita Lift|run|ride_beacon pass Anita Lift: beacon open: 50s to Undercity (0.0 s)", -- [112]
				"1794943040.500|Anita Lift|run|send RUN~R~6afca83b37~2~ride_beacon~pass~0.0~Anita Lift~beacon open: 50s to Undercity", -- [113]
				"1794943040.500|Anita Lift|run|step 3/37 ride_seen on Wuber Rocks: type /wuber: Anita's card is on Home", -- [114]
				"1794943041.000|Anita Lift|msg>|D W>Farra Way D~1~Undercity~1458~500~500~5000~Anita Lift~open~3~7~H~2.2.1~~0~1~CAMWOW EU5 Realm 5 PvE~1", -- [115]
				"1794943041.000|Anita Lift|msg>|D W>Wuber Rocks D~1~Undercity~1458~500~500~5000~Anita Lift~open~3~7~H~2.2.1~~0~1~CAMWOW EU5 Realm 5 PvE~1", -- [116]
				"1794943041.000|Anita Lift|msg>|D W>Hayley Cab D~1~Undercity~1458~500~500~5000~Anita Lift~open~3~7~H~2.2.1~~0~1~CAMWOW EU5 Realm 5 PvE~1", -- [117]
				"1794943041.000|Anita Lift|fire|DRIVE_ALERT Time to advertise in Trade: tap Advertise. advert", -- [118]
				"1794943041.000|Anita Lift|ui|toast [advert] Time to advertise in Trade: tap Advertise.", -- [119]
				"1794943041.050|Anita Lift|fire|DRIVE ", -- [120]
				"1794943042.050|Anita Lift|fire|DRIVE ", -- [121]
				"1794943042.200|Anita Lift|run|ride_seen pass Wuber Rocks: Anita listed (open, 50s) (0.0 s)", -- [122]
				"1794943042.200|Anita Lift|run|step 4/37 ride_confirm on Wuber Rocks: tap Anita's card", -- [123]
				"1794943042.600|Anita Lift|msg<|F W<Wuber Rocks F~1~H~?~orgrimmar:undercity", -- [124]
				"1794943043.050|Anita Lift|fire|DRIVE ", -- [125]
				"1794943043.100|Anita Lift|run|ride_confirm pass Wuber Rocks: the confirm screen for Anita (0.9 s)", -- [126]
				"1794943043.100|Anita Lift|run|step 5/37 ride_request on Wuber Rocks: press Request summon", -- [127]
				"1794943044.050|Anita Lift|fire|DRIVE ", -- [128]
				"1794943045.050|Anita Lift|fire|DRIVE ", -- [129]
				"1794943045.100|Anita Lift|plan|s3_r2;auto;by=confirm_shown;who=Wuber Rocks;src=sync", -- [130]
				"1794943045.100|Anita Lift|plan|s2_1;auto;by=app_open;who=Wuber Rocks;src=sync", -- [131]
				"1794943046.000|Anita Lift|fire|DRIVE_STATE Wuber Rocks nil", -- [132]
				"1794943046.000|Anita Lift|try|cap=comm ok=true result=0 combat=false", -- [133]
				"1794943046.000|Anita Lift|probe|C_PartyInfo.InviteUnit(Wuber Rocks) called combat=false", -- [134]
				"1794943046.000|Anita Lift|try|cap=invite ok=true result=nil combat=false", -- [135]
				"1794943046.000|Anita Lift|fire|DRIVE_STATE Wuber Rocks queued", -- [136]
				"1794943046.000|Anita Lift|try|cap=comm ok=true result=0 combat=false", -- [137]
				"1794943046.000|Anita Lift|whsp|< Wuber Rocks: WTB summon to Undercity for 50s", -- [138]
				"1794943046.000|Anita Lift|plan|s3_r3;auto;by=whisper_wtb_in;who=Anita Lift;src=local", -- [139]
				"1794943046.000|Anita Lift|plan|s3_c1;auto;by=whisper_wtb_in;who=Anita Lift;src=local", -- [140]
				"1794943046.050|Anita Lift|fire|DRIVE ", -- [141]
				"1794943046.100|Anita Lift|fire|REQUESTS n=1", -- [142]
				"1794943046.100|Anita Lift|msg>|A W>Wuber Rocks A~1~BSnQHF~5000~5", -- [143]
				"1794943046.100|Anita Lift|msg>|S W>Wuber Rocks S~1~BSnQHF~invited~~Farra Way~Hayley Cab", -- [144]
				"1794943046.100|Anita Lift|msg<|R W<Wuber Rocks R~1~BSnQHF~Undercity~5000~0~0", -- [145]
				"1794943046.200|Anita Lift|fire|DRIVE_STATE Wuber Rocks invited", -- [146]
				"1794943046.200|Anita Lift|ev|GROUP_ROSTER_UPDATE members=3 Farra Way,Hayley Cab,Wuber Rocks", -- [147]
				"1794943046.200|Anita Lift|sys|You have invited Wuber Rocks to join your group.", -- [148]
				"1794943046.250|Anita Lift|fire|DRIVE ", -- [149]
				"1794943046.600|Anita Lift|run|ride_request pass Wuber Rocks: booked; whispered 'WTB summon to Undercity for 50s' (3.5 s)", -- [150]
				"1794943046.600|Anita Lift|run|step 6/37 ride_taken on Anita Lift: Anita's Wuber takes the request", -- [151]
				"1794943046.600|Anita Lift|run|ride_taken pass Anita Lift: Wuber Rocks is in Anita's queue (joined) (0.0 s)", -- [152]
				"1794943046.600|Anita Lift|run|send RUN~R~6afca83b37~6~ride_taken~pass~0.0~Anita Lift~Wuber Rocks is in Anita's queue (joined)", -- [153]
				"1794943046.600|Anita Lift|run|step 7/37 ride_invited on Wuber Rocks: the invite arrives and is taken with no click", -- [154]
				"1794943047.000|Anita Lift|msg>|D W>Farra Way D~1~Undercity~1458~500~500~5000~Anita Lift~busy~3~6~H~2.2.1~~0~1~CAMWOW EU5 Realm 5 PvE~1", -- [155]
				"1794943047.000|Anita Lift|msg>|D W>Wuber Rocks D~1~Undercity~1458~500~500~5000~Anita Lift~busy~3~6~H~2.2.1~~0~1~CAMWOW EU5 Realm 5 PvE~1", -- [156]
				"1794943047.050|Anita Lift|fire|DRIVE ", -- [157]
				"1794943047.100|Anita Lift|msg>|D W>Hayley Cab D~1~Undercity~1458~500~500~5000~Anita Lift~busy~3~6~H~2.2.1~~0~1~CAMWOW EU5 Realm 5 PvE~1", -- [158]
				"1794943047.100|Anita Lift|run|ride_invited pass Wuber Rocks: joined Anita's group with no click (0.0 s)", -- [159]
				"1794943047.100|Anita Lift|run|step 8/37 ride_button on Anita Lift: the big button offers the summon", -- [160]
				"1794943047.100|Anita Lift|run|ride_button pass Anita Lift: it says 'Summon Wuber' (floating, MEDIUM) (0.0 s)", -- [161]
				"1794943047.100|Anita Lift|run|send RUN~R~6afca83b37~8~ride_button~pass~0.0~Anita Lift~it says 'Summon Wuber' (floating, MEDIUM)", -- [162]
				"1794943047.100|Anita Lift|run|step 9/37 ride_cast on Anita Lift: click the big button (it says {button})", -- [163]
				"1794943047.500|Anita Lift|sim|pretend cast on Wuber Rocks", -- [164]
				"1794943047.500|Anita Lift|fire|DRIVE_STATE Wuber Rocks joined", -- [165]
				"1794943047.500|Anita Lift|try|cap=comm ok=true result=0 combat=false", -- [166]
				"1794943047.500|Anita Lift|click|big button: 'Summon Wuber' (click: tells the price, targets and casts  -  20 shards) type=macro; floating MEDIUM/1, window HIGH/1", -- [167]
				"1794943047.500|Anita Lift|click|macro: /w Wuber-Rocks Anita Lift: summoning you to Undercity now - please accept the summon! The ride is 50s; just open trade with any of us when you land. ; /target [@party3] ; /stopmacro [combat,nocombat]", -- [168]
				"1794943047.500|Anita Lift|whsp|> Wuber Rocks: Anita Lift: summoning you to Undercity now - please accept the summon! The ride is 50s; just open trade with any of us when you land.", -- [169]
				"1794943047.500|Anita Lift|try|cap=comm ok=true result=0 combat=false", -- [170]
				"1794943047.500|Anita Lift|click|noted: greet Wuber Rocks, cast Wuber Rocks", -- [171]
				"1794943047.550|Anita Lift|fire|DRIVE ", -- [172]
				"1794943048.000|Anita Lift|run|ride_cast pass Anita Lift: the ritual started on Wuber Rocks (pretend) (0.9 s)", -- [173]
				"1794943048.000|Anita Lift|run|send RUN~R~6afca83b37~9~ride_cast~pass~0.9~Anita Lift~the ritual started on Wuber Rocks (pretend)", -- [174]
				"1794943048.000|Anita Lift|run|step 10/37 ride_portal1 on Farra Way: function: 0x56275c7bf820", -- [175]
				"1794943048.050|Anita Lift|fire|DRIVE ", -- [176]
				"1794943048.100|Anita Lift|msg>|S W>Wuber Rocks S~1~BSnQHF~summoning~~Farra Way~Hayley Cab", -- [177]
				"1794943048.200|Anita Lift|run|ride_portal1 skip Farra Way: test mode: the pretend ritual needs no portal clicks (0.0 s)", -- [178]
				"1794943048.200|Anita Lift|run|step 11/37 ride_portal2 on Hayley Cab: function: 0x56275c7bf820", -- [179]
				"1794943048.300|Anita Lift|run|ride_portal2 skip Hayley Cab: test mode: the pretend ritual needs no portal clicks (0.0 s)", -- [180]
				"1794943048.300|Anita Lift|run|step 12/37 ride_arrive on Wuber Rocks: function: 0x56275c31b720", -- [181]
				"1794943049.050|Anita Lift|fire|DRIVE ", -- [182]
				"1794943050.050|Anita Lift|fire|DRIVE ", -- [183]
				"1794943051.000|Anita Lift|sim|send Wuber Rocks: SIM~summon~Anita Lift~Undercity", -- [184]
				"1794943051.000|Anita Lift|try|cap=comm ok=true result=0 combat=false", -- [185]
				"1794943051.050|Anita Lift|fire|DRIVE ", -- [186]
				"1794943051.100|Anita Lift|plan|s3_c2;auto;by=auto_accept;who=Wuber Rocks;src=sync", -- [187]
				"1794943051.100|Anita Lift|plan|s3_r5;auto;by=auto_accept;who=Wuber Rocks;src=sync", -- [188]
				"1794943052.000|Anita Lift|fire|DRIVE_STATE Wuber Rocks summoning", -- [189]
				"1794943052.000|Anita Lift|msg>|S W>Wuber Rocks S~1~BSnQHF~portal~~Farra Way~Hayley Cab", -- [190]
				"1794943052.000|Anita Lift|try|cap=comm ok=true result=0 combat=false", -- [191]
				"1794943052.050|Anita Lift|fire|DRIVE ", -- [192]
				"1794943052.600|Anita Lift|sim|arrived (pretend): wuber rocks", -- [193]
				"1794943053.000|Anita Lift|fire|DRIVE_STATE Wuber Rocks waiting", -- [194]
				"1794943053.000|Anita Lift|msg>|S W>Wuber Rocks S~1~BSnQHF~arrived~~Farra Way~Hayley Cab", -- [195]
				"1794943053.050|Anita Lift|fire|DRIVE ", -- [196]
				"1794943053.100|Anita Lift|fire|DRIVE_CREW ", -- [197]
				"1794943053.100|Anita Lift|fire|DRIVE_CREW ", -- [198]
				"1794943053.150|Anita Lift|fire|DRIVE ", -- [199]
				"1794943053.600|Anita Lift|run|ride_arrive pass Wuber Rocks: arrived (arrived) (5.2 s)", -- [200]
				"1794943053.600|Anita Lift|run|step 13/37 ride_landed on Anita Lift: Anita's Wuber sees Wuber Rocks arrive", -- [201]
				"1794943053.600|Anita Lift|run|ride_landed pass Anita Lift: Wuber Rocks counts as here (arrived) (0.0 s)", -- [202]
				"1794943053.600|Anita Lift|run|send RUN~R~6afca83b37~13~ride_landed~pass~0.0~Anita Lift~Wuber Rocks counts as here (arrived)", -- [203]
				"1794943053.600|Anita Lift|run|step 14/37 ride_trade on Wuber Rocks: function: 0x56275c2b3810", -- [204]
				"1794943054.050|Anita Lift|fire|DRIVE ", -- [205]
				"1794943055.050|Anita Lift|fire|DRIVE ", -- [206]
				"1794943055.600|Anita Lift|plan|s3_r4;auto;by=accept_msg;who=Wuber Rocks;src=sync", -- [207]
				"1794943056.000|Anita Lift|ev|TRADE_SHOW with=Wuber Rocks trade=hidden my=0 their=0", -- [208]
				"1794943056.000|Anita Lift|try|cap=trade-open ok=true result=nil combat=false", -- [209]
				"1794943056.000|Anita Lift|ev|TRADE_MONEY_CHANGED trade=hidden my=0 their=5000", -- [210]
				"1794943056.000|Anita Lift|ev|TRADE_ACCEPT_UPDATE me=0 them=1 trade=hidden my=0 their=5000", -- [211]
				"1794943056.050|Anita Lift|fire|DRIVE ", -- [212]
				"1794943056.100|Anita Lift|run|ride_trade pass Wuber Rocks: put in 50s and pressed Trade (2.3 s)", -- [213]
				"1794943056.100|Anita Lift|run|step 15/37 ride_paid on Anita Lift: click the big button (it says {button})", -- [214]
				"1794943057.000|Anita Lift|click|big button: 'Accept 50s from Wuber' (click: accepts the trade) type=click; floating MEDIUM/1, window HIGH/1", -- [215]
				"1794943057.000|Anita Lift|ev|TRADE_ACCEPT_UPDATE me=1 them=1 trade=hidden my=0 their=5000", -- [216]
				"1794943057.000|Anita Lift|ev|PLAYER_MONEY +5000 now=1005000 (trade open)", -- [217]
				"1794943057.000|Anita Lift|ev|TRADE_CLOSED", -- [218]
				"1794943057.000|Anita Lift|probe|AcceptTrade() called combat=false trade=hidden my=0 their=0", -- [219]
				"1794943057.000|Anita Lift|click|noted: none", -- [220]
				"1794943057.050|Anita Lift|fire|DRIVE ", -- [221]
				"1794943057.100|Anita Lift|plan|s3_c3;auto;by=ride_arrived+fx_arrival;who=Wuber Rocks;src=sync", -- [222]
				"1794943057.100|Anita Lift|plan|s3_r6;auto;by=ride_arrived;who=Wuber Rocks;src=sync", -- [223]
				"1794943057.300|Anita Lift|run|ride_paid pass Anita Lift: paid 50s by Wuber Rocks (1.2 s)", -- [224]
				"1794943057.300|Anita Lift|run|send RUN~R~6afca83b37~15~ride_paid~pass~1.2~Anita Lift~paid 50s by Wuber Rocks", -- [225]
				"1794943057.300|Anita Lift|run|step 16/37 ride_done on Wuber Rocks: Wuber Rocks' Wuber marks the ride paid", -- [226]
				"1794943057.300|Anita Lift|fire|DRIVE_PAID Wuber Rocks 5000 0", -- [227]
				"1794943057.300|Anita Lift|fx|Fullscreen paid played", -- [228]
				"1794943057.300|Anita Lift|check|d_paidfx;auto;by=fx_paid;took=-;Paid burst plays", -- [229]
				"1794943057.300|Anita Lift|fire|DRIVE_LOG ", -- [230]
				"1794943057.300|Anita Lift|fire|DRIVE_STATE Wuber Rocks arrived", -- [231]
				"1794943057.300|Anita Lift|fire|DRIVE_LOG ", -- [232]
				"1794943057.300|Anita Lift|msg>|S W>Wuber Rocks S~1~BSnQHF~paid~~Farra Way~Hayley Cab", -- [233]
				"1794943057.300|Anita Lift|fire|REQUESTS n=0", -- [234]
				"1794943057.300|Anita Lift|try|cap=comm ok=true result=0 combat=false", -- [235]
				"1794943057.350|Anita Lift|fire|DRIVE ", -- [236]
				"1794943058.000|Anita Lift|msg>|D W>Farra Way D~1~Undercity~1458~500~500~5000~Anita Lift~open~3~6~H~2.2.1~~0~1~CAMWOW EU5 Realm 5 PvE~1", -- [237]
				"1794943058.000|Anita Lift|msg>|D W>Wuber Rocks D~1~Undercity~1458~500~500~5000~Anita Lift~open~3~6~H~2.2.1~~0~1~CAMWOW EU5 Realm 5 PvE~1", -- [238]
				"1794943058.000|Anita Lift|msg>|D W>Hayley Cab D~1~Undercity~1458~500~500~5000~Anita Lift~open~3~6~H~2.2.1~~0~1~CAMWOW EU5 Realm 5 PvE~1", -- [239]
				"1794943058.050|Anita Lift|fire|DRIVE ", -- [240]
				"1794943058.100|Anita Lift|run|ride_done pass Wuber Rocks: done, paid 50s (0.0 s)", -- [241]
				"1794943058.100|Anita Lift|run|step 17/37 ride_left on Wuber Rocks: Wuber Rocks leaves the group by itself", -- [242]
				"1794943058.600|Anita Lift|plan|s3_c4;auto;by=pay_exact;who=Wuber Rocks;src=sync", -- [243]
				"1794943059.050|Anita Lift|fire|DRIVE ", -- [244]
				"1794943060.000|Anita Lift|ev|GROUP_ROSTER_UPDATE members=2 Farra Way,Hayley Cab", -- [245]
				"1794943060.050|Anita Lift|fire|DRIVE ", -- [246]
				"1794943061.000|Anita Lift|fire|DRIVE_LOG ", -- [247]
				"1794943061.050|Anita Lift|fire|DRIVE ", -- [248]
				"1794943062.050|Anita Lift|fire|DRIVE ", -- [249]
				"1794943063.000|Anita Lift|msg>|D W>Farra Way D~1~Undercity~1458~500~500~5000~Anita Lift~open~3~7~H~2.2.1~~0~1~CAMWOW EU5 Realm 5 PvE~1", -- [250]
				"1794943063.000|Anita Lift|msg>|D W>Wuber Rocks D~1~Undercity~1458~500~500~5000~Anita Lift~open~3~7~H~2.2.1~~0~1~CAMWOW EU5 Realm 5 PvE~1", -- [251]
				"1794943063.000|Anita Lift|msg>|D W>Hayley Cab D~1~Undercity~1458~500~500~5000~Anita Lift~open~3~7~H~2.2.1~~0~1~CAMWOW EU5 Realm 5 PvE~1", -- [252]
				"1794943063.050|Anita Lift|fire|DRIVE ", -- [253]
				"1794943063.100|Anita Lift|plan|s3_c5;auto;by=auto_left;who=Wuber Rocks;src=sync", -- [254]
				"1794943064.050|Anita Lift|fire|DRIVE ", -- [255]
				"1794943064.100|Anita Lift|run|ride_left pass Wuber Rocks: left the group with no click (2.6 s)", -- [256]
				"1794943064.100|Anita Lift|run|step 18/37 ride_rate on Wuber Rocks: tap 5 stars on the Done screen", -- [257]
				"1794943064.600|Anita Lift|fire|RATING BSnQHF Wuber Rocks 5", -- [258]
				"1794943064.600|Anita Lift|fx|Fullscreen coins played", -- [259]
				"1794943064.600|Anita Lift|check|d_coins;auto;by=fx_coins;took=7.3;Coin shower on 5 stars", -- [260]
				"1794943064.600|Anita Lift|plan|s5_6;auto;by=fx_paid+fx_coins;who=Anita Lift;src=local", -- [261]
				"1794943064.600|Anita Lift|msg<|T W<Wuber Rocks T~1~BSnQHF~5", -- [262]
				"1794943065.050|Anita Lift|fire|DRIVE ", -- [263]
				"1794943066.000|Anita Lift|try|cap=comm ok=true result=0 combat=false", -- [264]
				"1794943066.050|Anita Lift|fire|DRIVE ", -- [265]
				"1794943067.050|Anita Lift|fire|DRIVE ", -- [266]
				"1794943068.050|Anita Lift|fire|DRIVE ", -- [267]
				"1794943068.100|Anita Lift|fire|DRIVE_CREW ", -- [268]
				"1794943068.100|Anita Lift|fire|DRIVE_CREW ", -- [269]
				"1794943068.150|Anita Lift|fire|DRIVE ", -- [270]
				"1794943069.050|Anita Lift|fire|DRIVE ", -- [271]
				"1794943069.100|Anita Lift|plan|s3_r8;auto;by=auto_left+rated+milestone_pop;who=Wuber Rocks;src=sync", -- [272]
				"1794943069.100|Anita Lift|plan|s3_c6;auto;by=milestone_pop+rated;who=Wuber Rocks;src=sync", -- [273]
				"1794943070.050|Anita Lift|fire|DRIVE ", -- [274]
				"1794943070.100|Anita Lift|run|ride_rate pass Wuber Rocks: rated 5 stars (5.0 s)", -- [275]
				"1794943070.100|Anita Lift|run|step 19/37 ride_thanks on Anita Lift: click the big button (it says {button})", -- [276]
				"1794943070.500|Anita Lift|click|big button: 'Thank Wuber' (click) type=macro; floating MEDIUM/1, window HIGH/1", -- [277]
				"1794943070.500|Anita Lift|click|macro: /w Wuber-Rocks Thank you, Wuber! Enjoy Undercity - Anita Lift is here whenever you need a lift.", -- [278]
				"1794943070.500|Anita Lift|whsp|> Wuber Rocks: Thank you, Wuber! Enjoy Undercity - Anita Lift is here whenever you need a lift.", -- [279]
				"1794943070.500|Anita Lift|run|ride_thanks pass Anita Lift: thank-you whisper sent to Wuber Rocks (0.4 s)", -- [280]
				"1794943070.500|Anita Lift|run|send RUN~R~6afca83b37~19~ride_thanks~pass~0.4~Anita Lift~thank-you whisper sent to Wuber Rocks", -- [281]
				"1794943070.500|Anita Lift|run|step 20/37 ride_earnings on Anita Lift: Drive tab: open Earnings, then click Snap (below)", -- [282]
				"1794943070.500|Anita Lift|fire|DRIVE_STATE Wuber Rocks paid", -- [283]
				"1794943070.500|Anita Lift|msg>|S W>Wuber Rocks S~1~BSnQHF~done~~Farra Way~Hayley Cab", -- [284]
				"1794943070.500|Anita Lift|try|cap=comm ok=true result=0 combat=false", -- [285]
				"1794943070.500|Anita Lift|click|noted: thanks Wuber Rocks", -- [286]
				"1794943070.500|Anita Lift|photo|shot 1 snap at 19:17:50 -> Screenshots\\WoWScrnShot_111726_191750", -- [287]
				"1794943070.500|Anita Lift|tool|screenshot 1 saved (19:17:50): World of Warcraft\\_forever_\\Screenshots\\WoWScrnShot_111726_191750", -- [288]
				"1794943070.500|Anita Lift|run|ride_earnings look Anita Lift: screenshot 1: Earnings with today's ride (0.0 s)", -- [289]
				"1794943070.500|Anita Lift|run|send RUN~R~6afca83b37~20~ride_earnings~look~0.0~Anita Lift~screenshot 1: Earnings with today's ride", -- [290]
				"1794943070.500|Anita Lift|run|step 21/37 raid_invite on Anita Lift: type /invite Wuber Rocks", -- [291]
				"1794943070.550|Anita Lift|fire|DRIVE ", -- [292]
				"1794943070.700|Anita Lift|sys|You have invited Wuber Rocks to join your group.", -- [293]
				"1794943071.000|Anita Lift|fire|DRIVE_REMOVED Wuber Rocks done", -- [294]
				"1794943071.050|Anita Lift|fire|DRIVE ", -- [295]
				"1794943072.050|Anita Lift|fire|DRIVE ", -- [296]
				"1794943073.050|Anita Lift|fire|DRIVE ", -- [297]
				"1794943073.100|Anita Lift|run|raid_invite pass Anita Lift: the invite reached Wuber Rocks (0.0 s)", -- [298]
				"1794943073.100|Anita Lift|run|step 22/37 raid_join on Wuber Rocks: click Accept on the group invite", -- [299]
				"1794943073.600|Anita Lift|fire|DRIVE_STATE Wuber Rocks nil", -- [300]
				"1794943073.600|Anita Lift|ev|GROUP_ROSTER_UPDATE members=3 Farra Way,Hayley Cab,Wuber Rocks", -- [301]
				"1794943073.650|Anita Lift|fire|DRIVE ", -- [302]
				"1794943074.000|Anita Lift|msg>|D W>Farra Way D~1~Undercity~1458~500~500~5000~Anita Lift~busy~3~6~H~2.2.1~~0~1~CAMWOW EU5 Realm 5 PvE~1", -- [303]
				"1794943074.000|Anita Lift|msg>|D W>Wuber Rocks D~1~Undercity~1458~500~500~5000~Anita Lift~busy~3~6~H~2.2.1~~0~1~CAMWOW EU5 Realm 5 PvE~1", -- [304]
				"1794943074.000|Anita Lift|msg>|D W>Hayley Cab D~1~Undercity~1458~500~500~5000~Anita Lift~busy~3~6~H~2.2.1~~0~1~CAMWOW EU5 Realm 5 PvE~1", -- [305]
				"1794943074.000|Anita Lift|fire|DRIVE_STATE Wuber Rocks joined", -- [306]
				"1794943074.050|Anita Lift|fire|DRIVE ", -- [307]
				"1794943075.050|Anita Lift|fire|DRIVE ", -- [308]
				"1794943076.050|Anita Lift|fire|DRIVE ", -- [309]
				"1794943077.050|Anita Lift|fire|DRIVE ", -- [310]
				"1794943077.100|Anita Lift|run|raid_join pass Wuber Rocks: in Anita's group (3.0 s)", -- [311]
				"1794943077.100|Anita Lift|run|step 23/37 raid_convert on Anita Lift: right-click your portrait, Convert to Raid", -- [312]
				"1794943077.500|Anita Lift|sys|Party converted to Raid", -- [313]
				"1794943077.500|Anita Lift|ev|GROUP_ROSTER_UPDATE members=4 Anita Lift,Farra Way,Hayley Cab,Wuber Rocks", -- [314]
				"1794943077.550|Anita Lift|fire|DRIVE ", -- [315]
				"1794943078.000|Anita Lift|run|raid_convert pass Anita Lift: a raid (0.9 s)", -- [316]
				"1794943078.000|Anita Lift|run|send RUN~R~6afca83b37~23~raid_convert~pass~0.9~Anita Lift~a raid", -- [317]
				"1794943078.000|Anita Lift|run|step 24/37 raid_start on Anita Lift: Drive tab: Raid summons, tick Anita, Farra and Hayley as summoners, press Start", -- [318]
				"1794943078.000|Anita Lift|try|cap=comm ok=true result=0 combat=false", -- [319]
				"1794943078.000|Anita Lift|try|cap=comm ok=true result=0 combat=false", -- [320]
				"1794943078.000|Anita Lift|fire|DRIVE_MODE raid", -- [321]
				"1794943078.000|Anita Lift|fire|DRIVE_RAID ", -- [322]
				"1794943078.000|Anita Lift|fire|SETTINGS drive={table}", -- [323]
				"1794943078.050|Anita Lift|fire|DRIVE ", -- [324]
				"1794943079.000|Anita Lift|try|cap=comm ok=true result=0 combat=false", -- [325]
				"1794943079.000|Anita Lift|fire|DRIVE_CREW ", -- [326]
				"1794943079.000|Anita Lift|fire|SETTINGS summoners=nil", -- [327]
				"1794943079.050|Anita Lift|fire|DRIVE ", -- [328]
				"1794943080.000|Anita Lift|try|cap=comm ok=true result=0 combat=false", -- [329]
				"1794943080.000|Anita Lift|try|cap=comm ok=true result=0 combat=false", -- [330]
				"1794943080.000|Anita Lift|try|cap=comm ok=true result=0 combat=false", -- [331]
				"1794943080.000|Anita Lift|fire|SETTINGS drive={table}", -- [332]
				"1794943080.000|Anita Lift|fire|DRIVE_RAID ", -- [333]
				"1794943080.050|Anita Lift|fire|DRIVE ", -- [334]
				"1794943080.500|Anita Lift|run|raid_start pass Anita Lift: raid summons on, 3 summoners (2.5 s)", -- [335]
				"1794943080.500|Anita Lift|run|send RUN~R~6afca83b37~24~raid_start~pass~2.5~Anita Lift~raid summons on, 3 summoners", -- [336]
				"1794943080.500|Anita Lift|run|step 25/37 raid_window on Anita Lift: keep Wuber's window open on the Drive tab (open it if it closed)", -- [337]
				"1794943080.500|Anita Lift|ui|window open", -- [338]
				"1794943081.050|Anita Lift|fire|DRIVE ", -- [339]
				"1794943082.050|Anita Lift|fire|DRIVE ", -- [340]
				"1794943083.000|Anita Lift|ui|tab Drive", -- [341]
				"1794943083.050|Anita Lift|fire|DRIVE ", -- [342]
				"1794943083.100|Anita Lift|fire|DRIVE_RAID ", -- [343]
				"1794943083.100|Anita Lift|fire|DRIVE_CREW ", -- [344]
				"1794943083.100|Anita Lift|fire|DRIVE_RAID ", -- [345]
				"1794943083.100|Anita Lift|fire|DRIVE_CREW ", -- [346]
				"1794943083.150|Anita Lift|fire|DRIVE ", -- [347]
				"1794943083.500|Anita Lift|run|raid_window pass Anita Lift: window open, big button docked on top (FULLSCREEN_DIALOG over HIGH) (3.0 s)", -- [348]
				"1794943083.500|Anita Lift|run|send RUN~R~6afca83b37~25~raid_window~pass~3.0~Anita Lift~window open, big button docked on top (FULLSCREEN_DIALOG over HIGH)", -- [349]
				"1794943083.500|Anita Lift|run|step 26/37 raid_away on Wuber Rocks: take Wuber Rocks out of Anita's zone (hearth or walk out), staying in the raid", -- [350]
				"1794943084.050|Anita Lift|fire|DRIVE ", -- [351]
				"1794943084.500|Anita Lift|run|raid_away pass Wuber Rocks: Wuber Rocks is away from the spot (Orgrimmar) (1.0 s)", -- [352]
				"1794943084.500|Anita Lift|run|send RUN~R~6afca83b37~26~raid_away~pass~1.0~Anita Lift~Wuber Rocks is away from the spot (Orgrimmar)", -- [353]
				"1794943084.500|Anita Lift|run|step 27/37 raid_tap on Wuber Rocks: type /wuber and tap Request a summon", -- [354]
				"1794943084.600|Anita Lift|fire|DRIVE_RAID ", -- [355]
				"1794943084.600|Anita Lift|try|cap=comm ok=true result=0 combat=false", -- [356]
				"1794943084.650|Anita Lift|fire|DRIVE ", -- [357]
				"1794943085.000|Anita Lift|run|raid_tap pass Wuber Rocks: queued from the app (Request a summon) (0.5 s)", -- [358]
				"1794943085.000|Anita Lift|run|send RUN~R~6afca83b37~27~raid_tap~pass~0.5~Anita Lift~queued from the app (Request a summon)", -- [359]
				"1794943085.000|Anita Lift|run|step 28/37 raid_nvm on Wuber Rocks: type nvm in raid chat", -- [360]
				"1794943085.000|Anita Lift|fire|DRIVE_RAID ", -- [361]
				"1794943085.000|Anita Lift|try|cap=comm ok=true result=0 combat=false", -- [362]
				"1794943085.050|Anita Lift|fire|DRIVE ", -- [363]
				"1794943085.500|Anita Lift|run|raid_nvm pass Wuber Rocks: dropped from the list (0.5 s)", -- [364]
				"1794943085.500|Anita Lift|run|send RUN~R~6afca83b37~28~raid_nvm~pass~0.5~Anita Lift~dropped from the list", -- [365]
				"1794943085.500|Anita Lift|run|step 29/37 raid_ask on Wuber Rocks: type 123 in raid chat", -- [366]
				"1794943085.500|Anita Lift|fire|DRIVE_RAID ", -- [367]
				"1794943085.500|Anita Lift|try|cap=comm ok=true result=0 combat=false", -- [368]
				"1794943085.550|Anita Lift|fire|DRIVE ", -- [369]
				"1794943086.000|Anita Lift|run|raid_ask pass Wuber Rocks: Wuber Rocks queued (queued) (0.5 s)", -- [370]
				"1794943086.000|Anita Lift|run|send RUN~R~6afca83b37~29~raid_ask~pass~0.5~Anita Lift~Wuber Rocks queued (queued)", -- [371]
				"1794943086.000|Anita Lift|run|step 30/37 raid_button on Anita Lift: the big button offers the summon", -- [372]
				"1794943086.000|Anita Lift|run|raid_button pass Anita Lift: it says 'Summon Wuber' (docked on top (FULLSCREEN_DIALOG over HIGH)) (0.0 s)", -- [373]
				"1794943086.000|Anita Lift|run|send RUN~R~6afca83b37~30~raid_button~pass~0.0~Anita Lift~it says 'Summon Wuber' (docked on top (FULLSCREEN_DIALOG over HIGH))", -- [374]
				"1794943086.000|Anita Lift|run|step 31/37 raid_cast on Anita Lift: click the big button (it says {button})", -- [375]
				"1794943086.000|Anita Lift|sim|pretend cast on Wuber Rocks", -- [376]
				"1794943086.000|Anita Lift|fire|DRIVE_RAID ", -- [377]
				"1794943086.000|Anita Lift|try|cap=comm ok=true result=0 combat=false", -- [378]
				"1794943086.000|Anita Lift|fire|DRIVE_RAID ", -- [379]
				"1794943086.000|Anita Lift|try|cap=comm ok=true result=0 combat=false", -- [380]
				"1794943086.000|Anita Lift|click|big button: 'Summon Wuber' (click: calls the clickers, targets and casts  -  20 shards) type=macro; docked FULLSCREEN_DIALOG/101, window HIGH/1", -- [381]
				"1794943086.000|Anita Lift|click|macro: /w Wuber-Rocks Summon coming from Anita - accept it when it pops ; /ra Summoning Wuber - click the portal please ; /target Wuber Rocks ; /stopmacro [combat,nocombat]", -- [382]
				"1794943086.000|Anita Lift|whsp|> Wuber Rocks: Summon coming from Anita - accept it when it pops", -- [383]
				"1794943086.000|Anita Lift|click|noted: raidsum Wuber Rocks, cast Wuber Rocks", -- [384]
				"1794943086.050|Anita Lift|fire|DRIVE ", -- [385]
				"1794943086.500|Anita Lift|run|raid_cast pass Anita Lift: Anita's ritual started on Wuber Rocks (pretend) (0.5 s)", -- [386]
				"1794943086.500|Anita Lift|run|send RUN~R~6afca83b37~31~raid_cast~pass~0.5~Anita Lift~Anita's ritual started on Wuber Rocks (pretend)", -- [387]
				"1794943086.500|Anita Lift|run|step 32/37 raid_portal1 on Farra Way: function: 0x56275c7bf820", -- [388]
				"1794943086.700|Anita Lift|run|raid_portal1 skip Farra Way: test mode: the pretend ritual needs no portal clicks (0.0 s)", -- [389]
				"1794943086.700|Anita Lift|run|step 33/37 raid_portal2 on Hayley Cab: function: 0x56275c7bf820", -- [390]
				"1794943086.800|Anita Lift|run|raid_portal2 skip Hayley Cab: test mode: the pretend ritual needs no portal clicks (0.0 s)", -- [391]
				"1794943086.800|Anita Lift|run|step 34/37 raid_arrive on Wuber Rocks: function: 0x56275c6d2080", -- [392]
				"1794943087.050|Anita Lift|fire|DRIVE ", -- [393]
				"1794943088.050|Anita Lift|fire|DRIVE ", -- [394]
				"1794943089.050|Anita Lift|fire|DRIVE ", -- [395]
				"1794943089.500|Anita Lift|sim|send Wuber Rocks: SIM~summon~Anita Lift~Undercity", -- [396]
				"1794943090.050|Anita Lift|fire|DRIVE ", -- [397]
				"1794943090.500|Anita Lift|fire|DRIVE_RAID ", -- [398]
				"1794943090.500|Anita Lift|try|cap=comm ok=true result=0 combat=false", -- [399]
				"1794943090.500|Anita Lift|fire|DRIVE_LOG ", -- [400]
				"1794943090.550|Anita Lift|fire|DRIVE ", -- [401]
				"1794943091.050|Anita Lift|fire|DRIVE ", -- [402]
				"1794943091.100|Anita Lift|sim|arrived (pretend): wuber rocks", -- [403]
				"1794943092.000|Anita Lift|run|raid_arrive pass Wuber Rocks: summoned, counted, off the list (5.2 s)", -- [404]
				"1794943092.000|Anita Lift|run|send RUN~R~6afca83b37~34~raid_arrive~pass~5.2~Anita Lift~summoned, counted, off the list", -- [405]
				"1794943092.000|Anita Lift|run|step 35/37 raid_one on Anita Lift: Farra's and Hayley's Wuber left Wuber Rocks to Anita", -- [406]
				"1794943092.000|Anita Lift|fire|DRIVE_RAID_DONE Wuber Rocks anita lift", -- [407]
				"1794943092.000|Anita Lift|fire|DRIVE_RAID ", -- [408]
				"1794943092.050|Anita Lift|fire|DRIVE ", -- [409]
				"1794943092.200|Anita Lift|run|raid_one pass Anita Lift: Farra's and Hayley's buttons and rituals left Wuber Rocks alone (0.2 s)", -- [410]
				"1794943092.200|Anita Lift|run|send RUN~R~6afca83b37~35~raid_one~pass~0.2~Anita Lift~Farra's and Hayley's buttons and rituals left Wuber Rocks alone", -- [411]
				"1794943092.200|Anita Lift|run|step 36/37 raid_stop on Anita Lift: press Stop on the Drive tab", -- [412]
				"1794943092.500|Anita Lift|try|cap=comm ok=true result=0 combat=false", -- [413]
				"1794943092.500|Anita Lift|try|cap=comm ok=true result=0 combat=false", -- [414]
				"1794943092.500|Anita Lift|try|cap=comm ok=true result=0 combat=false", -- [415]
				"1794943092.500|Anita Lift|fire|SETTINGS drive={table}", -- [416]
				"1794943092.500|Anita Lift|fire|DRIVE_RAID ", -- [417]
				"1794943092.550|Anita Lift|fire|DRIVE ", -- [418]
				"1794943093.000|Anita Lift|run|raid_stop pass Anita Lift: raid summons stopped (0.8 s)", -- [419]
				"1794943093.000|Anita Lift|run|send RUN~R~6afca83b37~36~raid_stop~pass~0.8~Anita Lift~raid summons stopped", -- [420]
				"1794943093.000|Anita Lift|run|step 37/37 photo_tour on Anita Lift: press Close on the Drive tab if open, then click Start photo tour (below): hands off for a minute", -- [421]
				"1794943093.000|Anita Lift|photo|tour start: 25 screens, automatic shots", -- [422]
				"1794943094.500|Anita Lift|photo|shot 2 home at 19:18:14 -> Screenshots\\WoWScrnShot_111726_191814", -- [423]
				"1794943096.200|Anita Lift|photo|shot 3 confirm at 19:18:16 -> Screenshots\\WoWScrnShot_111726_191816", -- [424]
				"1794943097.900|Anita Lift|photo|shot 4 portal at 19:18:17 -> Screenshots\\WoWScrnShot_111726_191817", -- [425]
				"1794943099.600|Anita Lift|photo|shot 5 pay at 19:18:19 -> Screenshots\\WoWScrnShot_111726_191819", -- [426]
				"1794943101.300|Anita Lift|photo|shot 6 stranger at 19:18:21 -> Screenshots\\WoWScrnShot_111726_191821", -- [427]
				"1794943103.000|Anita Lift|photo|shot 7 done_paid at 19:18:23 -> Screenshots\\WoWScrnShot_111726_191823", -- [428]
				"1794943104.700|Anita Lift|photo|shot 8 done_unpaid at 19:18:24 -> Screenshots\\WoWScrnShot_111726_191824", -- [429]
				"1794943106.400|Anita Lift|photo|shot 9 trips at 19:18:26 -> Screenshots\\WoWScrnShot_111726_191826", -- [430]
				"1794943108.100|Anita Lift|photo|shot 10 console_open at 19:18:28 -> Screenshots\\WoWScrnShot_111726_191828", -- [431]
				"1794943109.800|Anita Lift|photo|shot 11 button_summoning at 19:18:29 -> Screenshots\\WoWScrnShot_111726_191829", -- [432]
				"1794943111.500|Anita Lift|photo|shot 12 button_portal at 19:18:31 -> Screenshots\\WoWScrnShot_111726_191831", -- [433]
				"1794943113.200|Anita Lift|photo|shot 13 button_waiting at 19:18:33 -> Screenshots\\WoWScrnShot_111726_191833", -- [434]
				"1794943114.900|Anita Lift|photo|shot 14 console_closed at 19:18:34 -> Screenshots\\WoWScrnShot_111726_191834", -- [435]
				"1794943116.600|Anita Lift|photo|shot 15 raid at 19:18:36 -> Screenshots\\WoWScrnShot_111726_191836", -- [436]
				"1794943118.300|Anita Lift|photo|shot 16 earnings at 19:18:38 -> Screenshots\\WoWScrnShot_111726_191838", -- [437]
				"1794943120.000|Anita Lift|photo|shot 17 earnings_heatmap at 19:18:40 -> Screenshots\\WoWScrnShot_111726_191840", -- [438]
				"1794943121.700|Anita Lift|photo|shot 18 shift at 19:18:41 -> Screenshots\\WoWScrnShot_111726_191841", -- [439]
				"1794943123.400|Anita Lift|photo|shot 19 messages at 19:18:43 -> Screenshots\\WoWScrnShot_111726_191843", -- [440]
				"1794943125.100|Anita Lift|photo|shot 20 messages_edit at 19:18:45 -> Screenshots\\WoWScrnShot_111726_191845", -- [441]
				"1794943126.800|Anita Lift|photo|shot 21 crew at 19:18:46 -> Screenshots\\WoWScrnShot_111726_191846", -- [442]
				"1794943128.500|Anita Lift|photo|shot 22 settings_top at 19:18:48 -> Screenshots\\WoWScrnShot_111726_191848", -- [443]
				"1794943130.200|Anita Lift|photo|shot 23 settings_middle at 19:18:50 -> Screenshots\\WoWScrnShot_111726_191850", -- [444]
				"1794943131.900|Anita Lift|photo|shot 24 settings_driving at 19:18:51 -> Screenshots\\WoWScrnShot_111726_191851", -- [445]
				"1794943133.600|Anita Lift|photo|shot 25 settings_driving2 at 19:18:53 -> Screenshots\\WoWScrnShot_111726_191853", -- [446]
				"1794943135.300|Anita Lift|photo|shot 26 help at 19:18:55 -> Screenshots\\WoWScrnShot_111726_191855", -- [447]
				"1794943135.800|Anita Lift|ui|tab Drive", -- [448]
				"1794943135.800|Anita Lift|photo|photo tour done: 25 screenshots taken (25 screens) in 43 s; WuberDB and Wuber put back", -- [449]
				"1794943135.800|Anita Lift|tool|photo tour done: 25 screenshots taken (25 screens). They are in World of Warcraft\\_forever_\\Screenshots.", -- [450]
				"1794943136.000|Anita Lift|try|cap=comm ok=true result=0 combat=false", -- [451]
				"1794943136.000|Anita Lift|run|photo_tour pass Anita Lift: 25 screenshots (43.0 s)", -- [452]
				"1794943136.000|Anita Lift|run|send RUN~R~6afca83b37~37~photo_tour~pass~43.0~Anita Lift~25 screenshots", -- [453]
				"1794943136.000|Anita Lift|run|end 6afca83b37 (done): 37 of 37 checked, 0 failed", -- [454]
				"1794943136.000|Anita Lift|tool|test run done: log out or /reload, then tell the person running the test \"done\".", -- [455]
				"1794943136.050|Anita Lift|fire|DRIVE ", -- [456]
			},
			["realm"] = "CAMWOW EU5 Realm 5 PvE",
			["role"] = "driver",
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
					["id"] = "d_provider",
					["sec"] = "Setup",
					["text"] = "Ritual Rides drives for Wuber",
				}, -- [1]
				{
					["id"] = "d_online",
					["sec"] = "Setup",
					["text"] = "Beacon: open",
				}, -- [2]
				{
					["id"] = "d_check",
					["sec"] = "Setup",
					["text"] = "Check my game runs",
				}, -- [3]
				{
					["id"] = "d_seen",
					["manual"] = true,
					["sec"] = "Setup",
					["text"] = "Team seen on the rider's list and map",
				}, -- [4]
				{
					["id"] = "d_request",
					["sec"] = "Ride",
					["text"] = "Wuber request arrives",
				}, -- [5]
				{
					["id"] = "d_accept",
					["sec"] = "Ride",
					["text"] = "Accepted (A sent)",
				}, -- [6]
				{
					["id"] = "d_queue",
					["sec"] = "Ride",
					["text"] = "Queue place sent",
				}, -- [7]
				{
					["id"] = "d_invited",
					["sec"] = "Ride",
					["text"] = "Invited",
				}, -- [8]
				{
					["id"] = "d_summoning",
					["sec"] = "Ride",
					["text"] = "Summoning",
				}, -- [9]
				{
					["id"] = "d_portal",
					["sec"] = "Ride",
					["text"] = "Portal up",
				}, -- [10]
				{
					["id"] = "d_arrived",
					["sec"] = "Ride",
					["text"] = "Arrived",
				}, -- [11]
				{
					["id"] = "d_paid",
					["sec"] = "Ride",
					["text"] = "Paid in trade",
				}, -- [12]
				{
					["id"] = "d_rating",
					["sec"] = "Ride",
					["text"] = "Rating received",
				}, -- [13]
				{
					["id"] = "d_cancel",
					["sec"] = "Edge",
					["text"] = "Rider cancelled -> dropped",
				}, -- [14]
				{
					["id"] = "d_busy",
					["sec"] = "Edge",
					["text"] = "Busy beacon during a ride",
				}, -- [15]
				{
					["id"] = "d_paused",
					["sec"] = "Edge",
					["text"] = "Paused/closed -> declined",
				}, -- [16]
				{
					["id"] = "d_price",
					["sec"] = "Edge",
					["text"] = "Price change -> new beacon",
				}, -- [17]
				{
					["id"] = "d_one",
					["manual"] = true,
					["sec"] = "Edge",
					["text"] = "One status per step",
				}, -- [18]
				{
					["id"] = "d_crown",
					["manual"] = true,
					["sec"] = "Looks",
					["text"] = "Crown on the rider's screen",
				}, -- [19]
				{
					["id"] = "d_paidfx",
					["sec"] = "Looks",
					["text"] = "Paid burst plays",
				}, -- [20]
				{
					["id"] = "d_coins",
					["sec"] = "Looks",
					["text"] = "Coin shower on 5 stars",
				}, -- [21]
			},
			["versions"] = {
				["lab"] = "1.1.0",
				["rr"] = "1.4.0",
				["wuber"] = "1.0.0",
			},
		},
	},
	["login"] = {
		["Anita Lift"] = {
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
				"login_versions|pass|same versions as Farra, Hayley, Wuber Rocks (2.2.1/1.1.0/1)|1794943008.500|0.5", -- [9]
				"login_button|pass|the big button is hidden (closed)|1794943013.000|5.0", -- [10]
				"login_errors|pass|no Lua errors since login|1794943033.000|25.0", -- [11]
				"login_saved|skip|WuberLabDB came back empty and no other window remembers this one: a first start here|1794943033.000|25.0", -- [12]
				"login_community|skip|Community: not available in this game.|1794943033.000|25.0", -- [13]
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
			["by"] = "whisper_wtb_in",
			["r"] = "auto",
			["who"] = "Anita Lift",
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
			["at"] = 1794943136,
			["r"] = "pass",
			["sid"] = "6afca83b37",
			["ver"] = "2.2.1",
			["w"] = "Anita Lift",
			["why"] = "25 screenshots",
		},
		["raid_arrive"] = {
			["at"] = 1794943092,
			["r"] = "pass",
			["sid"] = "6afca83b37",
			["ver"] = "2.2.1",
			["w"] = "Wuber Rocks",
			["why"] = "summoned, counted, off the list",
		},
		["raid_ask"] = {
			["at"] = 1794943086,
			["r"] = "pass",
			["sid"] = "6afca83b37",
			["ver"] = "2.2.1",
			["w"] = "Wuber Rocks",
			["why"] = "Wuber Rocks queued (queued)",
		},
		["raid_away"] = {
			["at"] = 1794943084.5,
			["r"] = "pass",
			["sid"] = "6afca83b37",
			["ver"] = "2.2.1",
			["w"] = "Wuber Rocks",
			["why"] = "Wuber Rocks is away from the spot (Orgrimmar)",
		},
		["raid_button"] = {
			["at"] = 1794943086,
			["r"] = "pass",
			["sid"] = "6afca83b37",
			["ver"] = "2.2.1",
			["w"] = "Anita Lift",
			["why"] = "it says 'Summon Wuber' (docked on top (FULLSCREEN_DIALOG over HIGH))",
		},
		["raid_cast"] = {
			["at"] = 1794943086.5,
			["r"] = "pass",
			["sid"] = "6afca83b37",
			["ver"] = "2.2.1",
			["w"] = "Anita Lift",
			["why"] = "Anita's ritual started on Wuber Rocks (pretend)",
		},
		["raid_convert"] = {
			["at"] = 1794943078,
			["r"] = "pass",
			["sid"] = "6afca83b37",
			["ver"] = "2.2.1",
			["w"] = "Anita Lift",
			["why"] = "a raid",
		},
		["raid_invite"] = {
			["at"] = 1794943073.1,
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
			["at"] = 1794943085.5,
			["r"] = "pass",
			["sid"] = "6afca83b37",
			["ver"] = "2.2.1",
			["w"] = "Wuber Rocks",
			["why"] = "dropped from the list",
		},
		["raid_one"] = {
			["at"] = 1794943092.2,
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
			["at"] = 1794943080.5,
			["r"] = "pass",
			["sid"] = "6afca83b37",
			["ver"] = "2.2.1",
			["w"] = "Anita Lift",
			["why"] = "raid summons on, 3 summoners",
		},
		["raid_stop"] = {
			["at"] = 1794943093,
			["r"] = "pass",
			["sid"] = "6afca83b37",
			["ver"] = "2.2.1",
			["w"] = "Anita Lift",
			["why"] = "raid summons stopped",
		},
		["raid_tap"] = {
			["at"] = 1794943085,
			["r"] = "pass",
			["sid"] = "6afca83b37",
			["ver"] = "2.2.1",
			["w"] = "Wuber Rocks",
			["why"] = "queued from the app (Request a summon)",
		},
		["raid_window"] = {
			["at"] = 1794943083.5,
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
			["at"] = 1794943040.5,
			["r"] = "pass",
			["sid"] = "6afca83b37",
			["ver"] = "2.2.1",
			["w"] = "Anita Lift",
			["why"] = "beacon open: 50s to Undercity",
		},
		["ride_button"] = {
			["at"] = 1794943047.1,
			["r"] = "pass",
			["sid"] = "6afca83b37",
			["ver"] = "2.2.1",
			["w"] = "Anita Lift",
			["why"] = "it says 'Summon Wuber' (floating, MEDIUM)",
		},
		["ride_cast"] = {
			["at"] = 1794943048,
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
			["at"] = 1794943070.5,
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
			["at"] = 1794943053.6,
			["r"] = "pass",
			["sid"] = "6afca83b37",
			["ver"] = "2.2.1",
			["w"] = "Anita Lift",
			["why"] = "Wuber Rocks counts as here (arrived)",
		},
		["ride_left"] = {
			["at"] = 1794943064.1,
			["r"] = "pass",
			["sid"] = "6afca83b37",
			["ver"] = "2.2.1",
			["w"] = "Wuber Rocks",
			["why"] = "left the group with no click",
		},
		["ride_open"] = {
			["at"] = 1794943040.5,
			["r"] = "pass",
			["sid"] = "6afca83b37",
			["ver"] = "2.2.1",
			["w"] = "Anita Lift",
			["why"] = "open, selling at 50s",
		},
		["ride_paid"] = {
			["at"] = 1794943057.3,
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
			["at"] = 1794943070.1,
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
			["at"] = 1794943046.6,
			["r"] = "pass",
			["sid"] = "6afca83b37",
			["ver"] = "2.2.1",
			["w"] = "Anita Lift",
			["why"] = "Wuber Rocks is in Anita's queue (joined)",
		},
		["ride_thanks"] = {
			["at"] = 1794943070.5,
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
		["ended"] = 1794943136,
		["index"] = 38,
		["later"] = 0,
		["results"] = {
			["photo_tour"] = {
				["at"] = 1794943136,
				["judge"] = "Anita Lift",
				["r"] = "pass",
				["took"] = 43,
				["who"] = "Anita Lift",
				["why"] = "25 screenshots",
			},
			["raid_arrive"] = {
				["at"] = 1794943092,
				["judge"] = "Anita Lift",
				["r"] = "pass",
				["took"] = 5.2000000000003,
				["who"] = "Wuber Rocks",
				["why"] = "summoned, counted, off the list",
			},
			["raid_ask"] = {
				["at"] = 1794943086,
				["judge"] = "Anita Lift",
				["r"] = "pass",
				["took"] = 0.5,
				["who"] = "Wuber Rocks",
				["why"] = "Wuber Rocks queued (queued)",
			},
			["raid_away"] = {
				["at"] = 1794943084.5,
				["judge"] = "Anita Lift",
				["r"] = "pass",
				["took"] = 1,
				["who"] = "Wuber Rocks",
				["why"] = "Wuber Rocks is away from the spot (Orgrimmar)",
			},
			["raid_button"] = {
				["at"] = 1794943086,
				["judge"] = "Anita Lift",
				["r"] = "pass",
				["took"] = 0,
				["who"] = "Anita Lift",
				["why"] = "it says 'Summon Wuber' (docked on top (FULLSCREEN_DIALOG over HIGH))",
			},
			["raid_cast"] = {
				["at"] = 1794943086.5,
				["judge"] = "Anita Lift",
				["r"] = "pass",
				["took"] = 0.5,
				["who"] = "Anita Lift",
				["why"] = "Anita's ritual started on Wuber Rocks (pretend)",
			},
			["raid_convert"] = {
				["at"] = 1794943078,
				["judge"] = "Anita Lift",
				["r"] = "pass",
				["took"] = 0.90000000000009,
				["who"] = "Anita Lift",
				["why"] = "a raid",
			},
			["raid_invite"] = {
				["at"] = 1794943073.1,
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
				["at"] = 1794943085.5,
				["judge"] = "Anita Lift",
				["r"] = "pass",
				["took"] = 0.5,
				["who"] = "Wuber Rocks",
				["why"] = "dropped from the list",
			},
			["raid_one"] = {
				["at"] = 1794943092.2,
				["judge"] = "Anita Lift",
				["r"] = "pass",
				["took"] = 0.19999999999982,
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
				["at"] = 1794943080.5,
				["judge"] = "Anita Lift",
				["r"] = "pass",
				["took"] = 2.5,
				["who"] = "Anita Lift",
				["why"] = "raid summons on, 3 summoners",
			},
			["raid_stop"] = {
				["at"] = 1794943093,
				["judge"] = "Anita Lift",
				["r"] = "pass",
				["took"] = 0.80000000000018,
				["who"] = "Anita Lift",
				["why"] = "raid summons stopped",
			},
			["raid_tap"] = {
				["at"] = 1794943085,
				["judge"] = "Anita Lift",
				["r"] = "pass",
				["took"] = 0.5,
				["who"] = "Wuber Rocks",
				["why"] = "queued from the app (Request a summon)",
			},
			["raid_window"] = {
				["at"] = 1794943083.5,
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
				["at"] = 1794943040.5,
				["judge"] = "Anita Lift",
				["r"] = "pass",
				["took"] = 0,
				["who"] = "Anita Lift",
				["why"] = "beacon open: 50s to Undercity",
			},
			["ride_button"] = {
				["at"] = 1794943047.1,
				["judge"] = "Anita Lift",
				["r"] = "pass",
				["took"] = 0,
				["who"] = "Anita Lift",
				["why"] = "it says 'Summon Wuber' (floating, MEDIUM)",
			},
			["ride_cast"] = {
				["at"] = 1794943048,
				["judge"] = "Anita Lift",
				["r"] = "pass",
				["took"] = 0.90000000000009,
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
				["at"] = 1794943070.5,
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
				["at"] = 1794943053.6,
				["judge"] = "Anita Lift",
				["r"] = "pass",
				["took"] = 0,
				["who"] = "Anita Lift",
				["why"] = "Wuber Rocks counts as here (arrived)",
			},
			["ride_left"] = {
				["at"] = 1794943064.1,
				["judge"] = "Wuber Rocks",
				["r"] = "pass",
				["took"] = 2.6,
				["who"] = "Wuber Rocks",
				["why"] = "left the group with no click",
			},
			["ride_open"] = {
				["at"] = 1794943040.5,
				["judge"] = "Anita Lift",
				["r"] = "pass",
				["took"] = 5.5,
				["who"] = "Anita Lift",
				["why"] = "open, selling at 50s",
			},
			["ride_paid"] = {
				["at"] = 1794943057.3,
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
				["at"] = 1794943070.1,
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
				["at"] = 1794943046.6,
				["judge"] = "Anita Lift",
				["r"] = "pass",
				["took"] = 0,
				["who"] = "Anita Lift",
				["why"] = "Wuber Rocks is in Anita's queue (joined)",
			},
			["ride_thanks"] = {
				["at"] = 1794943070.5,
				["judge"] = "Anita Lift",
				["r"] = "pass",
				["took"] = 0.40000000000009,
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
		["secs"] = 554,
		["sid"] = "6afca83b37",
		["sim"] = true,
		["started"] = 1794943035,
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
			["ended"] = 1794943136,
			["fail"] = 0,
			["lab"] = "1.1.0",
			["later"] = 0,
			["lines"] = {
				"ride_open|Anita Lift|pass|open, selling at 50s|1794943040.500|5.5|Anita Lift|Anita open", -- [1]
				"ride_beacon|Anita Lift|pass|beacon open: 50s to Undercity|1794943040.500|0.0|Anita Lift|Beacon open", -- [2]
				"ride_seen|Wuber Rocks|pass|Anita listed (open, 50s)|1794943042.200|0.0|Wuber Rocks|Anita on Home", -- [3]
				"ride_confirm|Wuber Rocks|pass|the confirm screen for Anita|1794943043.100|0.9|Wuber Rocks|Confirm screen", -- [4]
				"ride_request|Wuber Rocks|pass|booked; whispered 'WTB summon to Undercity for 50s'|1794943046.600|3.5|Wuber Rocks|Request", -- [5]
				"ride_taken|Anita Lift|pass|Wuber Rocks is in Anita's queue (joined)|1794943046.600|0.0|Anita Lift|Request reaches Anita", -- [6]
				"ride_invited|Wuber Rocks|pass|joined Anita's group with no click|1794943047.100|0.0|Wuber Rocks|Invite taken", -- [7]
				"ride_button|Anita Lift|pass|it says 'Summon Wuber' (floating, MEDIUM)|1794943047.100|0.0|Anita Lift|Big button: Summon", -- [8]
				"ride_cast|Anita Lift|pass|the ritual started on Wuber Rocks (pretend)|1794943048.000|0.9|Anita Lift|The summon starts", -- [9]
				"ride_portal1|Farra Way|skip|test mode: the pretend ritual needs no portal clicks|1794943048.200|0.0|Farra Way|Farra clicks", -- [10]
				"ride_portal2|Hayley Cab|skip|test mode: the pretend ritual needs no portal clicks|1794943048.300|0.0|Hayley Cab|Hayley clicks", -- [11]
				"ride_arrive|Wuber Rocks|pass|arrived (arrived)|1794943053.600|5.2|Wuber Rocks|Summon accepted", -- [12]
				"ride_landed|Anita Lift|pass|Wuber Rocks counts as here (arrived)|1794943053.600|0.0|Anita Lift|Anita sees the arrival", -- [13]
				"ride_trade|Wuber Rocks|pass|put in 50s and pressed Trade|1794943056.100|2.3|Wuber Rocks|Rider pays", -- [14]
				"ride_paid|Anita Lift|pass|paid 50s by Wuber Rocks|1794943057.300|1.2|Anita Lift|Anita takes the fare", -- [15]
				"ride_done|Wuber Rocks|pass|done, paid 50s|1794943058.100|0.0|Wuber Rocks|Rider's ride paid", -- [16]
				"ride_left|Wuber Rocks|pass|left the group with no click|1794943064.100|2.6|Wuber Rocks|Left the group", -- [17]
				"ride_rate|Wuber Rocks|pass|rated 5 stars|1794943070.100|5.0|Wuber Rocks|Rating", -- [18]
				"ride_thanks|Anita Lift|pass|thank-you whisper sent to Wuber Rocks|1794943070.500|0.4|Anita Lift|Thank-you whisper", -- [19]
				"ride_earnings|Anita Lift|look|screenshot 1: Earnings with today's ride|1794943070.500|0.0|Anita Lift|Earnings (look)", -- [20]
				"raid_invite|Anita Lift|pass|the invite reached Wuber Rocks|1794943073.100|0.0|Wuber Rocks|Invite the rider", -- [21]
				"raid_join|Wuber Rocks|pass|in Anita's group|1794943077.100|3.0|Wuber Rocks|Rider joins", -- [22]
				"raid_convert|Anita Lift|pass|a raid|1794943078.000|0.9|Anita Lift|Make it a raid", -- [23]
				"raid_start|Anita Lift|pass|raid summons on, 3 summoners|1794943080.500|2.5|Anita Lift|Raid summons on", -- [24]
				"raid_window|Anita Lift|pass|window open, big button docked on top (FULLSCREEN_DIALOG over HIGH)|1794943083.500|3.0|Anita Lift|Window open, button on top", -- [25]
				"raid_away|Wuber Rocks|pass|Wuber Rocks is away from the spot (Orgrimmar)|1794943084.500|1.0|Anita Lift|Rider away from the spot", -- [26]
				"raid_tap|Wuber Rocks|pass|queued from the app (Request a summon)|1794943085.000|0.5|Anita Lift|Request from the app", -- [27]
				"raid_nvm|Wuber Rocks|pass|dropped from the list|1794943085.500|0.5|Anita Lift|nvm drops", -- [28]
				"raid_ask|Wuber Rocks|pass|Wuber Rocks queued (queued)|1794943086.000|0.5|Anita Lift|123 in raid chat", -- [29]
				"raid_button|Anita Lift|pass|it says 'Summon Wuber' (docked on top (FULLSCREEN_DIALOG over HIGH))|1794943086.000|0.0|Anita Lift|Big button: Summon", -- [30]
				"raid_cast|Anita Lift|pass|Anita's ritual started on Wuber Rocks (pretend)|1794943086.500|0.5|Anita Lift|Anita summons the raider", -- [31]
				"raid_portal1|Farra Way|skip|test mode: the pretend ritual needs no portal clicks|1794943086.700|0.0|Farra Way|Farra clicks", -- [32]
				"raid_portal2|Hayley Cab|skip|test mode: the pretend ritual needs no portal clicks|1794943086.800|0.0|Hayley Cab|Hayley clicks", -- [33]
				"raid_arrive|Wuber Rocks|pass|summoned, counted, off the list|1794943092.000|5.2|Anita Lift|Raider summoned", -- [34]
				"raid_one|Anita Lift|pass|Farra's and Hayley's buttons and rituals left Wuber Rocks alone|1794943092.200|0.2|Anita Lift|Nobody else took the raider", -- [35]
				"raid_stop|Anita Lift|pass|raid summons stopped|1794943093.000|0.8|Anita Lift|Stop", -- [36]
				"photo_tour|Anita Lift|pass|25 screenshots|1794943136.000|43.0|Anita Lift|Photo tour", -- [37]
			},
			["look"] = 1,
			["n"] = 37,
			["pass"] = 32,
			["sid"] = "6afca83b37",
			["sim"] = true,
			["skip"] = 4,
			["started"] = 1794943035,
			["todo"] = 0,
			["why"] = "done",
			["wuber"] = "2.2.1",
		}, -- [1]
	},
	["seenLab"] = {
		["farra way"] = 1794943008.2,
		["hayley cab"] = 1794943008.2,
		["wuber rocks"] = 1794943008.3,
	},
	["v"] = 1,
}
