(* ::Package:: *)

(* ::Section::Closed:: *)
(*Package Header*)


BeginPackage[ "Wolfram`AgentTools`PreferencesContent`" ];
Begin[ "`Private`" ];

Needs[ "Wolfram`AgentTools`"        ];
Needs[ "Wolfram`AgentTools`Common`" ];



(* ::**************************************************************************************************************:: *)
(**)


(* ::Section::Closed:: *)
(*resources*)


tr[id_] := Dynamic[FEPrivate`FrontEndResource["AgentToolsStrings", id]];


icon[id_] := Dynamic[RawBoxes @ FEPrivate`FrontEndResource["AgentToolsExpressions", id]];
icon[id_, args__] := Dynamic[RawBoxes @ FEPrivate`FrontEndResource["AgentToolsExpressions", id][args]];


ldsGray[n_] := LightDarkSwitched[GrayLevel[n]]


$allowDirectoryOperations = False;


(* ::Section::Closed:: *)
(*docsLink*)


docsLink[] :=
	MouseAppearance[
		Button[
			Framed[
				Row[{tr["prefsDocsLinkText"], " \[UpperRightArrow]"}, BaseStyle -> {FontSize -> Inherited - 2}],
				RoundingRadius -> 2,
				FrameMargins -> {{5,5},{1,1}},
				FrameStyle -> Dynamic[If[CurrentValue["MouseOver"], ldsGray[0.7], ldsGray[0.85]]],
				Background -> Dynamic[If[CurrentValue["MouseOver"], ldsGray[0.9], ldsGray[0.97]]]],
			If[
				TrueQ @ CurrentValue["OptionKey"],
				CreateDocument[{
					ExpressionCell[Defer[DeployedAgentTools[]], "Input"],
					ExpressionCell[DeployedAgentTools[], "Output"]
				}],
				SystemOpen["paclet:Wolfram/AgentTools/tutorial/QuickStartforAICodingApplications"]
			],
			Appearance -> None,
			BaseStyle -> {},
			DefaultBaseStyle -> {}
		],
		"LinkHand"
	]


(* ::Section::Closed:: *)
(*clientInterfaces*)


clientInterfaces[] :=
	DynamicModule[{update, clients, servers, globallyConfiguredClients, locallyConfiguredClients, detectedClients, otherClients, clientNameSpacer, initDone, refresh},

		Dynamic[
			Which[
				update;
				initDone =!= True,
					ProgressIndicator[Appearance -> "Necklace"],

				MatchQ[clients, Except[{__String}]],
					Style["[[The list of supported MCP clients is not available.]]", Italic, FontColor -> ldsGray[0.5]],
				MatchQ[servers, Except[{__String}]],
					Style["[[The list of default MCP servers is not available.]]", Italic, FontColor -> ldsGray[0.5]],
				
				True,
					Column[
						{
							If[
								globallyConfiguredClients === {}, Nothing, 
								Column[
									Prepend[
										clientRow["Configured", #, clientNameSpacer, Dynamic[refresh]]& /@ globallyConfiguredClients,
										Style[tr["prefsHarnessesConfigured"], Smaller, FontColor -> ldsGray[0.5], Bold]
									],
									ItemSize -> Scaled[1]
								]
							],
							
							If[
								detectedClients === {}, Nothing,
								Column[
									Join[
										{
											Style[tr["prefsHarnessesDetected"], Smaller, FontColor -> ldsGray[0.5], Bold],
											Button["Configure All",
												refresh @ Map[DeployAgentTools, detectedClients],
												ImageSize -> Automatic,
												FrameMargins -> {{30,30},{10,10}}
											]
										},
										clientRow["Detected", #, clientNameSpacer, Dynamic[refresh]]& /@ detectedClients
									],
									ItemSize -> Scaled[1]
								]
							],
							If[
								otherClients === {}, Nothing,
								Column[
									Prepend[
										clientRow["Other", #, clientNameSpacer, Dynamic[refresh]]& /@ otherClients,
										If[globallyConfiguredClients === detectedClients === {},
											Style[tr["prefsHarnessesAll"], Smaller, FontColor -> ldsGray[0.5], Bold],
											Style[tr["prefsHarnessesMore"], Smaller, FontColor -> ldsGray[0.5], Bold]
										]
									]
								]
							
							]
						},
						Dividers -> Center,
						FrameStyle -> ldsGray[0.8],
						Spacings -> 3
					]
			],
			TrackedSymbols :> {initDone, update}
		],

		Initialization :> (
			initDone = False;
			update = 0;
			clients = Keys @ Wolfram`AgentTools`$SupportedMCPClients;
			servers = Keys @ Wolfram`AgentTools`$DefaultMCPServers;
			clientNameSpacer = PaneSelector[KeyValueMap[#1 -> #2["DisplayName"]&, Wolfram`AgentTools`$SupportedMCPClients], True];
			(* If there are no stored settings for a client's selected toolset, initialize it to its default *)
			Do[
				CurrentValue[
					$FrontEnd,
					{PrivateFrontEndOptions, "InterfaceSettings", "ServicesForAIs", "SelectedToolset", client},
					Wolfram`AgentTools`$SupportedMCPClients[client]["DefaultToolset"]
				],
				{client, clients}
			];
			SetAttributes[refresh, HoldAll];
			refresh[evals___] := WithCleanup[
				CompoundExpression[update, evals],
				(*
					globallyConfiguredClients is the list of clients with a relevant, global configuration.
					If there are clients with relevant, per-directory configs but without a global config, 
					those will be in locallyConfiguredClients -- and thus in detectedClients -- instead.
				*)
				With[{ configured = {#["ClientName"], #["Toolset"], #["Scope"]}& /@  DeployedAgentTools[ ] },
					globallyConfiguredClients = Cases[configured, {name_, "Wolfram" | "WolframLanguage", "Global"} :> name];
					locallyConfiguredClients = Cases[configured, {name_, "Wolfram" | "WolframLanguage", _File} :> name];
				];
				detectedClients = Complement[
					Union[locallyConfiguredClients, Keys @ Wolfram`AgentTools`DetectedMCPClients[]],
					globallyConfiguredClients
				];
				otherClients = Complement[clients, globallyConfiguredClients, detectedClients];
				++update;
			];
			
			refresh[ ];
			initDone = True;
		),
		SynchronousInitialization -> False,
		UnsavedVariables :> {update, clients, servers, globallyConfiguredClients, locallyConfiguredClients, detectedClients, otherClients, clientNameSpacer, initDone, refresh}
	]


(* ::Section::Closed:: *)
(*clientRow*)


ClearAll[clientRow];
clientRow[category_, client_, spacer_, Dynamic[refresh_]] :=
	Grid[
		{{
			clientName[client, spacer],
			clientControls[category, client, Dynamic[refresh]]
		}},
		Dividers -> {{False, True, False}, None},
		FrameStyle -> ldsGray[0.85],
		Spacings -> {2,2},
		Background -> If[ category === "Configured",
			LightDarkSwitched[RGBColor[0.797, 0.931, 0.859]],
			Automatic
		]
	]


(* ::Section::Closed:: *)
(*clientName*)


clientName[client_, spacer_] :=
	With[{
			displayName = Wolfram`AgentTools`$SupportedMCPClients[client]["DisplayName"],
			url = Wolfram`AgentTools`$SupportedMCPClients[client]["URL"]
		},

		If[
			StringQ[url],
			PaneSelector[
				{
					True -> Hyperlink[
							displayName,
							url,
							Tooltip -> ToBoxes[url],
							BaseStyle -> {FontColor -> ldsGray[0]},
							ActiveStyle -> {FontColor -> StandardBlue}
						],
					False -> spacer
				},
				True,
				Alignment -> Left,
				ImageMargins -> {{15,20},{0,0}}
			],
			client
		]
	]


(* ::Section::Closed:: *)
(*clientControls*)


(*
Note: The UX calls for this interface to list two MCP servers: "ComputationTools", and "DevelopmentTools".
However, $DefaultMCPServers currently returns a list of 4 servers, none of which have those names.

So for now, the code below lists only the two names from the UX, and maps them to current names thusly:

"Wolfram" === "ComputationTools"
"WolframLanguage" === "DevelopmentTools"

If the naming of MCP servers in $DefaultMCPServers ever changes in an incompatible way, this code will need
to be adjusted to stay in sync.
*)


clientControls[category_, client_, Dynamic[refresh_]] :=
	DynamicModule[{dirSettings},
		Grid[
			{
				{
					(* menu *)
					PopupMenu[
						Dynamic[
							CurrentValue[$FrontEnd, {PrivateFrontEndOptions, "InterfaceSettings", "ServicesForAIs", "SelectedToolset", client}],
							(
								CurrentValue[$FrontEnd, {PrivateFrontEndOptions, "InterfaceSettings", "ServicesForAIs", "SelectedToolset", client}] = #;
								If[category === "Configured", refresh @ DeployAgentTools[client, #, OverwriteTarget -> True]]
							)&
						]
						,
						{
							"Wolfram" -> tr["prefsComputationTools"],
							"WolframLanguage" -> tr["prefsDevelopmentTools"]
						},
						None,
						Framed[
							Grid[
								{{
									Item[
										Dynamic[
											Replace[
												CurrentValue[$FrontEnd, {PrivateFrontEndOptions, "InterfaceSettings", "ServicesForAIs", "SelectedToolset", client}],
												{
													"Wolfram" -> tr["prefsComputationTools"],
													"WolframLanguage" -> tr["prefsDevelopmentTools"]
												}
											]
										],
										ItemSize -> Fit
									],
									icon["prefsDownPointer", ldsGray[0.2], 10]
								}},
								Alignment -> Left
							],
							RoundingRadius -> 3,
							ImageSize -> 320,
							FrameStyle -> (*ldsGray[0.85]*)Dynamic[If[CurrentValue["MouseOver"], ldsGray[0.7], ldsGray[0.85]]],
							Background -> (*ldsGray[0.97]*)Dynamic[If[CurrentValue["MouseOver"], ldsGray[0.9], ldsGray[0.97]]]
						],
						ImageSize -> 320,
						Appearance -> "ActionMenu",
						BaseStyle -> {}, (* needed to avoid very strange notebook-level settings in the Preferences Dialog *)
						DefaultBaseStyle -> {},
						DefaultMenuStyle -> {}
					],
					(* action button *)
					If[category === "Configured",
						Button[ (* disable *)
							PaneSelector[{0 -> tr["prefsDisableButton"], 1 -> tr["prefsConfigureButton"]}, 0, Alignment -> Center],
							refresh @ DeleteObject @ Select[
								DeployedAgentTools @ client,
								#["Scope"] === "Global" && MatchQ[#["Toolset"], "Wolfram"|"WolframLanguage"]&
							],
							Method -> "Queued"
						],
						Button[ (* configure *)
							PaneSelector[{0 -> tr["prefsDisableButton"], 1 -> tr["prefsConfigureButton"]}, 1, Alignment -> Center],
							refresh @ DeployAgentTools[
								client,
								CurrentValue[$FrontEnd, {PrivateFrontEndOptions, "InterfaceSettings", "ServicesForAIs", "SelectedToolset", client}],
								OverwriteTarget -> True
							],
							Method -> "Queued"
						]
					]
					,
					(* info link *)
					infoLink[category, client]
				},
				(*
					We cache per-directory settings when each instance of the interface is
					created. This allows us to continue displaying the info for any such
					objects, suitably restyled, after they have been removed by clicking
					the 'x' button.
				*)
				dirSettings = Cases[
					{#, #["Toolset"], #["Scope"], True}& /@ DeployedAgentTools[client],
					{_, "Wolfram" | "WolframLanguage", _File, _}
				];
				If[dirSettings === {},
					Nothing,
					{
						Pane[
							Dynamic[
								Grid[
									{
										{
											Style[tr["prefsSpecificDirectories"], Smaller, FontColor -> ldsGray[0.5], Bold],
											SpanFromLeft,
											SpanFromLeft
										},
										Splice @ Table[
											dirSettingsRow[Dynamic[dirSettings], i, dirSettings[[i]]],
											{i, Length[dirSettings]}
										]
									},
									Alignment -> {{Left, Right, Right}},
									ItemSize -> {{Fit, Automatic, Automatic}},
									Spacings -> {1, Automatic},
									BaseStyle -> {PrivateFontOptions -> {"OperatorSubstitution" -> False}}
								],
								TrackedSymbols :> {dirSettings}
							],
							ImageSize -> 310,
							Alignment -> Left,
							ImageMargins -> 5
						],
						"", (* action button column *)
						"" (* info button column *)
					}
				]
			},
			Alignment -> Left,
			BaselinePosition -> 1,
			ItemSize -> Full
		]
	]


(* ::Section::Closed:: *)
(*infoLink*)


(* Styling of this link/tooltip matches the standard Preferences dialog styling for such. *)


infoLink[category_, client_] := 
	Module[{objects, info, locations},
		Switch[category,
			"Configured",
				(* link to the global prefs file we know exists *)
				objects = DeployedAgentTools[client];
				info = {#["Scope"], #["MCP"]["Server"], #["MCP"]["ConfigFile"]}& /@ objects;
				locations = Cases[info, {"Global", "Wolfram" | "WolframLanguage", File[loc_]} :> loc],
			"Detected",
				(* link to where the global prefs file should be *)
				locations = {FileNameJoin @ Replace[
					Wolfram`AgentTools`$SupportedMCPClients[client]["InstallLocation"],
					{
						a_Association :> Lookup[a, $OperatingSystem, {}],
						Except[_List] :> {}
					}
				]},
			_,
				locations = {}
		];

		If[
			MatchQ[locations, {__String}],
			With[{locations = locations},
				Button[
					Tooltip[
						NotebookTools`Mousedown[
							icon["prefsInfoIcon", LightDarkSwitched @ RGBColor["#898989"], 14],
							icon["prefsInfoIcon", LightDarkSwitched @ RGBColor[0.692, 0.692, 0.692], 14],
							icon["prefsInfoIcon", LightDarkSwitched @ RGBColor[0.358, 0.358, 0.358], 14]],
						Pane[
							Column[
								{
									Style[tr["prefsInstallLocation"], FontColor -> ldsGray[0.4]],
									Row[{#, "\[UpperRightArrow]"}, "\[NonBreakingSpace]"]& /@ locations
								} // Flatten
							],
							ImageMargins -> 3,
							ImageSize -> UpTo[274]
						],
						TooltipStyle -> {
							Background -> LightDarkSwitched @ RGBColor["#EDEDED"],
							CellFrameColor -> LightDarkSwitched @ RGBColor["#D1D1D1"],
							CellFrameMargins -> 5,
							FontColor -> LightDarkSwitched @ RGBColor["#333333"],
							FontFamily -> "Roboto",
							FontSize -> 11
						}
					],
					SystemOpen @ First @ locations,
					Appearance -> None
				]
			],
			""
		]
	]


