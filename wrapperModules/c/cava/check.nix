{ pkgs, self, ... }:
let
  cavaWrapped = self.wrappers.cava.wrapped {
    inherit pkgs;
  };
in
pkgs.runCommand "cava-test" { } ''
  "${cavaWrapped}/bin/cava -v"
  touch $out
''
