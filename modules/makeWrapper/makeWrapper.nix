{
  config,
  wlib,
  lib,
  makeWrapper,
  makeBinaryWrapper,
  dieHook,
  ...
}:
let
  generateArgsFromFlags = (import ./genArgsFromFlags.nix { inherit lib wlib; }).genArgs flaggenfunc;
  flaggenfunc =
    is_list: flagSeparator: name: value:
    if !is_list && (value == false || value == null) then
      [ ]
    else if !is_list && value == true then
      [
        "--add-flag"
        name
      ]
    else if lib.trim flagSeparator == "" && flagSeparator != "" then
      [
        "--add-flag"
        name
        "--add-flag"
        (toString value)
      ]
    else
      [
        "--add-flag"
        "${name}${flagSeparator}${toString value}"
      ];

  argv0 = [
    (
      if builtins.isString (config.argv0 or null) then
        {
          data = [
            "--argv0"
            config.argv0
          ];
        }
      else if config.argv0type or null == "resolve" then
        { data = [ "--resolve-argv0" ]; }
      else
        { data = [ "--inherit-argv0" ]; }
    )
  ];
  envVarsDefault = lib.optionals (config.envDefault or { } != { }) (
    wlib.dag.mapDagToDal (n: v: [
      "--set-default"
      n
      (toString v)
    ]) config.envDefault
  );
  envVars = lib.optionals (config.env or { } != { }) (
    wlib.dag.mapDagToDal (n: v: [
      "--set"
      n
      (toString v)
    ]) config.env
  );
  flags = lib.optionals (config.flags or { } != { }) (
    generateArgsFromFlags (config.flagSeparator or " ") config.flags
  );
  mapargs =
    n: argname: single:
    wlib.dag.lmap (
      v:
      if builtins.isList v then
        if single then
          lib.concatMap (val: [
            "--${argname}"
            (toString val)
          ]) v
        else
          [ "--${argname}" ] ++ v
      else
        [
          "--${argname}"
          (toString v)
        ]
    ) (config.${n} or [ ]);

  other =
    mapargs "unsetVar" "unset" true
    ++ mapargs "chdir" "chdir" true
    ++ mapargs "prefixVar" "prefix" false
    ++ mapargs "suffixVar" "suffix" false;
  conditionals =
    if config.wrapperImplementation or null != "binary" then
      mapargs "runShell" "run" true
      ++ mapargs "prefixContent" "prefix-contents" false
      ++ mapargs "suffixContent" "suffix-contents" false
    else
      [ ];

  finalArgs =
    argv0
    ++ flags
    ++ mapargs "addFlag" "add-flag" true
    ++ mapargs "appendFlag" "append-flag" true
    ++ envVars
    ++ envVarsDefault
    ++ other
    ++ conditionals;

  baseArgs = lib.escapeShellArgs [
    (
      if !builtins.isString (config.exePath or null) || config.exePath == "" then
        "${config.package}"
      else
        "${config.package}/${config.exePath}"
    )
    "${placeholder "out"}/bin/${config.binName}"
  ];
  resArgs = lib.pipe finalArgs [
    (wlib.dag.unwrapSort "makeWrapper")
    (map (
      v:
      let
        esc-fn =
          if v.esc-fn or null != null then v.esc-fn else (config.escapingFunction or lib.escapeShellArg);
      in
      if builtins.isList v.data then map esc-fn v.data else esc-fn v.data
    ))
    lib.flatten
  ];

  srcsetup = p: "source ${lib.escapeShellArg "${p}/nix-support/setup-hook"}";
in
if
  !builtins.isString (config.binName or null)
  || config.binName == ""
  || !(lib.isStringLike (config.package or null))
then
  ""
else
  ''
    (
      ${srcsetup dieHook}
      ${srcsetup (
        if config.wrapperImplementation or null == "shell" then makeWrapper else makeBinaryWrapper
      )}
      makeWrapper ${baseArgs} ${builtins.concatStringsSep " " resArgs}
    )
  ''
