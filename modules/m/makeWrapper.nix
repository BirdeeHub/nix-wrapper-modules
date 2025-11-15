{
  config,
  wlib,
  lib,
  ...
}:
{
  imports = [ wlib.modules.makeWrapperBase ];
  options.argv0type = lib.mkOption {
    type = lib.types.enum [
      "resolve"
      "inherit"
    ];
    default = "inherit";
    description = ''
      `argv0` overrides this option if not null or unset

      `"inherit"`:
      `--inherit-argv0`

      The executable inherits argv0 from the wrapper.
      Use instead of `--argv0 '$0'`.

      `"resolve"`:

      `--resolve-argv0`

      If argv0 does not include a "/" character, resolve it against PATH.
    '';
  };
  options.argv0 = lib.mkOption {
    type = lib.types.nullOr lib.types.str;
    default = null;
    description = ''
      --argv0 NAME

      Set the name of the executed process to NAME.
      If unset or empty, defaults to EXECUTABLE.

      overrides the setting from `argv0type` if set.
    '';
  };
  options.useBinaryWrapper = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = ''
      changes the makeWrapper implementation from `pkgs.makeWrapper` to `pkgs.makeBinaryWrapper`

      also disables `--run`, `--prefix-contents`, and `--suffix-contents`,
      as they are not supported by `pkgs.makeBinaryWrapper`
    '';
  };
  options.unsetVar = lib.mkOption {
    type = wlib.types.dalOf lib.types.str;
    default = [ ];
    description = ''
      --unset VAR

      Remove VAR from the environment.
    '';
  };
  options.runShell = lib.mkOption {
    type = wlib.types.dalOf wlib.types.stringable;
    default = [ ];
    description = ''
      --run COMMAND

      Run COMMAND before executing the main program.

      This option takes a list.

      Any entry can instead be of type `{ data, name ? null, before ? [], after ? [] }`

      This will cause it to be added to the DAG.

      If no name is provided, it cannot be targeted.
    '';
  };
  options.chdir = lib.mkOption {
    type = wlib.types.dalOf wlib.types.stringable;
    default = [ ];
    description = ''
      --chdir DIR

      Change working directory before running the executable.
      Use instead of `--run "cd DIR"`.
    '';
  };
  options.addFlag = lib.mkOption {
    type = wlib.types.wrapperFlag;
    default = [ ];
    example = [
      "-v"
      "-f"
      [
        "--config"
        "\${./storePath.cfg}"
      ]
      [
        "-s"
        "idk"
      ]
    ];
    description = ''
      Wrapper for

      --add-flag ARG

      Prepend the single argument ARG to the invocation of the executable,
      before any command-line arguments.

      This option takes a list. To group them more strongly,
      option may take a list of lists as well.

      Any entry can instead be of type `{ data, name ? null, before ? [], after ? [] }`

      This will cause it to be added to the DAG.

      If no name is provided, it cannot be targeted.
    '';
  };
  options.appendFlag = lib.mkOption {
    type = wlib.types.wrapperFlag;
    default = [ ];
    example = [
      "-v"
      "-f"
      [
        "--config"
        "\${./storePath.cfg}"
      ]
      [
        "-s"
        "idk"
      ]
    ];
    description = ''
      --append-flag ARG

      Append the single argument ARG to the invocation of the executable,
      after any command-line arguments.

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
    example = [
      [
        "PATH"
        "SEP"
        "VAL"
      ]
      [
        "PATH"
        "SEP"
        "VAL"
      ]
    ];
    description = ''
      --prefix ENV SEP VAL

      Prefix ENV with VAL, separated by SEP.
    '';
  };
  options.suffixVar = lib.mkOption {
    type = wlib.types.wrapperFlags 3;
    default = [ ];
    example = [
      [
        "PATH"
        "SEP"
        "VAL"
      ]
      [
        "PATH"
        "SEP"
        "VAL"
      ]
    ];
    description = ''
      --suffix ENV SEP VAL

      Suffix ENV with VAL, separated by SEP.
    '';
  };
  options.prefixContents = lib.mkOption {
    type = wlib.types.wrapperFlags 3;
    default = [ ];
    example = [
      [
        "PATH"
        "SEP"
        "FILE"
      ]
      [
        "PATH"
        "SEP"
        "FILE"
      ]
    ];
    description = ''
      --prefix-contents ENV SEP FILES

      Like `--suffix-each`, but contents of FILES are read first and used as VALS.
    '';
  };
  options.suffixContents = lib.mkOption {
    type = wlib.types.wrapperFlags 3;
    default = [ ];
    example = [
      [
        "PATH"
        "SEP"
        "FILE"
      ]
      [
        "PATH"
        "SEP"
        "FILE"
      ]
    ];
    description = ''
      --suffix-contents ENV SEP FILES

      Like `--prefix-each`, but contents of FILES are read first and used as VALS.
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
    example = {
      "--config" = "\${./nixPath}";
    };
    description = ''
      Flags to pass to the wrapper.
      The key is the flag name, the value is the flag value.
      If the value is true, the flag will be passed without a value.
      If the value is false or null, the flag will not be passed.
      If the value is a list, the flag will be passed multiple times with each value.

      This option takes a set.

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
  options.extraPackages = lib.mkOption {
    type = lib.types.listOf lib.types.package;
    default = [ ];
    description = ''
      Additional packages to add to the wrapper's runtime PATH.
      This is useful if the wrapped program needs additional libraries or tools to function correctly.

      Adds all its entries to the DAG under the name `NIX_PATH_ADDITIONS`
    '';
  };
  options.runtimeLibraries = lib.mkOption {
    type = lib.types.listOf lib.types.package;
    default = [ ];
    description = ''
      Additional libraries to add to the wrapper's runtime LD_LIBRARY_PATH.
      This is useful if the wrapped program needs additional libraries or tools to function correctly.

      Adds all its entries to the DAG under the name `NIX_LIB_ADDITIONS`
    '';
  };
  options.env = lib.mkOption {
    type = wlib.types.dagOf wlib.types.stringable;
    default = { };
    example = {
      "XDG_DATA_HOME" = "/somewhere/on/your/machine";
    };
    description = ''
      Environment variables to set in the wrapper.

      This option takes a set.

      Any entry can instead be of type `{ data, before ? [], after ? [] }`

      This will cause it to be added to the DAG,
      which will cause the resulting wrapper argument to be sorted accordingly
    '';
  };
  options.envDefault = lib.mkOption {
    type = wlib.types.dagOf wlib.types.stringable;
    default = { };
    example = {
      "XDG_DATA_HOME" = "/only/if/not/set";
    };
    description = ''
      Environment variables to set in the wrapper.

      Like env, but only adds the variable if not already set in the environment.

      This option takes a set.

      Any entry can instead be of type `{ data, before ? [], after ? [] }`

      This will cause it to be added to the DAG,
      which will cause the resulting wrapper argument to be sorted accordingly
    '';
  };
  options.wrapperArgEscaping = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = ''
      Controls which `wlib.modules.makeWrapperBase` option to pass the generated wrapper arguments to

      if value is `true` then the wrapper arguments will be passed to `config.rawWrapperArgs`

      if value is `false` then the wrapper arguments will be passed to `config.unsafeWrapperArgs`

      WARNING: These arguments are passed to makeWrapper at build time! Not escaping may not do what you expect!
    '';
  };
  config =
    let
      generateArgsFromFlags =
        flagSeparator: dag_flags:
        wlib.dag.sortAndUnwrap {
          dag = wlib.dag.gmap (
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
          ) dag_flags;
        };

      argv0 = [
        (
          if builtins.isString config.argv0 then
            [
              "--argv0"
              config.argv0
            ]
          else if config.argv0type == "resolve" then
            [ "--resolve-argv0" ]
          else
            [ "--inherit-argv0" ]
        )
      ];
      envVarsDefault = lib.optionals (config.envDefault != { }) (
        wlib.dag.sortAndUnwrap {
          dag = (
            wlib.dag.gmap (n: v: [
              "--set-default"
              n
              "${toString v}"
            ]) config.env-default
          );
        }
      );
      envVars = lib.optionals (config.env != { }) (
        wlib.dag.sortAndUnwrap {
          dag = (
            wlib.dag.gmap (n: v: [
              "--set"
              n
              "${toString v}"
            ]) config.env
          );
        }
      );
      xtrapkgs = lib.optionals (config.extraPackages != [ ]) [
        {
          name = "NIX_PATH_ADDITIONS";
          data = lib.optionals (config.extraPackages != [ ]) [
            "--suffix"
            "PATH"
            ":"
            "${lib.makeBinPath config.extraPackages}"
          ];
        }
      ];
      xtralib = lib.optionals (config.runtimeLibraries != [ ]) [
        {
          name = "NIX_LIB_ADDITIONS";
          data = [
            "--suffix"
            "LD_LIBRARY_PATH"
            ":"
            "${lib.makeLibraryPath config.extraPackages}"
          ];
        }
      ];
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
        if !config.useBinaryWrapper then
          mapargs "runShell" "run" true
          ++ mapargs "prefixContents" "prefix-contents" false
          ++ mapargs "suffixContents" "suffix-contents" false
        else
          [ ];

      finalArgs =
        argv0
        ++ mapargs "addFlag" "add-flag" true
        ++ flags
        ++ mapargs "appendFlag" "append-flag" true
        ++ xtrapkgs
        ++ xtralib
        ++ envVars
        ++ envVarsDefault
        ++ other
        ++ conditionals;
    in
    {
      makeWrapper =
        if config.useBinaryWrapper then config.pkgs.makeBinaryWrapper else config.pkgs.makeWrapper;
      rawWrapperArgs = lib.mkIf config.wrapperArgEscaping finalArgs;
      unsafeWrapperArgs = lib.mkIf (!config.wrapperArgEscaping) finalArgs;
    };
}
