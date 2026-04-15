{
  pkgs,
  self,
  ...
}:

let
  mpvWithPkgs = self.wrappers.mpv.apply { inherit pkgs; };
  mpvWithoutConfigDirectory = mpvWithPkgs.wrap {
    script.visualizer.path = pkgs.mpvScripts.visualizer;
    "mpv.conf".content = ''
      ao=null
      vo=null
    '';
  };
  mpvWithConfigDirectory = mpvWithPkgs.wrap {
    script.visualizer.path = pkgs.mpvScripts.visualizer;
    configDir = {
      "script-opts/visualizer.conf".content = ''
        mode="force"
      '';
    };
    "mpv.conf".content = ''
      ao=null
      vo=null
    '';
  };
  mpvWithScriptOptsAppend = mpvWithPkgs.wrap {
    script = {
      "visualizer.lua" = {
        path = pkgs.mpvScripts.visualizer;
        opts = {
          mode = "force";
          custom_opt = "test_value";
        };
      };
    };
    "mpv.conf".content = ''
      ao=null
      vo=null
    '';
  };
  mpvWithScriptPath = mpvWithPkgs.wrap {
    script = {
      "my-script.lua" = {
        path = pkgs.mpvScripts.visualizer + "/share/mpv/scripts/visualizer.lua";
        opts = {
          mode = "force";
        };
      };
    };
    "mpv.conf".content = ''
      ao=null
      vo=null
    '';
  };
  mpvWithNixpkgsScriptViaPath = mpvWithPkgs.wrap {
    script = {
      visualizer = {
        path = pkgs.mpvScripts.visualizer;
        opts = {
          mode = "force";
        };
      };
    };
    "mpv.conf".content = ''
      ao=null
      vo=null
    '';
  };
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

  res="$(${mpvWithScriptOptsAppend}/bin/mpv --version)"
  if ! echo "$res" | grep "mpv"; then
    echo "failed to run wrapped package with script-opts-append!"
    echo "wrapper content for ${mpvWithScriptOptsAppend}/bin/mpv"
    cat "${mpvWithScriptOptsAppend}/bin/mpv"
    exit 1
  fi
  if ! grep -q "script-opts-append" "${mpvWithScriptOptsAppend}/bin/mpv"; then
    echo "failed to find --script-opts-append flag in wrapper"
    cat "${mpvWithScriptOptsAppend}/bin/mpv"
    exit 1
  fi
  if ! grep -q "visualizer-mode=force" "${mpvWithScriptOptsAppend}/bin/mpv"; then
    echo "failed to find visualizer_mode=force in --script-opts-append"
    cat "${mpvWithScriptOptsAppend}/bin/mpv"
    exit 1
  fi
  if ! grep -q "visualizer-custom_opt=test_value" "${mpvWithScriptOptsAppend}/bin/mpv"; then
    echo "failed to find visualizer_custom_opt=test_value in --script-opts-append"
    cat "${mpvWithScriptOptsAppend}/bin/mpv"
    exit 1
  fi

  res="$(${mpvWithScriptPath}/bin/mpv --version)"
  if ! echo "$res" | grep "mpv"; then
    echo "failed to run wrapped package with script path!"
    echo "wrapper content for ${mpvWithScriptPath}/bin/mpv"
    cat "${mpvWithScriptPath}/bin/mpv"
    exit 1
  fi
  if ! grep -q "scripts-append" "${mpvWithScriptPath}/bin/mpv"; then
    echo "failed to find --scripts-append flag in wrapper with path"
    cat "${mpvWithScriptPath}/bin/mpv"
    exit 1
  fi
  if ! grep -q "my_script-mode=force" "${mpvWithScriptPath}/bin/mpv"; then
    echo "failed to find my_script-mode=force in --script-opts-append with path"
    cat "${mpvWithScriptPath}/bin/mpv"
    exit 1
  fi

  res="$(${mpvWithNixpkgsScriptViaPath}/bin/mpv --version)"
  if ! echo "$res" | grep "mpv"; then
    echo "failed to run wrapped package with nixpkgs script via path!"
    echo "wrapper content for ${mpvWithNixpkgsScriptViaPath}/bin/mpv"
    cat "${mpvWithNixpkgsScriptViaPath}/bin/mpv"
    exit 1
  fi
  if grep -q "scripts-append" "${mpvWithNixpkgsScriptViaPath}/bin/mpv"; then
    echo "FAIL: nixpkgs script should NOT use --scripts-append"
    cat "${mpvWithNixpkgsScriptViaPath}/bin/mpv"
    exit 1
  fi
  if ! cat "${mpvWithNixpkgsScriptViaPath.configuration.package}/bin/mpv" | LC_ALL=C grep -a -F "share/mpv/scripts/visualizer.lua"; then
    echo "FAIL: nixpkgs script should be in override (package bin/mpv)"
    cat "${mpvWithNixpkgsScriptViaPath.configuration.package}/bin/mpv"
    exit 1
  fi
  if ! grep -q "visualizer-mode=force" "${mpvWithNixpkgsScriptViaPath}/bin/mpv"; then
    echo "FAIL: nixpkgs script opts should still use --script-opts-append"
    cat "${mpvWithNixpkgsScriptViaPath}/bin/mpv"
    exit 1
  fi
  touch $out
''
