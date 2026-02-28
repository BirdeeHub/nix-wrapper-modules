{
  pkgs,
  self,
}:
let
  cavaWrapper = self.wrappers.cava.apply { inherit pkgs; };
in
pkgs.runCommand "cava-test" { } ''
  "${cavaWrapper.wrapper}/bin/cava" -v | grep "${cavaWrapper.wrapper.version}"
  touch $out
''
