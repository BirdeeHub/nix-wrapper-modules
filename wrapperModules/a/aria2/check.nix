{
  pkgs,
  self,
  ...
}:
let
  aria2Wrapper = self.wrappers.aria2.wrap {
    inherit pkgs;
    settings = {
      file-allocation = "none";
      log-level = "warn";
      max-connection-per-server = 4;
      min-split-size = "5M";
      on-download-complete = "exit";
      auto-file-renaming = false;
    };
  };
in
pkgs.runCommand "aria2-test" { } ''
  "${aria2Wrapper}/bin/aria2c" -v | grep "${aria2Wrapper.version}"
  touch $out
''
