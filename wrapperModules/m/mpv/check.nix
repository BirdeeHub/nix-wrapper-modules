{
  pkgs,
  self,
}:

let
  mpvWithoutConfigDirectory =
    (self.wrappers.mpv.apply {
      inherit pkgs;
      scripts = [
        pkgs.mpvScripts.visualizer
      ];
      "mpv.conf".content = ''
        ao=null
        vo=null
      '';
    }).wrapper;
  mpvWithConfigDirectory =
    (self.wrappers.mpv.apply {
      inherit pkgs;
      scripts = [
        pkgs.mpvScripts.visualizer
      ];
      scriptFiles = {
        "script-opts/visualizer.conf" = ''
          mode="force"
        '';
      };
      "mpv.conf".content = ''
        ao=null
        vo=null
      '';
    }).wrapper;
in
pkgs.runCommand "mpv-test" { } ''
  res="$(${mpvWithoutConfigDirectory}/bin/mpv --version)"
  if ! echo "$res" | grep "mpv"; then
    echo "failed to run wrapped package!"
    echo "wrapper content for ${mpvWithoutConfigDirectory}/bin/mpv"
    cat "${mpvWithoutConfigDirectory}/bin/mpv"
    exit 1
  fi
  if ! cat "${mpvWithoutConfigDirectory.configuration.package}/bin/mpv" | LC_ALL=C grep -a -F "share/mpv/scripts/visualizer.lua"; then
    echo "failed to find added script when inspecting overriden package value"
    echo "overriden package value ${mpvWithoutConfigDirectory.configuration.package}/bin/mpv"
    cat "${mpvWithoutConfigDirectory.configuration.package}/bin/mpv"
    exit 1
  fi

  res="$(${mpvWithConfigDirectory}/bin/mpv --version)"
  if ! echo "$res" | grep "mpv"; then
    echo "failed to run wrapped package with config directory!"
    echo "wrapper content for ${mpvWithConfigDirectory}/bin/mpv"
    cat "${mpvWithConfigDirectory}/bin/mpv"
    exit 1
  fi
  if ! cat "${mpvWithConfigDirectory.configuration.package}/bin/mpv" | LC_ALL=C grep -a -F "share/mpv/scripts/visualizer.lua"; then
    echo "failed to find added script when inspecting overriden package value with config directory"
    echo "overriden package value ${mpvWithConfigDirectory.configuration.package}/bin/mpv"
    cat "${mpvWithConfigDirectory.configuration.package}/bin/mpv"
    exit 1
  fi
  if ! grep -q "force" "${mpvWithConfigDirectory}/mpv-config/script-opts/visualizer.conf"; then
    echo "failed to read script options from config directory"
    exit 1
  fi
  touch $out
''
