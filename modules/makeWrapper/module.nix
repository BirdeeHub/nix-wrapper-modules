let
  options_module =
    excluded: is_top:
    {
      config,
      options,
      wlib,
      lib,
      mainConfig ? null,
      mainOpts ? null,
      ...
    }:
    {
      _file = ./module.nix;
      options.${if !(excluded.argv0type or false) then "argv0type" else null} = lib.mkOption {
        type =
          with lib.types;
          either (enum [
            "resolve"
            "inherit"
          ]) (functionTo str);
        default = if mainConfig != null && config.mirror or false then mainConfig.argv0type else "inherit";
        description = ''
          `argv0` overrides this option if not null or unset

          Both `shell` and the `nix` implementations
          ignore this option, as the shell always resolves `$0`

          However, the `binary` implementation will use this option

          Values:

          - `"inherit"`:

          The executable inherits argv0 from the wrapper.
          Use instead of `--argv0 '$0'`.

          - `"resolve"`:

          If argv0 does not include a "/" character, resolve it against PATH.

          - Function form: `str -> str`

          This one works only in the nix implementation. The others will treat it as `inherit`

          Rather than calling exec, you get the command plus all its flags supplied,
          and you can choose how to run it.

          e.g. `command_string: "eval \"$(''${command_string})\";`

          It will also be added to the end of the overall `DAL`,
          with the name `NIX_RUN_MAIN_PACKAGE`

          Thus, you can make things run after it,
          but by default it is still last.
        '';
      };
      options.${if !(excluded.argv0 or false) then "argv0" else null} = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = if mainConfig != null && config.mirror or false then mainConfig.argv0 else null;
        description = ''
          --argv0 NAME

          Set the name of the executed process to NAME.
          If unset or null, defaults to EXECUTABLE.

          overrides the setting from `argv0type` if set.
        '';
      };
      options.${if !(excluded.unsetVar or false) then "unsetVar" else null} = lib.mkOption {
        type = wlib.types.dalWithEsc lib.types.str;
        default = if mainConfig != null && config.mirror or false then mainConfig.unsetVar else [ ];
        description = ''
          --unset VAR

          Remove VAR from the environment.
        '';
      };
      options.${if !(excluded.runShell or false) then "runShell" else null} = lib.mkOption {
        type = wlib.types.dalWithEsc wlib.types.stringable;
        default = if mainConfig != null && config.mirror or false then mainConfig.runShell else [ ];
        description = ''
          --run COMMAND

          Run COMMAND before executing the main program.

          This option takes a list.

          Any entry can instead be of type `{ data, name ? null, before ? [], after ? [], esc-fn ? null }`

          This will cause it to be added to the DAG.

          If no name is provided, it cannot be targeted.
        '';
      };
      options.${if !(excluded.chdir or false) then "chdir" else null} = lib.mkOption {
        type = wlib.types.dalWithEsc wlib.types.stringable;
        default = if mainConfig != null && config.mirror or false then mainConfig.chdir else [ ];
        description = ''
          --chdir DIR

          Change working directory before running the executable.
          Use instead of `--run "cd DIR"`.
        '';
      };
      options.${if !(excluded.addFlag or false) then "addFlag" else null} = lib.mkOption {
        type = wlib.types.wrapperFlag;
        default = if mainConfig != null && config.mirror or false then mainConfig.addFlag else [ ];
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
      options.${if !(excluded.appendFlag or false) then "appendFlag" else null} = lib.mkOption {
        type = wlib.types.wrapperFlag;
        default = if mainConfig != null && config.mirror or false then mainConfig.appendFlag else [ ];
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
      options.${if !(excluded.prefixVar or false) then "prefixVar" else null} = lib.mkOption {
        type = wlib.types.wrapperFlags 3;
        default = if mainConfig != null && config.mirror or false then mainConfig.prefixVar else [ ];
        example = [
          [
            "LD_LIBRARY_PATH"
            ":"
            "\${lib.makeLibraryPath (with pkgs; [ ... ])}"
          ]
          [
            "PATH"
            ":"
            "\${lib.makeBinPath (with pkgs; [ ... ])}"
          ]
        ];
        description = ''
          --prefix ENV SEP VAL

          Prefix ENV with VAL, separated by SEP.
        '';
      };
      options.${if !(excluded.suffixVar or false) then "suffixVar" else null} = lib.mkOption {
        type = wlib.types.wrapperFlags 3;
        default = if mainConfig != null && config.mirror or false then mainConfig.suffixVar else [ ];
        example = [
          [
            "LD_LIBRARY_PATH"
            ":"
            "\${lib.makeLibraryPath (with pkgs; [ ... ])}"
          ]
          [
            "PATH"
            ":"
            "\${lib.makeBinPath (with pkgs; [ ... ])}"
          ]
        ];
        description = ''
          --suffix ENV SEP VAL

          Suffix ENV with VAL, separated by SEP.
        '';
      };
      options.${if !(excluded.prefixContent or false) then "prefixContent" else null} = lib.mkOption {
        type = wlib.types.wrapperFlags 3;
        default = if mainConfig != null && config.mirror or false then mainConfig.prefixContent else [ ];
        description = ''
          ```nix
          [
            [ "ENV" "SEP" "FILE" ]
          ]
          ```

          Prefix ENV with contents of FILE and SEP at build time.

          Also accepts sets like the other options

          ```nix
          [
            [ "ENV" "SEP" "FILE" ]
            { data = [ "ENV" "SEP" "FILE" ]; esc-fn = lib.escapeShellArg; /* name, before, after */ }
          ]
          ```
        '';
      };
      options.${if !(excluded.suffixContent or false) then "suffixContent" else null} = lib.mkOption {
        type = wlib.types.wrapperFlags 3;
        default = if mainConfig != null && config.mirror or false then mainConfig.suffixContent else [ ];
        description = ''
          ```nix
          [
            [ "ENV" "SEP" "FILE" ]
          ]
          ```

          Suffix ENV with SEP and then the contents of FILE at build time.

          Also accepts sets like the other options

          ```nix
          [
            [ "ENV" "SEP" "FILE" ]
            { data = [ "ENV" "SEP" "FILE" ]; esc-fn = lib.escapeShellArg; /* name, before, after */ }
          ]
          ```
        '';
      };
      options.${if !(excluded.flags or false) then "flags" else null} = lib.mkOption {
        type = (import ./genArgsFromFlags.nix { inherit lib wlib; }).flagDag;
        default = if mainConfig != null && config.mirror or false then mainConfig.flags else { };
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
      options.${if !(excluded.flagSeparator or false) then "flagSeparator" else null} = lib.mkOption {
        type = lib.types.str;
        default = if mainConfig != null && config.mirror or false then mainConfig.flagSeparator else " ";
        description = ''
          Separator between flag names and values when generating args from flags.
          `" "` for `--flag value` or `"="` for `--flag=value`
        '';
      };
      options.${if !(excluded.extraPackages or false) then "extraPackages" else null} = lib.mkOption {
        type = lib.types.listOf lib.types.package;
        default = if mainConfig != null && config.mirror or false then mainConfig.extraPackages else [ ];
        description = ''
          Additional packages to add to the wrapper's runtime PATH.
          This is useful if the wrapped program needs additional libraries or tools to function correctly.

          Adds all its entries to the DAG under the name `NIX_PATH_ADDITIONS`
        '';
      };
      options.${if !(excluded.runtimeLibraries or false) then "runtimeLibraries" else null} =
        lib.mkOption
          {
            type = lib.types.listOf lib.types.package;
            default = if mainConfig != null && config.mirror or false then mainConfig.runtimeLibraries else [ ];
            description = ''
              Additional libraries to add to the wrapper's runtime LD_LIBRARY_PATH.
              This is useful if the wrapped program needs additional libraries or tools to function correctly.

              Adds all its entries to the DAG under the name `NIX_LIB_ADDITIONS`
            '';
          };
      config.${
        if excluded.extraPackages or false && excluded.runtimeLibraries or false then "suffixVar" else null
      } =
        lib.optional (config.extraPackages != [ ]) {
          name = "NIX_PATH_ADDITIONS";
          data = [
            "PATH"
            ":"
            "${lib.makeBinPath config.extraPackages}"
          ];
        }
        ++ lib.optional (config.runtimeLibraries != [ ]) {
          name = "NIX_LIB_ADDITIONS";
          data = [
            "LD_LIBRARY_PATH"
            ":"
            "${lib.makeLibraryPath config.runtimeLibraries}"
          ];
        };
      options.${if !(excluded.env or false) then "env" else null} = lib.mkOption {
        type = wlib.types.dagWithEsc wlib.types.stringable;
        default = if mainConfig != null && config.mirror or false then mainConfig.env else { };
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
      options.${if !(excluded.envDefault or false) then "envDefault" else null} = lib.mkOption {
        type = wlib.types.dagWithEsc wlib.types.stringable;
        default = if mainConfig != null && config.mirror or false then mainConfig.envDefault else { };
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
      options.${if !(excluded.escapingFunction or false) then "escapingFunction" else null} =
        lib.mkOption
          {
            type = lib.types.functionTo lib.types.str;
            default =
              if mainConfig != null && config.mirror or false then
                mainConfig.escapingFunction
              else
                lib.escapeShellArg;
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
      options.${if !(excluded.wrapperImplementation or false) then "wrapperImplementation" else null} =
        lib.mkOption
          {
            type = lib.types.enum [
              "nix"
              "shell"
              "binary"
            ];
            default =
              if mainConfig != null && config.mirror or false then mainConfig.wrapperImplementation else "nix";
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
      config._module.args = {
        mainConfig = null;
        mainOpts = null;
      };
      options.${if !(excluded.wrapperVariants or false) && is_top then "wrapperVariants" else null} =
        lib.mkOption
          {
            default = { };
            description = ''
              Allows for you to apply the wrapper options to multiple binaries from config.package (or elsewhere)

              They are called variants because they are the same options as the top level makeWrapper options,
              however, their defaults mirror the values of the top level options.

              Meaning if you set `config.env.MYVAR = "HELLO"` at the top level,
              then the following statement would be true by default:

              `config.wrapperVariants.foo.env.MYVAR.data == "HELLO"`

              They achieve this by receiving `mainConfig` and `mainOpts` via `specialArgs`,
              which contain `config` and `options` from the top level.
            '';
            type = lib.types.attrsOf (
              lib.types.submoduleWith {
                specialArgs = {
                  mainConfig = config;
                  mainOpts = options;
                  inherit wlib;
                };
                modules = [
                  (options_module excluded false)
                  (
                    { name, ... }:
                    {
                      options.enable = lib.mkOption {
                        type = lib.types.bool;
                        default = true;
                        description = ''
                          Enables the wrapping of this variant
                        '';
                      };
                      options.mirror = lib.mkOption {
                        type = lib.types.bool;
                        default = true;
                        description = ''
                          Allows the variant to inherit defaults from the top level
                        '';
                      };
                      options.exePath = lib.mkOption {
                        type = lib.types.nullOr wlib.types.nonEmptyLine;
                        default = "bin/${name}";
                        description = ''
                          The location within the package of the thing to wrap.
                        '';
                      };
                      options.binName = lib.mkOption {
                        type = wlib.types.nonEmptyLine;
                        default = name;
                        description = ''
                          The name of the file to output to `$out/bin/`
                        '';
                      };
                      options.package = lib.mkOption {
                        type = wlib.types.stringable;
                        default = config.package;
                        description = ''
                          The package to wrap with these options
                        '';
                      };
                    }
                  )
                ];
              }
            );
          };
    };
  usage_err = name: ''
    ERROR: usage of ${name} is as follows:

    (import wlib.modules.makeWrapper).${name} {
      inherit config wlib;
      inherit (pkgs) callPackage; # or `inherit pkgs`;${
        if name != "wrapVariant" then "" else "\n  name = \"attribute\";\n"
      }
    };${
      if name != "wrapVariant" then
        ""
      else
        "\n\nWhere `attribute` is a valid attribute of the `config.wrapperVariants` set"
    }
  '';
in
{
  wrapperFunction = import ./. null;

  wrapAll =
    {
      pkgs ? null,
      wlib,
      callPackage ? pkgs.callPackage or (usage_err "wrapAll"),
      config,
    }:
    callPackage (import ./. null) { inherit config wlib; };
  wrapMain =
    {
      pkgs ? null,
      wlib,
      callPackage ? pkgs.callPackage or (usage_err "wrapMain"),
      config,
    }:
    callPackage (import ./. false) { inherit config wlib; };
  wrapVariants =
    {
      pkgs ? null,
      wlib,
      callPackage ? pkgs.callPackage or (usage_err "wrapVariants"),
      config,
    }:
    callPackage (import ./. true) { inherit config wlib; };
  wrapVariant =
    {
      pkgs ? null,
      wlib,
      callPackage ? pkgs.callPackage or (usage_err "wrapVariant"),
      config,
      name,
    }:
    assert builtins.isString name || usage_err "wrapVariant";
    callPackage (import ./. name) { inherit config wlib; };

  excluded_options = { };
  exclude_wrapper = false;
  exclude_meta = false;
  __functor =
    self:
    {
      wlib,
      lib,
      ...
    }:
    {
      _file = ./module.nix;
      key = ./module.nix;
      imports = [ (options_module (self.excluded_options or { }) true) ];
      config.${if self.exclude_wrapper or false then null else "wrapperFunction"} = lib.mkDefault (
        self.wrapperFunction or (import ./. null)
      );
      config.${if self.exclude_meta or false then null else "meta"} = {
        maintainers = lib.mkDefault [ wlib.maintainers.birdee ];
        description = lib.mkDefault {
          pre = ''
            An implementation of the `makeWrapper` interface via type safe module options.

            Allows you to choose one of several underlying implementations of the `makeWrapper` interface.

            Imported by `wlib.modules.default`

            Wherever the type includes `DAG` you can mentally substitute this with `attrsOf`

            Wherever the type includes `DAL` or `DAG list` you can mentally substitute this with `listOf`

            However they also take items of the form `{ data, name ? null, before ? [], after ? [] }`

            This allows you to specify that values are added to the wrapper before or after another value.

            The sorting occurs across ALL the options, thus you can target items in any `DAG` or `DAL` within this module from any other `DAG` or `DAL` option within this module.

            The `DAG`/`DAL` entries in this module also accept an extra field, `esc-fn ? null`

            If defined, it will be used instead of the value of `options.escapingFunction` to escape that value.

            It also has a set of submodule options under `config.wrapperVariants` which allow you
            to duplicate the effects to other binaries from the package, or add extra ones.

            Each one contains an `enable` option, and a `mirror` option.

            They also contain the same options the top level module does, however if `mirror` is `true`,
            as it is by default, then they will inherit the defaults from the top level as well.

            They also have their own `package`, `exePath`, and `binName` options, with sensible defaults.

            ---
          '';
          post = ''
            ---

            ## The `makeWrapper` library:

            Should you ever need to redefine `config.wrapperFunction`, or use these options somewhere else,
            this module doubles as a library for doing so!

            `makeWrapper = import wlib.modules.makeWrapper;`

            If you import it like shown, you gain access to some values.

            First, you may modify the module itself.

            For this it offers:

            `exclude_wrapper = true;` to stop it from setting `config.wrapperFunction`

            `wrapperFunction = ...;` to override the default `config.wrapperFunction` that it sets instead of excluding it.

            `exclude_meta = true;` to stop it from setting any values in `config.meta`

            `excluded_options = { ... };` where you may include `optionname = true`
            in order to not define that option.

            In order to change these values, you change them in the set before importing the module like so:

            ```nix
              imports = [ (import wlib.modules.makeWrapper // { excluded_options.wrapperVariants = true; }) ];
            ```

            It also offers 4 functions for using those options to generate build instructions for a wrapper

            - `wrapAll`: generates build instructions for the main target and all variants
            - `wrapMain`: generates build instructions for the main target
            - `wrapVariants`: generates build instructions for all variants but not the main target
            - `wrapVariant`: generates build instructions for a single variant

            All 4 of them return a string that can be added to the derivation definition to build the specified wrappers.

            The first 3, `wrapAll`, `wrapMain`, and `wrapVariants`, are used like this:

            (import wlib.modules.makeWrapper).wrapAll {
              inherit config wlib;
              inherit (pkgs) callPackage; # or `inherit pkgs`;
            };

            The 4th, `wrapVariant`, has an extra `name` argument:

            (import wlib.modules.makeWrapper).wrapVariant {
              inherit config wlib;
              inherit (pkgs) callPackage; # or `inherit pkgs`;
              name = \"attribute\";
            };

            Where `attribute` is an attribute of the `config.wrapperVariants` set

            Other than whatever options from the `wlib.modules.makeWrapper` module
            are defined in the `config` variable passed,
            each one relies on `config` containing `binName`, `package`, and `exePath`.

            If `config.exePath` is not a string or is an empty string,
            `config.package` will be the full path wrapped.
            Otherwise, it will wrap `"''${config.package}/''${config.binName}`.

            If `config.binName` or `config.package` are not provided it will return an empty string for that target.

            In addition, if a variant has `enable` set to `false`, it will also not be included in the returned string.
          '';
        };
      };
    };
}
