{
  lib,
  wlib,
  pkgs,
  ...
}:
{
  options.wrapperVariants = lib.mkOption {
    type = lib.types.attrsOf (
      lib.types.submoduleWith {
        modules = [
          (
            { name, ... }:
            {
              _file = wlib.modules.makeWrapper;
              config.mirror = lib.mkOverride 1400 false;
              config.package = lib.mkOverride 1400 (pkgs.${name} or pkgs.hello);
              # add back this option we removed from the top level
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
            }
          )
        ];
      }
    );
  };
}
