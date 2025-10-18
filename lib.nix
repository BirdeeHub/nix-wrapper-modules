{ lib }:
let
  # Helper function to generate args list from flags attrset
  generateArgsFromFlags =
    flags: flagSeparator:
    lib.flatten (
      lib.mapAttrsToList (
        name: value:
        if value == false || value == null then
          [ ]
        else if value == { } then
          [ name ]
        else if lib.isList value then
          lib.flatten (
            map (
              v:
              if flagSeparator == " " then
                [
                  name
                  (toString v)
                ]
              else
                [ "${name}${flagSeparator}${toString v}" ]
            ) value
          )
        else if flagSeparator == " " then
          [
            name
            (toString value)
          ]
        else
          [ "${name}${flagSeparator}${toString value}" ]
      ) flags
    );

  /**
    A function to create a wrapper module.
    returns an attribute set with options and apply function.

    Example usage:
      helloWrapper = wrapModule (wlib: { config, ... }: {
        options.greeting = lib.mkOption {
          type = lib.types.str;
          default = "hello";
        };
        config.package = config.pkgs.hello;
        config.flags = {
          "--greeting" = config.greeting;
        };
        # Or use args directly:
        # config.args = [ "--greeting" config.greeting ];
      };

      helloWrapper.apply {
        pkgs = pkgs;
        greeting = "hi";
      };

      # This will return a derivation that wraps the hello package with the --greeting flag set to "hi".
  */
  wrapModule =
    packageInterface:
    let
      wrapperLib = {
        types = {
          inherit file;
        };
      };
      # pkgs -> module { content, path }
      file =
        # we need to pass pkgs here, because writeText is in pkgs
        pkgs:
        lib.types.submodule (
          { name, config, ... }:
          {
            options = {
              content = lib.mkOption {
                type = lib.types.lines;
                description = ''
                  content of file
                '';
              };
              path = lib.mkOption {
                type = lib.types.path;
                description = ''
                  the path to the file
                '';
                default = pkgs.writeText name config.content;
                defaultText = "pkgs.writeText name <content>";
              };
            };
          }
        );
      staticModules = [
        (
          { config, ... }:
          {
            options = {
              pkgs = lib.mkOption {
                description = ''
                  The nixpkgs pkgs instance to use.
                  We want to have this, so wrapper modules can be system agnostic.
                '';
              };
              package = lib.mkOption {
                type = lib.types.package;
                description = ''
                  The base package to wrap.
                  This means we inherit all other files from this package
                  (like man page, /share, ...)
                '';
              };
              extraPackages = lib.mkOption {
                type = lib.types.listOf lib.types.package;
                default = [ ];
                description = ''
                  Additional packages to add to the wrapper's runtime dependencies.
                  This is useful if the wrapped program needs additional libraries or tools to function correctly.
                  These packages will be added to the wrapper's runtime dependencies, ensuring they are available when the wrapped program is executed.
                '';
              };
              flags = lib.mkOption {
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
              flagSeparator = lib.mkOption {
                type = lib.types.str;
                default = " ";
                description = ''
                  Separator between flag names and values when generating args from flags.
                  " " for "--flag value" or "=" for "--flag=value"
                '';
              };
              args = lib.mkOption {
                type = lib.types.listOf lib.types.str;
                default = generateArgsFromFlags config.flags config.flagSeparator;
                description = ''
                  Command-line arguments to pass to the wrapper (like argv in execve).
                  This is a list of strings representing individual arguments.
                  If not specified, will be automatically generated from flags.
                '';
              };
              env = lib.mkOption {
                type = lib.types.attrsOf lib.types.str;
                default = { };
                description = ''
                  Environment variables to set in the wrapper.
                '';
              };
              passthru = lib.mkOption {
                type = lib.types.attrs;
                default = { };
                description = ''
                  Additional attributes to add to the resulting derivation's passthru.
                  This can be used to add additional metadata or functionality to the wrapped package.
                  This will always contain options, config and settings, so these are reserved names and cannot be used here.
                '';
              };
              filesToPatch = lib.mkOption {
                type = lib.types.listOf lib.types.str;
                default = [ "share/applications/*.desktop" ];
                description = ''
                  List of file paths (glob patterns) relative to package root to patch for self-references.
                  Desktop files are patched by default to update Exec= and Icon= paths.
                '';
              };
            };
          }
        )
      ];
      eval =
        settings:
        lib.evalModules {
          modules = [
            (
              { config, ... }:
              {
                options.interface = lib.mkOption {
                  type = lib.types.deferredModule;
                  default = packageInterface;
                };
                options.settings = lib.mkOption {
                  type = lib.types.deferredModule;
                  default = settings;
                };
                options.result = lib.mkOption {
                  type = lib.types.deferredModule;
                  apply =
                    v:
                    (lib.evalModules {
                      modules = [ v ];
                      specialArgs = {
                        wlib = wrapperLib;
                      };
                    });
                  default = {
                    imports = staticModules ++ [
                      config.interface
                      config.settings
                    ];
                  };
                };
              }
            )
          ];
        };
    in
    {
      # expose options to generate documentation of available modules
      options = (eval { }).config.result.options;
      apply =
        settings:
        let
          # Result of eval modules is a 'configuration' with options, config
          configuration = eval settings;
          config = configuration.config.result.config;
        in
        wrapPackage {
          pkgs = config.pkgs;
          package = config.package;
          runtimeInputs = config.extraPackages;
          flags = config.flags;
          flagSeparator = config.flagSeparator;
          args = config.args;
          env = config.env;
          filesToPatch = config.filesToPatch;
          passthru = {
            inherit configuration settings;
          }
          // config.passthru;
        };
    };

  /**
    Create a wrapped application that preserves all original outputs (man pages, completions, etc.)

    # Arguments

    - `pkgs`: The nixpkgs pkgs instance to use
    - `package`: The package to wrap
    - `runtimeInputs`: List of packages to add to PATH (optional)
    - `env`: Attribute set of environment variables to export (optional)
    - `flags`: Attribute set of command-line flags to add (optional)
    - `flagSeparator`: Separator between flag names and values when generating args from flags (optional, defaults to " ")
    - `args`: List of command-line arguments like argv in execve (optional, auto-generated from flags if not provided)
    - `preHook`: Shell script to run before executing the command (optional)
    - `passthru`: Attribute set to pass through to the wrapped derivation (optional)
    - `aliases`: List of additional names to symlink to the wrapped executable (optional)
    - `filesToPatch`: List of file paths (glob patterns) to patch for self-references (optional, defaults to ["share/applications/*.desktop"])
    - `wrapper`: Custom wrapper function (optional, defaults to exec'ing the original binary with args)
      - Called with { env, flags, args, envString, flagsString, exePath, preHook }

    # Example

    ```nix
    wrapPackage {
      pkgs = pkgs;
      package = pkgs.curl;
      runtimeInputs = [ pkgs.jq ];
      env = {
        CURL_CA_BUNDLE = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";
      };
      flags = {
        "--silent" = { }; # becomes --silent
        "--connect-timeout" = "30"; # becomes --connect-timeout 30
      };
      # Or use args directly:
      # args = [ "--silent" "--connect-timeout" "30" ];
      preHook = ''
        echo "Making request..." >&2
      '';
    }

    # Or with custom wrapper:
    wrapPackage pkgs.someProgram {
      wrapper = { exePath, flagsString, envString, preHook, ... }: ''
        ${envString}
        ${preHook}
        echo "Custom logic here"
        exec ${exePath} ${flagsString} "$@"
      '';
    }
    ```
  */
  wrapPackage =
    {
      pkgs,
      package,
      runtimeInputs ? [ ],
      env ? { },
      flags ? { },
      flagSeparator ? " ",
      # " " for "--flag value" or "=" for "--flag=value"
      args ? generateArgsFromFlags flags flagSeparator,
      preHook ? "",
      passthru ? { },
      aliases ? [ ],
      filesToPatch ? [ "share/applications/*.desktop" ],
      # List of file paths relative to package root to patch for self-references (e.g., ["bin/*", "lib/*.sh"])
      wrapper ? (
        {
          exePath,
          flagsString,
          envString,
          preHook,
          ...
        }:
        ''
          ${envString}
          ${preHook}
          exec ${exePath}${flagsString} "$@"
        ''
      ),
    }@funcArgs:
    let
      # Extract binary name from the exe path
      exePath = lib.getExe package;
      binName = baseNameOf exePath;

      # Generate environment variable exports
      envString =
        if env == { } then
          ""
        else
          lib.concatStringsSep "\n" (
            lib.mapAttrsToList (name: value: ''export ${name}="${toString value}"'') env
          )
          + "\n";

      # Generate flag arguments with proper line breaks and indentation
      flagsString =
        if args == [ ] then
          ""
        else
          " \\\n  " + lib.concatStringsSep " \\\n  " (map lib.escapeShellArg args);

      finalWrapper = wrapper {
        inherit
          env
          flags
          args
          envString
          flagsString
          exePath
          preHook
          ;
      };

      # Multi-output aware symlink join function with optional file patching
      multiOutputSymlinkJoin =
        {
          name,
          paths,
          outputs ? [ "out" ],
          originalOutputs ? { },
          passthru ? { },
          meta ? { },
          aliases ? [ ],
          binName ? null,
          filesToPatch ? [ ],
          ...
        }@args:
        pkgs.stdenv.mkDerivation (
          {
            inherit name outputs;

            nativeBuildInputs = lib.optionals (filesToPatch != [ ]) [ pkgs.replace ];

            buildCommand = ''
              # Symlink all paths to the main output
              mkdir -p $out
              for path in ${lib.concatStringsSep " " (map toString paths)}; do
                ${pkgs.lndir}/bin/lndir -silent "$path" $out
              done

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
              ${lib.optionalString (aliases != [ ] && binName != null) ''
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
                      ${pkgs.lndir}/bin/lndir -silent "${originalOutputs.${output}}" ${"$" + output}
                    fi
                  ''
                else
                  ""
              ) outputs}
            '';

            inherit passthru meta;
          }
          // (removeAttrs args [
            "name"
            "paths"
            "outputs"
            "originalOutputs"
            "passthru"
            "meta"
            "aliases"
            "binName"
            "filesToPatch"
          ])
        );

      # Get original package outputs for symlinking
      originalOutputs =
        if package ? outputs then
          lib.listToAttrs (
            map (output: {
              name = output;
              value = if package ? ${output} then package.${output} else null;
            }) package.outputs
          )
        else
          { };

      # Create the wrapper derivation using our multi-output aware symlink join
      wrappedPackage = multiOutputSymlinkJoin (
        {
          name = package.pname or package.name;
          paths = [
            (pkgs.writeShellApplication {
              name = binName;
              runtimeInputs = runtimeInputs;
              text = finalWrapper;
            })
            package
          ];
          outputs = if package ? outputs then package.outputs else [ "out" ];
          inherit
            originalOutputs
            aliases
            binName
            filesToPatch
            ;
          passthru =
            (package.passthru or { })
            // passthru
            // {
              inherit
                env
                flags
                args
                preHook
                aliases
                ;
              override =
                overrideArgs:
                wrapPackage (
                  funcArgs
                  // {
                    package = package.override overrideArgs;
                  }
                );
            };
          # Pass through original attributes
          meta = package.meta or { };
        }
        // lib.optionalAttrs (package ? version) {
          inherit (package) version;
        }
        // lib.optionalAttrs (package ? pname) {
          inherit (package) pname;
        }
      );
    in
    wrappedPackage;
in
{
  inherit wrapModule wrapPackage;
}
