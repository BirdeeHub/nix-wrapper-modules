{ wlib, lib }:
lib.mapAttrs'
  (name: _:
  lib.nameValuePair
    (lib.removeSuffix ".nix" name)
    (import ./modules/${name} { inherit wlib lib; })
  )
  (builtins.readDir ./modules)

