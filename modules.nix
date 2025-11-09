{ lib, wlib }:
let
  all_mod_results = import ./modules { inherit lib wlib; };
in
(builtins.removeAttrs all_mod_results [ "modules" ])
// {
  modules = (all_mod_results.modules or { }) // rec {
    default = {
      imports = [
        symlinkScript
        makeWrapper
        basic
      ];
    };
    basic =
      {
        config,
        lib,
        wlib,
        ...
      }:
      {
        options.preHook = lib.mkOption {
          type = lib.types.nullOr lib.types.lines;
          default = null;
          internal = true;
          description = "deprecated alias for wrapArgs.\"--run\" = [ string ]";
        };
        config.wrapArgs."--run" = lib.mkIf (config.preHook != null) (
          lib.warn
            "preHook has been changed to wrapArgs.\"--run\" = [ string ]. wrapProgram now takes a module!"
            [ config.preHook ]
        );
        options.runtimeInputs = lib.mkOption {
          type = lib.types.nullOr (lib.types.listOf lib.types.package);
          default = null;
          internal = true;
          description = "deprecated alias for extraPackages";
        };
        config.extraPackages = lib.mkIf (config.runtimeInputs != null) (
          lib.warn "runtimeInputs has been renamed to extraPackages. wrapProgram now takes a module!" config.runtimeInputs
        );

        options.flags = lib.mkOption {
          type = lib.types.attrsOf lib.types.unspecified; # TODO add list handling
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
        options.args = lib.mkOption {
          type = lib.types.listOf (lib.types.oneOf [ lib.types.str or lib.types.package ]);
          default = [ ];
          description = ''
            Command-line arguments to pass to the wrapper (like argv in execve).
            This is a list of strings representing individual arguments.
            If not specified, will be automatically generated from flags.
          '';
        };
        config.wrapArgs."--add-flag" = lib.mkIf (
          (config.args or [ ]) != [ ] || (config.flags or { }) != { }
        ) (config.args ++ wlib.generateArgsFromFlags (config.flagSeparator or " ") config.flags);

        options.env = lib.mkOption {
          type = lib.types.attrsOf (lib.types.oneOf [ lib.types.str or lib.types.package ]);
          default = { };
          description = ''
            Environment variables to set in the wrapper.
          '';
        };
        config.wrapArgs."--set" = lib.mkIf ((config.env or { }) != { }) (
          lib.mapAttrsToList (n: v: [
            n
            "${v}"
          ]) config.env
        );

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
        config.wrapArgs."--suffix" =
          lib.mkIf ((config.extraPackages or [ ]) != [ ] || (config.runtimeLibraries or [ ]) != [ ])
            (
              lib.optionals ((config.extraPackages or [ ]) != [ ]) [
                "PATH"
                ":"
                "${lib.makeBinPath config.extraPackages}"
              ]
              ++ lib.optionals ((config.runtimeLibraries or [ ]) != [ ]) [
                "LD_LIBRARY_PATH"
                ":"
                "${lib.makeLibraryPath config.extraPackages}"
              ]
            );
      };

    symlinkScript =
      {
        config,
        lib,
        wlib,
        ...
      }:
      {
        options = {
          aliases = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [ ];
            description = "Aliases for the package to also be added to the PATH";
          };
          filesToPatch = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [ "share/applications/*.desktop" ];
            description = ''
              List of file paths (glob patterns) relative to package root to patch for self-references.
              Desktop files are patched by default to update Exec= and Icon= paths.
            '';
          };
          filesToExclude = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [ ];
            description = ''
              List of file paths (glob patterns) relative to package root to exclude from the wrapped package.
              This allows filtering out unwanted binaries or files.
              Example: [ "bin/unwanted-tool" "share/applications/*.desktop" ]
            '';
          };
        };
        config.extraDrvAttrs.nativeBuildInputs = lib.mkIf ((config.filesToPatch or [ ]) != [ ]) [
          config.pkgs.replace
        ];
        config.symlinkScript = lib.mkDefault (
          {
            config,
            wlib,
            wrapper,
            # other args from callPackage
            lib,
            lndir,
            ...
          }:
          let
            inherit (config)
              package
              aliases
              binName
              outputs
              filesToPatch
              filesToExclude
              ;
            originalOutputs = wlib.getPackageOutputsSet package;
          in
          ''
            # Symlink all paths to the main output
            mkdir -p $out
            for path in ${
              lib.concatStringsSep " " (
                map toString (
                  (lib.optional (wrapper != null) wrapper)
                  ++ [
                    package
                  ]
                )
              )
            }; do
              ${lndir}/bin/lndir -silent "$path" $out
            done

            # Exclude specified files
            ${lib.optionalString (filesToExclude != [ ]) ''
              echo "Excluding specified files..."
              ${lib.concatMapStringsSep "\n" (pattern: ''
                for file in $out/${pattern}; do
                  if [[ -e "$file" ]]; then
                    echo "Removing $file"
                    rm -f "$file"
                  fi
                done
              '') filesToExclude}
            ''}

            # Patch specified files to replace references to the original package with the wrapped one
            ${lib.optionalString (filesToPatch != [ ]) ''
              echo "Patching self-references in specified files..."
              oldPath="${package}"
              newPath="$out"

              # Process each file pattern
              ${lib.concatMapStringsSep "\n" (pattern: ''
                for file in $out/${pattern}; do
                  if [[ -L "$file" ]]; then
                    # It's a symlink, we need to resolve it
                    target=$(readlink -f "$file")

                    # Check if the file contains the old path
                    if grep -qF "$oldPath" "$target" 2>/dev/null; then
                      echo "Patching $file"
                      # Remove symlink and create a real file with patched content
                      rm "$file"
                      # Use replace-literal which works for both text and binary files
                      replace-literal "$oldPath" "$newPath" < "$target" > "$file"
                      # Preserve permissions
                      chmod --reference="$target" "$file"
                    fi
                  fi
                done
              '') filesToPatch}
            ''}

            # Create symlinks for aliases
            ${lib.optionalString (aliases != [ ] && binName != null && binName != "") ''
              mkdir -p $out/bin
              for alias in ${lib.concatStringsSep " " (map lib.escapeShellArg aliases)}; do
                ln -sf ${lib.escapeShellArg binName} $out/bin/$alias
              done
            ''}

            # Handle additional outputs by symlinking from the original package's outputs
            ${lib.concatMapStringsSep "\n" (
              output:
              if output != "out" && originalOutputs ? ${output} && originalOutputs.${output} != null then
                ''
                  if [[ -n "''${${output}:-}" ]]; then
                    mkdir -p ${"$" + output}
                    # Only symlink from the original package's corresponding output
                    ${lndir}/bin/lndir -silent "${originalOutputs.${output}}" ${"$" + output}
                  fi
                ''
              else
                ""
            ) outputs}

          ''
        );
      };

    makeWrapper =
      {
        wlib,
        lib,
        ...
      }:
      {
        options.wrapArgs = {
          argv0 = lib.mkOption {
            type = lib.types.enum [
              "set"
              "resolve"
              "inherit"
            ];
            default = "inherit";
            description = ''
              If "set" is provided, `wrapArgs."--argv0"` must be provided as well.

              The other options require no further configuration.

              Possible values are:

              `"set"`:

              --argv0 NAME

              Set the name of the executed process to NAME.
              If unset or empty, defaults to EXECUTABLE.
              If "set" is provided, `wrapArgs."--argv0"` must be provided as well.

              `"inherit"`:
              `--inherit-argv0`

              The executable inherits argv0 from the wrapper.
              Use instead of --argv0 '$0'.

              `"resolve"`:

              `--resolve-argv0`

              If argv0 does not include a "/" character, resolve it against PATH.
            '';
          };
          "--argv0" = wlib.mkWrapperFlag {
            len = lib.types.nullOr lib.types.str;
            description = ''
              --argv0 NAME

              Set the name of the executed process to NAME.
              If unset or empty, defaults to EXECUTABLE.
            '';
          };
          "--set" = wlib.mkWrapperFlag {
            len = 2;
            description = ''
              --set VAR VAL

              Add VAR with value VAL to the executable's environment.
            '';
          };
          "--set-default" = wlib.mkWrapperFlag {
            len = 2;
            description = ''
              --set-default VAR VAL

              Like --set, but only adds VAR if not already set in the environment.
            '';
          };
          "--unset" = wlib.mkWrapperFlag {
            len = 1;
            description = ''
              --unset VAR

              Remove VAR from the environment.
            '';
          };
          "--chdir" = wlib.mkWrapperFlag {
            len = lib.types.nullOr lib.types.str;
            description = ''
              --chdir DIR

              Change working directory before running the executable.
              Use instead of --run "cd DIR".
            '';
          };
          "--run" = wlib.mkWrapperFlag {
            len = 1;
            description = ''
              --run COMMAND

              Run COMMAND before executing the main program.
            '';
          };
          "--add-flag" = wlib.mkWrapperFlag {
            len = 1;
            description = ''
              --add-flag ARG

              Prepend the single argument ARG to the invocation of the executable,
              before any command-line arguments.
            '';
          };
          "--append-flag" = wlib.mkWrapperFlag {
            len = 1;
            description = ''
              --append-flag ARG

              Append the single argument ARG to the invocation of the executable,
              after any command-line arguments.
            '';
          };
          "--add-flags" = wlib.mkWrapperFlag {
            len = 1;
            description = ''
              --add-flags ARGS

              Prepend ARGS verbatim to the Bash-interpreted invocation of the executable.
            '';
          };
          "--append-flags" = wlib.mkWrapperFlag {
            len = 1;
            description = ''
              --append-flags ARGS

              Append ARGS verbatim to the Bash-interpreted invocation of the executable.
            '';
          };
          "--prefix" = wlib.mkWrapperFlag {
            len = 3;
            description = ''
              --prefix ENV SEP VAL

              Prefix or suffix ENV with VAL, separated by SEP.
            '';
          };
          "--suffix" = wlib.mkWrapperFlag {
            len = 3;
            description = ''
              --suffix ENV SEP VAL

              Suffix or prefix ENV with VAL, separated by SEP.
            '';
          };
          "--prefix-each" = wlib.mkWrapperFlag {
            len = 3;
            description = ''
              --prefix-each ENV SEP VALS

              Like --prefix, but VALS is a list.
            '';
          };
          "--suffix-each" = wlib.mkWrapperFlag {
            len = 3;
            description = ''
              --suffix-each ENV SEP VALS

              Like --suffix, but VALS is a list.
            '';
          };
          "--prefix-contents" = wlib.mkWrapperFlag {
            len = 3;
            description = ''
              --prefix-contents ENV SEP FILES

              Like --suffix-each, but contents of FILES are read first and used as VALS.
            '';
          };
          "--suffix-contents" = wlib.mkWrapperFlag {
            len = 3;
            description = ''
              --suffix-contents ENV SEP FILES

              Like --prefix-each, but contents of FILES are read first and used as VALS.
            '';
          };
        };
        config.wrapperFunction = lib.mkDefault (
          {
            config,
            wlib,
            pkgs,
            ...
          }:
          let
            binName = if config.binName != null then config.binName else "";
            argv0 =
              if config.wrapArgs.argv0 or "" == "set" then
                (
                  if builtins.isString (config.wrapArgs."--argv0" or null) then
                    [ ]
                  else
                    builtins.throw "If wrapArgs.argv0 is set to \"set\", then wrapArgs.\"--argv0\" must be a string"
                )
              else if config.wrapArgs.argv0 or "" == "resolve" then
                [ "--resolve-argv0" ]
              else
                [ "--inherit-argv0" ];
          in
          pkgs.runCommand "${binName}-wrapped"
            {
              nativeBuildInputs = [ pkgs.makeWrapper ];
            }
            (
              if binName == "" then
                "mkdir -p $out"
              else
                # bash
                ''
                  makeWrapper ${
                    lib.escapeShellArgs (
                      [
                        "${config.package}/bin/${binName}"
                        "${placeholder "out"}/bin/${binName}"
                      ]
                      ++ argv0
                      ++ wlib.argOpts2list (builtins.removeAttrs config.wrapArgs [ "argv0" ])
                    )
                  }
                ''
            )

        );
      };

    makeBinaryWrapper =
      {
        wlib,
        lib,
        ...
      }:
      {
        options.wrapArgs = {
          argv0 = lib.mkOption {
            type = lib.types.enum [
              "set"
              "resolve"
              "inherit"
            ];
            default = "inherit";
            description = ''
              If "set" is provided, `wrapArgs."--argv0"` must be provided as well.

              The other options require no further configuration.

              Possible values are:

              `"set"`:

              --argv0 NAME

              Set the name of the executed process to NAME.
              If unset or empty, defaults to EXECUTABLE.
              If "set" is provided, `wrapArgs."--argv0"` must be provided as well.

              `"inherit"`:
              `--inherit-argv0`

              The executable inherits argv0 from the wrapper.
              Use instead of --argv0 '$0'.

              `"resolve"`:

              `--resolve-argv0`

              If argv0 does not include a "/" character, resolve it against PATH.
            '';
          };
          "--argv0" = wlib.mkWrapperFlag {
            len = lib.types.nullOr lib.types.str;
            description = ''
              --argv0 NAME

              Set the name of the executed process to NAME.
              If unset or empty, defaults to EXECUTABLE.
            '';
          };

          "--set" = wlib.mkWrapperFlag {
            len = 2;
            description = ''
              --set VAR VAL

              Adds VAR with value VAL to the environment.
            '';
          };
          "--set-default" = wlib.mkWrapperFlag {
            len = 2;
            description = ''
              --set-default VAR VAL

              Like --set, but only adds VAR if not already defined.
            '';
          };
          "--unset" = wlib.mkWrapperFlag {
            len = 1;
            description = ''
              --unset VAR

              Removes VAR from the environment.
            '';
          };
          "--chdir" = wlib.mkWrapperFlag {
            len = lib.types.nullOr lib.types.str;
            description = ''
              --chdir DIR

              Changes working directory before running the executable.
            '';
          };
          "--add-flag" = wlib.mkWrapperFlag {
            len = 1;
            description = ''
              --add-flag ARG

              Prepends a single argument ARG before command-line arguments.
            '';
          };
          "--append-flag" = wlib.mkWrapperFlag {
            len = 1;
            description = ''
              --append-flag ARG

              Appends a single argument ARG after command-line arguments.
            '';
          };
          "--add-flags" = wlib.mkWrapperFlag {
            len = 1;
            description = ''
              --add-flags ARGS

              Prepends a whitespace-separated list of ARGS before command-line arguments.
            '';
          };
          "--append-flags" = wlib.mkWrapperFlag {
            len = 1;
            description = ''
              --append-flags ARGS

              Appends a whitespace-separated list of ARGS after command-line arguments.
            '';
          };
          "--prefix" = wlib.mkWrapperFlag {
            len = 3;
            description = ''
              --prefix ENV SEP VAL

              Prefixes ENV with VAL, separated by SEP.
            '';
          };
          "--suffix" = wlib.mkWrapperFlag {
            len = 3;
            description = ''
              --suffix ENV SEP VAL

              Suffixes ENV with VAL, separated by SEP.
            '';
          };
        };
        config.wrapperFunction = lib.mkDefault (
          {
            config,
            wlib,
            pkgs,
            ...
          }:
          let
            binName = if config.binName != null then config.binName else "";
            argv0 =
              if config.wrapArgs.argv0 or "" == "set" then
                (
                  if builtins.isString (config.wrapArgs."--argv0" or null) then
                    [ ]
                  else
                    builtins.throw "If wrapArgs.argv0 is set to \"set\", then wrapArgs.\"--argv0\" must be a string"
                )
              else if config.wrapArgs.argv0 or "" == "resolve" then
                [ "--resolve-argv0" ]
              else
                [ "--inherit-argv0" ];
          in
          pkgs.runCommand "${binName}-wrapped"
            {
              nativeBuildInputs = [ pkgs.makeBinaryWrapper ];
            }
            (
              if binName == "" then
                "mkdir -p $out"
              else
                # bash
                ''
                  makeWrapper ${
                    lib.escapeShellArgs (
                      [
                        "${config.package}/bin/${binName}"
                        "${placeholder "out"}/bin/${binName}"
                      ]
                      ++ argv0
                      ++ wlib.argOpts2list (builtins.removeAttrs config.wrapArgs [ "argv0" ])
                    )
                  }
                ''
            )
        );
      };

  };
}
