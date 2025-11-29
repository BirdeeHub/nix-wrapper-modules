{
  lib,
  wlib,
  wrapperModules,
  modules,
  checks,
  modulesPath,
  maintainers,
}:
{
  inherit
    wrapperModules
    modules
    checks
    maintainers
    ;

  types = import ./types.nix { inherit lib wlib; };

  dag = import ./dag.nix { inherit lib wlib; };

  /**
    calls `nixpkgs.lib.evalModules` with the core module imported and `wlib` added to `specialArgs`

    `wlib.evalModules` takes the same arguments as `nixpkgs.lib.evalModules`
  */
  evalModules =
    evalArgs:
    let
      res = lib.evalModules (
        {
          modules = [
            ./core.nix
          ]
          ++ (evalArgs.modules or [ ])
          ++ [
            {
              _file = ./core.nix;
              __extend = lib.mkOverride 0 res.extendModules;
            }
          ];
          specialArgs = {
            inherit modulesPath;
          }
          // (evalArgs.specialArgs or { })
          // {
            inherit wlib;
          };
        }
        // (builtins.removeAttrs evalArgs [
          "modules"
          "specialArgs"
        ])
      );
    in
    res;

  /**
    `evalModule = module: wlib.evalModules { modules = [ module ]; };`

    Evaluates the module along with the core options, using `lib.evalModules`

    Takes a module as its argument. Returns the result from `lib.evalModules` directly.

    To submit a module to this repo, this function must be able to evaluate it.

    The wrapper module system integrates with NixOS module evaluation:
    - Uses `lib.evalModules` for configuration evaluation
    - Supports all standard module features (imports, conditionals, mkIf, etc.)
    - Provides `config` for accessing evaluated configuration
    - Provides `options` for introspection and documentation
  */
  evalModule = module: wlib.evalModules { modules = [ module ]; };

  /**
    Creates a reusable wrapper module.

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
    module:
    (wlib.evalModules {
      modules = [
        wlib.modules.default
        module
      ];
    }).config;

  /**
    Imports `wlib.modules.default` then evaluates the module. It then returns the wrapped package.

    Use this when you want to quickly create a wrapped package directly. Requires a `pkgs` to be set.

    Equivalent to:

    ```nix
    wrapModule = (wlib.evalModule wlib.modules.default).config.wrap;
    ```
  */
  wrapPackage =
    module:
    (wlib.evalModules {
      modules = [
        wlib.modules.default
        module
      ];
    }).config.wrapper;

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
    pkgs.runCommandLocal name { } ''ln -s ${lib.escapeShellArg pathStr} $out'';

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
