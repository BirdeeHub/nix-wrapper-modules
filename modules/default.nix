{
  lib,
  ...
}:
{
  modules = lib.pipe ./. [
    builtins.readDir
    (lib.filterAttrs (_: type: type == "directory"))
    (builtins.mapAttrs (name: _: ./. + "/${name}/module.nix"))
    (
      v:
      v
      // {
        default = rec {
          _file = ./default.nix;
          key = _file;
          imports = [
            v.symlinkScript
            v.makeWrapper
          ];
        };
      }
    )
  ];
  checks = lib.pipe ./. [
    builtins.readDir
    (lib.filterAttrs (
      name: type: type == "directory" && builtins.pathExists (./. + "/${name}/check.nix")
    ))
    (builtins.mapAttrs (name: _: ./. + "/${name}/check.nix"))
  ];
}
