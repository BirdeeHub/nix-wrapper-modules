{
  config,
  wlib,
  lib,
  ...
}:
{
  options.argv0type = lib.mkOption {
    type = lib.types.enum [
      "resolve"
      "inherit"
    ];
    default = "inherit";
    description = ''
      `argv0` overrides this option if not null or unset

      Both `shell` and the `nix` implementations
      ignore this option, as the shell always resolves `$0`

      However, the `binary` implementation will use this option

      Values:

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
      If unset or null, defaults to EXECUTABLE.

      overrides the setting from `argv0type` if set.
    '';
  };
  options.unsetVar = lib.mkOption {
    type = wlib.types.dalWithEsc lib.types.str;
    default = [ ];
    description = ''
      --unset VAR

      Remove VAR from the environment.
    '';
  };
  options.runShell = lib.mkOption {
    type = wlib.types.dalWithEsc wlib.types.stringable;
    default = [ ];
    description = ''
      --run COMMAND

      Run COMMAND before executing the main program.

      This option takes a list.

      Any entry can instead be of type `{ data, name ? null, before ? [], after ? [], esc-fn ? null }`

      This will cause it to be added to the DAG.

      If no name is provided, it cannot be targeted.
    '';
  };
  options.chdir = lib.mkOption {
    type = wlib.types.dalWithEsc wlib.types.stringable;
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

      Any entry can instead be of type `{ data, name ? null, before ? [], after ? [], esc-fn ? null }`

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

      Any entry can instead be of type `{ data, name ? null, before ? [], after ? [], esc-fn ? null }`

      This will cause it to be added to the DAG.

      If no name is provided, it cannot be targeted.
    '';
  };
  options.prefixVar = lib.mkOption {
    type = wlib.types.wrapperFlags 3;
    default = [ ];
    example = [
      [
        "LD_LIBRARY_PATH"
        ":"
        "\${lib.makeLibraryPath (with config.pkgs; [ ... ])}"
      ]
      [
        "PATH"
        ":"
        "\${lib.makeBinPath (with config.pkgs; [ ... ])}"
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
        "LD_LIBRARY_PATH"
        ":"
        "\${lib.makeLibraryPath (with config.pkgs; [ ... ])}"
      ]
      [
        "PATH"
        ":"
        "\${lib.makeBinPath (with config.pkgs; [ ... ])}"
      ]
    ];
    description = ''
      --suffix ENV SEP VAL

      Suffix ENV with VAL, separated by SEP.
    '';
  };
  options.prefixContent = lib.mkOption {
    type = wlib.types.wrapperFlags 3;
    default = [ ];
    description = ''
      [
        [ "ENV" "SEP" "FILE" ]
      ]

      Prefix ENV with contents of FILE and SEP at build time.

      Values may contain environment variable references using `$` to expand at runtime
    '';
  };
  options.suffixContent = lib.mkOption {
    type = wlib.types.wrapperFlags 3;
    default = [ ];
    description = ''
      [
        [ "ENV" "SEP" "FILE" ]
      ]

      Suffix ENV with SEP and then the contents of FILE at build time.

      Values may contain environment variable references using `$` to expand at runtime
    '';
  };
  options.flags = lib.mkOption {
    type = (import ./genArgsFromFlags.nix { inherit lib wlib; }).flagDag;
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

      Any entry can instead be of type `{ data, before ? [], after ? [], esc-fn ? null, sep ? null }`

      The `sep` field may be used to override the value of `config.flagSeparator`

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
    type = wlib.types.dagWithEsc wlib.types.stringable;
    default = { };
    example = {
      "XDG_DATA_HOME" = "/somewhere/on/your/machine";
    };
    description = ''
      Environment variables to set in the wrapper.

      This option takes a set.

      Any entry can instead be of type `{ data, before ? [], after ? [], esc-fn ? null }`

      This will cause it to be added to the DAG,
      which will cause the resulting wrapper argument to be sorted accordingly
    '';
  };
  options.envDefault = lib.mkOption {
    type = wlib.types.dagWithEsc wlib.types.stringable;
    default = { };
    example = {
      "XDG_DATA_HOME" = "/only/if/not/set";
    };
    description = ''
      Environment variables to set in the wrapper.

      Like env, but only adds the variable if not already set in the environment.

      This option takes a set.

      Any entry can instead be of type `{ data, before ? [], after ? [], esc-fn ? null }`

      This will cause it to be added to the DAG,
      which will cause the resulting wrapper argument to be sorted accordingly
    '';
  };
  options.wrapperImplementation = lib.mkOption {
    type = lib.types.enum [
      "nix"
      "shell"
      "binary"
    ];
    default = "nix";
    description = ''
      the `nix` implementation is the default

      It makes the `escapingFunction` most relevant.

      This is because the `shell` and `binary` implementations
      use `pkgs.makeWrapper` or `pkgs.makeBinaryWrapper`,
      and arguments to these functions are passed at BUILD time.

      So, generally, when not using the nix implementation,
      you should always prefer to have `escapingFunction`
      set to `lib.escapeShellArg`.

      However, if you ARE using the `nix` implementation,
      using `wlib.escapeShellArgWithEnv` will allow you
      to use `$` expansions, which will expand at runtime.

      `binary` implementation is useful for programs
      which are likely to be used in "shebangs",
      as macos will not allow scripts to be used for these.

      However, it is more limited. It does not have access to
      `runShell`, `prefixContent`, and `suffixContent` options.

      Chosing `binary` will thus cause values in those options to be ignored.
    '';
  };
  options.escapingFunction = lib.mkOption {
    type = lib.types.functionTo lib.types.str;
    default = lib.escapeShellArg;
    defaultText = "lib.escapeShellArg";
    description = ''
      The function to use to escape shell values

      Caution: When using `shell` or `binary` implementations,
      these will be expanded at BUILD time.

      You should probably leave this as is when using either of those implementations.

      However, when using the `nix` implementation, they will expand at runtime!
      Which means `wlib.escapeShellArgWithEnv` may prove to be a useful substitute!
    '';
  };
  config.suffixVar =
    lib.optionals (config.extraPackages != [ ]) [
      {
        name = "NIX_PATH_ADDITIONS";
        data = lib.optionals (config.extraPackages != [ ]) [
          "PATH"
          ":"
          "${lib.makeBinPath config.extraPackages}"
        ];
      }
    ]
    ++ lib.optionals (config.runtimeLibraries != [ ]) [
      {
        name = "NIX_LIB_ADDITIONS";
        data = [
          "LD_LIBRARY_PATH"
          ":"
          "${lib.makeLibraryPath config.extraPackages}"
        ];
      }
    ];
  config.drv.nativeBuildInputs =
    lib.mkIf (config.wrapperImplementation == "shell" || config.wrapperImplementation == "binary")
      [
        (
          if config.wrapperImplementation == "shell" then
            config.pkgs.makeWrapper
          else
            config.pkgs.makeBinaryWrapper
        )
      ];
  config.wrapperFunction = lib.mkDefault (
    import (if config.wrapperImplementation == "nix" then ./makeWrapperNix.nix else ./makeWrapper.nix)
  );
  config.meta.maintainers = lib.mkDefault [ lib.maintainers.birdee ];

  options.rawWrapperArgs = lib.mkOption {
    type = wlib.types.wrapperFlag;
    default = [ ];
    internal = true;
    description = "DEPRECATED";
    apply =
      value:
      if value != [ ] then
        throw ''
          The option `rawWrapperArgs` is deprecated and must not be used.

          They were not an interface which was easily implemnented by other implementations,
          and the module system options are a better interface anyway.
        ''
      else
        value;
  };
  options.unsafeWrapperArgs = lib.mkOption {
    type = wlib.types.wrapperFlag;
    default = [ ];
    internal = true;
    description = "DEPRECATED";
    apply =
      value:
      if value != [ ] then
        throw ''
          The option `unsafeWrapperArgs` is deprecated and must not be used.

          They were not an interface which was easily implemnented by other implementations,
          and the module system options are a better interface anyway.
        ''
      else
        value;
  };
  options.wrapperArgEscaping = lib.mkOption {
    type = lib.types.nullOr lib.types.bool;
    default = null;
    internal = true;
    description = "DEPRECATED";
  };
  config.escapingFunction = lib.mkIf (config.wrapperArgEscaping != null) (
    lib.warn
      "wrapperArgEscaping has been renamed to escapingFunction and takes a function which recieves the value and returns the escaped version"
      (if config.wrapperArgEscaping then lib.escapeShellArg else (s: toString s))
  );
  options.useBinaryWrapper = lib.mkOption {
    type = lib.types.nullOr lib.types.bool;
    default = null;
    internal = true;
    description = "DEPRECATED";
  };
  options.makeWrapper = lib.mkOption {
    type = lib.types.nullOr lib.types.package;
    default = null;
    internal = true;
    description = "DEPRECATED";
  };
  config.wrapperImplementation =
    lib.mkIf (config.useBinaryWrapper != null || config.makeWrapper != null)
      (
        let
          msg = "useBinaryWrapper has been renamed to wrapperImplementation and takes an enum of 'binary', 'shell', or 'nix'";
        in
        if config.useBinaryWrapper == true then
          lib.warn msg "binary"
        else if config.useBinaryWrapper == false then
          lib.warn msg "shell"
        else
          throw "makeWrapper option is no longer supported, use wrapperImplementation instead, which takes an enum of 'binary', 'shell', or 'nix'"
      );

  options.prefixContents = lib.mkOption {
    type = wlib.types.wrapperFlags 3;
    default = [ ];
    internal = true;
    description = "DEPRECATED";
  };
  config.prefixContent = lib.mkIf (config.prefixContents != [ ]) (
    lib.warn "prefixContents has been renamed to prefixContent and takes only 1 file" config.prefixContents
  );
  options.suffixContents = lib.mkOption {
    type = wlib.types.wrapperFlags 3;
    default = [ ];
    internal = true;
    description = "DEPRECATED";
  };
  config.suffixContent = lib.mkIf (config.suffixContents != [ ]) (
    lib.warn "suffixContents has been renamed to suffixContent and takes only 1 file" config.suffixContents
  );
}
