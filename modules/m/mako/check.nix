{
  pkgs,
  self,
}:

let
  mpvWrapped =
    (self.wrapperModules.mako.apply {
      inherit pkgs;
      "--config".content = ''
        ao=null
        vo=null
      '';
    }).wrapper;

in
if builtins.elem pkgs.system self.wrapperModules.mako.meta.platforms then
  pkgs.runCommand "mpv-test" { } ''
    "${mpvWrapped}/bin/mako" --help | grep -q "mako"
    touch $out
  ''
else
  pkgs.runCommand "mpv-test-disabled" { } ''
    touch $out
  ''
