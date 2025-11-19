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
    wlib.dag.lmap (var: "unset ${config.escapingFunction var}") config.unsetVar
    ++ wlib.dag.sortAndUnwrap {
      dag = wlib.dag.gmap (
        n: v: "wrapperSetEnv ${config.escapingFunction n} ${config.escapingFunction v}"
      ) config.env;
    }
    ++ wlib.dag.sortAndUnwrap {
      dag = wlib.dag.gmap (
        n: v: ''wrapperSetEnvDefault ${config.escapingFunction n} ${config.escapingFunction v}''
      ) config.envDefault;
    }
    ++ wlib.dag.lmap (
      tuple:
      with builtins;
      let
        env = elemAt tuple 0;
        sep = elemAt tuple 1;
        val = elemAt tuple 2;
      in
      "wrapperPrefixEnv ${config.escapingFunction env} ${config.escapingFunction sep} ${config.escapingFunction val}"
    ) config.prefixVar
    ++ wlib.dag.lmap (
      tuple:
      with builtins;
      let
        env = elemAt tuple 0;
        sep = elemAt tuple 1;
        val = elemAt tuple 2;
      in
      "wrapperSuffixEnv ${config.escapingFunction env} ${config.escapingFunction sep} ${config.escapingFunction val}"
    ) config.suffixVar
    ++ config.runShell;

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
    ++ lib.optional (config.prefixVar != [ ]) prefixvarfunc
    ++ lib.optional (config.suffixVar != [ ]) suffixvarfunc;
  wrapstr = ''
    #!${bash}/bin/bash
    ${builtins.concatStringsSep "\n" prefuncs}
    ${builtins.concatStringsSep "\n" shellcmds}
    exec -a ${arg0} ${
      if config.exePath == "" then "${config.package}" else "${config.package}/${config.exePath}"
    } ${preFlagStr} "$@" ${postFlagStr}
  '';
in
''
  mkdir -p $out/bin
  echo ${lib.escapeShellArg wrapstr} > $out/bin/${config.binName}
  chmod +x $out/bin/${config.binName}
''
