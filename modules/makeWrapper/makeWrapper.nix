{
  config,
  wlib,
  lib,
  ...
}:
let
  generateArgsFromFlags =
    flagSeparator:
    wlib.dag.mapDagToDal (
      name: value:
      if value == false || value == null then
        [ ]
      else if value == true then
        [
          "--add-flag"
          name
        ]
      else if lib.isList value then
        lib.concatMap (
          v:
          if lib.trim flagSeparator == "" then
            [
              "--add-flag"
              name
              "--add-flag"
              (toString v)
            ]
          else
            [
              "--add-flag"
              "${name}${flagSeparator}${toString v}"
            ]
        ) value
      else if lib.trim flagSeparator == "" then
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
        ]
    );

  argv0 = [
    (
      if builtins.isString config.argv0 then
        {
          data = [
            "--argv0"
            config.argv0
          ];
        }
      else if config.argv0type == "resolve" then
        { data = [ "--resolve-argv0" ]; }
      else
        { data = [ "--inherit-argv0" ]; }
    )
  ];
  envVarsDefault = lib.optionals (config.envDefault != { }) (
    wlib.dag.mapDagToDal (n: v: [
      "--set-default"
      n
      (toString v)
    ]) config.envDefault
  );
  envVars = lib.optionals (config.env != { }) (
    wlib.dag.mapDagToDal (n: v: [
      "--set"
      n
      (toString v)
    ]) config.env
  );
  flags = lib.optionals (config.flags != { }) (
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
    ) config.${n};

  other =
    mapargs "unsetVar" "unset" true
    ++ mapargs "chdir" "chdir" true
    ++ mapargs "prefixVar" "prefix" false
    ++ mapargs "suffixVar" "suffix" false;
  conditionals =
    if config.wrapperImplementation != "binary" then
      mapargs "runShell" "run" true
      ++ mapargs "prefixContent" "prefix-contents" false
      ++ mapargs "suffixContent" "suffix-contents" false
    else
      [ ];

  finalArgs =
    argv0
    ++ mapargs "addFlag" "add-flag" true
    ++ flags
    ++ mapargs "appendFlag" "append-flag" true
    ++ envVars
    ++ envVarsDefault
    ++ other
    ++ conditionals;

  baseArgs = lib.escapeShellArgs [
    (if config.exePath == "" then "${config.package}" else "${config.package}/${config.exePath}")
    "${placeholder "out"}/bin/${config.binName}"
  ];
  resArgs = lib.pipe finalArgs [
    (
      dag:
      wlib.dag.sortAndUnwrap {
        inherit dag;
        mapIfOk =
          v:
          let
            esc-fn = if v.esc-fn or null != null then v.esc-fn else config.escapingFunction;
          in
          if builtins.isList v.data then map esc-fn v.data else esc-fn v.data;
      }
    )
    lib.flatten
  ];
in
if config.binName == "" then
  ""
else
  "makeWrapper ${baseArgs} ${builtins.concatStringsSep " " resArgs}"
