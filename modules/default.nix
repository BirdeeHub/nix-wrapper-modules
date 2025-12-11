{
  lib,
  ...
}:
{
  modules = lib.pipe ./. [
    builtins.readDir
    (lib.filterAttrs (_: type: type == "directory"))
    (builtins.mapAttrs (name: _: ./. + "/${name}/module.nix"))
  ];
  checks = lib.pipe ./. [
    builtins.readDir
    (lib.filterAttrs (
      name: type: type == "directory" && builtins.pathExists (./. + "/${name}/check.nix")
    ))
    (builtins.mapAttrs (name: _: ./. + "/${name}/check.nix"))
  ];
}
