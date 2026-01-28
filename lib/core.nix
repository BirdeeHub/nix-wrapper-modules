{
  options,
  config,
  lib,
  wlib,
  extendModules,
  # NOTE: makes sure builderFunction and wrapperFunction get name from _module.args
  name ? null,
  ...
}@args:
let
  descriptionsWithFiles =
    let
      opts = {
        pre = lib.mkOption {
          type = lib.types.str;
          default = "";
          description = "header text";
        };
        post = lib.mkOption {
          type = lib.types.str;
          default = "";
          description = "footer text";
        };
      };
    in
    lib.mkOptionType {
      name = "descriptionsWithFiles";
      check = (lib.types.either lib.types.str (lib.types.submodule { options = opts; })).check;
      descriptionClass = "noun";
      description = ''string or { pre ? "", post ? "" } (converted to `[ { pre, post, file } ]`)'';
      merge =
        loc: defs:
        (lib.types.listOf (
          lib.types.submodule {
            options = opts // {
              file = lib.mkOption {
                type = wlib.types.stringable;
                description = "file";
              };
            };
          }
        )).merge
          loc
          (
            map (
              v:
              v
              // {
                value =
                  if builtins.isString v.value then
                    [
                      {
                        inherit (v) file;
                        pre = v.value;
                      }
                    ]
                  else
                    [ (v.value // { inherit (v) file; }) ];
              }
            ) defs
          );
    };
  maintainersWithFiles =
    let
      maintainer = lib.types.submodule (
        { name, ... }:
        {
          freeformType = wlib.types.attrsRecursive;
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
          map (
            def:
            def
            // {
              value = map (
                def':
                def'
                // {
                  inherit (def) file;
                }
              ) def.value;
            }
          ) defs
        );
    };