(* ::Section::Closed:: *)
(*dirSettingsRow*)


dirSettingsRow[Dynamic[dirSettings_], i_, {obj_, server_, scope_, active_}] :=
	{
		(* directory display *)
		MouseAppearance[
			Button[
				Row[{
					Replace[scope,
						File[path_String] :>
							FE`Evaluate[FEPrivate`TruncateStringToWidth[path, "ControlStyle", 200, Left]]
					],
					If[active, " \[UpperRightArrow]", Nothing]
				}]
				,
				SystemOpen[scope],
				Appearance -> None,
				DefaultBaseStyle -> {},
				Enabled -> active,
				BaseStyle -> {
					FontColor -> Dynamic[If[active && CurrentValue["MouseOver"], StandardBlue, ldsGray[0.5]]],
					FontVariations -> If[active, {}, {"StrikeThrough" -> True}],
					FontSize -> Inherited - 2
				},
				BaselinePosition -> Baseline,
				ImageMargins -> {{5,0},{0,0}},
				Tooltip -> ToBoxes @ First @ obj["Scope"]
			],
			If[active, "LinkHand", Automatic]
		],
		(* toolset name *)
		Style[
			Replace[server, {
				"Wolfram" :> tr["prefsComputationTools"],
				"WolframLanguage" :> tr["prefsDevelopmentTools"]
			}],
			FontColor -> If[active, Inherited, ldsGray[0.5], Inherited],
			FontVariations -> If[active, {}, {"StrikeThrough" -> True}],
			FontSize -> Inherited - 2
		],
		(* directory operation buttons, if any *)
		If[$allowDirectoryOperations,
			Button[
				Mouseover[
					icon["prefsRemoveIcon", ldsGray[0.2], 10],
					icon["prefsRemoveIcon", StandardRed, 10]
				],
				DeleteObject[obj];
				dirSettings[[i, 4]] = False,
				Appearance -> None,
				DefaultBaseStyle -> {},
				BaseStyle -> {
					FontColor -> Dynamic[If[CurrentValue["MouseOver"], StandardBlue, ldsGray[0.5]]],
					ShowContents -> active
				},
				Tooltip -> ToBoxes @ tr["prefsUninstallTool"]
			],
			SpanFromLeft
		]
	}


