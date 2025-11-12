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
pkgs.runCommand "mpv-test" { } ''
  "${mpvWrapped}/bin/mako" --help | grep -q "mako"
  touch $out
''
