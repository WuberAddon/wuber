
WuberLabDB = {
	["chars"] = {
		["Anita Lift"] = {
			["checks"] = {
				["d_accept"] = {
					["at"] = 1794943027.6,
					["by"] = "api_accept",
					["r"] = "auto",
					["sec"] = "Ride",
					["text"] = "Accepted (A sent)",
					["took"] = 0,
				},
				["d_arrived"] = {
					["at"] = 1794943044,
					["by"] = "stage_arrived",
					["r"] = "auto",
					["sec"] = "Ride",
					["text"] = "Arrived",
					["took"] = 1.5,
				},
				["d_busy"] = {
					["at"] = 1794943027.6,
					["by"] = "beacon_busy",
					["r"] = "auto",
					["sec"] = "Edge",
					["text"] = "Busy beacon during a ride",
				},
				["d_coins"] = {
					["at"] = 1794943053.599,
					["by"] = "fx_coins",
					["r"] = "auto",
					["sec"] = "Looks",
					["text"] = "Coin shower on 5 stars",
					["took"] = 4.7990000247955,
				},
				["d_invited"] = {
					["at"] = 1794943027.6,
					["by"] = "stage_invited",
					["r"] = "auto",
					["sec"] = "Ride",
					["text"] = "Invited",
					["took"] = 0,
				},
				["d_online"] = {
					["at"] = 1794943002.1,
					["by"] = "beacon_open",
					["r"] = "auto",
					["sec"] = "Setup",
					["text"] = "Beacon: open",
					["took"] = 2.0999999046326,
				},
				["d_paid"] = {
					["at"] = 1794943048.8,
					["by"] = "stage_paid",
					["r"] = "auto",
					["sec"] = "Ride",
					["text"] = "Paid in trade",
					["took"] = 4.7999999523163,
				},
				["d_paidfx"] = {
					["at"] = 1794943048.8,
					["by"] = "fx_paid",
					["r"] = "auto",
					["sec"] = "Looks",
					["text"] = "Paid burst plays",
				},
				["d_portal"] = {
					["at"] = 1794943042.5,
					["by"] = "stage_portal",
					["r"] = "auto",
					["sec"] = "Ride",
					["text"] = "Portal up",
					["took"] = 4,
				},
				["d_provider"] = {
					["at"] = 1794943000,
					["by"] = "provider",
					["r"] = "auto",
					["sec"] = "Setup",
					["text"] = "Ritual Rides drives for Wuber",
				},
				["d_rating"] = {
					["at"] = 1794943053.599,
					["by"] = "prov_rating",
					["r"] = "auto",
					["sec"] = "Ride",
					["text"] = "Rating received",
					["took"] = 4.7990000247955,
				},
				["d_request"] = {
					["at"] = 1794943027.6,
					["by"] = "prov_request",
					["r"] = "auto",
					["sec"] = "Ride",
					["text"] = "Wuber request arrives",
				},
				["d_summoning"] = {
					["at"] = 1794943038.5,
					["by"] = "stage_summoning",
					["r"] = "auto",
					["sec"] = "Ride",
					["text"] = "Summoning",
					["took"] = 10.900000095367,
				},
			},
			["dropped"] = 0,
			["lastLogin"] = 1794943000,
			["lines"] = {
				"1794943000.000|Anita Lift|rr|says: Services only works in a capital city (or you have not joined it: /join services). Here the advert goes to LookingForGroup, and Trade when you are in a city.", -- [1]
				"1794943000.000|Anita Lift|api|SetDriver Ritual Rides", -- [2]
				"1794943000.000|Anita Lift|fire|PROVIDER Ritual Rides", -- [3]
				"1794943000.000|Anita Lift|login|char=Anita Lift realm=Forever role=driver build=1.60.1/70938/Nov 12 2026/16001 lab=1.0.0 Wuber=1.0.0 RitualRides=1.4.0 OpenMap=off Moo=off !BugGrabber=off BugSack=off W.VERSION=1.1.0 RR.VERSION=1.4.1 channels=4 errhandler=replaced later buggrabber=no", -- [4]
				"1794943000.000|Anita Lift|fire|provider at login: Ritual Rides", -- [5]
				"1794943000.000|Anita Lift|check|d_provider;auto;by=provider;took=-;Ritual Rides drives for Wuber", -- [6]
				"1794943000.000|Anita Lift|probe|channels=4 wuberIndex=nil (login)", -- [7]
				"1794943000.000|Anita Lift|ev|PLAYER_ENTERING_WORLD login=true reload=false", -- [8]
				"1794943000.000|Anita Lift|ev|ZONE_CHANGED_NEW_AREA zone=The Barrens sub=Ratchet", -- [9]
				"1794943000.000|Anita Lift|ev|GROUP_ROSTER_UPDATE members=2 Farra Way,Hayley Cab", -- [10]
				"1794943000.100|Anita Lift|rr|says: heard Farra's Ritual Rides. With only your three Warlocks in the group, type /cffffd200/rr team/r in each window.", -- [11]
				"1794943001.000|Anita Lift|prov|beacon off", -- [12]
				"1794943002.000|Anita Lift|tool|test mode on (developer only). /lab opens the test plan. Role: driver", -- [13]
				"1794943002.100|Anita Lift|api|Beacon", -- [14]
				"1794943002.100|Anita Lift|prov|beacon Ratchet/50000/open/3/7/0", -- [15]
				"1794943002.100|Anita Lift|check|d_online;auto;by=beacon_open;took=2.1;Beacon: open", -- [16]
				"1794943002.100|Anita Lift|plan|s3_d1;auto;by=beacon_open;who=Anita Lift;src=local", -- [17]
				"1794943003.000|Anita Lift|probe|font Poppins SetFont ok=true returned=true GetFont=Interface\\AddOns\\Wuber\\Media\\fonts\\Poppins-Regular.ttf T.poppins=true", -- [18]
				"1794943003.000|Anita Lift|rr|says: /cffffd200time to advertise/r in Trade: click /cffffd200Advertise/r, then press Enter.", -- [19]
				"1794943006.000|Anita Lift|probe|JoinTemporaryChannel(WuberNet) called combat=false", -- [20]
				"1794943006.000|Anita Lift|probe|CheckChannel(true) -> false index=nil channels=4 fails=nil", -- [21]
				"1794943006.500|Anita Lift|fire|NETWORK true", -- [22]
				"1794943006.500|Anita Lift|msg>|Q C>5 Q~1", -- [23]
				"1794943006.500|Anita Lift|ui|Ping ok=true nil", -- [24]
				"1794943006.500|Anita Lift|msg>|D C>5 D~1~Ratchet~1413~627~370~50000~Ritual Rides~open~3~7~H~1.1.0~~0", -- [25]
				"1794943006.500|Anita Lift|probe|CheckChannel(false) -> true index=5 channels=5 fails=nil", -- [26]
				"1794943006.500|Anita Lift|probe|channels=5 wuberIndex=5 (CHANNEL_UI_UPDATE)", -- [27]
				"1794943006.600|Anita Lift|msg<|Q C<Anita Lift Q~1", -- [28]
				"1794943006.600|Anita Lift|msg<|D C<Anita Lift D~1~Ratchet~1413~627~370~50000~Ritual Rides~open~3~7~H~1.1.0~~0", -- [29]
				"1794943006.600|Anita Lift|msg<|Q C<Farra Way Q~1", -- [30]
				"1794943006.600|Anita Lift|msg<|Q C<Hayley Cab Q~1", -- [31]
				"1794943008.000|Anita Lift|self|[login] 15 of 15 passed", -- [32]
				"1794943008.600|Anita Lift|msg<|Q C<Wuber Rocks Q~1", -- [33]
				"1794943010.000|Anita Lift|plan|s0_1@anita lift;ok;by=probe:fresh;who=Anita Lift;src=local", -- [34]
				"1794943010.000|Anita Lift|probe|plan s0_1 (fresh) on Anita Lift: ok", -- [35]
				"1794943010.000|Anita Lift|plan|s0_2@anita lift;ok;by=probe:addons;who=Anita Lift;src=local", -- [36]
				"1794943010.000|Anita Lift|probe|plan s0_2 (addons) on Anita Lift: ok", -- [37]
				"1794943010.000|Anita Lift|plan|s1_1@anita lift;ok;by=probe:fresh;who=Anita Lift;src=local", -- [38]
				"1794943010.000|Anita Lift|probe|plan s1_1 (fresh) on Anita Lift: ok", -- [39]
				"1794943010.600|Anita Lift|plan|s0_2@hayley cab;ok;by=probe:addons;who=Hayley Cab;src=sync", -- [40]
				"1794943010.600|Anita Lift|plan|s0_1@hayley cab;ok;by=probe:fresh;who=Hayley Cab;src=sync", -- [41]
				"1794943010.600|Anita Lift|plan|s1_1@hayley cab;ok;by=probe:fresh;who=Hayley Cab;src=sync", -- [42]
				"1794943011.500|Anita Lift|msg>|D C>5 D~1~Ratchet~1413~627~370~50000~Ritual Rides~open~3~7~H~1.1.0~~0", -- [43]
				"1794943012.100|Anita Lift|plan|s1_1@farra way;ok;by=probe:fresh;who=Farra Way;src=sync", -- [44]
				"1794943012.100|Anita Lift|plan|s0_2@farra way;ok;by=probe:addons;who=Farra Way;src=sync", -- [45]
				"1794943012.100|Anita Lift|plan|s0_1@farra way;ok;by=probe:fresh;who=Farra Way;src=sync", -- [46]
				"1794943012.600|Anita Lift|plan|s0_2@wuber rocks;no;by=probe:addons;who=Wuber Rocks;src=sync", -- [47]
				"1794943012.600|Anita Lift|plan|s1_1@wuber rocks;ok;by=probe:fresh;who=Wuber Rocks;src=sync", -- [48]
				"1794943012.600|Anita Lift|plan|s1_1;auto;by=probe;who=Anita Lift;src=local", -- [49]
				"1794943012.600|Anita Lift|plan|s0_1@wuber rocks;ok;by=probe:fresh;who=Wuber Rocks;src=sync", -- [50]
				"1794943012.600|Anita Lift|plan|s0_1;auto;by=probe;who=Anita Lift;src=local", -- [51]
				"1794943026.100|Anita Lift|plan|s3_r2;auto;by=confirm_shown;who=Wuber Rocks;src=sync", -- [52]
				"1794943026.100|Anita Lift|plan|s2_1;auto;by=app_open;who=Wuber Rocks;src=sync", -- [53]
				"1794943027.500|Anita Lift|probe|C_PartyInfo.InviteUnit(Wuber Rocks) called combat=false", -- [54]
				"1794943027.500|Anita Lift|rr|customer Wuber Rocks queued>invited", -- [55]
				"1794943027.500|Anita Lift|rr|Request Wuber Rocks source=whisper msg='WTB summon to Ratchet for 5g' -> customer invited", -- [56]
				"1794943027.500|Anita Lift|rr|bell sent: Anita: whisper from Wuber Rocks: WTB summon to Ratchet for 5g", -- [57]
				"1794943027.500|Anita Lift|whsp|< Wuber Rocks: WTB summon to Ratchet for 5g", -- [58]
				"1794943027.500|Anita Lift|plan|s3_r3;auto;by=whisper_wtb_in;who=Anita Lift;src=local", -- [59]
				"1794943027.500|Anita Lift|plan|s3_c1;auto;by=whisper_wtb_in;who=Anita Lift;src=local", -- [60]
				"1794943027.600|Anita Lift|api|Beacon", -- [61]
				"1794943027.600|Anita Lift|prov|beacon Ratchet/50000/busy/3/7/0", -- [62]
				"1794943027.600|Anita Lift|check|d_busy;auto;by=beacon_busy;took=-;Busy beacon during a ride", -- [63]
				"1794943027.600|Anita Lift|msg>|D C>5 D~1~Ratchet~1413~627~370~50000~Ritual Rides~busy~3~7~H~1.1.0~~0", -- [64]
				"1794943027.600|Anita Lift|fire|REQUESTS n=1", -- [65]
				"1794943027.600|Anita Lift|prov|onRequest id=VKNhsP buyer=Wuber Rocks dest=Ratchet price=50000 tier=0 rides=0", -- [66]
				"1794943027.600|Anita Lift|drv|VKNhsP;request;dt=0.0;tot=0.0;buyer=Wuber Rocks;dest=Ratchet;price=50000", -- [67]
				"1794943027.600|Anita Lift|check|d_request;auto;by=prov_request;took=-;Wuber request arrives", -- [68]
				"1794943027.600|Anita Lift|rr|LogWuber wreq", -- [69]
				"1794943027.600|Anita Lift|rr|bell sent: Anita: Wuber ride request from Wuber Rocks", -- [70]
				"1794943027.600|Anita Lift|rr|Request Wuber Rocks source=wuber msg='WTB summon to Ratchet (Wuber)' -> customer invited", -- [71]
				"1794943027.600|Anita Lift|api|Accept id=VKNhsP buyer=Wuber Rocks eta=5 price=50000", -- [72]
				"1794943027.600|Anita Lift|drv|VKNhsP;accepted;dt=0.0;tot=0.0;eta=5;price=50000", -- [73]
				"1794943027.600|Anita Lift|check|d_accept;auto;by=api_accept;took=0.0;Accepted (A sent)", -- [74]
				"1794943027.600|Anita Lift|msg>|A W>Wuber Rocks A~1~VKNhsP~50000~5", -- [75]
				"1794943027.600|Anita Lift|api|Status id=VKNhsP buyer=Wuber Rocks stage=invited", -- [76]
				"1794943027.600|Anita Lift|drv|VKNhsP;stage:invited;dt=0.0;tot=0.0", -- [77]
				"1794943027.600|Anita Lift|check|d_invited;auto;by=stage_invited;took=0.0;Invited", -- [78]
				"1794943027.600|Anita Lift|msg>|S W>Wuber Rocks S~1~VKNhsP~invited", -- [79]
				"1794943027.600|Anita Lift|msg<|R W<Wuber Rocks R~1~VKNhsP~Ratchet~50000~0~0", -- [80]
				"1794943027.700|Anita Lift|msg<|D C<Anita Lift D~1~Ratchet~1413~627~370~50000~Ritual Rides~busy~3~7~H~1.1.0~~0", -- [81]
				"1794943027.700|Anita Lift|rr|customer Wuber Rocks invited>joined wuber=VKNhsP", -- [82]
				"1794943027.700|Anita Lift|ev|GROUP_ROSTER_UPDATE members=3 Farra Way,Hayley Cab,Wuber Rocks", -- [83]
				"1794943027.700|Anita Lift|sys|You have invited Wuber Rocks to join your group.", -- [84]
				"1794943027.750|Anita Lift|rr|bell sent: Anita: Summon Wuber", -- [85]
				"1794943028.000|Anita Lift|prov|beacon Ratchet/50000/busy/3/6/0", -- [86]
				"1794943029.610|Anita Lift|api|Beacon", -- [87]
				"1794943032.100|Anita Lift|plan|s3_c2;auto;by=auto_accept;who=Wuber Rocks;src=sync", -- [88]
				"1794943032.100|Anita Lift|plan|s3_r5;auto;by=auto_accept;who=Wuber Rocks;src=sync", -- [89]
				"1794943032.600|Anita Lift|msg>|D C>5 D~1~Ratchet~1413~627~370~50000~Ritual Rides~busy~3~6~H~1.1.0~~0", -- [90]
				"1794943032.700|Anita Lift|msg<|D C<Anita Lift D~1~Ratchet~1413~627~370~50000~Ritual Rides~busy~3~6~H~1.1.0~~0", -- [91]
				"1794943038.500|Anita Lift|whsp|> Wuber Rocks: Ritual Rides: summoning you to Ratchet now - please accept the summon! The ride is 5g; just open trade with any of us when you land.", -- [92]
				"1794943038.500|Anita Lift|rr|customer Wuber Rocks joined>summoning wuber=VKNhsP", -- [93]
				"1794943038.500|Anita Lift|api|Status id=VKNhsP buyer=Wuber Rocks stage=summoning", -- [94]
				"1794943038.500|Anita Lift|drv|VKNhsP;stage:summoning;dt=10.9;tot=10.9", -- [95]
				"1794943038.500|Anita Lift|check|d_summoning;auto;by=stage_summoning;took=10.9;Summoning", -- [96]
				"1794943038.500|Anita Lift|msg>|S W>Wuber Rocks S~1~VKNhsP~summoning", -- [97]
				"1794943039.600|Anita Lift|plan|s3_r4;auto;by=accept_msg;who=Wuber Rocks;src=sync", -- [98]
				"1794943042.500|Anita Lift|rr|customer Wuber Rocks summoning>waiting wuber=VKNhsP", -- [99]
				"1794943042.500|Anita Lift|api|Status id=VKNhsP buyer=Wuber Rocks stage=portal", -- [100]
				"1794943042.500|Anita Lift|drv|VKNhsP;stage:portal;dt=4.0;tot=14.9", -- [101]
				"1794943042.500|Anita Lift|check|d_portal;auto;by=stage_portal;took=4.0;Portal up", -- [102]
				"1794943042.500|Anita Lift|msg>|S W>Wuber Rocks S~1~VKNhsP~portal", -- [103]
				"1794943044.000|Anita Lift|rr|customer Wuber Rocks waiting>arrived wuber=VKNhsP", -- [104]
				"1794943044.000|Anita Lift|api|Status id=VKNhsP buyer=Wuber Rocks stage=arrived", -- [105]
				"1794943044.000|Anita Lift|drv|VKNhsP;stage:arrived;dt=1.5;tot=16.4", -- [106]
				"1794943044.000|Anita Lift|check|d_arrived;auto;by=stage_arrived;took=1.5;Arrived", -- [107]
				"1794943044.000|Anita Lift|msg>|S W>Wuber Rocks S~1~VKNhsP~arrived", -- [108]
				"1794943044.100|Anita Lift|plan|s3_c3;auto;by=ride_arrived+fx_arrival;who=Wuber Rocks;src=sync", -- [109]
				"1794943044.100|Anita Lift|plan|s3_r6;auto;by=ride_arrived;who=Wuber Rocks;src=sync", -- [110]
				"1794943047.000|Anita Lift|ev|TRADE_SHOW with=Wuber Rocks trade=hidden my=0 their=0", -- [111]
				"1794943048.500|Anita Lift|ev|TRADE_MONEY_CHANGED trade=hidden my=0 their=50000", -- [112]
				"1794943048.500|Anita Lift|ev|TRADE_ACCEPT_UPDATE me=0 them=1 trade=hidden my=0 their=50000", -- [113]
				"1794943048.500|Anita Lift|ev|TRADE_ACCEPT_UPDATE me=1 them=1 trade=hidden my=0 their=50000", -- [114]
				"1794943048.500|Anita Lift|ev|PLAYER_MONEY +50000 now=1050000 (trade open)", -- [115]
				"1794943048.500|Anita Lift|ev|TRADE_CLOSED", -- [116]
				"1794943048.800|Anita Lift|rr|LogRide 50000 Wuber Rocks t", -- [117]
				"1794943048.800|Anita Lift|plan|s3_c7;auto;by=rr_logride;who=Anita Lift;src=local", -- [118]
				"1794943048.800|Anita Lift|rr|customer Wuber Rocks arrived>paid wuber=VKNhsP", -- [119]
				"1794943048.800|Anita Lift|api|Status id=VKNhsP buyer=Wuber Rocks stage=paid", -- [120]
				"1794943048.800|Anita Lift|drv|VKNhsP;stage:paid;dt=4.8;tot=21.2", -- [121]
				"1794943048.800|Anita Lift|check|d_paid;auto;by=stage_paid;took=4.8;Paid in trade", -- [122]
				"1794943048.800|Anita Lift|msg>|S W>Wuber Rocks S~1~VKNhsP~paid", -- [123]
				"1794943048.800|Anita Lift|fire|REQUESTS n=0", -- [124]
				"1794943048.800|Anita Lift|fx|Fullscreen paid played", -- [125]
				"1794943048.800|Anita Lift|check|d_paidfx;auto;by=fx_paid;took=-;Paid burst plays", -- [126]
				"1794943048.800|Anita Lift|rr|bell sent: Anita: Wuber Rocks paid 5g", -- [127]
				"1794943048.800|Anita Lift|rr|says: Wuber Rocks paid 5g.", -- [128]
				"1794943048.850|Anita Lift|rr|bell sent: Anita: Thank Wuber, Remove Wuber", -- [129]
				"1794943048.900|Anita Lift|api|Beacon", -- [130]
				"1794943048.900|Anita Lift|prov|beacon Ratchet/50000/open/3/6/0", -- [131]
				"1794943048.900|Anita Lift|msg>|D C>5 D~1~Ratchet~1413~627~370~50000~Ritual Rides~open~3~6~H~1.1.0~~0", -- [132]
				"1794943048.999|Anita Lift|msg<|D C<Anita Lift D~1~Ratchet~1413~627~370~50000~Ritual Rides~open~3~6~H~1.1.0~~0", -- [133]
				"1794943050.099|Anita Lift|plan|s3_c4;auto;by=pay_exact;who=Wuber Rocks;src=sync", -- [134]
				"1794943051.499|Anita Lift|ev|GROUP_ROSTER_UPDATE members=2 Farra Way,Hayley Cab", -- [135]
				"1794943051.549|Anita Lift|rr|bell sent: Anita: Thank Wuber", -- [136]
				"1794943051.599|Anita Lift|api|Beacon", -- [137]
				"1794943051.599|Anita Lift|prov|beacon Ratchet/50000/open/3/7/0", -- [138]
				"1794943051.599|Anita Lift|plan|s3_c5;auto;by=auto_left;who=Wuber Rocks;src=sync", -- [139]
				"1794943053.599|Anita Lift|prov|onRating id=VKNhsP buyer=Wuber Rocks stars=5", -- [140]
				"1794943053.599|Anita Lift|drv|VKNhsP;rated;dt=4.8;tot=26.0;stars=5", -- [141]
				"1794943053.599|Anita Lift|check|d_rating;auto;by=prov_rating;took=4.8;Rating received", -- [142]
				"1794943053.599|Anita Lift|rr|says: Wuber Rocks rated the ride 5 stars", -- [143]
				"1794943053.599|Anita Lift|fire|RATING VKNhsP Wuber Rocks 5", -- [144]
				"1794943053.599|Anita Lift|fx|Fullscreen coins played", -- [145]
				"1794943053.599|Anita Lift|check|d_coins;auto;by=fx_coins;took=4.8;Coin shower on 5 stars", -- [146]
				"1794943053.599|Anita Lift|plan|s5_6;auto;by=fx_paid+fx_coins;who=Anita Lift;src=local", -- [147]
				"1794943053.599|Anita Lift|msg<|T W<Wuber Rocks T~1~VKNhsP~5", -- [148]
				"1794943053.899|Anita Lift|msg>|D C>5 D~1~Ratchet~1413~627~370~50000~Ritual Rides~open~3~7~H~1.1.0~~0", -- [149]
				"1794943053.999|Anita Lift|msg<|D C<Anita Lift D~1~Ratchet~1413~627~370~50000~Ritual Rides~open~3~7~H~1.1.0~~0", -- [150]
				"1794943056.099|Anita Lift|plan|s3_r8;auto;by=auto_left+rated+milestone_pop;who=Wuber Rocks;src=sync", -- [151]
				"1794943056.099|Anita Lift|plan|s3_c6;auto;by=milestone_pop+rated;who=Wuber Rocks;src=sync", -- [152]
				"1794943060.000|Anita Lift|rr|LogRivals 0", -- [153]
				"1794943116.000|Anita Lift|msg>|D C>5 D~1~Ratchet~1413~627~370~50000~Ritual Rides~open~3~7~H~1.1.0~~0", -- [154]
				"1794943122.100|Anita Lift|plan|s5_1;fail;by=hand;who=Wuber Rocks;src=sync;note=crown too small", -- [155]
			},
			["realm"] = "Forever",
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
			["by"] = "whisper_wtb_in",
			["r"] = "auto",
			["who"] = "Anita Lift",
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
