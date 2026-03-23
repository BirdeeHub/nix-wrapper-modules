{
  pkgs,
  self,
}:
let
  yaziWrapper = self.wrappers.yazi.wrap { inherit pkgs; };
in
pkgs.runCommand "yazi-test" { } ''
  "${yaziWrapper}/bin/yazi" --debug | grep "${yaziWrapper.generatedConfig}"
  touch $out
''