in
{
  config.meta.description = lib.mkOverride 1499 ''
    # Core (builtin) Options set

    These are the core options that make everything else possible.

    They include the `.extendModules`, `.apply`, `.eval`, and `.wrap` functions, and the `.wrapper` itself

    They are always imported with every module evaluation.

    They are somewhat minimal by design. They pertain to building the derivation, not the wrapper script.

    The default `builderFunction` value provides no options.

    The default `wrapperFunction` is null.

    `wlib.modules.default` provides great values for these options, and creates many more for you to use.

    But you may want to wrap your package via different means, provide different options, or provide modules for others to use to help do those things!

    Doing it this way allows wrapper modules to do anything you might wish involving wrapping some source/package in a derivation.

    Excited to see what ways to use these options everyone comes up with! Docker helpers? BubbleWrap? If it's a derivation, it should be possible!

    ---
  '';
  config.meta.maintainers = lib.mkOverride 1499 [ wlib.maintainers.birdee ];
  config._module.args.pkgs = config.pkgs;
  options = {
    meta = {
      maintainers = lib.mkOption {
        description = "Maintainers of this module.";
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
      description = lib.mkOption {
        description = ''
          Description of the module.

          Accepts either a string, or a set of `{ pre ? "", post ? "" }`

          Resulting config value will be a list of `{ pre, post, file }`
        '';
        default = "";
        type = descriptionsWithFiles;
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
      apply =
        package:
        builtins.foldl' (
          acc: v:
          builtins.addErrorContext "config.overrides type error in ${acc} wrapper module!" (
            if v.type == null then
              builtins.addErrorContext "If `type` is `null`, then `data` must be a function!" (v.data acc)
            else
              builtins.addErrorContext "while calling: (${acc}).${v.type}:" (
                builtins.addErrorContext
                  "If `type` is a string, then `config.package` must have that field, and it must be a function!"
                  acc.${v.type}
                  v.data
              )
          )
        ) package (wlib.dag.unwrapSort "overrides" config.overrides);
      type = lib.types.addCheck wlib.types.stringable (
        v: if builtins.isString v then wlib.types.nonEmptyLine.check v else true
      );
      description = ''
        The base package to wrap.
        This means `config.builderFunction` will be responsible
        for inheriting all other files from this package
        (like man page, /share, ...)

        The `config.package` value given by this option already has all
        values from `config.overrides` applied to it.
      '';
    };
    overrides = lib.mkOption {
      type = wlib.types.seriesOf (
        wlib.types.specWith {
          specialArgs = { inherit wlib; };
          modules = [
            {
              options = {
                data = lib.mkOption {
                  type = lib.types.raw;
                  description = ''
                    If type is null, then this is the function to call on the package.

                    If type is a string, then this is the data to pass to the function corresponding with that attribute.
                  '';
                };
                type = lib.mkOption {
                  type = lib.types.nullOr (
                    lib.types.either (lib.types.enum [
                      "override"
                      "overrideAttrs"
                    ]) lib.types.str
                  );
                  default = null;
                  description = ''
                    The attribute of `config.package` to pass the override argument to.
                    If `null`, then data receives and returns the package instead.

                    If `null`, data must be a function.
                    If a `string`, `config.package` must have the corresponding attribute, and it must be a function.
                  '';
                };
                name = lib.mkOption {
                  type = lib.types.nullOr lib.types.str;
                  default = null;
                  description = ''
                    The name for targeting from the before or after fields of other specs.

                    If `null` it cannot be targeted by other specs.
                  '';
                };
                before = lib.mkOption {
                  type = lib.types.listOf lib.types.str;
                  default = [ ];
                  description = ''
                    Items that this spec should be ordered before.
                  '';
                };
                after = lib.mkOption {
                  type = lib.types.listOf lib.types.str;
                  default = [ ];
                  description = ''
                    Items that this spec should be ordered after.
                  '';
                };
              };
            }
            config.overmods
          ];
        }
      );
      default = [ ];
      description = ''
        the list of `.override` and `.overrideAttrs` to apply to `config.package`

        Accessing `config.package` will return the package with all overrides applied.

        Accepts a list of `{ data, type ? null, name ? null, before ? [], after ? [] }`

        If `type == null` then `data` must be a function. It will receive and return the package.

        If `type` is a string like `override` or `overrideAttrs`, it represents the attribute of `config.package` to pass the `data` field to.

        If a raw value is given, it will be used as the `data` field, and `type` will be `null`.

        ```nix
        config.package = pkgs.mpv;
        config.overrides = [
          { # If they don't have a name they cannot be targeted!
            type = "override";
            after = [ "MPV_SCRIPTS" ];
            data = (prev: {
              scripts = (prev.scripts or []) ++ [ pkgs.mpvScripts.visualizer ];
            });
          }
          {
            name = "MPV_SCRIPTS";
            type = "override";
            data = (prev: {
              scripts = (prev.scripts or []) ++ [ pkgs.mpvScripts.modernz ];
            });
          }
          # the default `type` is `null`
          (pkg: pkg.override (prev: {
            scripts = (prev.scripts or []) ++ [ pkgs.mpvScripts.autocrop ];
          }))
          {
            type = null;
            before = [ "MPV_SCRIPTS" ];
            data = (pkg: pkg.override (prev: {
              scripts = (prev.scripts or []) ++ config.scripts;
            }));
          }
          { # It was already after "MPV_SCRIPTS" so this will stay where it is
            type = "overrideAttrs";
            after = [ "MPV_SCRIPTS" ];
            data = prev: {
              name = prev.name + "-wrapped";
            };
          }
        ];
        ```

        The above will add `config.scripts`, then `modernz` then `visualizer` and finally `autocrop`

        Then it will add `-wrapped` to the end of `config.package`'s `name` attribute.

        The sort will not always put the value directly after the targeted value, it fulfils the requested `before` or `after` dependencies and no more.

        You can modify the specs!

        The type supports type merging, so you may redeclare it in order to add more options or change default values.

        ```nix
        { config, lib, wlib, pkgs, ... }:{
          options.overrides = lib.mkOption {
            type = wlib.types.seriesOf (wlib.types.spec ({ config, ... }: {
              options = {};
              config = {};
            }));
          };
        }
        ```
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
    drv = lib.mkOption {
      default = { };
      type = wlib.types.attrsRecursive;
      description = ''
        Extra attributes to add to the resulting derivation.

        Cannot affect `passthru`, or `outputs`. For that,
        use `config.passthru`, or `config.outputs` instead.

        Also cannot override `buildCommand`.
        That is controlled by the `config.builderFunction`
        and `config.sourceStdenv` options.
      '';
    };
    binName = lib.mkOption {
      type = wlib.types.nonEmptyLine;
      default = baseNameOf (
        builtins.addErrorContext ''
          `config.package`: ${config.package} is not a derivation.
          You must specify `config.binName` manually.
        '' (lib.getExe config.package)
      );
      description = ''
        The name of the binary output by `wrapperFunction` to `$out/bin`

        If not specified, the default name from the package will be used.
      '';
    };
    exePath = lib.mkOption {
      type = lib.types.nullOr wlib.types.nonEmptyLine;
      default = lib.removePrefix "/" (
        lib.removePrefix "${config.package}" (
          builtins.addErrorContext ''
            `config.package`: ${config.package} is not a derivation.
            You must specify `config.exePath` manually.
          '' (lib.getExe config.package)
        )
      );
      description = ''
        The relative path to the executable to wrap. i.e. `bin/exename`

        If not specified, the path gained from calling `lib.getExe` on `config.package` and subtracting the path to the package will be used.
      '';
    };
    outputs = lib.mkOption rec {
      type =
        let
          base = lib.types.addCheck (lib.types.listOf lib.types.str) (v: builtins.length v > 0);
        in
        base // { description = "non-empty " + base.description or "listOf str"; };
      default = if type.check config.package.outputs then config.package.outputs else [ "out" ];
      description = ''
        Override the list of nix outputs that get symlinked into the final package.

        Default is config.package.outputs or `[ "out" ]` if invalid.
      '';
    };
    wrapperFunction = lib.mkOption {
      type = lib.types.nullOr (lib.types.functionTo lib.types.raw);
      default = null;
      description = ''
        Arguments:

        This option takes a function receiving the following arguments:

        module arguments + `pkgs.callPackage`

        ```
        {
          config,
          wlib,
          ... # <- anything you can get from pkgs.callPackage
        }
        ```

        The result of this function is passed DIRECTLY to the value of the `builderFunction` function.

        The relative path to the thing to wrap from within `config.package` is `config.exePath`

        You should wrap the package and place the wrapper at `"$out/bin/''${config.binName}"`
      '';
    };
    builderFunction = lib.mkOption {
      type = lib.types.functionTo (
        lib.types.either lib.types.str (lib.types.functionTo (lib.types.attrsOf lib.types.raw))
      );
      description = ''
        Outside of importing `wlib.modules.symlinkScript` module,
        which is included in `wlib.modules.default`,
        This is usually an option you will never have to redefine.

        This option takes a function receiving the following arguments:

        module arguments + `wrapper` + `pkgs.callPackage`

        ```
        {
          wlib,
          config,
          wrapper,
          ... # <- anything you can get from pkgs.callPackage
        }@initialArgs:
        "<buildCommand>"
        ```

        It is in charge of linking `wrapper` and `config.outputs` to the final package.

        `wrapper` is the unchecked result of calling `wrapperFunction`, or null if one was not provided.

        - The function is to return a string which will be added to the buildCommand of the wrapper.

        The builtin implementation, and also the `wlib.modules.symlinkScript` module,
        accept either a string to prepend to the returned `buildCommand` string,
        or a derivation to link with lndir

        - Alternatively, it may return a function which returns a set like:

        ```nix
        { wlib, config, wrapper, ... }@initialArgs:
        drvArgs:
        drvArgs // {}
        ```

        If it does this, that function will be given the final computed derivation attributes,
        and it will be expected to return the final attribute set to be passed to `pkgs.stdenv.mkDerivation`.

        Regardless of if you return a string or function,
        `passthru.wrap`, `passthru.apply`, `passthru.eval`, `passthru.extendModules`, `passthru.override`,
        `passthru.overrideAttrs` will be added to the thing you return, and `config.sourceStdenv` will be handled for you.

        However:

        - You can also return a _functor_ with a (required) `mkDerivation` field.

        ```nix
          { config, stdenv, wrapper, wlib, ... }@initialArgs:
          {
            inherit (stdenv) mkDerivation;
            __functor = {
              mkDerivation,
              __functor,
              defaultPhases, # [ "<all stdenv phases>" ... ]
              setupPhases, # phases: "if [ -z \"''${phases[*]:-}\" ]; then phases="etc..."; fi"
              runPhases, # "for curPhase in ''${phases[*]}; do runPhase \"$curPhase\"; done"
              ...
            }@self:
            defaultArgs:
            defaultArgs // (if config.sourceStdenv then { } else { buildCommand = ""; }
          }
        ```

        - If you do this:
          - You are in control over the entire derivation.
          - This means you need to take care of `config.passthru` and `config.sourceStdenv` yourself.
          - The `mkDerivation` function will be called with the final result of your functor.

        As you can see, you are provided with some things to help you via the `self` argument to your functor.

        The generated `passthru` items mentioned above are given to you as part of what is shown as defaultArgs above

        And you are also given some helpers to help you run the phases if needed!

        Tip: A _functor_ is a set with a `{ __functor = self: args: ...; }` field.
        You can call it like a function and it gets passed itself as its first argument!
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
        Run the enabled stdenv phases on the wrapper derivation.

        NOTE: often you may prefer to use things like `drv.doDist = true;`,
        or even `drv.phases = [ ... "buildPhase" etc ... ];` instead,
        to override this choice in a more fine-grained manner
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
          inherit (config)
            pkgs
            package
            binName
            ;
          meta = (package.meta or { }) // { mainProgram = binName; } // (config.drv.meta or { });
          version =
            package.version or meta.version or package.revision or meta.revision or package.rev or meta.rev
              or package.release or meta.release or package.releaseDate or meta.releaseDate or "master";
          defaultargs = {
            passthru = config.passthru // {
              configuration = config;
              inherit (config)
                wrap
                eval
                apply
                extendModules
                ;
              override =
                overrideArgs:
                config.wrap {
                  _file = wlib.core;
                  overrides = lib.mkOverride (options.overrides.highestPrio or lib.modules.defaultOverridePriority) [
                    {
                      type = "override";
                      data = overrideArgs;
                    }
                  ];
                };
              overrideAttrs =
                overrideArgs:
                config.wrap {
                  _file = wlib.core;
                  overrides = lib.mkOverride (options.overrides.highestPrio or lib.modules.defaultOverridePriority) [
                    {
                      type = "overrideAttrs";
                      data = overrideArgs;
                    }
                  ];
                };
            };
            dontUnpack = true;
            dontConfigure = true;
            dontPatch = true;
            dontFixup = true;
            name = package.name or "${package.pname or binName}-${version}";
            pname = package.pname or binName;
            inherit version meta;
            inherit (config) outputs;
            buildPhase = ''
              runHook preBuild
              runHook postBuild
            '';
            installPhase = ''
              runHook preInstall
              runHook postInstall
            '';
          }
          // builtins.removeAttrs config.drv [
            "passthru"
            "buildCommand"
            "outputs"
            "meta"
          ];
          errormsg = "config.builderFunction function must return (a string) or (a function that recieves attrset and returns an attrset) or (a functor as described in https://birdeehub.github.io/nix-wrapper-modules/core.html#builderfunction)";
          defaultPhases = [
            "unpackPhase"
            "patchPhase"
            "configurePhase"
            "buildPhase"
            "checkPhase"
            "installPhase"
            "fixupPhase"
            "installCheckPhase"
            "distPhase"
          ];
          setupPhases =
            phases:
            let
              capitalize =
                s:
                let
                  first = builtins.substring 0 1 s;
                  rest = builtins.substring 1 (builtins.stringLength s - 1) s;
                in
                lib.strings.toUpper first + rest;
            in
            if builtins.isList phases then
              (lib.pipe phases [
                (builtins.concatMap (n: [
                  "\${pre${capitalize n}s[*]:-}"
                  "${n}"
                ]))
                (v: if builtins.length v > 0 then builtins.tail v else [ ])
                (v: [ "\${prePhases[*]:-}" ] ++ v ++ [ "\${postPhases[*]:-}" ])
                (builtins.concatStringsSep " ")
                wlib.escapeShellArgWithEnv
                (v: "\n" + ''if [ -z "''${phases[*]:-}" ]; then phases=${v}; fi'' + "\n")
              ])
            else
              ''

                if [ -z "''${phases[*]:-}" ]; then
                    phases="''${prePhases[*]:-} unpackPhase patchPhase ''${preConfigurePhases[*]:-} \
                        configurePhase ''${preBuildPhases[*]:-} buildPhase checkPhase \
                        ''${preInstallPhases[*]:-} installPhase ''${preFixupPhases[*]:-} fixupPhase installCheckPhase \
                        ''${preDistPhases[*]:-} distPhase ''${postPhases[*]:-}";
                fi
              '';
          runPhases = ''

            for curPhase in ''${phases[*]}; do
                runPhase "$curPhase"
            done
          '';
          initial = pkgs.callPackage config.builderFunction (
            args
            // {
              wrapper =
                if config.wrapperFunction == null then null else pkgs.callPackage config.wrapperFunction args;
            }
          );
        in
        (initial.mkDerivation or pkgs.stdenv.mkDerivation) (
          if lib.isFunction initial then
            lib.pipe initial [
              (
                v:
                if v ? mkDerivation then
                  v
                  // {
                    inherit runPhases setupPhases defaultPhases;
                    configuration = config;
                  }
                else
                  v
              )
              (f: f defaultargs)
              (
                v:
                if initial ? mkDerivation then
                  v
                else if builtins.isAttrs v then
                  v
                  // {
                    passthru = v.passthru or { } // defaultargs.passthru;
                    passAsFile = [ "buildCommand" ] ++ v.passAsFile or [ ];
                    buildCommand =
                      lib.optionalString config.sourceStdenv (setupPhases defaultPhases)
                      + v.buildCommand or ""
                      + lib.optionalString config.sourceStdenv runPhases;
                  }
                else
                  throw errormsg
              )
            ]
          else if builtins.isString initial then
            defaultargs
            // {
              passAsFile = [ "buildCommand" ] ++ defaultargs.passAsFile or [ ];
              buildCommand =
                lib.optionalString config.sourceStdenv (setupPhases defaultPhases)
                + initial
                + lib.optionalString config.sourceStdenv runPhases;
            }
          else
            throw errormsg
        );
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
      default = module: extendModules { modules = lib.toList module; };
    };
    extendModules = lib.mkOption {
      type = lib.types.raw // {
        inherit (lib.types.functionTo lib.types.raw) description;
      };
      readOnly = true;
      default = args // {
        __functionArgs = lib.functionArgs extendModules;
        __functor = _: extendModules;
      };
      description = ''
        Alias for `.extendModules` so that you can call it from outside of `wlib.types.subWrapperModule` types

        In addition, it is also a set which stores the function args for the module evaluation.
        This may prove useful when dealing with subWrapperModules or packages, which otherwise would not have access to some of them.
      '';
    };
    symlinkScript = lib.mkOption {
      type = lib.types.nullOr (
        lib.types.functionTo (
          lib.types.either lib.types.str (lib.types.functionTo (lib.types.attrsOf lib.types.raw))
        )
      );
      internal = true;
      default = null;
      description = "DEPRECATED";
    };
    overmods = lib.mkOption {
      type = lib.types.nullOr lib.types.deferredModule;
      default = null;
      internal = true;
      description = "DEPRECATED";
      apply =
        x:
        let
          msg = ''
            Attention: config.overmods is deprecated!

            Why? You could already do it like this!

            ```nix
            { config, lib, wlib, pkgs, ... }:{
              options.overrides = lib.mkOption {
                type = wlib.types.seriesOf (wlib.types.spec ({ config, ... }: {
                  options = {}; # spec types support type merging!
                  config = {};
                }));
              };
            }
            ```

            Before the addition of `wlib.types.seriesOf`,
            trying that with `listOf` would mess up the ordering.

            You could reimplement this option yourself like the following example.
            Don't forget to declare the option you want to use for it!

            ```nix
            { config, lib, wlib, ... }:{
              options.overrides = lib.mkOption {
                type = wlib.types.seriesOf (wlib.types.spec (config.<desired_option_name>));
              };
            }
            ```
          '';
        in
        if x != null then lib.warn msg x else { };
    };
  };
  config.builderFunction = lib.mkIf (config.symlinkScript != null) (
    lib.warn ''
      Renamed option in wrapper module for ${config.binName}!
      `config.symlinkScript` -> `config.builderFunction`
      Please update all usages of the option to the new name.
    '' config.symlinkScript
  );
}
