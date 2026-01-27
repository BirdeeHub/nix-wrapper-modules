{
  pkgs,
  self,
}:
let
  yaziWrapped = (self.wrappers.yazi.apply { inherit pkgs; }).wrapper;
in
pkgs.runCommand "yazi-test" { } ''
  "${yaziWrapped}/bin/yazi" -V | grep -q "${yaziWrapped.version}"
  touch $out
''
