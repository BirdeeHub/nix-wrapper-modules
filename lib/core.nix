{
  config,
  lib,
  wlib,
  ...
}@args:
let
  maintainersWithFiles =
    let
      maintainer = lib.types.submodule (
        { name, ... }:
        {
          freeformType = lib.types.raw;
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
      );
    in
    lib.types.listOf maintainer
    // {
      name = "maintainersWithFiles";
      getSubModules = null;
      merge =
        loc: defs:
        (lib.types.listOf maintainer).merge loc (
          lib.imap1 (
            n: def:
            (
              def
              // {
                value = lib.imap1 (
                  m: def':
                  maintainer.merge (loc ++ [ "[${toString n}-${toString m}]" ]) [
                    (
                      def
                      // {
                        value = def' // {
                          inherit (def) file;
                        };
                      }
                    )
                  ]
                ) def.value;
              }
            )
          ) defs
        );
    };
in
{
  config.meta.maintainers = lib.mkOverride 1001 [ lib.maintainers.birdee ];
  config.drv = lib.mkIf (config.extraDrvAttrs != null) (
    lib.warn "extraDrvAttrs has been renamed to `config.drv`" config.extraDrvAttrs
  );
  options = {
    meta = {
      maintainers = lib.mkOption {
        description = ''Maintainers of this module.'';
        type = maintainersWithFiles;
        default = [ ];
      };
      platforms = lib.mkOption {
        type = (lib.types.listOf (lib.types.enum lib.platforms.all)) // {
          description = "list of strings from enum of lib.platforms.all";
        };
        example = [
          "x86_64-linux"
          "aarch64-linux"
        ];
        default = lib.platforms.all;
        defaultText = "lib.platforms.all";
        description = "Supported platforms";
      };
    };
    pkgs = lib.mkOption {
      description = ''
        The nixpkgs pkgs instance to use.

        Required in order to access `.wrapper` attribute,
        either directly, or indirectly.
      '';
    };
    package = lib.mkOption {
      # If config.package has not changed since last using override or overrideAttrs
      # then use the package from override or overrideAttrs
      apply = v: if config.__package.old or null == v then config.__package.package else v;
      type = lib.types.package;
      description = ''
        The base package to wrap.
        This means `config.symlinkScript` will be responsible
        for inheriting all other files from this package
        (like man page, /share, ...)

        If you use `.override` or `.overrideAttrs` on the final wrapped package,
        it will override this value until you set `config.package`
        with a `lib.mkOverride` priority higher than the previous value of `config.package`
      '';
    };
    passthru = lib.mkOption {
      type = wlib.types.attrsRecursive;
      default = { };
      description = ''
        Additional attributes to add to the resulting derivation's passthru.
        This can be used to add additional metadata or functionality to the wrapped package.
        Anything added under the attribute name `configuration` will be ignored, as that value is used internally.
      '';
    };
    extraDrvAttrs = lib.mkOption {
      default = null;
      internal = true;
      type = lib.types.nullOr wlib.types.attrsRecursive;
      description = "DEPRECATED renamed to `drv`";
    };
    drv = lib.mkOption {
      default = { };
      type = wlib.types.attrsRecursive;
      description = ''
        Extra attributes to add to the resulting derivation.

        Cannot affect `passthru`, or `outputs`. For that,
        use `config.passthru`, or `config.outputs` instead.

        Also cannot override `buildCommand`.
        That is controlled by the `config.symlinkScript`
        and `config.sourceStdenv` options.
      '';
    };
    binName = lib.mkOption {
      type = lib.types.str;
      default = baseNameOf (lib.getExe config.package);
      description = ''
        The name of the binary output by `wrapperFunction` to `$out/bin`

        If not specified, the default name from the package will be used.

        If set as an empty string, `symlinkScript` or `wrapperFunction` may behave unpredictably, depending on its implementation.
      '';
    };
    exePath = lib.mkOption {
      type = lib.types.str;
      default = lib.removePrefix "/" (lib.removePrefix "${config.package}" (lib.getExe config.package));
      description = ''
        The relative path to the executable to wrap. i.e. `bin/exename`

        If not specified, the path gained from calling `lib.getExe` on `config.package` and subtracting the path to the package will be used.

        If set as an empty string, `symlinkScript` or `wrapperFunction` may behave unpredictably, depending on its implementation.
      '';
    };
    outputs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = config.package.outputs or [ "out" ];
      description = ''
        Override the list of nix outputs that get symlinked into the final package.
      '';
    };
    wrapperFunction = lib.mkOption {
      type = with lib.types; nullOr (functionTo raw);
      default = null;
      description = ''
        Arguments:

        This option takes a function receiving the following arguments:

        module arguments + pkgs.callPackage

        ```
        {
          config,
          wlib,
          ... # <- anything you can get from pkgs.callPackage
        }
        ```

        The result of this function is passed DIRECTLY to the value of the `symlinkScript` function.

        The relative path to the thing to wrap from within `config.package` is `config.exePath`

        You should wrap the package and place the wrapper at `"$out/bin/''${config.binName}"`
      '';
    };
    symlinkScript = lib.mkOption {
      type =
        with lib.types;
        functionTo (oneOf [
          str
          (functionTo (attrsOf raw))
        ]);
      description = ''
        Outside of importing `wlib.modules.symlinkScript` module,
        which is included in `wlib.modules.default`,
        This is usually an option you will never have to redefine.

        This option takes a function receiving the following arguments:

        module arguments + `wrapper` + pkgs.callPackage

        ```
        {
          wlib,
          config,
          wrapper,
          ... # <- anything you can get from pkgs.callPackage
        }:
        ```

        The function is to return a string which will be added to the buildCommand of the wrapper.

        It is in charge of linking `wrapper` and `config.outputs` to the final package.

        `wrapper` is the unchecked result of calling `wrapperFunction`, or null if one was not provided.

        The builtin implementation, and also the `wlib.modules.symlinkScript` module,
        accept either a string to prepend to the returned `buildCommand` string,
        or a derivation to link with lndir

        Alternatively, it may return a function.

        If it returns a function, that function will be given the final computed derivation attributes,
        and it will be expected to return the final attribute set to be passed to `pkgs.stdenv.mkDerivation`.

        Regardless of if you return a string or function,
        `passthru.wrap`, `passthru.apply`, `passthru.eval`, `passthru.override`,
        `passthru.overrideAttrs`, and `config.sourceStdenv` will be handled for you.
      '';
      default =
        {
          wlib,
          config,
          wrapper,
          lib,
          lndir,
          ...
        }:
        let
          path = if wrapper != null then wrapper else config.package;
          originalOutputs = wlib.getPackageOutputsSet config.package;
        in
        "mkdir -p $out \n"
        + (if builtins.isString wrapper then wrapper else "${lndir}/bin/lndir -silent \"${path}\" $out")
        + ''

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
          ) config.outputs}
        '';
    };
    sourceStdenv = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Whether to call $stdenv/setup to set up the environment before the symlinkScript

        If any phases are enabled, also runs the enabled phases after the symlinkScript command has ran.

        NOTE: often you may prefer to set `drv.phases = [ ... "buildPhase" etc ... ];` instead,
        to override this choice in a more fine-grained manner
      '';
    };
    wrap = lib.mkOption {
      type = lib.types.functionTo lib.types.package;
      readOnly = true;
      description = ''
        Function to extend the current configuration with additional modules.
        Can accept a single module, or a list of modules.
        Re-evaluates the configuration with the original settings plus the new module(s).

        Returns the updated package.
      '';
      default = module: (config.eval module).config.wrapper;
    };
    apply = lib.mkOption {
      type = lib.types.functionTo lib.types.raw;
      readOnly = true;
      description = ''
        Function to extend the current configuration with additional modules.
        Can accept a single module, or a list of modules.
        Re-evaluates the configuration with the original settings plus the new module(s).

        Returns `.config` from the `lib.evalModules` result
      '';
      default = module: (config.eval module).config;
    };
    eval = lib.mkOption {
      type = lib.types.functionTo lib.types.raw;
      readOnly = true;
      description = ''
        Function to extend the current configuration with additional modules.
        Can accept a single module, or a list of modules.
        Re-evaluates the configuration with the original settings plus the new module(s).

        Returns the raw `lib.evalModules` result
      '';
      default =
        module:
        let
          res = config.__extend {
            modules = (if builtins.isList module then module else [ module ]) ++ [
              {
                _file = ./core.nix;
                __extend = lib.mkOverride 0 res.extendModules;
              }
            ];
          };
        in
        res;
    };
    __extend = lib.mkOption {
      type = lib.types.mkOptionType {
        name = "lastWins";
        description = "All definitions (of the same priority) override the previous one";
        check = lib.isFunction;
        # merge is ordered latest first within the same priority
        merge = loc: defs: (builtins.head defs).value;
        emptyValue = _: { };
      };
      internal = true;
      description = ''
        Internal option storing the `.extendModules` function at each re-evaluation.
        Used by `.eval` to re-evaluate with additional modules.
      '';
    };
    __package = lib.mkOption {
      type = lib.types.mkOptionType {
        name = "lastWins";
        description = "All definitions (of the same priority) override the previous one";
        check =
          x:
          let
            ispkg = lib.types.package.check;
          in
          x == null || (ispkg (x.package or null) && ispkg (x.old or null));
        # merge is ordered latest first within the same priority
        merge = loc: defs: (builtins.head defs).value;
        emptyValue = null;
      };
      default = null;
      internal = true;
      description = ''
        holds the output of .override and .overrideAttrs
        along with what they were before.

        This allows the apply of the package option
        to figure out if it should be using the result of overrides or not
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
          passthru = config.passthru // {
            configuration = config;
          };
          inherit (passthru.configuration)
            pkgs
            package
            binName
            outputs
            ;
          meta = (package.meta or { }) // {
            mainProgram = binName;
          };
          drvargs = {
            passthru = passthru;
            dontUnpack = true;
            dontConfigure = true;
            dontPatch = true;
            name = package.pname or package.name or binName;
            pname = package.pname or package.name or binName;
            inherit outputs;
            inherit meta;
            version =
              package.version or meta.version or package.revision or meta.revision or package.rev or meta.rev
                or package.release or meta.release or package.releaseDate or meta.releaseDate or "master";
            buildPhase = ''
              runHook preBuild
              runHook postBuild
            '';
            installPhase = ''
              runHook preInstall
              runHook postInstall
            '';
          }
          // builtins.removeAttrs passthru.configuration.drv [
            "passthru"
            "buildCommand"
            "outputs"
          ];
          symres =
            let
              initial = pkgs.callPackage passthru.configuration.symlinkScript (
                builtins.removeAttrs args [ "config" ]
                // {
                  config = passthru.configuration;
                  wrapper =
                    if passthru.configuration.wrapperFunction == null then
                      null
                    else
                      pkgs.callPackage passthru.configuration.wrapperFunction (
                        builtins.removeAttrs args [ "config" ] // { config = passthru.configuration; }
                      );
                }
              );
              errormsg = "config.symlinkScript function must return (a string) or (a function that recieves attrset and returns an attrset)";
            in
            if lib.isFunction initial then
              let
                res = (initial (builtins.removeAttrs drvargs [ "buildCommand" ]));
              in
              if builtins.isAttrs res then res else throw errormsg
            else if builtins.isString initial then
              initial
            else
              throw errormsg;
        in
        pkgs.stdenv.mkDerivation (
          (
            if builtins.isString symres then
              drvargs
            else
              builtins.removeAttrs symres [
                "buildCommand"
                "passthru"
              ]
          )
          // {
            passthru = (if builtins.isString symres then drvargs.passthru else symres.passthru or { }) // {
              wrap = passthru.configuration.wrap;
              apply = passthru.configuration.apply;
              eval = passthru.configuration.eval;
              override =
                overrideArgs:
                passthru.configuration.wrap {
                  _file = ./core.nix;
                  __package = lib.mkOverride 0 {
                    package = package.override overrideArgs;
                    old = package;
                  };
                };
              overrideAttrs =
                overrideArgs:
                passthru.configuration.wrap {
                  _file = ./core.nix;
                  __package = lib.mkOverride 0 {
                    package = package.overrideAttrs overrideArgs;
                    old = package;
                  };
                };
            };
            buildCommand =
              lib.optionalString passthru.configuration.sourceStdenv ''
                source $stdenv/setup

                if [ -z "''${phases[*]:-}" ]; then
                    phases="''${prePhases[*]:-} unpackPhase patchPhase ''${preConfigurePhases[*]:-} \
                        configurePhase ''${preBuildPhases[*]:-} buildPhase checkPhase \
                        ''${preInstallPhases[*]:-} installPhase ''${preFixupPhases[*]:-} fixupPhase installCheckPhase \
                        ''${preDistPhases[*]:-} distPhase ''${postPhases[*]:-}";
                fi

              ''
              + (if builtins.isString symres then symres else symres.buildCommand or "")
              + lib.optionalString passthru.configuration.sourceStdenv ''

                for curPhase in ''${phases[*]}; do
                    runPhase "$curPhase"
                done
              '';
          }
        );
    };
  };
}
