{ lib, wlib }:
evalArgs:
let
  coreModule =
    {
      config,
      lib,
      wlib,
      ...
    }:
    {
      options = {
        pkgs = lib.mkOption {
          description = ''
            The nixpkgs pkgs instance to use.

            Required in order to access `.wrapper` attribute,
            either directly, or indirectly.
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
        passthru = lib.mkOption {
          type = lib.types.attrs;
          default = { };
          description = ''
            Additional attributes to add to the resulting derivation's passthru.
            This can be used to add additional metadata or functionality to the wrapped package.
            This will always contain options, config and settings, so these are reserved names and cannot be used here.
          '';
        };
        extraDrvAttrs = lib.mkOption {
          default = { };
          type = lib.types.attrsOf lib.types.raw;
          description = ''Extra attributes to add to the resulting derivation.'';
        };
        binName = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = ''
            The name of the binary output by `wrapperFunction`.
            If not specified, the name of the package will be used.
            If set as an empty string, wrapperFunction may behave unpredictably, depending on its implementation.
          '';
        };
        outputs = lib.mkOption {
          type = lib.types.nullOr (lib.types.listOf lib.types.str);
          default = null;
          description = ''
            Override the list of nix outputs that get symlinked into the final package.
          '';
        };
        wrap = lib.mkOption {
          type = lib.types.functionTo lib.types.raw;
          readOnly = true;
          description = ''
            Function to extend the current configuration with additional modules.
            Re-evaluates the configuration with the original settings plus the new module.
            Returns the updated package.
          '';
          default = module: (config.eval module).config.wrapper;
        };
        apply = lib.mkOption {
          type = lib.types.functionTo lib.types.raw;
          readOnly = true;
          description = ''
            Function to extend the current configuration with additional modules.
            Re-evaluates the configuration with the original settings plus the new module.
          '';
          default = module: (config.eval module).config;
        };
        eval = lib.mkOption {
          type = lib.types.functionTo lib.types.raw;
          readOnly = true;
          description = ''
            Function to extend the current configuration with additional modules.
            Re-evaluates the configuration with the original settings plus the new module.
            Returns the raw evaluated module.
          '';
          default =
            module:
            evaled.extendModules {
              modules = [
                config._moduleSettings
                module
                {
                  _moduleSettings = lib.mkForce {
                    imports = [
                      config._moduleSettings
                      module
                    ];
                  };
                }
              ];
            };
        };
        meta = {
          maintainers = lib.mkOption {
            description = "Maintainers of this wrapper module.";
            type = lib.types.listOf (
              lib.types.submodule (
                { name, ... }:
                {
                  options = {
                    name = lib.mkOption {
                      type = lib.types.str;
                      default = name;
                      description = "name";
                    };
                    github = lib.mkOption {
                      type = lib.types.str;
                      description = "GitHub username";
                    };
                    githubId = lib.mkOption {
                      type = lib.types.int;
                      description = "GitHub id";
                    };
                    email = lib.mkOption {
                      type = lib.types.nullOr lib.types.str;
                      default = null;
                      description = "email";
                    };
                    matrix = lib.mkOption {
                      type = lib.types.nullOr lib.types.str;
                      default = null;
                      description = "Matrix ID";
                    };
                  };
                }
              )
            );
            default = [ ];
          };
          platforms = lib.mkOption {
            type = lib.types.listOf (lib.types.enum lib.platforms.all);
            default = lib.platforms.all;
            description = "Supported platforms";
          };
        };
        wrapperFunction = lib.mkOption {
          type = with lib.types; nullOr (functionTo package);
          default = null;
          description = ''
            A function which returns a package.

            Arguments:

            `{ config, wlib, outputs, binName, /* other args from callPackage */ ... }`

            That package returned must contain `"$out/bin/''${binName}"`
            as the executable to be wrapped.
            (unless you also override `symlinkScript`)

            `binName` is the value of `config.binName` if non-null, otherwise it is given a default value via `baseNameOf` `lib.getExe`

            The value of `config.binName` is left as the user of the module set it, so that you can know who is giving you the value.

            The same is true of the `outputs` argument.

            The usual implementation is imported via `wlib.modules.makeWrapperBase`

            `wlib.modules.makeWrapper` and `wlib.modules.default` include that module automatically.
          '';
        };
        sourceStdenv = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = ''
            Whether to call $stdenv/setup to set up the environment before the symlinkScript

            If any phases are enabled, also runs the enabled phases after the symlinkScript command has ran.

            NOTE: often you may prefer to set `extraDrvAttrs.phases = [ ... "buildPhase" etc ... ];` instead,
            to override this choice in a more fine-grained manner
          '';
        };
        symlinkScript = lib.mkOption {
          type = lib.types.functionTo lib.types.str;
          description = ''
            Outside of importing `wlib.modules.symlinkScript` module,
            which is included in `wlib.modules.default`,
            This is usually an option you will never have to redefine.

            This option takes a function receiving the following arguments:
            ```
            {
              wlib,
              config,
              outputs,
              binName,
              wrapper,
              ... # <- anything you can get from pkgs.callPackage
            }:
            ```
            The function is to return a string which will be added to the buildCommand of the wrapper.
            It is in charge of taking those options, and linking the files into place as requested.

            `binName` is the value of `config.binName` if non-null, otherwise it is given a default value via `baseNameOf` `lib.getExe` on the `config.package` value

            The value of `config.binName` is left as the user of the module set it, so that you can know who is giving you the value.

            The same is true of the `outputs` argument.

            `wrapper` is the result of calling `wrapperFunction`, or null if one was not provided.
          '';
          default =
            {
              wlib,
              config,
              outputs,
              binName,
              wrapper,
              lib,
              lndir,
              ...
            }:
            let
              path = if wrapper != null then wrapper else config.package;
              originalOutputs = wlib.getPackageOutputsSet config.package;
            in
            ''
              mkdir -p $out
              ${lndir}/bin/lndir -silent "${path}" $out

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
            '';
        };
        wrapper = lib.mkOption {
          type = lib.types.package;
          readOnly = true;
          description = ''
            The final wrapped package.

            You may still call `.eval` and the rest on the package again afterwards.

            Accessing this value without defining `pkgs` option,
            either directly, or via some other means like `.wrap`,
            will cause an error.
          '';
          default =
            let
              wrapPackageInternal =
                passthru:
                let
                  inherit (passthru.configuration) pkgs;
                in
                pkgs.stdenv.mkDerivation (
                  final:
                  let
                    # Extract binary name from the exe path
                    inherit (final.passthru.configuration) package;
                    binName =
                      if builtins.isString final.passthru.configuration.binName then
                        final.passthru.configuration.binName
                      else
                        baseNameOf (lib.getExe package);
                    outputs =
                      if final.passthru.configuration.outputs != null then
                        final.passthru.configuration.outputs
                      else if package.outputs or null != null then
                        package.outputs
                      else
                        [ "out" ];
                    wrapper =
                      if final.passthru.configuration.wrapperFunction != null then
                        pkgs.callPackage final.passthru.configuration.wrapperFunction {
                          config = final.passthru.configuration;
                          inherit binName outputs wlib;
                        }
                      else
                        null;
                  in
                  {
                    name = package.pname or package.name;
                    inherit outputs;
                    passthru = passthru // {
                      wrap = final.passthru.configuration.wrap;
                      apply = final.passthru.configuration.apply;
                      eval = final.passthru.configuration.eval;
                      override =
                        overrideArgs:
                        wrapPackageInternal (
                          final.passthru
                          // {
                            config = final.passthru.configuration // {
                              package = package.override overrideArgs;
                            };
                          }
                        );
                    };
                    nativeBuildInputs = final.passthru.configuration.extraDrvAttrs.nativeBuildInputs or [ ];
                    phases = [
                      "buildPhase"
                      "checkPhase"
                      "installPhase"
                      "installCheckPhase"
                      "fixupPhase"
                      "distPhase"
                    ];
                    buildPhase = ''
                      runHook preBuild
                      runHook postBuild
                    '';
                    installPhase = ''
                      runHook preInstall
                      runHook postInstall
                    '';
                    buildCommand =
                      (
                        if final.passthru.configuration.sourceStdenv then
                          ''
                            source $stdenv/setup
                          ''
                        else
                          ""
                      )
                      + pkgs.callPackage final.passthru.configuration.symlinkScript {
                        config = final.passthru.configuration;
                        inherit
                          binName
                          outputs
                          wrapper
                          wlib
                          ;
                      }
                      + (
                        if final.passthru.configuration.sourceStdenv then
                          ''

                            for phase in ''${phases[@]}; do
                              # Some phases are conditional
                              if [ "$phase" = "checkPhase" ] && [ "$doCheck" != 1 ]; then
                                continue
                              fi
                              if [ "$phase" = "installCheckPhase" ] && [ "$doInstallCheck" != 1 ]; then
                                continue
                              fi
                              if [ "$phase" = "distPhase" ] && [ "$doDist" != 1 ]; then
                                continue
                              fi
                              # call the function defined earlier, e.g., buildPhase()
                              $phase
                            done
                          ''
                        else
                          ""
                      );
                    meta =
                      (package.meta or { })
                      //
                        lib.optionalAttrs
                          (final.passthru.configuration.binName != null && final.passthru.configuration.binName != "")
                          {
                            mainProgram = "$out/bin/${binName}";
                          };
                    version =
                      package.version or final.meta.version or package.revision or final.meta.revision or package.rev
                        or final.meta.rev or package.release or final.meta.release or package.releaseDate
                          or final.meta.releaseDate or "master";
                    pname = package.pname or package.name or binName;
                  }
                  // builtins.removeAttrs passthru.configuration.extraDrvAttrs [
                    "passthru"
                    "buildCommand"
                    "nativeBuildInputs"
                    "outputs"
                  ]
                );
            in
            wrapPackageInternal (
              config.passthru
              // {
                configuration = config;
              }
            );
        };
        _moduleSettings = lib.mkOption {
          type = lib.types.raw;
          internal = true;
          description = ''
            Internal option storing the settings module passed to apply.
            Used by apply to re-evaluate with additional modules.
          '';
        };
      };
    };
  evaled =
    lib.evalModules {
      modules = [
        coreModule
      ]
      ++ (evalArgs.modules or [ ])
      ++ [
        { _moduleSettings = { }; }
      ];
      specialArgs = (evalArgs.specialArgs or { }) // {
        inherit wlib;
      };
    }
    // (builtins.removeAttrs evalArgs [
      "modules"
      "specialArgs"
    ]);
in
evaled
