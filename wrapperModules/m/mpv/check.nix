{
  pkgs,
  self,
}:

let
  mpvWrapped =
    (self.wrappedModules.mpv.apply {
      inherit pkgs;
      scripts = [
        pkgs.mpvScripts.visualizer
      ];
      "mpv.conf".content = ''
        ao=null
        vo=null
      '';
    }).wrapper;
in
pkgs.runCommand "mpv-test" { } ''
  res=$(${mpvWrapped}/bin/mpv --version)
  if ! echo "$res" | grep -q "mpv"; then
    echo "failed to run wrapped package!"
    echo "wrapper content for ${mpvWrapped}/bin/mpv"
    cat "${mpvWrapped}/bin/mpv"
    exit 1
  fi
  if ! cat "${mpvWrapped.configuration.package}/bin/mpv" | LC_ALL=C grep -a -F -q "share/mpv/scripts/visualizer.lua"; then
    echo "failed to find added script when inspecting overriden package value"
    echo "overriden package value ${mpvWrapped.configuration.package}/bin/mpv"
    cat "${mpvWrapped.configuration.package}/bin/mpv"
    exit 1
  fi
  touch $out
''
