{
  callPackage,
  lib,
  ...
}@args:
lib.pipe ./checks [
  builtins.readDir
  (lib.filterAttrs (name: type: type == "regular" && lib.hasSuffix ".nix" name))
  (lib.mapAttrs' (
    name: _: lib.nameValuePair (lib.removeSuffix ".nix" name) (callPackage (./checks + "/${name}") args)
  ))
]
