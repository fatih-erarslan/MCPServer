(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`AgentTools`UIResources`" ];
Begin[ "`Private`" ];

Needs[ "Wolfram`AgentTools`"        ];
Needs[ "Wolfram`AgentTools`Common`" ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Configuration*)

(* Mapping of tool names to their associated UI resource URIs *)
$toolUIAssociations = <|
    "NotebookViewer"           -> "ui://wolfram/notebook-viewer",
    "MCPAppsTest"              -> "ui://wolfram/mcp-apps-test",
    "WolframLanguageEvaluator" -> "ui://wolfram/evaluator-viewer",
    (* The WolframAlpha tool does not have a text-only fallback app view, so we make it conditional *)
    "WolframAlpha" :> If[ $deployCloudNotebooks, "ui://wolfram/wolframalpha-viewer", None ]
|>;

$includeAppearanceElements = False;
$deployedNotebookRoot      = "AgentTools/Notebooks";
$deployCloudNotebooks     := $deployCloudNotebooks = $CloudConnected; (* must be connected to deploy notebooks *)

(* Resource URI prefix used by the "dropped _meta" workaround: apps that never received a
   notebookUrl (because the host stripped _meta/structuredContent) read
   "ui://wolfram/notebook-url/<hexId>" to recover the full cloud URL. See makeNotebookUIResult
   and readNotebookURLResource below, and the matching client code in the viewer apps. *)
$notebookURLResourcePrefix = "ui://wolfram/notebook-url/";

(* Inline notebooks are not yet the default since there are still some issues to work out.
   These can be enabled via the following environment variable: *)
$mcpAppsNotebookMethod := $mcpAppsNotebookMethod = Environment[ "MCP_APPS_NOTEBOOK_METHOD" ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Cloud Notebooks*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*deployCloudNotebookForMCPApp*)
deployCloudNotebookForMCPApp // beginDefinition;

deployCloudNotebookForMCPApp[ nb_Notebook, _ ] /; $mcpAppsNotebookMethod === "Inline" := Enclose[
    (* This should be true if this function is being called: *)
    ConfirmAssert[ $deployCloudNotebooks, "DeployCloudNotebooksAssert" ];

    ConfirmBy[ ExportString[ nb, "NB" ], StringQ, "Exported" ],
    throwInternalFailure
];

deployCloudNotebookForMCPApp[ nb_Notebook, identifier_ ] := Enclose[
    Module[ { hash, target, deployed },

        (* This should be true if this function is being called: *)
        ConfirmAssert[ $deployCloudNotebooks, "DeployCloudNotebooksAssert" ];

        hash = ConfirmBy[ Hash[ Unevaluated @ identifier, Automatic, "HexString" ], StringQ, "Hash" ];

        target = ConfirmMatch[
            FileNameJoin @ {
                CloudObject[ $deployedNotebookRoot, Permissions -> { "All" -> { "Read", "Interact" } } ],
                hash <> ".nb"
            },
            _CloudObject,
            "Target"
        ];

        deployed = ConfirmMatch[
            cloudDeployTryAppearanceElements[ nb, target ],
            _CloudObject | _? FailureQ,
            "Deployed"
        ];

        If[ MatchQ[ deployed, _CloudObject ],
            ConfirmBy[ First @ deployed, StringQ, "Result" ],
            (* If deploying failed, disable cloud notebook deployment for the remainder of the session: *)
            $deployCloudNotebooks = False;
            $Failed
        ]
    ],
    throwInternalFailure
];

deployCloudNotebookForMCPApp // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*makeNotebookUIResult*)
(* Builds the UI-enhanced tool result for a deployed notebook. The notebookUrl is carried in
   _meta and structuredContent (per the MCP Apps spec) so it reaches the app without entering
   model context. Because some hosts drop both (ext-apps#696), we also append an opaque
   "<nbid>...</nbid>" marker to the content: the app extracts it and recovers the URL via
   resources/read (see readNotebookURLResource). The marker text is intentionally cryptic so
   the model ignores it, and each viewer strips it before rendering. *)
makeNotebookUIResult // beginDefinition;

makeNotebookUIResult[ textContent_List, deployed_String ] := <|
    "Content"           -> appendNotebookIDMarker[ textContent, deployed ],
    "_meta"             -> <| "notebookUrl" -> deployed |>,
    "StructuredContent" -> <| "notebookUrl" -> deployed |>
|>;

(* Deployment failed (deployCloudNotebookForMCPApp returned $Failed): no UI result. *)
makeNotebookUIResult[ _List, _ ] := $Failed;

makeNotebookUIResult // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*appendNotebookIDMarker*)
appendNotebookIDMarker // beginDefinition;

(* Only cloud URLs have a recoverable base name. Inline notebooks (MCP_APPS_NOTEBOOK_METHOD=
   "Inline") carry the whole serialized notebook as the value, which cannot be reconstructed
   from an id, so no marker is appended in that case. *)
appendNotebookIDMarker[ textContent_List, url_String ] /; StringStartsQ[ url, "http" ] :=
    Append[ textContent, <| "type" -> "text", "text" -> "<nbid>" <> notebookIDFromURL[ url ] <> "</nbid>" |> ];

appendNotebookIDMarker[ textContent_List, _ ] := textContent;

appendNotebookIDMarker // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*notebookIDFromURL*)
(* The deployed notebook's id is the base name of its cloud URL, e.g.
   ".../AgentTools/Notebooks/08aba9b360121fee.nb" -> "08aba9b360121fee". Uses plain string ops
   (cloud URLs are always "/"-separated) so it is platform independent. *)
notebookIDFromURL // beginDefinition;
notebookIDFromURL[ url_String ] := StringDelete[ Last @ StringSplit[ url, "/" ], ".nb" ~~ EndOfString ];
notebookIDFromURL // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*delayedDisplay*)
(* This is a workaround for plots showing up empty when embedding an inline notebook expression instead of a URL *)
delayedDisplay // beginDefinition;

delayedDisplay[ boxes_ ] /; $mcpAppsNotebookMethod =!= "Inline" := boxes;

delayedDisplay[ boxes_ ] /; FreeQ[ boxes, GraphicsBox|Graphics3DBox ] := boxes;

delayedDisplay[ boxes_ ] :=
    With[ { b64 = BaseEncode @ BinarySerialize[ Unevaluated @ RawBoxes @ boxes, PerformanceGoal -> "Size" ] },
        ToBoxes @ DynamicModule[
            { display },
            Dynamic[ Replace[ display, _Symbol :> ProgressIndicator[ Appearance -> "Percolate" ] ] ],
            Initialization            :> (display = BinaryDeserialize @ BaseDecode @ b64),
            SynchronousInitialization -> False,
            UnsavedVariables          :> { display }
        ]
    ];

delayedDisplay // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*cloudDeployTryAppearanceElements*)
cloudDeployTryAppearanceElements // beginDefinition;

cloudDeployTryAppearanceElements[ expr_, target_ ] /; $includeAppearanceElements :=
    cloudDeployWithAppearanceElements[ expr, target ];

(* This tries to CloudDeploy with AppearanceElements -> None, since the footer links will not be clickable in the app.
   However, some cloud accounts do not support this option, which causes CloudDeploy to fail with a message.
   In that case, we retry without the AppearanceElements option. *)
cloudDeployTryAppearanceElements[ expr_, target_ ] := Quiet[
    Check[
        CloudDeploy[
            expr,
            target,
            AppearanceElements -> None,
            AutoRemove         -> True,
            IconRules          -> { },
            Permissions        -> { "All" -> { "Read", "Interact" } }
        ],
        (* Disable this check for the remainder of the session: *)
        $includeAppearanceElements = True;
        cloudDeployWithAppearanceElements[ expr, target ],
        { CloudDeploy::appearancenotsup }
    ],
    { CloudDeploy::appearancenotsup }
];

cloudDeployTryAppearanceElements // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*cloudDeployWithAppearanceElements*)
cloudDeployWithAppearanceElements // beginDefinition;

cloudDeployWithAppearanceElements[ expr_, target_ ] := CloudDeploy[
    expr,
    target,
    AutoRemove  -> True,
    IconRules   -> { },
    Permissions -> { "All" -> { "Read", "Interact" } }
];

cloudDeployWithAppearanceElements // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*MCP Integration Helpers*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*clientSupportsUIQ*)
clientSupportsUIQ // beginDefinition;

clientSupportsUIQ[ msg_Association ] :=
    ! MissingQ @ msg[ "params", "capabilities", "extensions", "io.modelcontextprotocol/ui" ];

clientSupportsUIQ[ _ ] := False;

clientSupportsUIQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*mcpAppsEnabledQ*)
mcpAppsEnabledQ // beginDefinition;

mcpAppsEnabledQ[ ] :=
    With[ { val = Environment[ "MCP_APPS_ENABLED" ] },
        ! StringQ[ val ] || ! StringMatchQ[ val, "false", IgnoreCase -> True ]
    ];

mcpAppsEnabledQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*initializeUIResources*)
initializeUIResources // beginDefinition;

