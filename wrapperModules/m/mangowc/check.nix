{
  pkgs,
  self,
  ...
}:
let
  mangowcWrapped = self.wrappers.mangowc.wrap {
    inherit pkgs;

    sourcedFiles = [
      ./config.conf
    ];

    extraContent = ''
      # menu and terminal
      bind=Alt,space,spawn,rofi -show drun
      bind=Alt,Return,spawn,${pkgs.lib.getExe pkgs.foot}
    '';
  };
in
if builtins.elem pkgs.stdenv.hostPlatform.system self.wrappers.mangowc.meta.platforms then
  pkgs.runCommand "mangowc-test" { } ''
    cat ${mangowcWrapped}/bin/mango
    cat ${mangowcWrapped}/config.conf
    "${mangowcWrapped}/bin/mango" -v | grep -q "${mangowcWrapped.version}"
    "${mangowcWrapped}/bin/mango" -p
    touch $out
  ''
else
  null
