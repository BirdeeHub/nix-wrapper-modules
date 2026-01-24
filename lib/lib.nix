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

}
