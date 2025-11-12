{
  pkgs,
  self,
}:

let
  mpvWrapped =
    (self.wrapperModules.mpv.apply {
      inherit pkgs;
      "mpv.conf".content = ''
        ao=null
        vo=null
      '';
    }).wrapper;

in
pkgs.runCommand "mpv-test" { } ''
  "${mpvWrapped}/bin/mpv" --version | grep -q "mpv"
  touch $out
''
