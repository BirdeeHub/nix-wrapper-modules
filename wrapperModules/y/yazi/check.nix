{
  pkgs,
  self,
}:
let
  yaziWrapper = self.wrappers.yazi.apply { inherit pkgs; };
  cfgdir = yaziWrapper.env.YAZI_CONFIG_HOME.data;
in
pkgs.runCommand "yazi-test" { } ''
  "${yaziWrapper.wrapper}/bin/yazi" --debug | grep "${cfgdir}"
  touch $out
''
