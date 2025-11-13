{
  config,
  wlib,
  lib,
  ...
}:
{
  options.argv0 = lib.mkOption {
    type = lib.types.nullOr lib.types.str;
    default = null;
    description = ''
      --argv0 NAME

      Set the name of the executed process to NAME.
      If unset or empty, defaults to EXECUTABLE.

      overrides the setting from `argv0type` if set.

      Values may contain environment variable references using `$` to expand at runtime
    '';
  };
  options.addFlag = lib.mkOption {
    type =
      with lib.types;
      wlib.types.dalOf (oneOf [
        wlib.types.stringable
        (listOf wlib.types.stringable)
      ]);
    default = [ ];
    description = ''
      This option takes a list. To group them more strongly,
      option may take a list of lists as well.

      Values may contain environment variable references using `$` to expand at runtime

      Any entry can instead be of type `{ data, name ? null, before ? [], after ? [] }`

      This will cause it to be added to the DAG.

      If no name is provided, it cannot be targeted.
    '';
  };
  options.appendFlag = lib.mkOption {
    type =
      with lib.types;
      wlib.types.dalOf (oneOf [
        wlib.types.stringable
        (listOf wlib.types.stringable)
      ]);
    default = [ ];
    description = ''
      like flags and addFlag, except appends after the runtime user's arguments

      Values may contain environment variable references using `$` to expand at runtime

      This option takes a list. To group them more strongly,
      option may take a list of lists as well.

      Any entry can instead be of type `{ data, name ? null, before ? [], after ? [] }`

      This will cause it to be added to the DAG.

      If no name is provided, it cannot be targeted.
    '';
  };
  options.flags = lib.mkOption {
    type =
      with lib.types;
      wlib.types.dagOf (
        nullOr (oneOf [
          bool
          wlib.types.stringable
          (listOf wlib.types.stringable)
        ])
      );
    default = { };
    description = ''
      Flags to pass to the wrapper.
      The key is the flag name, the value is the flag value.
      If the value is true, the flag will be passed without a value.
      If the value is false or null, the flag will not be passed.
      If the value is a list, the flag will be passed multiple times with each value.

      This option takes a set.

      Values may contain environment variable references using `$` to expand at runtime

      Any entry can instead be of type `{ data, before ? [], after ? [] }`

      This will cause it to be added to the DAG,
      which will cause the resulting wrapper argument to be sorted accordingly
    '';
  };
  options.flagSeparator = lib.mkOption {
    type = lib.types.str;
    default = " ";
    description = ''
      Separator between flag names and values when generating args from flags.
      `" "` for `--flag value` or `"="` for `--flag=value`
    '';
  };
  options.env = lib.mkOption {
    type = wlib.types.dagOf wlib.types.stringable;
    default = { };
    description = ''
      Environment variables to set in the wrapper.

      Values may contain environment variable references using `$` to expand at runtime

      This option takes a set.

      Any entry can instead be of type `{ data, before ? [], after ? [] }`

      This will cause it to be added to the DAG,
      which will cause the resulting wrapper argument to be sorted accordingly
    '';
  };
  options.unsetVar = lib.mkOption {
    type = wlib.types.dalOf lib.types.str;
    default = [ ];
    description = ''
      Remove VAR from the environment.
    '';
  };
  options.runShell = lib.mkOption {
    type = wlib.types.dalOf wlib.types.stringable;
    default = [ ];
    description = ''
      Run COMMAND before executing the main program.

      This option takes a list. To group them more strongly,
      option may take a list of lists as well.

      Any entry can instead be of type `{ data, name ? null, before ? [], after ? [] }`

      This will cause it to be added to the DAG.

      If no name is provided, it cannot be targeted.
    '';
  };
  options.prefixVar = lib.mkOption {
    type = wlib.types.wrapperFlags 3;
    default = [ ];
    description = ''
      [ "ENV" "SEP" "VAL" ]

      Prefix ENV with VAL, separated by SEP.

      Values may contain environment variable references using `$` to expand at runtime
    '';
  };
  options.suffixVar = lib.mkOption {
    type = wlib.types.wrapperFlags 3;
    default = [ ];
    description = ''
      [ "ENV" "SEP" "VAL" ]

      Suffix ENV with VAL, separated by SEP.

      Values may contain environment variable references using `$` to expand at runtime
    '';
  };
  options.escapingFunction = lib.mkOption {
    type = lib.types.functionTo lib.types.str;
    default = wlib.escapeShellArgWithEnv;
    description = ''
      The function to use to escape shell arguments before concatenation

      default: `wlib.escapeShellArgWithEnv`
    '';
  };
  config.wrapperFunction = lib.mkDefault (
    {
      config,
      wlib,
      binName,
      outputs,
      writeShellScriptBin,
      lib,
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
        ++ lib.optionals (config.env != { }) (
          wlib.dag.sortAndUnwrap {
            dag = wlib.dag.gmap (n: v: "export " + config.escapingFunction "${n}=${toString v}") config.env;
          }
        )
        ++ wlib.dag.lmap (
          tuple:
          with builtins;
          let
            env = elemAt tuple 0;
            sep = elemAt tuple 1;
            val = elemAt tuple 2;
          in
          "export " + config.escapingFunction "${env}=${val}${sep}${env}"
        ) config.prefixVar
        ++ wlib.dag.lmap (
          tuple:
          with builtins;
          let
            env = elemAt tuple 0;
            sep = elemAt tuple 1;
            val = elemAt tuple 2;
          in
          "export " + config.escapingFunction "${env}=${env}${sep}${val}"
        ) config.suffixVar
        ++ config.runShell;

      shellcmds = lib.optionals (shellcmdsdal != [ ]) (
        wlib.dag.sortAndUnwrap {
          dag = shellcmdsdal;
          mapIfOk = v: v.data;
        }
      );

    in
    writeShellScriptBin binName ''
      ${builtins.concatStringsSep "\n" shellcmds}
      exec -a ${arg0} ${config.package}/bin/${binName} ${preFlagStr} "$@" ${postFlagStr}
    ''
  );
}
