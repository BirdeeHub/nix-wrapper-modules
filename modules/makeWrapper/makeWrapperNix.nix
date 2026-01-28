{
  config,
  wlib,
  lib,
  bash,
  ...
}:
let
  inherit (builtins) elemAt;
  generateArgsFromFlags = (import ./genArgsFromFlags.nix { inherit lib wlib; }).genArgs flaggenfunc;
  flaggenfunc =
    is_list: flagSeparator: name: value:
    if !is_list && (value == false || value == null) then
      [ ]
    else if !is_list && value == true then
      [
        name
      ]
    else if lib.trim flagSeparator == "" && flagSeparator != "" then
      [
        name
        (toString value)
      ]
    else
      [
        "${name}${flagSeparator}${toString value}"
      ];

  preFlagStr = builtins.concatStringsSep " " (
    wlib.dag.sortAndUnwrap {
      name = "addFlag";
      dag =
        lib.optionals (config.flags or { } != { }) (
          generateArgsFromFlags (config.flagSeparator or " ") config.flags
        )
        ++ lib.optionals (config.addFlag or { } != [ ]) config.addFlag;
      mapIfOk =
        v:
        let
          esc-fn =
            if v.esc-fn or null != null then v.esc-fn else (config.escapingFunction or lib.escapeShellArg);
        in
        if builtins.isList v.data then builtins.concatStringsSep " " (map esc-fn v.data) else esc-fn v.data;
    }
  );
  postFlagStr = builtins.concatStringsSep " " (
    wlib.dag.sortAndUnwrap {
      name = "appendFlag";
      dag = (config.appendFlag or [ ]);
      mapIfOk =
        v:
        let
          esc-fn =
            if v.esc-fn or null != null then v.esc-fn else (config.escapingFunction or lib.escapeShellArg);
        in
        if builtins.isList v.data then builtins.concatStringsSep " " (map esc-fn v.data) else esc-fn v.data;
    }
  );

  wrapcmd = partial: ''
    echo ${lib.escapeShellArg partial} >> $out/bin/${config.binName}
  '';
  shellcmdsdal =
    wlib.dag.lmap (var: esc-fn: wrapcmd "unset ${esc-fn var}") (config.unsetVar or [ ])
    ++ wlib.dag.mapDagToDal (
      n: v: esc-fn:
      wrapcmd "wrapperSetEnv ${esc-fn n} ${esc-fn v}"
    ) (config.env or { })
    ++ wlib.dag.mapDagToDal (
      n: v: esc-fn:
      wrapcmd "wrapperSetEnvDefault ${esc-fn n} ${esc-fn v}"
    ) (config.envDefault or { })
    ++ wlib.dag.lmap (
      tuple: esc-fn:
      let
        env = elemAt tuple 0;
        sep = elemAt tuple 1;
        val = elemAt tuple 2;
      in
      wrapcmd "wrapperPrefixEnv ${esc-fn env} ${esc-fn sep} ${esc-fn val}"
    ) (config.prefixVar or [ ])
    ++ wlib.dag.lmap (
      tuple: esc-fn:
      let
        env = elemAt tuple 0;
        sep = elemAt tuple 1;
        val = elemAt tuple 2;
      in
      wrapcmd "wrapperSuffixEnv ${esc-fn env} ${esc-fn sep} ${esc-fn val}"
    ) (config.suffixVar or [ ])
    ++ wlib.dag.lmap (
      tuple: esc-fn:
      let
        env = elemAt tuple 0;
        sep = elemAt tuple 1;
        val = elemAt tuple 2;
        cmd = "wrapperPrefixEnv ${esc-fn env} ${esc-fn sep} ";
      in
      ''echo ${lib.escapeShellArg cmd}"$(cat ${esc-fn val})" >> $out/bin/${config.binName}''
    ) (config.prefixContent or [ ])
    ++ wlib.dag.lmap (
      tuple: esc-fn:
      let
        env = elemAt tuple 0;
        sep = elemAt tuple 1;
        val = elemAt tuple 2;
        cmd = "wrapperSuffixEnv ${esc-fn env} ${esc-fn sep} ";
      in
      ''echo ${lib.escapeShellArg cmd}"$(cat ${esc-fn val})" >> $out/bin/${config.binName}''
    ) (config.suffixContent or [ ])
    ++ wlib.dag.lmap (dir: esc-fn: wrapcmd "cd ${esc-fn dir}") (config.chdir or [ ])
    ++ wlib.dag.lmap (cmd: _: wrapcmd cmd) (config.runShell or [ ]);

  arg0 =
    if builtins.isString (config.argv0 or null) then
      (config.escapingFunction or lib.escapeShellArg) config.argv0
    else
      "\"$0\"";
  finalcmd = ''${
    if !builtins.isString (config.exePath or null) || config.exePath == "" then
      "${config.package}"
    else
      "${config.package}/${config.exePath}"
  } ${preFlagStr} "$@" ${postFlagStr}'';

  shellcmds = lib.optionals (shellcmdsdal != [ ] || lib.isFunction (config.argv0type or null)) (
    wlib.dag.sortAndUnwrap {
      name = "makeWrapperNix";
      dag =
        shellcmdsdal
        ++ lib.optional (lib.isFunction (config.argv0type or null)) {
          name = "NIX_RUN_MAIN_PACKAGE";
          data = _: wrapcmd (config.argv0type finalcmd);
        };
      mapIfOk =
        v:
        v.data (
          if (v.esc-fn or null) != null then v.esc-fn else (config.escapingFunction or lib.escapeShellArg)
        );
    }
  );

  setvarfunc = /* bash */ ''wrapperSetEnv() { export "$1=$2"; }'';
  setvardefaultfunc = /* bash */ ''wrapperSetEnvDefault() { [ -z "''${!1+x}" ] && export "$1=$2"; }'';
  prefixvarfunc = /* bash */ ''wrapperPrefixEnv() { export "$1=''${!1:+$3$2}''${!1:-$3}"; }'';
  suffixvarfunc = /* bash */ ''wrapperSuffixEnv() { export "$1=''${!1:+''${!1}$2}$3"; }'';
  prefuncs =
    lib.optional (config.env or { } != { }) setvarfunc
    ++ lib.optional (config.envDefault or { } != { }) setvardefaultfunc
    ++ lib.optional (config.prefixVar or [ ] != [ ] || config.prefixContent or [ ] != [ ]) prefixvarfunc
    ++ lib.optional (
      config.suffixVar or [ ] != [ ] || config.suffixContent or [ ] != [ ]
    ) suffixvarfunc;
in
if
  !builtins.isString (config.binName or null)
  || config.binName == ""
  || !(lib.isStringLike (config.package or null))
then
  ""
else
  ''
    mkdir -p $out/bin
    echo ${lib.escapeShellArg "#!${bash}/bin/bash"} > $out/bin/${config.binName}
    ${wrapcmd (builtins.concatStringsSep "\n" prefuncs)}
    ${builtins.concatStringsSep "\n" shellcmds}
    ${lib.optionalString (!lib.isFunction (config.argv0type or null)) (
      wrapcmd "exec -a ${arg0} ${finalcmd}"
    )}
    chmod +x $out/bin/${config.binName}
  ''
