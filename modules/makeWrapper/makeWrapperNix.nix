{
  config,
  wlib,
  lib,
  bash,
  ...
}:
let
  arg0 = if config.argv0 == null then "\"$0\"" else config.escapingFunction config.argv0;
  generateArgsFromFlags =
    flagSeparator:
    wlib.dag.mapDagToDal (
      name: value:
      if value == false || value == null then
        [ ]
      else if value == true then
        [
          name
        ]
      else if lib.isList value then
        lib.concatMap (
          v:
          if lib.trim flagSeparator == "" then
            [
              name
              (toString v)
            ]
          else
            [
              "${name}${flagSeparator}${toString v}"
            ]
        ) value
      else if lib.trim flagSeparator == "" then
        [
          name
          (toString value)
        ]
      else
        [
          "${name}${flagSeparator}${toString value}"
        ]
    );
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

  shellcmdsdal =
    wlib.dag.lmap (
      var: esc-fn:
      let
        cmd = "unset ${esc-fn var}";
      in
      "echo ${lib.escapeShellArg cmd} >> $out/bin/${config.binName}"
    ) config.unsetVar
    ++ wlib.dag.mapDagToDal (
      n: v: esc-fn:
      let
        cmd = "wrapperSetEnv ${esc-fn n} ${esc-fn v}";
      in
      "echo ${lib.escapeShellArg cmd} >> $out/bin/${config.binName}"
    ) config.env
    ++ wlib.dag.mapDagToDal (
      n: v: esc-fn:
      let
        cmd = "wrapperSetEnvDefault ${esc-fn n} ${esc-fn v}";
      in
      "echo ${lib.escapeShellArg cmd} >> $out/bin/${config.binName}"
    ) config.envDefault
    ++ wlib.dag.lmap (
      tuple:
      with builtins;
      esc-fn:
      let
        env = elemAt tuple 0;
        sep = elemAt tuple 1;
        val = elemAt tuple 2;
        cmd = "wrapperPrefixEnv ${esc-fn env} ${esc-fn sep} ${esc-fn val}";
      in
      "echo ${lib.escapeShellArg cmd} >> $out/bin/${config.binName}"
    ) config.prefixVar
    ++ wlib.dag.lmap (
      tuple:
      with builtins;
      esc-fn:
      let
        env = elemAt tuple 0;
        sep = elemAt tuple 1;
        val = elemAt tuple 2;
        cmd = "wrapperSuffixEnv ${esc-fn env} ${esc-fn sep} ${esc-fn val}";
      in
      "echo ${lib.escapeShellArg cmd} >> $out/bin/${config.binName}"
    ) config.suffixVar
    ++ wlib.dag.lmap (
      tuple:
      with builtins;
      esc-fn:
      let
        env = elemAt tuple 0;
        sep = elemAt tuple 1;
        val = elemAt tuple 2;
        cmd = "wrapperPrefixEnv ${esc-fn env} ${esc-fn sep} ";
      in
      ''echo ${lib.escapeShellArg cmd}"$(cat ${esc-fn val})" >> $out/bin/${config.binName}''
    ) config.prefixContent
    ++ wlib.dag.lmap (
      tuple:
      with builtins;
      esc-fn:
      let
        env = elemAt tuple 0;
        sep = elemAt tuple 1;
        val = elemAt tuple 2;
        cmd = "wrapperSuffixEnv ${esc-fn env} ${esc-fn sep} ";
      in
      ''echo ${lib.escapeShellArg cmd}"$(cat ${esc-fn val})" >> $out/bin/${config.binName}''
    ) config.suffixContent
    ++ wlib.dag.lmap (
      dir: esc-fn: "echo ${lib.escapeShellArg "cd ${esc-fn dir}"} >> $out/bin/${config.binName}"
    ) config.chdir
    ++ wlib.dag.lmap (
      cmd: _: "echo ${lib.escapeShellArg cmd} >> $out/bin/${config.binName}"
    ) config.runShell;

  shellcmds = lib.optionals (shellcmdsdal != [ ]) (
    wlib.dag.sortAndUnwrap {
      dag = shellcmdsdal;
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
    ++ lib.optional (config.prefixVar != [ ] || config.suffixContent != [ ]) prefixvarfunc
    ++ lib.optional (config.suffixVar != [ ] || config.suffixContent != [ ]) suffixvarfunc;
  execcmd = ''
    exec -a ${arg0} ${
      if config.exePath == "" then "${config.package}" else "${config.package}/${config.exePath}"
    } ${preFlagStr} "$@" ${postFlagStr}
  '';
in
''
  mkdir -p $out/bin
  echo ${lib.escapeShellArg "#!${bash}/bin/bash"} > $out/bin/${config.binName}
  echo ${lib.escapeShellArg (builtins.concatStringsSep "\n" prefuncs)} >> $out/bin/${config.binName}
  ${builtins.concatStringsSep "\n" shellcmds}
  echo ${lib.escapeShellArg execcmd} >> $out/bin/${config.binName}
  chmod +x $out/bin/${config.binName}
''
