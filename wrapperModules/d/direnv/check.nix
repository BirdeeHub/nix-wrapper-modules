{
  pkgs,
  self,
}:

let
  lib = pkgs.lib;
  testUtils = ''
    is_directory() {
      local path="$1"
      if [ -d "$path" ]; then
        return 0
      else
        echo "No directory $path" >&2
        return 1
      fi
    }

    is_file() {
      local path="$1"
      if [ -f "$path" ]; then
        return 0
      else
        echo "No such file $path" >&2
        return 1
      fi
    }

    file_contains() {
      local file="$1"
      local pattern="$2"
      if grep -q "$pattern" "$file"; then
          return 0
      else
        echo "Pattern '$pattern' not found in $file" >&2
        return 1
      fi
    }
  '';

  runTests =
    name: scripts:
    pkgs.runCommand name { } ''
      ${testUtils}
      ${lib.concatStringsSep "\n\n" scripts}
      touch $out
    '';

  runTest = name: script: ''
    run() {
      ${script}
    }

    run || (echo 'test "${name}" failed' >&2 && exit 1)
  '';

  getDotdir =
    wrapper:
    let
      cfg = (wrapper.eval { }).config;
      dotdir = "${wrapper}/${cfg.configDirname}";
    in
    dotdir;
in
# runTests "direnv-all" checks
runTests "direnv-test" [
  (runTest "wrapper should output correct version" (
    let
      wrapper = self.wrappers.direnv.wrap {
        inherit pkgs;
        nix-direnv.enable = true;
      };
    in
    ''
      "${wrapper}/bin/direnv" --version | grep -q "${wrapper.version}"
    ''
  ))
  (runTest "if nix-direnv is enabled then lib/nix-direnv.sh should exists" (
    let
      wrapper = self.wrappers.direnv.wrap {
        inherit pkgs;
        nix-direnv.enable = true;
      };
    in
    ''
      is_directory "${getDotdir wrapper}"
      is_file "${getDotdir wrapper}/lib/nix-direnv.sh"
    ''
  ))
  (runTest "if nix-direnv is disabled then lib/nix-direnv.sh should not exist" (
    let
      wrapper = self.wrappers.direnv.wrap {
        inherit pkgs;
        nix-direnv.enable = false;
      };
    in
    ''
      is_directory "${getDotdir wrapper}"
      ! is_file "${getDotdir wrapper}/lib/nix-direnv.sh"
    ''
  ))
  (runTest "if a lib-script is set then it should be generated" (
    let
      libScriptFile = "${getDotdir wrapper}/lib/foo.sh";
      libScriptContent = "echo foo";
      wrapper = self.wrappers.direnv.wrap {
        inherit pkgs;
        lib."foo.sh" = libScriptContent;
      };
    in
    ''
      is_directory "${getDotdir wrapper}"
      is_file "${libScriptFile}"
      file_contains ${libScriptFile} ${libScriptContent}
    ''
  ))
  (runTest "if silent mode is enabled then log settings should be set" (
    let
      direnvTomlFile = "${getDotdir wrapper}/direnv.toml";
      wrapper = self.wrappers.direnv.wrap {
        inherit pkgs;
        silent = true;
      };
    in
    ''
      is_directory "${getDotdir wrapper}"
      is_file "${direnvTomlFile}"
      file_contains ${direnvTomlFile} 'log_format'
      file_contains ${direnvTomlFile} 'log_filter'
    ''
  ))
  (runTest "if extraConfig is working" (
    let
      direnvTomlFile = "${getDotdir wrapper}/direnv.toml";
      wrapper = self.wrappers.direnv.wrap {
        inherit pkgs;
        extraConfig = {
          fooSection.fooKey = "fooValue";
        };
      };
    in
    ''
      is_directory "${getDotdir wrapper}"
      is_file "${direnvTomlFile}"
      file_contains ${direnvTomlFile} '[fooSection]'
      file_contains ${direnvTomlFile} 'fooKey.*fooValue'
    ''
  ))
  (runTest "if direnvrc is working" (
    let
      direnvrcFile = "${getDotdir wrapper}/direnvrc";
      direnvrcContent = "echo foo";

      wrapper = self.wrappers.direnv.wrap {
        inherit pkgs;
        direnvrc = direnvrcContent;
      };
    in
    ''
      is_directory "${getDotdir wrapper}"
      is_file "${direnvrcFile}"
      file_contains ${direnvrcFile} '${direnvrcContent}'
    ''
  ))
]