(* ::Section::Closed:: *)
(*CreatePreferencesContent*)


CreatePreferencesContent // beginDefinition;


CreatePreferencesContent[] :=
Deploy[
	Pane[
		Column[
			{
				Grid[
					{{
						Item[
							StringTemplate[
									FrontEndResource["AgentToolsStrings", "prefsSubtitle"],
									CombinerFunction -> Row, 
									InsertionFunction -> Identity] @@
								Table[
									Tooltip[
										Mouseover[
											Row[{
												Style[tr[id], FontColor -> LightDarkSwitched @ Black],
												" ",
												icon["prefsInfoIcon", LightDarkSwitched @ RGBColor["#898989"], 14]
											}],
											Row[{
												Style[tr[id], FontColor -> LightDarkSwitched @ Gray],
												" ",
												icon["prefsInfoIcon", LightDarkSwitched @ RGBColor[0.692, 0.692, 0.692], 14]
											}]
										],
										tr[id <> "Description"]
									],
									{id, {"prefsComputationTools", "prefsDevelopmentTools"}}
								],
							ItemSize -> Fit
						],
						Item[docsLink[], Alignment -> Right]
					}},
					Alignment -> {Left, Center},
					BaseStyle -> {LinebreakAdjustments -> {1, 10, 1, 0, 1}},
					Spacings -> {2,0}
				],

				clientInterfaces[]
			},
			Dividers -> {None, {None, ldsGray[0.85], None}},
			ItemSize -> Scaled[1],
			Spacings -> {Automatic, {0,3}}
		],
		Alignment -> Left,
		ImageMargins -> {{25,25},{11,11}}
	]
]



CreatePreferencesContent // endExportedDefinition;


(* ::Section::Closed:: *)
(*Package Footer*)


addToMXInitialization[
    Null
];

End[ ];
EndPackage[ ];
