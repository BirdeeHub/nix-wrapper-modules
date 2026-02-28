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
  argv0 =
    if builtins.isString (config.argv0 or null) then
      [
        "--argv0"
        (lib.escapeShellArg config.argv0)
      ]
    else if config.argv0type or null == "resolve" then
      [ "--resolve-argv0" ]
    else
      [ "--inherit-argv0" ];
  baseArgs = map lib.escapeShellArg [
    (
      if !builtins.isString (config.exePath or null) || config.exePath == "" then
        "${config.package}"
      else
        "${config.package}/${config.exePath}"
    )
    "${placeholder "out"}/${config.binDir or "bin"}/${config.binName}"
  ];
  split = wlib.makeWrapper.splitDal (wlib.makeWrapper.aggregateSingleOptionSet { inherit config; });
  cliArgs = lib.pipe split.args [
    (wlib.makeWrapper.fixArgs { sep = config.flagSeparator or null; })
    (
      { addFlag, appendFlag }:
      let
        mapArgs =
          name:
          lib.flip lib.pipe [
            (map (
              v:
              let
                esc-fn = if v.esc-fn or null != null then v.esc-fn else config.escapingFunction;
              in
              if builtins.isList (v.data or null) then
                map esc-fn v.data
              else if v ? data && v.data or null != null then
                esc-fn v.data
              else
                [ ]
            ))
            lib.flatten
            (builtins.concatMap (v: [
              "--${name}"
              v
            ]))
          ];
      in
      mapArgs "add-flag" addFlag ++ mapArgs "append-flag" appendFlag
    )
  ];

  makeWrapperArgs = lib.pipe split.other [
    (builtins.concatMap (
      v:
      let
        esc-fn = if v.esc-fn or null != null then v.esc-fn else config.escapingFunction;
        esc-list = map esc-fn;
      in
      if v.type or null == "unsetVar" then
        [ "--unset" ] ++ [ (esc-fn v.data) ]
      else if v.type or null == "env" then
        [ "--set" ]
        ++ esc-list [
          v.attr-name
          v.data
        ]
      else if v.type or null == "envDefault" then
        [ "--set-default" ]
        ++ esc-list [
          v.attr-name
          v.data
        ]
      else if v.type or null == "prefixVar" then
        [ "--prefix" ] ++ esc-list v.data
      else if v.type or null == "suffixVar" then
        [ "--suffix" ] ++ esc-list v.data
      else if v.type or null == "chdir" then
        [ "--chdir" ] ++ [ (esc-fn v.data) ]
      else if config.wrapperImplementation or null != "binary" then
        if v.type or null == "prefixContent" then
          [ "--prefix-contents" ] ++ esc-list v.data
        else if v.type or null == "suffixContent" then
          [ "--suffix-contents" ] ++ esc-list v.data
        else if v.type or null == "runShell" then
          [ "--run" ] ++ [ (esc-fn v.data) ]
        else
          [ ]
      else
        [ ]
    ))
    (res: baseArgs ++ argv0 ++ cliArgs ++ res)
    (builtins.concatStringsSep " ")
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
      OLD_OPTS="$(set +o)"
      ${srcsetup dieHook}
      ${srcsetup (
        if config.wrapperImplementation or null != "binary" then makeWrapper else makeBinaryWrapper
      )}
      eval "$OLD_OPTS"
      makeWrapper ${makeWrapperArgs}
    )
  ''
