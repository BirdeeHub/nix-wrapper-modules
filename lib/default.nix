{ lib }:
let
  wlib = import ./lib.nix { inherit lib wlib; };
in
wlib
