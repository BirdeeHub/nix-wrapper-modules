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
      Use instead of --argv0 '$0'.

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
    '';
  };
  options.useBinaryWrapper = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = ''
      changes the makeWrapper implementation from pkgs.makeWrapper to pkgs.makeBinaryWrapper

      also disables --run, --prefix-contents, and --suffix-contents,
      as they are not supported by pkgs.makeBinaryWrapper
    '';
  };
  options.unset = lib.mkOption {
    type =
      with lib.types;
      wlib.types.dalOf (oneOf [
        str
        package
      ]);
    default = [ ];
    description = ''
      --unset VAR

      Remove VAR from the environment.
    '';
  };
  options.run = lib.mkOption {
    type =
      with lib.types;
      wlib.types.dalOf (oneOf [
        str
        package
      ]);
    default = [ ];
    description = ''
      --run COMMAND

      Run COMMAND before executing the main program.
    '';
  };
  options.chdir = lib.mkOption {
    type =
      with lib.types;
      wlib.types.dalOf (oneOf [
        str
        package
      ]);
    default = [ ];
    description = ''
      --chdir DIR

      Change working directory before running the executable.
      Use instead of --run "cd DIR".
    '';
  };
  options.add-flag = lib.mkOption {
    type =
      with lib.types;
      wlib.types.dalOf (oneOf [
        str
        package
      ]);
    default = [ ];
    description = ''
      --add-flag ARG

      Prepend the single argument ARG to the invocation of the executable,
      before any command-line arguments.
    '';
  };
  options.append-flag = lib.mkOption {
    type =
      with lib.types;
      wlib.types.dalOf (oneOf [
        str
        package
      ]);
    default = [ ];
    description = ''
      --append-flag ARG

      Append the single argument ARG to the invocation of the executable,
      after any command-line arguments.
    '';
  };
  options.prefix = lib.mkOption {
    type = wlib.types.wrapperFlags 3;
    default = [ ];
    description = ''
      --prefix ENV SEP VAL

      Prefix or suffix ENV with VAL, separated by SEP.
    '';
  };
  options.suffix = lib.mkOption {
    type = wlib.types.wrapperFlags 3;
    default = [ ];
    description = ''
      --suffix ENV SEP VAL

      Suffix or prefix ENV with VAL, separated by SEP.
    '';
  };
  options.prefix-contents = lib.mkOption {
    type = wlib.types.wrapperFlags 3;
    default = [ ];
    description = ''
      --prefix-contents ENV SEP FILES

      Like --suffix-each, but contents of FILES are read first and used as VALS.
    '';
  };
  options.suffix-contents = lib.mkOption {
    type = wlib.types.wrapperFlags 3;
    default = [ ];
    description = ''
      --suffix-contents ENV SEP FILES

      Like --prefix-each, but contents of FILES are read first and used as VALS.
    '';
  };
  options.flags = lib.mkOption {
    type =
      with lib.types;
      wlib.types.dagOf (
        nullOr (oneOf [
          bool
          str
          package
          (listOf (oneOf [
            str
            package
          ]))
        ])
      );
    default = { };
    description = ''
      Flags to pass to the wrapper.
      The key is the flag name, the value is the flag value.
      If the value is true, the flag will be passed without a value.
      If the value is false or null, the flag will not be passed.
      If the value is a list, the flag will be passed multiple times with each value.
    '';
  };
  options.flagSeparator = lib.mkOption {
    type = lib.types.str;
    default = " ";
    description = ''
      Separator between flag names and values when generating args from flags.
      " " for "--flag value" or "=" for "--flag=value"
    '';
  };
  options.extraPackages = lib.mkOption {
    type = lib.types.listOf lib.types.package;
    default = [ ];
    description = ''
      Additional packages to add to the wrapper's runtime PATH.
      This is useful if the wrapped program needs additional libraries or tools to function correctly.
    '';
  };
  options.runtimeLibraries = lib.mkOption {
    type = lib.types.listOf lib.types.package;
    default = [ ];
    description = ''
      Additional libraries to add to the wrapper's runtime LD_LIBRARY_PATH.
      This is useful if the wrapped program needs additional libraries or tools to function correctly.
    '';
  };
  options.env = lib.mkOption {
    type = wlib.types.dagOf (
      lib.types.oneOf [
        lib.types.str
        lib.types.package
      ]
    );
    default = { };
    description = ''
      Environment variables to set in the wrapper.
    '';
  };
  options.env-default = lib.mkOption {
    type = wlib.types.dagOf (
      lib.types.oneOf [
        lib.types.str
        lib.types.package
      ]
    );
    default = { };
    description = ''
      Environment variables to set in the wrapper.

      Like env, but only adds the variable if not already set in the environment.
    '';
  };
  config =
    let

      /**
        generateArgsFromFlags :: flagSeparator "" -> flags {} -> args [""]
        The key is the flag name, the value is the flag value.
        If the value is true, the flag will be passed without a value.
        If the value is false or null, the flag will not be passed.
        If the value is a list, the flag will be passed multiple times with each value.

        type =
          with lib.types;
          wlib.types.dagOf (oneOf [
            bool
            str
            package
            (listOf (oneOf [
              str
              package
            ]))
          ]);

        to
          with lib.types;
          (dalOf
            (listOf (oneOf [
              str
              package
            ]))
          )
      */
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
                  "--add-flag"
                  name
                ]
              else if lib.isList value then
                lib.flatten (
                  map (
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
                )
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
            ) dag_flags
          );
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
      envVarsDefault = lib.optionals (config.env-default != { }) (
        wlib.dag.sortAndUnwrap {
          dag = (
            wlib.dag.gmap (n: v: [
              "--set-default"
              n
              "${v}"
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
              "${v}"
            ]) config.env
          );
        }
      );
      xtrapkgs = lib.optionals (config.extraPackages != [ ]) [
        {
          name = "NIX_PATH_ADDITIONS";
          data = lib.optionals (config.extraPackages != [ ]) [
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
            "LD_LIBRARY_PATH"
            ":"
            "${lib.makeLibraryPath config.extraPackages}"
          ];
        }
      ];
      flags = lib.optionals (config.flags != { }) (
        generateArgsFromFlags (config.flagSeparator or " ") config.flags
      );
      mapsingles =
        n:
        wlib.dag.lmap (v: [
          "--${n}"
          "${v}"
        ]) config.${n};
      maplists = n: wlib.dag.lmap (v: [ "--${n}" ] ++ v) config.${n};

      other = mapsingles "unset" ++ mapsingles "chdir" ++ maplists "prefix" ++ maplists "suffix";
      conditionals =
        if !config.useBinaryWrapper then
          mapsingles "run" ++ maplists "prefix-contents" ++ maplists "suffix-contents"
        else
          [ ];
    in
    {
      makeWrapper =
        if config.useBinaryWrapper then config.pkgs.makeBinaryWrapper else config.pkgs.makeWrapper;
      rawWrapperArgs =
        argv0
        ++ mapsingles "add-flag"
        ++ flags
        ++ mapsingles "append-flag"
        ++ xtrapkgs
        ++ xtralib
        ++ envVars
        ++ envVarsDefault
        ++ other
        ++ conditionals;
    };
}
