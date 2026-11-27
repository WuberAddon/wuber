
WuberLabDB = {
	["chars"] = {
		["Anita Lift"] = {
			["lines"] = {
			},
		},
	},
	["facts"] = {
		["L1"] = {
			[1] = {
				["a"] = {
					["noCall"] = true,
				},
				["build"] = "1.60.1 (71037)",
				["line"] = "C_IncomingSummon: no such call",
				["t"] = 1794943026,
			},
			[2] = {
				["a"] = {
					["has"] = true,
					["instance"] = false,
					["status"] = 2,
					["unit"] = "player",
				},
				["build"] = "1.60.1 (71037)",
				["line"] = "unit player: status 2, has true, no cast yet, not in an instance",
				["t"] = 1794943026,
			},
			[3] = {
				["a"] = {
					["has"] = true,
					["instance"] = false,
					["status"] = 2,
					["unit"] = "party1",
				},
				["build"] = "1.60.1 (71037)",
				["line"] = "unit party1: status 2, has true, no cast yet, not in an instance",
				["t"] = 1794943026,
			},
		},
		["L1.table"] = {
			[1] = {
				["a"] = {
					["keys"] = {
						[1] = "HasIncomingSummon",
						[2] = "IncomingSummonStatus",
					},
				},
				["build"] = "1.60.1 (71037)",
				["line"] = "C_IncomingSummon has 2 entries: HasIncomingSummon, IncomingSummonStatus",
				["t"] = 1794943026,
			},
		},
		["L10"] = {
			[1] = {
				["a"] = {
					["codes"] = {
						["AddonMessageThrottle"] = 3,
						["ChannelThrottle"] = 8,
						["GeneralError"] = 9,
						["InvalidChannel"] = 7,
						["InvalidChatType"] = 4,
						["InvalidMessage"] = 2,
						["InvalidPrefix"] = 1,
						["NotInGroup"] = 5,
						["Success"] = 0,
						["TargetRequired"] = 6,
					},
				},
				["build"] = "1.60.1 (71037)",
				["line"] = "10 send result codes: 0=Success 1=InvalidPrefix 2=InvalidMessage 3=AddonMessageThrottle 4=InvalidChatType 5=NotInGroup 6=TargetRequired 7=InvalidChannel 8=ChannelThrottle 9=GeneralError",
				["t"] = 1794943028,
			},
		},
		["L12.self"] = {
			[1] = {
				["a"] = {
					["GetUnitName"] = {
						["len"] = 10,
						["realmTail"] = false,
						["space"] = true,
					},
					["UnitFullName"] = {
						["name"] = {
							["len"] = 5,
							["realmTail"] = false,
							["space"] = false,
						},
						["realmGiven"] = true,
					},
					["UnitGUID"] = {
						["len"] = 19,
						["prefix"] = "Player",
					},
					["UnitName"] = {
						["name"] = {
							["len"] = 10,
							["realmTail"] = false,
							["space"] = true,
						},
						["realmGiven"] = false,
					},
				},
				["build"] = "1.60.1 (71037)",
				["line"] = "UnitName len 10 space; UnitFullName len 5; GetUnitName(,true) len 10 space; GUID Player",
				["t"] = 1794943005,
			},
		},
		["L13.blocked"] = {
			[1] = {
				["a"] = {
					["count"] = 1,
					["list"] = {
						[1] = {
							["addon"] = "Wuber",
							["combat"] = false,
							["event"] = "ADDON_ACTION_BLOCKED",
							["func"] = "ShowUIPanel()",
						},
					},
				},
				["build"] = "1.60.1 (71037)",
				["line"] = "blocked actions this session: 1 (last: BLOCKED Wuber ShowUIPanel())",
				["t"] = 1794943028,
			},
		},
		["L13.style"] = {
			[1] = {
				["a"] = {
					["GetCurrentStyle"] = "no such call",
					["cvar"] = "nil",
					["enum"] = "no such call",
				},
				["build"] = "1.60.1 (71037)",
				["line"] = "input style no such call, CVar nil",
				["t"] = 1794943000,
			},
		},
		["L14.wuber"] = {
			[1] = {
				["a"] = {
					["blocked"] = {
					},
					["blockedCount"] = 0,
					["closed"] = true,
					["how"] = "wuber",
					["opened"] = true,
					["via"] = "ShowUIPanel",
				},
				["build"] = "1.60.1 (71037)",
				["line"] = "opened via ShowUIPanel: map open; blocked actions in 3 minutes: 0",
				["t"] = 1794943029,
			},
		},
		["L15"] = {
			[1] = {
				["a"] = {
					["afterWuber"] = "Wuber's window not shown",
					["bareBoxFont"] = {
					},
					["chat"] = {
					},
					["sameObject"] = "no font object to compare",
					["wuberShown"] = false,
				},
				["build"] = "1.60.1 (71037)",
				["line"] = "chat box font nil nil nil; bare EditBox shares the font object: no font object to compare",
				["t"] = 1794943028,
			},
		},
		["L16"] = {
			[1] = {
				["a"] = {
					["GetCurrentRegion"] = "no such call",
					["GetNormalizedRealmName"] = "CAMWOWEU5Realm5PvE",
					["GetRealmID"] = "no such call",
					["GetRealmName"] = "CAMWOW EU5 Realm 5 PvE",
					["IsHardcoreActive"] = "no such call",
					["IsWarModeActive"] = "no such call",
				},
				["build"] = "1.60.1 (71037)",
				["line"] = "realm CAMWOW EU5 Realm 5 PvE (CAMWOWEU5Realm5PvE, id no such call), region no such call, hardcore no such call, war mode no such call",
				["t"] = 1794943028,
			},
		},
		["L16.char"] = {
			[1] = {
				["a"] = {
					["GetCurrentRegion"] = "no such call",
					["GetNormalizedRealmName"] = "CAMWOWEU5Realm5PvE",
					["GetRealmID"] = "no such call",
					["GetRealmName"] = "CAMWOW EU5 Realm 5 PvE",
					["IsHardcoreActive"] = "no such call",
					["IsWarModeActive"] = "no such call",
					["IsWarModeDesired"] = "no such call",
					["fullNameLen"] = 5,
					["fullNameRealm"] = "Forever",
					["why"] = "login",
					["wuberRemembered"] = "EU-PvE",
					["wuberRuleset"] = "EU-PvE",
				},
				["build"] = "1.60.1 (71037)",
				["line"] = "realm CAMWOW EU5 Realm 5 PvE (CAMWOWEU5Realm5PvE, id no such call), region no such call, hardcore no such call, war mode no such call (wanted no such call), realm in the full name Forever; Wuber says EU-PvE, remembered EU-PvE",
				["t"] = 1794943006,
			},
		},
		["L18"] = {
			[1] = {
				["a"] = {
					["gameSounds"] = 0,
					["hookRan"] = false,
					["hooked"] = true,
					["played"] = true,
					["taintLog"] = "nil",
					["why"] = "login",
				},
				["build"] = "1.60.1 (71037)",
				["line"] = "taint log nil; hook ran: no; the game's own sounds the hook heard before this: 0",
				["t"] = 1794943006,
			},
			[2] = {
				["a"] = {
					["gameSounds"] = 0,
					["hookRan"] = true,
					["hooked"] = true,
					["played"] = true,
					["taintLog"] = "nil",
					["why"] = "auto",
				},
				["build"] = "1.60.1 (71037)",
				["line"] = "taint log nil; hook ran: yes; the game's own sounds the hook heard before this: 0",
				["t"] = 1794943028,
			},
		},
		["L19"] = {
			[1] = {
				["a"] = {
					["answers"] = {
					},
					["call"] = "no such call",
					["why"] = "auto",
				},
				["build"] = "1.60.1 (71037)",
				["line"] = "C_ChatInfo.RequestCanLocalWhisperTarget: no such call",
				["t"] = 1794943028,
			},
		},
		["L3.read"] = {
			[1] = {
				["a"] = {
					["after"] = {
						["dropped"] = 0,
						["failed"] = 0,
						["sent"] = 0,
					},
					["event"] = "PLAYER_ENTERING_WORLD",
					["instType"] = "none",
					["instance"] = false,
					["lockdown"] = false,
					["net"] = {
						["dropped"] = 0,
						["failed"] = 0,
						["sent"] = 0,
					},
				},
				["build"] = "1.60.1 (71037)",
				["line"] = "PLAYER_ENTERING_WORLD: chat lockdown false, not in an instance; Wuber sent 0, failed 0 in 6 s",
				["t"] = 1794943000,
			},
			[2] = {
				["a"] = {
					["after"] = {
						["dropped"] = 0,
						["failed"] = 0,
						["sent"] = 0,
					},
					["event"] = "ENCOUNTER_START",
					["instType"] = "none",
					["instance"] = false,
					["lockdown"] = false,
					["net"] = {
						["dropped"] = 0,
						["failed"] = 0,
						["sent"] = 4,
					},
				},
				["build"] = "1.60.1 (71037)",
				["line"] = "ENCOUNTER_START: chat lockdown false, not in an instance; Wuber sent 0, failed 0 in 6 s",
				["t"] = 1794943028,
			},
		},
		["L3.send"] = {
			[1] = {
				["a"] = {
					["code"] = 3,
					["codeName"] = "AddonMessageThrottle",
					["combat"] = false,
					["inGroup"] = true,
					["instType"] = "none",
					["instance"] = false,
					["lockdown"] = false,
				},
				["build"] = "1.60.1 (71037)",
				["line"] = "party message: code 3 (AddonMessageThrottle), chat lockdown false, not in an instance, out of combat",
				["t"] = 1794943029,
			},
		},
		["L4"] = {
			[1] = {
				["a"] = {
					["codes"] = {
						[1] = 0,
						[2] = 0,
						[3] = 0,
						[4] = 0,
						[5] = 0,
						[6] = 0,
						[7] = 0,
						[8] = 0,
						[9] = 0,
						[10] = 0,
					},
					["sinceEnter"] = 29,
					["tally"] = {
						["0"] = 10,
					},
				},
				["build"] = "1.60.1 (71037)",
				["line"] = "10 whispers to yourself 29 s after the last loading screen: 0(Success) x10",
				["t"] = 1794943029,
			},
		},
		["L5"] = {
			[1] = {
				["a"] = {
					["channels"] = 6,
					["owner"] = "no such call",
					["slot"] = 6,
				},
				["build"] = "1.60.1 (71037)",
				["line"] = "channel WuberNet: slot 6 of 6 channels; owner no such call",
				["t"] = 1794943020,
			},
		},
		["L5.notice"] = {
			[1] = {
				["a"] = {
					["words"] = {
						["NOTICE:YOU_CHANGED"] = 1,
						["NOTICE:YOU_JOINED"] = 1,
					},
				},
				["build"] = "1.60.1 (71037)",
				["line"] = "channel notices: NOTICE:YOU_CHANGED x1, NOTICE:YOU_JOINED x1",
				["t"] = 1794943006,
			},
		},
		["L6"] = {
			[1] = {
				["a"] = {
					["ms"] = 0,
					["name"] = {
						["len"] = 10,
						["realmTail"] = false,
						["space"] = true,
					},
					["result"] = "name",
					["via"] = "C_SummonInfo",
				},
				["build"] = "1.60.1 (71037)",
				["line"] = "summoner name: name after 0 ms",
				["t"] = 1794943027,
			},
		},
		["L7"] = {
			[1] = {
				["a"] = {
					["firstYes"] = {
						["C_Spell.GetSpellInfo"] = 0,
						["IsPlayerSpell"] = "no such call",
						["IsSpellKnown"] = 0,
					},
					["id"] = 698,
					["idFrom"] = "Wuber",
					["noCall"] = {
					},
				},
				["build"] = "1.60.1 (71037)",
				["line"] = "ritual 698: IsPlayerSpell no such call; IsSpellKnown yes at 0 s; C_Spell.GetSpellInfo yes at 0 s",
				["t"] = 1794943012,
			},
		},
		["LBL"] = {
			[1] = {
				["a"] = {
					["blank"] = {
					},
					["blankLater"] = 0,
					["cutLater"] = {
					},
					["cutNow"] = {
					},
					["cutOnlyLater"] = {
					},
					["texts"] = 0,
				},
				["build"] = "1.60.1 (71037)",
				["line"] = "0 texts on shown Wuber frames: 0 blank, 0 cut now, 0 cut a frame later (0 only later)",
				["t"] = 1794943028,
			},
		},
		["SECRETS"] = {
			[1] = {
				["a"] = {
					["C"] = {
						["HasSecretRestrictions"] = "no such call",
						["ShouldAurasBeSecret"] = "no such call",
						["ShouldCooldownsBeSecret"] = "no such call",
						["ShouldUnitStatsBeSecret"] = "no such call",
						["canCompare_plate1_player"] = "no such call",
						["canCompare_player_target"] = "no such call",
						["castSecrecy698"] = "no such call",
						["cast_party1_698"] = "no such call",
						["casting_party1"] = "no such call",
						["casting_player"] = "no such call",
						["compare_plate1_player"] = "no such call",
						["compare_player_target"] = "no such call",
						["cooldown698"] = "no such call",
						["cooldownSecrecy698"] = "no such call",
						["exists"] = "0 of 27",
						["identity_nameplate1"] = "no such call",
						["identity_party1"] = "no such call",
						["identity_player"] = "no such call",
						["identity_target"] = "no such call",
					},
					["cast"] = {
						["party1"] = {
							["casting"] = {
								["n"] = 0,
							},
						},
						["player"] = {
							["casting"] = {
								["n"] = 0,
							},
							["channel"] = {
								["n"] = 0,
							},
						},
					},
					["cd"] = {
						[686] = {
							["duration"] = "number",
							["isActive"] = "nil",
							["isEnabled"] = true,
							["isOnGCD"] = "nil",
							["startTime"] = "number",
						},
						[698] = {
							["duration"] = "number",
							["isActive"] = "nil",
							["isEnabled"] = true,
							["isOnGCD"] = "nil",
							["startTime"] = "number",
						},
						[8690] = {
							["duration"] = "number",
							["isActive"] = "nil",
							["isEnabled"] = true,
							["isOnGCD"] = "nil",
							["startTime"] = "number",
						},
					},
					["chat"] = {
						["lockdown"] = false,
						["outgoingRestricted"] = true,
					},
					["has"] = {
						["C_RestrictedActions"] = false,
						["C_Secrets"] = false,
						["canaccesstable"] = false,
						["canaccessvalue"] = true,
						["issecrettable"] = false,
						["issecretvalue"] = true,
						["scrub"] = false,
						["secretwrap"] = false,
					},
					["restrict"] = {
						[0] = {
							["active"] = "no such call",
							["state"] = "no such call",
						},
						[1] = {
							["active"] = "no such call",
							["state"] = "no such call",
						},
						[2] = {
							["active"] = "no such call",
							["state"] = "no such call",
						},
						[3] = {
							["active"] = "no such call",
							["state"] = "no such call",
						},
						[4] = {
							["active"] = "no such call",
							["state"] = "no such call",
						},
						[5] = {
							["active"] = "no such call",
							["state"] = "no such call",
						},
					},
					["unit"] = {
						["nameplate1"] = {
							["guid"] = {
								[1] = "nil",
								["n"] = 1,
							},
							["name"] = {
								[1] = "nil",
								["n"] = 1,
							},
						},
						["party1"] = {
							["guid"] = {
								[1] = "nil",
								["n"] = 1,
							},
							["name"] = {
								[1] = "nil",
								["n"] = 1,
							},
						},
						["party1class"] = {
							[1] = "nil",
							["n"] = 1,
						},
						["player"] = {
							["guid"] = {
								[1] = "string",
								["n"] = 1,
							},
							["name"] = {
								[1] = "string",
								["n"] = 1,
							},
						},
						["target"] = {
							["guid"] = {
								[1] = "nil",
								["n"] = 1,
							},
							["name"] = {
								[1] = "nil",
								["n"] = 1,
							},
						},
					},
					["where"] = {
						["affecting"] = false,
						["combatLockdown"] = false,
						["inInstance"] = "no answer",
						["instanceType"] = "none",
					},
					["why"] = "PLAYER_ENTERING_WORLD",
				},
				["build"] = "1.60.1 (71037)",
				["line"] = "PLAYER_ENTERING_WORLD: has C_Secrets false, HasSecretRestrictions no such call; restrict combat no such call/enc no such call/key no such call/pvp no such call/map no such call/chat no such call; chat lockdown false; combat false, instance no answer (none); ritual cd start number dur number active nil; name(party1) nil",
				["t"] = 1794943000,
			},
			[2] = {
				["a"] = {
					["C"] = {
						["HasSecretRestrictions"] = "no such call",
						["ShouldAurasBeSecret"] = "no such call",
						["ShouldCooldownsBeSecret"] = "no such call",
						["ShouldUnitStatsBeSecret"] = "no such call",
						["canCompare_plate1_player"] = "no such call",
						["canCompare_player_target"] = "no such call",
						["castSecrecy698"] = "no such call",
						["cast_party1_698"] = "no such call",
						["casting_party1"] = "no such call",
						["casting_player"] = "no such call",
						["compare_plate1_player"] = "no such call",
						["compare_player_target"] = "no such call",
						["cooldown698"] = "no such call",
						["cooldownSecrecy698"] = "no such call",
						["exists"] = "0 of 27",
						["identity_nameplate1"] = "no such call",
						["identity_party1"] = "no such call",
						["identity_player"] = "no such call",
						["identity_target"] = "no such call",
					},
					["cast"] = {
						["party1"] = {
							["casting"] = {
								["n"] = 0,
							},
						},
						["player"] = {
							["casting"] = {
								["n"] = 0,
							},
							["channel"] = {
								["n"] = 0,
							},
						},
					},
					["cd"] = {
						[686] = {
							["duration"] = "number",
							["isActive"] = "nil",
							["isEnabled"] = true,
							["isOnGCD"] = "nil",
							["startTime"] = "number",
						},
						[698] = {
							["duration"] = "number",
							["isActive"] = "nil",
							["isEnabled"] = true,
							["isOnGCD"] = "nil",
							["startTime"] = "number",
						},
						[8690] = {
							["duration"] = "number",
							["isActive"] = "nil",
							["isEnabled"] = true,
							["isOnGCD"] = "nil",
							["startTime"] = "number",
						},
					},
					["chat"] = {
						["lockdown"] = false,
						["outgoingRestricted"] = true,
					},
					["has"] = {
						["C_RestrictedActions"] = false,
						["C_Secrets"] = false,
						["canaccesstable"] = false,
						["canaccessvalue"] = true,
						["issecrettable"] = false,
						["issecretvalue"] = true,
						["scrub"] = false,
						["secretwrap"] = false,
					},
					["restrict"] = {
						[0] = {
							["active"] = "no such call",
							["state"] = "no such call",
						},
						[1] = {
							["active"] = "no such call",
							["state"] = "no such call",
						},
						[2] = {
							["active"] = "no such call",
							["state"] = "no such call",
						},
						[3] = {
							["active"] = "no such call",
							["state"] = "no such call",
						},
						[4] = {
							["active"] = "no such call",
							["state"] = "no such call",
						},
						[5] = {
							["active"] = "no such call",
							["state"] = "no such call",
						},
					},
					["unit"] = {
						["nameplate1"] = {
							["guid"] = {
								[1] = "nil",
								["n"] = 1,
							},
							["name"] = {
								[1] = "nil",
								["n"] = 1,
							},
						},
						["party1"] = {
							["guid"] = {
								[1] = "nil",
								["n"] = 1,
							},
							["name"] = {
								[1] = "nil",
								["n"] = 1,
							},
						},
						["party1class"] = {
							[1] = "nil",
							["n"] = 1,
						},
						["player"] = {
							["guid"] = {
								[1] = "string",
								["n"] = 1,
							},
							["name"] = {
								[1] = "string",
								["n"] = 1,
							},
						},
						["target"] = {
							["guid"] = {
								[1] = "nil",
								["n"] = 1,
							},
							["name"] = {
								[1] = "nil",
								["n"] = 1,
							},
						},
					},
					["where"] = {
						["affecting"] = false,
						["combatLockdown"] = false,
						["inInstance"] = "no answer",
						["instanceType"] = "none",
					},
					["why"] = "PLAYER_ENTERING_WORLD+1s",
				},
				["build"] = "1.60.1 (71037)",
				["line"] = "PLAYER_ENTERING_WORLD+1s: has C_Secrets false, HasSecretRestrictions no such call; restrict combat no such call/enc no such call/key no such call/pvp no such call/map no such call/chat no such call; chat lockdown false; combat false, instance no answer (none); ritual cd start number dur number active nil; name(party1) ",
				["t"] = 1794943001,
			},
			[3] = {
				["a"] = {
					["C"] = {
						["HasSecretRestrictions"] = "no such call",
						["ShouldAurasBeSecret"] = "no such call",
						["ShouldCooldownsBeSecret"] = "no such call",
						["ShouldUnitStatsBeSecret"] = "no such call",
						["canCompare_plate1_player"] = "no such call",
						["canCompare_player_target"] = "no such call",
						["castSecrecy698"] = "no such call",
						["cast_party1_698"] = "no such call",
						["casting_party1"] = "no such call",
						["casting_player"] = "no such call",
						["compare_plate1_player"] = "no such call",
						["compare_player_target"] = "no such call",
						["cooldown698"] = "no such call",
						["cooldownSecrecy698"] = "no such call",
						["exists"] = "0 of 27",
						["identity_nameplate1"] = "no such call",
						["identity_party1"] = "no such call",
						["identity_player"] = "no such call",
						["identity_target"] = "no such call",
					},
					["cast"] = {
						["party1"] = {
							["casting"] = {
								["n"] = 0,
							},
						},
						["player"] = {
							["casting"] = {
								["n"] = 0,
							},
							["channel"] = {
								["n"] = 0,
							},
						},
					},
					["cd"] = {
						[686] = {
							["duration"] = "number",
							["isActive"] = "nil",
							["isEnabled"] = true,
							["isOnGCD"] = "nil",
							["startTime"] = "number",
						},
						[698] = {
							["duration"] = "number",
							["isActive"] = "nil",
							["isEnabled"] = true,
							["isOnGCD"] = "nil",
							["startTime"] = "number",
						},
						[8690] = {
							["duration"] = "number",
							["isActive"] = "nil",
							["isEnabled"] = true,
							["isOnGCD"] = "nil",
							["startTime"] = "number",
						},
					},
					["chat"] = {
						["lockdown"] = false,
						["outgoingRestricted"] = true,
					},
					["has"] = {
						["C_RestrictedActions"] = false,
						["C_Secrets"] = false,
						["canaccesstable"] = false,
						["canaccessvalue"] = true,
						["issecrettable"] = false,
						["issecretvalue"] = true,
						["scrub"] = false,
						["secretwrap"] = false,
					},
					["restrict"] = {
						[0] = {
							["active"] = "no such call",
							["state"] = "no such call",
						},
						[1] = {
							["active"] = "no such call",
							["state"] = "no such call",
						},
						[2] = {
							["active"] = "no such call",
							["state"] = "no such call",
						},
						[3] = {
							["active"] = "no such call",
							["state"] = "no such call",
						},
						[4] = {
							["active"] = "no such call",
							["state"] = "no such call",
						},
						[5] = {
							["active"] = "no such call",
							["state"] = "no such call",
						},
					},
					["unit"] = {
						["nameplate1"] = {
							["guid"] = {
								[1] = "nil",
								["n"] = 1,
							},
							["name"] = {
								[1] = "nil",
								["n"] = 1,
							},
						},
						["party1"] = {
							["guid"] = {
								[1] = "nil",
								["n"] = 1,
							},
							["name"] = {
								[1] = "nil",
								["n"] = 1,
							},
						},
						["party1class"] = {
							[1] = "nil",
							["n"] = 1,
						},
						["player"] = {
							["guid"] = {
								[1] = "string",
								["n"] = 1,
							},
							["name"] = {
								[1] = "string",
								["n"] = 1,
							},
						},
						["target"] = {
							["guid"] = {
								[1] = "nil",
								["n"] = 1,
							},
							["name"] = {
								[1] = "nil",
								["n"] = 1,
							},
						},
					},
					["where"] = {
						["affecting"] = false,
						["combatLockdown"] = false,
						["inInstance"] = "no answer",
						["instanceType"] = "none",
					},
					["why"] = "ZONE_CHANGED_NEW_AREA",
				},
				["build"] = "1.60.1 (71037)",
				["line"] = "ZONE_CHANGED_NEW_AREA: has C_Secrets false, HasSecretRestrictions no such call; restrict combat no such call/enc no such call/key no such call/pvp no such call/map no such call/chat no such call; chat lockdown false; combat false, instance no answer (none); ritual cd start number dur number active nil; name(party1) nil",
				["t"] = 1794943003,
			},
			[4] = {
				["a"] = {
					["C"] = {
						["HasSecretRestrictions"] = "no such call",
						["ShouldAurasBeSecret"] = "no such call",
						["ShouldCooldownsBeSecret"] = "no such call",
						["ShouldUnitStatsBeSecret"] = "no such call",
						["canCompare_plate1_player"] = "no such call",
						["canCompare_player_target"] = "no such call",
						["castSecrecy698"] = "no such call",
						["cast_party1_698"] = "no such call",
						["casting_party1"] = "no such call",
						["casting_player"] = "no such call",
						["compare_plate1_player"] = "no such call",
						["compare_player_target"] = "no such call",
						["cooldown698"] = "no such call",
						["cooldownSecrecy698"] = "no such call",
						["exists"] = "0 of 27",
						["identity_nameplate1"] = "no such call",
						["identity_party1"] = "no such call",
						["identity_player"] = "no such call",
						["identity_target"] = "no such call",
					},
					["cast"] = {
						["party1"] = {
							["casting"] = {
								["n"] = 0,
							},
						},
						["player"] = {
							["casting"] = {
								["n"] = 0,
							},
							["channel"] = {
								["n"] = 0,
							},
						},
					},
					["cd"] = {
						[686] = {
							["duration"] = "number",
							["isActive"] = "nil",
							["isEnabled"] = true,
							["isOnGCD"] = "nil",
							["startTime"] = "number",
						},
						[698] = {
							["duration"] = "number",
							["isActive"] = "nil",
							["isEnabled"] = true,
							["isOnGCD"] = "nil",
							["startTime"] = "number",
						},
						[8690] = {
							["duration"] = "number",
							["isActive"] = "nil",
							["isEnabled"] = true,
							["isOnGCD"] = "nil",
							["startTime"] = "number",
						},
					},
					["chat"] = {
						["lockdown"] = false,
						["outgoingRestricted"] = true,
					},
					["has"] = {
						["C_RestrictedActions"] = false,
						["C_Secrets"] = false,
						["canaccesstable"] = false,
						["canaccessvalue"] = true,
						["issecrettable"] = false,
						["issecretvalue"] = true,
						["scrub"] = false,
						["secretwrap"] = false,
					},
					["restrict"] = {
						[0] = {
							["active"] = "no such call",
							["state"] = "no such call",
						},
						[1] = {
							["active"] = "no such call",
							["state"] = "no such call",
						},
						[2] = {
							["active"] = "no such call",
							["state"] = "no such call",
						},
						[3] = {
							["active"] = "no such call",
							["state"] = "no such call",
						},
						[4] = {
							["active"] = "no such call",
							["state"] = "no such call",
						},
						[5] = {
							["active"] = "no such call",
							["state"] = "no such call",
						},
					},
					["unit"] = {
						["nameplate1"] = {
							["guid"] = {
								[1] = "nil",
								["n"] = 1,
							},
							["name"] = {
								[1] = "nil",
								["n"] = 1,
							},
						},
						["party1"] = {
							["guid"] = {
								[1] = "nil",
								["n"] = 1,
							},
							["name"] = {
								[1] = "nil",
								["n"] = 1,
							},
						},
						["party1class"] = {
							[1] = "nil",
							["n"] = 1,
						},
						["player"] = {
							["guid"] = {
								[1] = "string",
								["n"] = 1,
							},
							["name"] = {
								[1] = "string",
								["n"] = 1,
							},
						},
						["target"] = {
							["guid"] = {
								[1] = "nil",
								["n"] = 1,
							},
							["name"] = {
								[1] = "nil",
								["n"] = 1,
							},
						},
					},
					["where"] = {
						["affecting"] = false,
						["combatLockdown"] = false,
						["inInstance"] = "no answer",
						["instanceType"] = "none",
					},
					["why"] = "ZONE_CHANGED_NEW_AREA+1s",
				},
				["build"] = "1.60.1 (71037)",
				["line"] = "ZONE_CHANGED_NEW_AREA+1s: has C_Secrets false, HasSecretRestrictions no such call; restrict combat no such call/enc no such call/key no such call/pvp no such call/map no such call/chat no such call; chat lockdown false; combat false, instance no answer (none); ritual cd start number dur number active nil; name(party1) ",
				["t"] = 1794943004,
			},
			[5] = {
				["a"] = {
					["bnSender"] = "nil",
					["combat"] = false,
					["ev"] = "CHAT_MSG_SYSTEM",
					["guid"] = "nil",
					["inInstance"] = "no answer",
					["lockdown"] = false,
					["n"] = 1,
					["sender"] = "nil",
					["sender2"] = "nil",
					["text"] = "string",
				},
				["build"] = "1.60.1 (71037)",
				["line"] = "CHAT_MSG_SYSTEM: lockdown false, instance no answer, combat false: text string, sender nil, guid nil (1 args)",
				["t"] = 1794943006,
			},
			[6] = {
				["a"] = {
					["bnSender"] = "nil",
					["combat"] = false,
					["ev"] = "CHAT_MSG_ADDON",
					["guid"] = "nil",
					["inInstance"] = "no answer",
					["lockdown"] = false,
					["n"] = 9,
					["sender"] = "string",
					["sender2"] = "string",
					["text"] = "string",
				},
				["build"] = "1.60.1 (71037)",
				["line"] = "CHAT_MSG_ADDON: lockdown false, instance no answer, combat false: text string, sender string, guid nil (9 args)",
				["t"] = 1794943006,
			},
			[7] = {
				["a"] = {
					["C"] = {
						["HasSecretRestrictions"] = "no such call",
						["ShouldAurasBeSecret"] = "no such call",
						["ShouldCooldownsBeSecret"] = "no such call",
						["ShouldUnitStatsBeSecret"] = "no such call",
						["canCompare_plate1_player"] = "no such call",
						["canCompare_player_target"] = "no such call",
						["castSecrecy698"] = "no such call",
						["cast_party1_698"] = "no such call",
						["casting_party1"] = "no such call",
						["casting_player"] = "no such call",
						["compare_plate1_player"] = "no such call",
						["compare_player_target"] = "no such call",
						["cooldown698"] = "no such call",
						["cooldownSecrecy698"] = "no such call",
						["exists"] = "0 of 27",
						["identity_nameplate1"] = "no such call",
						["identity_party1"] = "no such call",
						["identity_player"] = "no such call",
						["identity_target"] = "no such call",
					},
					["cast"] = {
						["party1"] = {
							["casting"] = {
								["n"] = 0,
							},
						},
						["player"] = {
							["casting"] = {
								["n"] = 0,
							},
							["channel"] = {
								["n"] = 0,
							},
						},
					},
					["cd"] = {
						[686] = {
							["duration"] = "number",
							["isActive"] = "nil",
							["isEnabled"] = true,
							["isOnGCD"] = "nil",
							["startTime"] = "number",
						},
						[698] = {
							["duration"] = "number",
							["isActive"] = "nil",
							["isEnabled"] = true,
							["isOnGCD"] = "nil",
							["startTime"] = "number",
						},
						[8690] = {
							["duration"] = "number",
							["isActive"] = "nil",
							["isEnabled"] = true,
							["isOnGCD"] = "nil",
							["startTime"] = "number",
						},
					},
					["chat"] = {
						["lockdown"] = false,
						["outgoingRestricted"] = true,
					},
					["has"] = {
						["C_RestrictedActions"] = false,
						["C_Secrets"] = false,
						["canaccesstable"] = false,
						["canaccessvalue"] = true,
						["issecrettable"] = false,
						["issecretvalue"] = true,
						["scrub"] = false,
						["secretwrap"] = false,
					},
					["restrict"] = {
						[0] = {
							["active"] = "no such call",
							["state"] = "no such call",
						},
						[1] = {
							["active"] = "no such call",
							["state"] = "no such call",
						},
						[2] = {
							["active"] = "no such call",
							["state"] = "no such call",
						},
						[3] = {
							["active"] = "no such call",
							["state"] = "no such call",
						},
						[4] = {
							["active"] = "no such call",
							["state"] = "no such call",
						},
						[5] = {
							["active"] = "no such call",
							["state"] = "no such call",
						},
					},
					["unit"] = {
						["nameplate1"] = {
							["guid"] = {
								[1] = "nil",
								["n"] = 1,
							},
							["name"] = {
								[1] = "nil",
								["n"] = 1,
							},
						},
						["party1"] = {
							["guid"] = {
								[1] = "nil",
								["n"] = 1,
							},
							["name"] = {
								[1] = "nil",
								["n"] = 1,
							},
						},
						["party1class"] = {
							[1] = "nil",
							["n"] = 1,
						},
						["player"] = {
							["guid"] = {
								[1] = "string",
								["n"] = 1,
							},
							["name"] = {
								[1] = "string",
								["n"] = 1,
							},
						},
						["target"] = {
							["guid"] = {
								[1] = "nil",
								["n"] = 1,
							},
							["name"] = {
								[1] = "nil",
								["n"] = 1,
							},
						},
					},
					["where"] = {
						["affecting"] = false,
						["combatLockdown"] = false,
						["inInstance"] = "no answer",
						["instanceType"] = "none",
					},
					["why"] = "login",
				},
				["build"] = "1.60.1 (71037)",
				["line"] = "login: has C_Secrets false, HasSecretRestrictions no such call; restrict combat no such call/enc no such call/key no such call/pvp no such call/map no such call/chat no such call; chat lockdown false; combat false, instance no answer (none); ritual cd start number dur number active nil; name(party1) nil",
				["t"] = 1794943007,
			},
			[8] = {
				["a"] = {
					["C"] = {
						["HasSecretRestrictions"] = "no such call",
						["ShouldAurasBeSecret"] = "no such call",
						["ShouldCooldownsBeSecret"] = "no such call",
						["ShouldUnitStatsBeSecret"] = "no such call",
						["canCompare_plate1_player"] = "no such call",
						["canCompare_player_target"] = "no such call",
						["castSecrecy698"] = "no such call",
						["cast_party1_698"] = "no such call",
						["casting_party1"] = "no such call",
						["casting_player"] = "no such call",
						["compare_plate1_player"] = "no such call",
						["compare_player_target"] = "no such call",
						["cooldown698"] = "no such call",
						["cooldownSecrecy698"] = "no such call",
						["exists"] = "0 of 27",
						["identity_nameplate1"] = "no such call",
						["identity_party1"] = "no such call",
						["identity_player"] = "no such call",
						["identity_target"] = "no such call",
					},
					["cast"] = {
						["party1"] = {
							["casting"] = {
								["n"] = 0,
							},
						},
						["player"] = {
							["casting"] = {
								["n"] = 0,
							},
							["channel"] = {
								["n"] = 0,
							},
						},
					},
					["cd"] = {
						[686] = {
							["duration"] = "number",
							["isActive"] = "nil",
							["isEnabled"] = true,
							["isOnGCD"] = "nil",
							["startTime"] = "number",
						},
						[698] = {
							["duration"] = "number",
							["isActive"] = "nil",
							["isEnabled"] = true,
							["isOnGCD"] = "nil",
							["startTime"] = "number",
						},
						[8690] = {
							["duration"] = "number",
							["isActive"] = "nil",
							["isEnabled"] = true,
							["isOnGCD"] = "nil",
							["startTime"] = "number",
						},
					},
					["chat"] = {
						["lockdown"] = false,
						["outgoingRestricted"] = true,
					},
					["has"] = {
						["C_RestrictedActions"] = false,
						["C_Secrets"] = false,
						["canaccesstable"] = false,
						["canaccessvalue"] = true,
						["issecrettable"] = false,
						["issecretvalue"] = true,
						["scrub"] = false,
						["secretwrap"] = false,
					},
					["restrict"] = {
						[0] = {
							["active"] = "no such call",
							["state"] = "no such call",
						},
						[1] = {
							["active"] = "no such call",
							["state"] = "no such call",
						},
						[2] = {
							["active"] = "no such call",
							["state"] = "no such call",
						},
						[3] = {
							["active"] = "no such call",
							["state"] = "no such call",
						},
						[4] = {
							["active"] = "no such call",
							["state"] = "no such call",
						},
						[5] = {
							["active"] = "no such call",
							["state"] = "no such call",
						},
					},
					["unit"] = {
						["nameplate1"] = {
							["guid"] = {
								[1] = "nil",
								["n"] = 1,
							},
							["name"] = {
								[1] = "nil",
								["n"] = 1,
							},
						},
						["party1"] = {
							["guid"] = {
								[1] = "string",
								["n"] = 1,
							},
							["name"] = {
								[1] = "string",
								[2] = "string",
								["n"] = 2,
							},
						},
						["party1class"] = {
							[1] = "string",
							[2] = "string",
							[3] = "number",
							["n"] = 3,
						},
						["player"] = {
							["guid"] = {
								[1] = "string",
								["n"] = 1,
							},
							["name"] = {
								[1] = "string",
								["n"] = 1,
							},
						},
						["target"] = {
							["guid"] = {
								[1] = "nil",
								["n"] = 1,
							},
							["name"] = {
								[1] = "nil",
								["n"] = 1,
							},
						},
					},
					["where"] = {
						["affecting"] = false,
						["combatLockdown"] = false,
						["inInstance"] = "no answer",
						["instanceType"] = "none",
					},
					["why"] = "ENCOUNTER_START",
				},
				["build"] = "1.60.1 (71037)",
				["line"] = "ENCOUNTER_START: has C_Secrets false, HasSecretRestrictions no such call; restrict combat no such call/enc no such call/key no such call/pvp no such call/map no such call/chat no such call; chat lockdown false; combat false, instance no answer (none); ritual cd start number dur number active nil; name(party1) string",
				["t"] = 1794943028,
			},
			[9] = {
				["a"] = {
					["C"] = {
						["HasSecretRestrictions"] = "no such call",
						["ShouldAurasBeSecret"] = "no such call",
						["ShouldCooldownsBeSecret"] = "no such call",
						["ShouldUnitStatsBeSecret"] = "no such call",
						["canCompare_plate1_player"] = "no such call",
						["canCompare_player_target"] = "no such call",
						["castSecrecy698"] = "no such call",
						["cast_party1_698"] = "no such call",
						["casting_party1"] = "no such call",
						["casting_player"] = "no such call",
						["compare_plate1_player"] = "no such call",
						["compare_player_target"] = "no such call",
						["cooldown698"] = "no such call",
						["cooldownSecrecy698"] = "no such call",
						["exists"] = "0 of 27",
						["identity_nameplate1"] = "no such call",
						["identity_party1"] = "no such call",
						["identity_player"] = "no such call",
						["identity_target"] = "no such call",
					},
					["cast"] = {
						["party1"] = {
							["casting"] = {
								["n"] = 0,
							},
						},
						["player"] = {
							["casting"] = {
								["n"] = 0,
							},
							["channel"] = {
								["n"] = 0,
							},
						},
					},
					["cd"] = {
						[686] = {
							["duration"] = "number",
							["isActive"] = "nil",
							["isEnabled"] = true,
							["isOnGCD"] = "nil",
							["startTime"] = "number",
						},
						[698] = {
							["duration"] = "number",
							["isActive"] = "nil",
							["isEnabled"] = true,
							["isOnGCD"] = "nil",
							["startTime"] = "number",
						},
						[8690] = {
							["duration"] = "number",
							["isActive"] = "nil",
							["isEnabled"] = true,
							["isOnGCD"] = "nil",
							["startTime"] = "number",
						},
					},
					["chat"] = {
						["lockdown"] = false,
						["outgoingRestricted"] = true,
					},
					["has"] = {
						["C_RestrictedActions"] = false,
						["C_Secrets"] = false,
						["canaccesstable"] = false,
						["canaccessvalue"] = true,
						["issecrettable"] = false,
						["issecretvalue"] = true,
						["scrub"] = false,
						["secretwrap"] = false,
					},
					["restrict"] = {
						[0] = {
							["active"] = "no such call",
							["state"] = "no such call",
						},
						[1] = {
							["active"] = "no such call",
							["state"] = "no such call",
						},
						[2] = {
							["active"] = "no such call",
							["state"] = "no such call",
						},
						[3] = {
							["active"] = "no such call",
							["state"] = "no such call",
						},
						[4] = {
							["active"] = "no such call",
							["state"] = "no such call",
						},
						[5] = {
							["active"] = "no such call",
							["state"] = "no such call",
						},
					},
					["unit"] = {
						["nameplate1"] = {
							["guid"] = {
								[1] = "nil",
								["n"] = 1,
							},
							["name"] = {
								[1] = "nil",
								["n"] = 1,
							},
						},
						["party1"] = {
							["guid"] = {
								[1] = "string",
								["n"] = 1,
							},
							["name"] = {
								[1] = "string",
								[2] = "string",
								["n"] = 2,
							},
						},
						["party1class"] = {
							[1] = "string",
							[2] = "string",
							[3] = "number",
							["n"] = 3,
						},
						["player"] = {
							["guid"] = {
								[1] = "string",
								["n"] = 1,
							},
							["name"] = {
								[1] = "string",
								["n"] = 1,
							},
						},
						["target"] = {
							["guid"] = {
								[1] = "nil",
								["n"] = 1,
							},
							["name"] = {
								[1] = "nil",
								["n"] = 1,
							},
						},
					},
					["where"] = {
						["affecting"] = false,
						["combatLockdown"] = false,
						["inInstance"] = "no answer",
						["instanceType"] = "none",
					},
					["why"] = "auto",
				},
				["build"] = "1.60.1 (71037)",
				["line"] = "auto: has C_Secrets false, HasSecretRestrictions no such call; restrict combat no such call/enc no such call/key no such call/pvp no such call/map no such call/chat no such call; chat lockdown false; combat false, instance no answer (none); ritual cd start number dur number active nil; name(party1) string",
				["t"] = 1794943028,
			},
			[10] = {
				["a"] = {
					["C"] = {
						["HasSecretRestrictions"] = "no such call",
						["ShouldAurasBeSecret"] = "no such call",
						["ShouldCooldownsBeSecret"] = "no such call",
						["ShouldUnitStatsBeSecret"] = "no such call",
						["canCompare_plate1_player"] = "no such call",
						["canCompare_player_target"] = "no such call",
						["castSecrecy698"] = "no such call",
						["cast_party1_698"] = "no such call",
						["casting_party1"] = "no such call",
						["casting_player"] = "no such call",
						["compare_plate1_player"] = "no such call",
						["compare_player_target"] = "no such call",
						["cooldown698"] = "no such call",
						["cooldownSecrecy698"] = "no such call",
						["exists"] = "0 of 27",
						["identity_nameplate1"] = "no such call",
						["identity_party1"] = "no such call",
						["identity_player"] = "no such call",
						["identity_target"] = "no such call",
					},
					["cast"] = {
						["party1"] = {
							["casting"] = {
								["n"] = 0,
							},
						},
						["player"] = {
							["casting"] = {
								["n"] = 0,
							},
							["channel"] = {
								["n"] = 0,
							},
						},
					},
					["cd"] = {
						[686] = {
							["duration"] = "number",
							["isActive"] = "nil",
							["isEnabled"] = true,
							["isOnGCD"] = "nil",
							["startTime"] = "number",
						},
						[698] = {
							["duration"] = "number",
							["isActive"] = "nil",
							["isEnabled"] = true,
							["isOnGCD"] = "nil",
							["startTime"] = "number",
						},
						[8690] = {
							["duration"] = "number",
							["isActive"] = "nil",
							["isEnabled"] = true,
							["isOnGCD"] = "nil",
							["startTime"] = "number",
						},
					},
					["chat"] = {
						["lockdown"] = false,
						["outgoingRestricted"] = true,
					},
					["has"] = {
						["C_RestrictedActions"] = false,
						["C_Secrets"] = false,
						["canaccesstable"] = false,
						["canaccessvalue"] = true,
						["issecrettable"] = false,
						["issecretvalue"] = true,
						["scrub"] = false,
						["secretwrap"] = false,
					},
					["restrict"] = {
						[0] = {
							["active"] = "no such call",
							["state"] = "no such call",
						},
						[1] = {
							["active"] = "no such call",
							["state"] = "no such call",
						},
						[2] = {
							["active"] = "no such call",
							["state"] = "no such call",
						},
						[3] = {
							["active"] = "no such call",
							["state"] = "no such call",
						},
						[4] = {
							["active"] = "no such call",
							["state"] = "no such call",
						},
						[5] = {
							["active"] = "no such call",
							["state"] = "no such call",
						},
					},
					["unit"] = {
						["nameplate1"] = {
							["guid"] = {
								[1] = "nil",
								["n"] = 1,
							},
							["name"] = {
								[1] = "nil",
								["n"] = 1,
							},
						},
						["party1"] = {
							["guid"] = {
								[1] = "string",
								["n"] = 1,
							},
							["name"] = {
								[1] = "string",
								[2] = "string",
								["n"] = 2,
							},
						},
						["party1class"] = {
							[1] = "string",
							[2] = "string",
							[3] = "number",
							["n"] = 3,
						},
						["player"] = {
							["guid"] = {
								[1] = "string",
								["n"] = 1,
							},
							["name"] = {
								[1] = "string",
								["n"] = 1,
							},
						},
						["target"] = {
							["guid"] = {
								[1] = "nil",
								["n"] = 1,
							},
							["name"] = {
								[1] = "nil",
								["n"] = 1,
							},
						},
					},
					["where"] = {
						["affecting"] = false,
						["combatLockdown"] = false,
						["inInstance"] = "no answer",
						["instanceType"] = "none",
					},
					["why"] = "ENCOUNTER_START+1s",
				},
				["build"] = "1.60.1 (71037)",
				["line"] = "ENCOUNTER_START+1s: has C_Secrets false, HasSecretRestrictions no such call; restrict combat no such call/enc no such call/key no such call/pvp no such call/map no such call/chat no such call; chat lockdown false; combat false, instance no answer (none); ritual cd start number dur number active nil; name(party1) string",
				["t"] = 1794943029,
			},
		},
		["TRADEBTN"] = {
			[1] = {
				["a"] = {
					["enabled"] = true,
					["enumValue"] = "no Enum.ForbiddenAspect",
					["exists"] = true,
					["forbidden"] = false,
					["hasAccessConstraints"] = "no such call",
					["protected"] = false,
					["scriptedInput64"] = "no such call",
					["scriptedInputEnum"] = "no such call",
					["shown"] = true,
					["verdict"] = "unknown",
					["why"] = "auto",
					["wuberBlocked"] = false,
				},
				["build"] = "1.60.1 (71037)",
				["line"] = "TradeFrameTradeButton: constraints no such call, ScriptedInput no such call, forbidden false, protected false, Wuber's recorded refusal false: the secure click would be unknown",
				["t"] = 1794943028,
			},
		},
	},
	["v"] = 1,
}
