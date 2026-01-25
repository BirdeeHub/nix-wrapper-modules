{
  lib,
  wlib,
  wrapperModules,
  modules,
  checks,
  modulesPath,
  maintainers,
}:
let
  inherit (lib) toList;
in
{
  inherit
    wrapperModules
    modules
    checks
    maintainers
    modulesPath
    ;

  types = import ./types.nix { inherit lib wlib; };

  dag = import ./dag.nix { inherit lib wlib; };

  core = toString ./core.nix;

  /**
    calls `nixpkgs.lib.evalModules` with the core module imported and `wlib` added to `specialArgs`

    `wlib.evalModules` takes the same arguments as `nixpkgs.lib.evalModules`
  */
  evalModules =
    evalArgs:
    lib.evalModules (
      evalArgs
      // {
        modules = [
          wlib.core
        ]
        ++ (evalArgs.modules or [ ]);
        specialArgs = (evalArgs.specialArgs or { }) // {
          inherit (wlib) modulesPath;
          inherit wlib;
        };
      }
    );

  /**
    `evalModule = module: wlib.evalModules { modules = lib.toList module; };`

    Evaluates the module along with the core options, using `lib.evalModules`

    Takes a module (or list of modules) as its argument.
    Returns the result from `lib.evalModules` directly.

    To submit a module to this repo, this function must be able to evaluate it.

    The wrapper module system integrates with NixOS module evaluation:
    - Uses `lib.evalModules` for configuration evaluation
    - Supports all standard module features (imports, conditionals, mkIf, etc.)
    - Provides `config` for accessing evaluated configuration
    - Provides `options` for introspection and documentation
  */
  evalModule = module: wlib.evalModules { modules = toList module; };

  /**
    ```nix
    evalPackage = module: (wlib.evalModules { modules = lib.toList module; }).config.wrapper;
    ```

    Evaluates the module along with the core options, using `lib.evalModules`

    Takes a module (or list of modules) as its argument.

    Returns the final wrapped package from `eval_result.config.wrapper` directly.

    Requires a `pkgs` to be set.

    ```nix
    home.packages = [
      (wlib.evalPackage [
        { inherit pkgs; }
        ({ pkgs, wlib, lib, ... }: {
          imports = [ wlib.modules.default ];
          package = pkgs.hello;
          flags."--greeting" = "greetings!";
        })
      ])
      (wlib.evalPackage [
        { inherit pkgs; }
        ({ pkgs, wlib, lib, ... }: {
          imports = [ wlib.wrapperModules.tmux ];
          plugins = [ pkgs.tmuxPlugins.onedark-theme ];
        })
      ])
    ];
    ```
  */
  evalPackage = module: (wlib.evalModules { modules = toList module; }).config.wrapper;

  /**
    Produces a module for another module system,
    that can be imported to configure and/or install a wrapper module.

    *Arguments:*

    ```nix
    {
      name, # string
      value, # module or list of modules
      optloc ? [ "wrappers" ],
      loc ? [
        "environment"
        "systemPackages"
      ],
      as_list ? true,
      # Also accepts any valid top-level module attribute
      # other than `config` or `options`
      ...
    }:
    ```

    Creates a `wlib.types.subWrapperModule` option with an extra `enable` option at
    the path indicated by `optloc ++ [ name ]`, with the default `optloc` being `[ "wrappers" ]`

    Defines a list value at the path indicated by `loc` containing the `.wrapper` value of the submodule,
    with the default `loc` being `[ "environment" "systemPackages" ]`

    If `as_list` is false, it will set the value at the path indicated by `loc` as it is,
    without putting it into a list.

    This means it will create a module that can be used like so:

    ```nix
    # in a nixos module
    { ... }: {
      imports = [
        (mkInstallModule { name = "?"; value = someWrapperModule; })
      ];
      config.wrappers."?" = {
        enable = true;
        env.EXTRAVAR = "TEST VALUE";
      };
    }
    ```

    ```nix
    # in a home-manager module
    { ... }: {
      imports = [
        (mkInstallModule { name = "?"; loc = [ "home" "packages" ]; value = someWrapperModule; })
      ];
      config.wrappers."?" = {
        enable = true;
        env.EXTRAVAR = "TEST VALUE";
      };
    }
    ```

    If needed, you can also grab the package directly with `config.wrappers."?".wrapper`

    Note: This function will try to provide a `pkgs` to the `subWrapperModule` automatically.

    If the target module evaluation does not provide a `pkgs` via its module arguments to use,
    you will need to supply it to the submodule yourself later.
  */
  mkInstallModule =
    {
      optloc ? [ "wrappers" ],
      loc ? [
        "environment"
        "systemPackages"
      ],
      as_list ? true,
      name,
      value,
      ...
    }@args:
    {
      pkgs ? null,
      lib,
      config,
      ...
    }:
    # https://github.com/NixOS/nixpkgs/blob/c171bfa97744c696818ca23d1d0fc186689e45c7/lib/modules.nix#L615C1-L623C25
    builtins.intersectAttrs {
      _class = null;
      _file = null;
      key = null;
      disabledModules = null;
      imports = null;
      meta = null;
      freeformType = null;
    } args
    // {
      options = lib.setAttrByPath (optloc ++ [ name ]) (
        lib.mkOption {
          default = { };
          type = wlib.types.subWrapperModule (
            (lib.toList value)
            ++ [
              {
                config.pkgs = lib.mkIf (pkgs != null) pkgs;
                options.enable = lib.mkEnableOption name;
              }
            ]
          );
        }
      );
      config = lib.setAttrByPath loc (
        lib.mkIf
          (lib.getAttrFromPath (
            optloc
            ++ [
              name
              "enable"
            ]
          ) config)
          (
            let
              res = lib.getAttrFromPath (
                optloc
                ++ [
                  name
                  "wrapper"
                ]
              ) config;
            in
            if as_list then [ res ] else res
          )
      );
    };

  /**
    Imports `wlib.modules.default` then evaluates the module. It then returns `.config` so that `.wrap` is easily accessible!

    Use this when you want to quickly create a wrapper but without providing it a `pkgs` yet.

    Equivalent to:

    ```nix
    wrapModule = (wlib.evalModule wlib.modules.default).config.apply;
    ```

    Example usage:

    ```nix
      helloWrapper = wrapModule ({ config, wlib, pkgs, ... }: {
        options.greeting = lib.mkOption {
          type = lib.types.str;
          default = "hello";
        };
        config.package = pkgs.hello;
        config.flags = {
          "--greeting" = config.greeting;
        };
      };

      # This will return a derivation that wraps the hello package with the --greeting flag set to "hi".
      helloWrapper.wrap {
        pkgs = pkgs;
        greeting = "hi";
      };
      ```
  */
  wrapModule =
    module: (wlib.evalModules { modules = [ wlib.modules.default ] ++ (toList module); }).config;

  /**
    Imports `wlib.modules.default` then evaluates the module. It then returns the wrapped package.

    Use this when you want to quickly create a wrapped package directly, which does not have an existing module already.

    Requires a `pkgs` to be set.

    Equivalent to:

    ```nix
    wrapPackage = module: wlib.evalPackage ([ wlib.modules.default ] ++ toList module);
    ```
  */
  wrapPackage = module: wlib.evalPackage ([ wlib.modules.default ] ++ toList module);

  /**
    mkOutOfStoreSymlink :: pkgs -> path -> { out = ...; ... }

    Lifted straight from home manager, but requires pkgs to be passed to it first.

    Creates a symlink to a local absolute path, does not check if it is a store path first.

    Returns a store path that can be used for things which require a store path.
  */
  mkOutOfStoreSymlink =
    pkgs: path:
    let
      pathStr = toString path;
      name = baseNameOf pathStr;
    in
    pkgs.runCommandLocal name { } "ln -s ${lib.escapeShellArg pathStr} $out";

  /**
    getPackageOutputsSet ::
      Derivation -> AttrSet

    Given a package derivation, returns an attribute set mapping each of its
    output names (e.g. "out", "dev", "doc") to the corresponding output path.

    This is useful when a wrapper or module needs to reference multiple outputs
    of a single derivation. If the derivation does not define multiple outputs,
    an empty set is returned.

    Example:
      getPackageOutputsSet pkgs.git
      => {
        out = /nix/store/...-git;
        man = /nix/store/...-git-man;
      }
  */
  getPackageOutputsSet =
    package:
    if package ? outputs then
      lib.listToAttrs (
        map (output: {
          name = output;
          value = if package ? ${output} then package.${output} else null;
        }) package.outputs
      )
    else
      { };

  /**
    Escape a shell argument while preserving environment variable expansion.

    This escapes backslashes and double quotes to prevent injection, then

    wraps the result in double quotes.

    Unlike lib.escapeShellArg which uses single quotes, this allows

    environment variable expansion (e.g., `$HOME`, `${VAR}`).

    Caution! This is best used by the `nix` backend for `wlib.modules.makeWrapper` to escape things,
    because the `shell` and `binary` implementations pass their args to `pkgs.makeWrapper` at **build** time,
    so allowing variable expansion may not always do what you expect!

    # Example

    ```nix

    escapeShellArgWithEnv "$HOME/config.txt"

    => "\"$HOME/config.txt\""

    escapeShellArgWithEnv "/path/with\"quote"

    => "\"/path/with\\\"quote\""

    escapeShellArgWithEnv "/path/with\\backslash"

    => "\"/path/with\\\\backslash\""

    ```
  */
  escapeShellArgWithEnv = arg: ''"${lib.escape [ ''\'' ''"'' ] (toString arg)}"'';

  /**
    Wrap a function (or callable attribute set) to make it customizable via a
    named override entry.

    A slightly generalized version of `nixpkgs.lib.makeOverridable`, with explicit
    support for:
    - custom override names
    - configurable argument-merging semantics
    - preserving override entry points across common derivation-like patch
      functions (e.g. `override`, `overrideAttrs`, `overrideDerivation`)

    This helper turns `f` into a functor that:
    - Preserves the original argument signature of `f`
    - Exposes an override function under the attribute `${name}`
    - Recomputes `f` when arguments are overridden
    - Re-attaches `${name}` to selected callable attributes on the result of `f`,
      so that chaining through derivation-style patch functions does not lose
      the custom override entry

    Signature:

    ```nix
    makeCustomizable =
      name:
      {
        patches ? [
          "override"
          "overrideAttrs"
          "overrideDerivation"
        ],
        mergeArgs ?
          origArgs: newArgs:
            origArgs // (if lib.isFunction newArgs then newArgs origArgs else newArgs),
      }@opts:
      f:
    ```

    Parameters:
    - `name`:
        The attribute name under which the override function is exposed
        (e.g. `customize`, `withPackages`). This attribute is attached both to `f`
        itself and to applicable results returned by calling `f`.

    - `opts.patches`:
        A list of attribute names on the *result* of `f` that should propagate
        the named override. Each listed attribute is expected to be callable
        when present. This is primarily intended for derivation-like results,
        ensuring that calling methods such as `override`, `overrideAttrs`,
        or `overrideDerivation` preserves the custom override entry rather than
        discarding it. It will only patch the value if present.

    - `opts.mergeArgs`:
        A function controlling how new arguments are merged with the original
        arguments when overriding. It receives `origArgs` and `newArgs` and
        must return the argument used to re-invoke `f`. By default, this
        performs a shallow merge, evaluating `newArgs` if it is a function.

    - `f`:
        The function (or callable attribute set) to wrap. If `f` is an attribute
        set, its additional attributes are preserved, and an existing `${name}`
        entry (if present) is composed rather than replaced.

    Semantics:
    - Argument overrides recompute `f` with merged arguments.
    - Result-level patches recompute `f` and then delegate to the corresponding
      callable attribute on the result.
    - Returned attribute sets and functions gain a `${name}` attribute that can
      be chained arbitrarily.

    Example:

    ```nix
      luaEnv = wlib.makeCustomizable
        "withPackages"
        { mergeArgs = og: new: lp: og lp ++ new lp; }
        pkgs.luajit.withPackages
        (lp: [ lp.inspect ]);

      # inspect + cjson
      luaEnv2 = luaEnv.withPackages (lp: [ lp.cjson ]);
      # inspect + cjson + luassert
      luaEnv3 = luaEnv.withPackages (lp: [ lp.luassert ]);
    ```
  */
  makeCustomizable =
    # https://github.com/NixOS/nixpkgs/blob/f36330bf81e58a7df04a603806c9d01eefc7a4bb/lib/customisation.nix#L154
    name:
    {
      patches ? [
        "override"
        "overrideAttrs"
        "overrideDerivation"
      ],
      mergeArgs ?
        origArgs: newArgs: origArgs // (if lib.isFunction newArgs then newArgs origArgs else newArgs),
    }@opts:
    f:
    let
      mkOver = wlib.makeCustomizable name opts;
      # Creates a functor with the same arguments as f
      mirrorArgs = lib.mirrorFunctionArgs f;
      # Recover overrider and additional attributes for f
      # When f is a callable attribute set,
      # it may contain its own `f.${name}` and additional attributes.
      # This helper function recovers those attributes and decorate the overrider.
      recoverMetadata =
        if builtins.isAttrs f then
          fDecorated:
          # Preserve additional attributes for f
          f
          // fDecorated
          # Decorate f.${name} if presented
          // {
            ${if builtins.isString name && f ? "${name}" then name else null} = fdrv: mkOver (f.${name} fdrv);
          }
        else
          (x: x);
      decorate = f': recoverMetadata (mirrorArgs f');
    in
    decorate (
      origArgs:
      let
        result = f origArgs;
        # Re-call the function but with different arguments
        overrideArgs = mirrorArgs (newArgs: mkOver f (mergeArgs origArgs newArgs));
        # Change the result of the function call by applying g to it
        overrideResult = g: mkOver (mirrorArgs (args: g (f args))) origArgs;
      in
      if builtins.isAttrs result then
        result
        // lib.pipe patches [
          (map (patch: {
            ${if result ? "${patch}" then patch else null} = fdrv: overrideResult (x: x.${patch} fdrv);
          }))
          (builtins.foldl' (acc: v: acc // v) { })
        ]
        // {
          ${name} = overrideArgs;
        }
      else if builtins.isFunction result then
        # Transform the result into a functor while propagating its arguments
        lib.setFunctionArgs result (lib.functionArgs result)
        // {
          ${name} = overrideArgs;
        }
      else
        result
    );

}
