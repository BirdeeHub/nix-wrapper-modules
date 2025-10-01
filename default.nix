{ pkgs ? import <nixpkgs> { } }:
let
  lib = pkgs.lib;
  wlib = import ./lib.nix { inherit lib; };
in
{
  lib = wlib;
  wrapperModules = import ./modules.nix {
    inherit lib wlib;
  };
}
