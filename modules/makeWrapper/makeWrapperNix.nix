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
    flagSeparator: dag_flags:
    wlib.dag.sortAndUnwrap {
      dag = (
        wlib.dag.gmap (
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
        ) dag_flags
      );
    };
  preFlagStr = builtins.concatStringsSep " " (
    wlib.dag.sortAndUnwrap {
      dag =
        lib.optionals (config.addFlag != [ ]) config.addFlag
        ++ lib.optionals (config.flags != { }) (
          generateArgsFromFlags (config.flagSeparator or " ") config.flags
        );
      mapIfOk =
        v:
        if builtins.isList v.data then
          builtins.concatStringsSep " " (map config.escapingFunction v.data)
        else
          config.escapingFunction v.data;
    }
  );
  postFlagStr = builtins.concatStringsSep " " (
    wlib.dag.sortAndUnwrap {
      dag = config.appendFlag;
      mapIfOk =
        v:
        if builtins.isList v.data then
          builtins.concatStringsSep " " (map config.escapingFunction v.data)
        else
          config.escapingFunction v.data;
    }
  );

  shellcmdsdal =
    wlib.dag.lmap (
      var:
      let
        cmd = "unset ${config.escapingFunction var}";
      in
      "echo ${lib.escapeShellArg cmd} >> $out/bin/${config.binName}"
    ) config.unsetVar
    ++ wlib.dag.sortAndUnwrap {
      dag = wlib.dag.gmap (
        n: v:
        let
          cmd = "wrapperSetEnv ${config.escapingFunction n} ${config.escapingFunction v}";
        in
        "echo ${lib.escapeShellArg cmd} >> $out/bin/${config.binName}"
      ) config.env;
    }
    ++ wlib.dag.sortAndUnwrap {
      dag = wlib.dag.gmap (
        n: v:
        let
          cmd = "wrapperSetEnvDefault ${config.escapingFunction n} ${config.escapingFunction v}";
        in
        "echo ${lib.escapeShellArg cmd} >> $out/bin/${config.binName}"
      ) config.envDefault;
    }
    ++ wlib.dag.lmap (
      tuple:
      with builtins;
      let
        env = elemAt tuple 0;
        sep = elemAt tuple 1;
        val = elemAt tuple 2;
        cmd = "wrapperPrefixEnv ${config.escapingFunction env} ${config.escapingFunction sep} ${config.escapingFunction val}";
      in
      "echo ${lib.escapeShellArg cmd} >> $out/bin/${config.binName}"
    ) config.prefixVar
    ++ wlib.dag.lmap (
      tuple:
      with builtins;
      let
        env = elemAt tuple 0;
        sep = elemAt tuple 1;
        val = elemAt tuple 2;
        cmd = "wrapperSuffixEnv ${config.escapingFunction env} ${config.escapingFunction sep} ${config.escapingFunction val}";
      in
      "echo ${lib.escapeShellArg cmd} >> $out/bin/${config.binName}"
    ) config.suffixVar
    ++ wlib.dag.lmap (
      tuple:
      with builtins;
      let
        env = elemAt tuple 0;
        sep = elemAt tuple 1;
        val = elemAt tuple 2;
        cmd = "wrapperPrefixEnv ${config.escapingFunction env} ${config.escapingFunction sep} ";
      in
      ''echo ${lib.escapeShellArg cmd}"$(cat ${config.escapingFunction val})" >> $out/bin/${config.binName}''
    ) config.prefixContent
    ++ wlib.dag.lmap (
      tuple:
      with builtins;
      let
        env = elemAt tuple 0;
        sep = elemAt tuple 1;
        val = elemAt tuple 2;
        cmd = "wrapperSuffixEnv ${config.escapingFunction env} ${config.escapingFunction sep} ";
      in
      ''echo ${lib.escapeShellArg cmd}"$(cat ${config.escapingFunction val})" >> $out/bin/${config.binName}''
    ) config.suffixContent
    ++ wlib.dag.lmap (
      dir: "echo ${lib.escapeShellArg "cd ${config.escapingFunction dir}"} >> $out/bin/${config.binName}"
    ) config.chdir
    ++ wlib.dag.lmap (
      cmd: "echo ${lib.escapeShellArg cmd} >> $out/bin/${config.binName}"
    ) config.runShell;

  shellcmds = lib.optionals (shellcmdsdal != [ ]) (
    wlib.dag.sortAndUnwrap {
      dag = shellcmdsdal;
      mapIfOk = v: v.data;
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
