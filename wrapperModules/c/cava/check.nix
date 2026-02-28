{
  pkgs,
  self,
}:
let
  cavaWrapper = self.wrappers.cava.wrap { inherit pkgs; };
in
if builtins.elem pkgs.stdenv.hostPlatform.system self.wrappers.cava.meta.platforms then
  pkgs.runCommand "cava-test" { } ''
    "${cavaWrapper}/bin/cava" -v | grep "${cavaWrapper.version}"
    touch $out
  ''
else
  null
