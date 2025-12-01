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
      dag =
        lib.optionals (config.addFlag != [ ]) config.addFlag
        ++ lib.optionals (config.flags != { }) (
          generateArgsFromFlags (config.flagSeparator or " ") config.flags
        );
      mapIfOk =
        v:
        let
          esc-fn = if v.esc-fn or null != null then v.esc-fn else config.escapingFunction;
        in
        if builtins.isList v.data then builtins.concatStringsSep " " (map esc-fn v.data) else esc-fn v.data;
    }
  );
  postFlagStr = builtins.concatStringsSep " " (
    wlib.dag.sortAndUnwrap {
      dag = config.appendFlag;
      mapIfOk =
        v:
        let
          esc-fn = if v.esc-fn or null != null then v.esc-fn else config.escapingFunction;
        in
        if builtins.isList v.data then builtins.concatStringsSep " " (map esc-fn v.data) else esc-fn v.data;
    }
  );

  wrapcmd = partial: ''
    echo ${lib.escapeShellArg partial} >> $out/bin/${config.binName}
  '';
  shellcmdsdal =
    wlib.dag.lmap (var: esc-fn: wrapcmd "unset ${esc-fn var}") config.unsetVar
    ++ wlib.dag.mapDagToDal (
      n: v: esc-fn:
      wrapcmd "wrapperSetEnv ${esc-fn n} ${esc-fn v}"
    ) config.env
    ++ wlib.dag.mapDagToDal (
      n: v: esc-fn:
      wrapcmd "wrapperSetEnvDefault ${esc-fn n} ${esc-fn v}"
    ) config.envDefault
    ++ wlib.dag.lmap (
      tuple: esc-fn:
      let
        env = elemAt tuple 0;
        sep = elemAt tuple 1;
        val = elemAt tuple 2;
      in
      wrapcmd "wrapperPrefixEnv ${esc-fn env} ${esc-fn sep} ${esc-fn val}"
    ) config.prefixVar
    ++ wlib.dag.lmap (
      tuple: esc-fn:
      let
        env = elemAt tuple 0;
        sep = elemAt tuple 1;
        val = elemAt tuple 2;
      in
      wrapcmd "wrapperSuffixEnv ${esc-fn env} ${esc-fn sep} ${esc-fn val}"
    ) config.suffixVar
    ++ wlib.dag.lmap (
      tuple: esc-fn:
      let
        env = elemAt tuple 0;
        sep = elemAt tuple 1;
        val = elemAt tuple 2;
        cmd = "wrapperPrefixEnv ${esc-fn env} ${esc-fn sep} ";
      in
      ''echo ${lib.escapeShellArg cmd}"$(cat ${esc-fn val})" >> $out/bin/${config.binName}''
    ) config.prefixContent
    ++ wlib.dag.lmap (
      tuple: esc-fn:
      let
        env = elemAt tuple 0;
        sep = elemAt tuple 1;
        val = elemAt tuple 2;
        cmd = "wrapperSuffixEnv ${esc-fn env} ${esc-fn sep} ";
      in
      ''echo ${lib.escapeShellArg cmd}"$(cat ${esc-fn val})" >> $out/bin/${config.binName}''
    ) config.suffixContent
    ++ wlib.dag.lmap (dir: esc-fn: wrapcmd "cd ${esc-fn dir}") config.chdir
    ++ wlib.dag.lmap (cmd: _: wrapcmd cmd) config.runShell;

  arg0 = if config.argv0 == null then "\"$0\"" else config.escapingFunction config.argv0;
  finalcmd = ''${
    if config.exePath == "" then "${config.package}" else "${config.package}/${config.exePath}"
  } ${preFlagStr} "$@" ${postFlagStr}'';

  shellcmds = lib.optionals (shellcmdsdal != [ ]) (
    wlib.dag.sortAndUnwrap {
      dag =
        shellcmdsdal
        ++ lib.optional (lib.isFunction config.argv0type) {
          name = "NIX_RUN_MAIN_PACKAGE";
          data = _: (wrapcmd (config.argv0type finalcmd));
        };
      mapIfOk = v: v.data (if (v.esc-fn or null) != null then v.esc-fn else config.escapingFunction);
    }
  );

  setvarfunc = /* bash */ ''wrapperSetEnv() { export "$1=$2"; }'';
  setvardefaultfunc = /* bash */ ''wrapperSetEnvDefault() { [ -z "''${!1+x}" ] && export "$1=$2"; }'';
  prefixvarfunc = /* bash */ ''wrapperPrefixEnv() { export "$1=''${!1:+$3$2}''${!1:-$3}"; }'';
  suffixvarfunc = /* bash */ ''wrapperSuffixEnv() { export "$1=''${!1:+''${!1}$2}$3"; }'';
  prefuncs =
    lib.optional (config.env != { }) setvarfunc
    ++ lib.optional (config.envDefault != { }) setvardefaultfunc
    ++ lib.optional (config.prefixVar != [ ] || config.prefixContent != [ ]) prefixvarfunc
    ++ lib.optional (config.suffixVar != [ ] || config.suffixContent != [ ]) suffixvarfunc;
in
''
  mkdir -p $out/bin
  echo ${lib.escapeShellArg "#!${bash}/bin/bash"} > $out/bin/${config.binName}
  ${wrapcmd (builtins.concatStringsSep "\n" prefuncs)}
  ${builtins.concatStringsSep "\n" shellcmds}
  ${lib.optionalString (!lib.isFunction config.argv0type) (wrapcmd "exec -a ${arg0} ${finalcmd}")}
  chmod +x $out/bin/${config.binName}
''