initializeUIResources[ ] := Enclose[
    Module[ { assetsDir, htmlFiles },
        assetsDir = ConfirmBy[
            PacletObject[ "Wolfram/AgentTools" ][ "AssetLocation", "Apps" ],
            DirectoryQ,
            "AssetsDir"
        ];
        htmlFiles = FileNames[ "*.html", assetsDir ];
        $uiResourceRegistry = Association[
            loadUIResource /@ htmlFiles
        ];
        debugPrint[ "Loaded " <> ToString[ Length @ htmlFiles ] <> " UI resources" ];
    ],
    (
        (* Graceful fallback: no UI resources. Log the error but do not fail startup. *)
        writeError[ "Failed to load UI app assets. MCP Apps will be disabled." ];
        $uiResourceRegistry = <| |>
    ) &
];

initializeUIResources // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*loadUIResource*)
loadUIResource // beginDefinition;

loadUIResource[ htmlFile_String ] := Enclose[
    Module[ { baseName, uri, html, metaFile, meta },
        baseName = FileBaseName @ htmlFile;
        uri = "ui://wolfram/" <> baseName;
        html = ConfirmBy[ ByteArrayToString @ ReadByteArray @ htmlFile, StringQ, "HTML" ];
        metaFile = FileNameJoin[ { DirectoryName @ htmlFile, baseName <> ".json" } ];
        meta = If[ FileExistsQ @ metaFile,
            Quiet @ Developer`ReadRawJSONString @ ByteArrayToString @ ReadByteArray @ metaFile,
            <| |>
        ];
        uri -> <|
            "uri"      -> uri,
            "name"     -> baseName,
            "mimeType" -> "text/html;profile=mcp-app",
            "html"     -> html,
            "meta"     -> Replace[ meta, Except[ _Association ] :> <| |> ]
        |>
    ],
    throwInternalFailure
];

loadUIResource // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*listUIResources*)
listUIResources // beginDefinition;

listUIResources[ ] :=
    If[ TrueQ @ $clientSupportsUI,
        KeyValueMap[
            Function[ { uri, data },
                <|
                    "uri"         -> uri,
                    "name"        -> data[ "name" ],
                    "description" -> Lookup[ data, "description", "" ],
                    "mimeType"    -> data[ "mimeType" ]
                |>
            ],
            $uiResourceRegistry
        ],
        { }
    ];

listUIResources // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*readUIResource*)
readUIResource // beginDefinition;

readUIResource[ msg_Association, req_ ] := Enclose[
    Module[ { uri },
        uri = ConfirmBy[ msg[[ "params", "uri" ]], StringQ, "URI" ];
        (* Notebook-url resolution requests (the "dropped _meta" workaround) are handled
           separately; everything else is a registered HTML app resource. *)
        If[ StringStartsQ[ uri, $notebookURLResourcePrefix ],
            readNotebookURLResource @ uri,
            readRegisteredUIResource @ uri
        ]
    ],
    throwInternalFailure
];

readUIResource // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*readRegisteredUIResource*)
readRegisteredUIResource // beginDefinition;

readRegisteredUIResource[ uri_String ] :=
    Module[ { resource },
        resource = Lookup[ $uiResourceRegistry, uri, Missing[ "NotFound" ] ];
        If[ MissingQ @ resource,
            throwFailure[ "UIResourceNotFound", uri ],
            <| "contents" -> {
                <|
                    "uri"      -> resource[ "uri" ],
                    "mimeType" -> resource[ "mimeType" ],
                    "text"     -> resource[ "html" ],
                    "_meta"    -> resource[ "meta" ]
                |>
            } |>
        ]
    ];

readRegisteredUIResource // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*readNotebookURLResource*)
(* Reconstructs the full cloud notebook URL from the hex id embedded in the URI and returns it
   as the resource text. The text payload of a resource is not stripped by hosts (unlike _meta),
   so this is how the workaround gets the URL to the app. *)
readNotebookURLResource // beginDefinition;

readNotebookURLResource[ uri_String ] := Enclose[
    Module[ { id, url },
        id = notebookIDFromResourceURI @ uri;
        (* Restrict to hex ids: keeps arbitrary path segments out of the reconstructed
           CloudObject and treats anything else as an unknown resource. *)
        If[ notebookIDStringQ @ id,
            url = ConfirmBy[ resolveNotebookURLFromID @ id, StringQ, "URL" ];
            <| "contents" -> { <| "uri" -> uri, "mimeType" -> "text/plain", "text" -> url |> } |>,
            (* else: not a valid notebook id *)
            throwFailure[ "UIResourceNotFound", uri ]
        ]
    ],
    throwInternalFailure
];

readNotebookURLResource // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*notebookIDFromResourceURI*)
notebookIDFromResourceURI // beginDefinition;
notebookIDFromResourceURI[ uri_String ] := StringDelete[ uri, StartOfString ~~ $notebookURLResourcePrefix ];
notebookIDFromResourceURI // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*notebookIDStringQ*)
notebookIDStringQ // beginDefinition;
notebookIDStringQ[ id_String ] := StringLength @ id > 0 && StringMatchQ[ id, HexadecimalCharacter.. ];
notebookIDStringQ[ _ ] := False;
notebookIDStringQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*resolveNotebookURLFromID*)
(* Deterministically rebuilds the deployed URL from its base name; this is the exact inverse of
   notebookIDFromURL and matches what CloudDeploy returned for the same target (verified: the
   CloudObject URL is constructed locally from the base name and the user's cloud path). *)
resolveNotebookURLFromID // beginDefinition;

resolveNotebookURLFromID[ id_String ] := Enclose[
    ConfirmBy[
        First @ CloudObject @ FileNameJoin @ { CloudObject @ $deployedNotebookRoot, id <> ".nb" },
        StringQ,
        "URL"
    ],
    throwInternalFailure
];

resolveNotebookURLFromID // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*toolUIMetadata*)
toolUIMetadata // beginDefinition;

toolUIMetadata[ toolName_String ] :=
    If[ TrueQ @ $clientSupportsUI,
        toolUIMetadata[ toolName, Lookup[ $toolUIAssociations, toolName, None ] ],
        { }
    ];

toolUIMetadata[ toolName_String, uri_String ] :=
    { "_meta" -> <| "ui" -> <| "resourceUri" -> uri, "visibility" -> { "model", "app" } |> |> };

toolUIMetadata[ toolName_String, None ] := { };

toolUIMetadata // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*withToolUIMetadata*)
withToolUIMetadata // beginDefinition;

withToolUIMetadata[ tools_List ] :=
    Map[
        Function[ tool, Join[ tool, Association @ toolUIMetadata[ tool[ "name" ] ] ] ],
        tools
    ];

withToolUIMetadata // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
addToMXInitialization[
    Null
];

End[ ];
EndPackage[ ];
