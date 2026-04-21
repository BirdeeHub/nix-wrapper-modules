{
  pkgs,
  self,
  tlib,
  ...
}:

let
  inherit (tlib)
    fileContains
    isDirectory
    isFile
    notIsFile
    test
    ;
  getDotdir = wrapper: "${wrapper}/${wrapper.configuration.configDirname}";
in
tlib.mkTestDrv "direnv-tests" [
  (test "wrapper should output correct version" (
    let
      wrapper = self.wrappers.direnv.wrap {
        inherit pkgs;
      };
    in
    ''
      "${wrapper}/bin/direnv" --version | grep -q "${wrapper.version}"
    ''
  ))
  (test "if nix-direnv is enabled then lib/nix-direnv.sh should exists" (
    let
      wrapper = self.wrappers.direnv.wrap {
        inherit pkgs;
        nix-direnv.enable = true;
      };
    in
    [
      (isDirectory (getDotdir wrapper))
      (isFile "${getDotdir wrapper}/lib/nix-direnv.sh")
    ]
  ))
  (test "if nix-direnv is disabled then lib/nix-direnv.sh should not exist" (
    let
      wrapper = self.wrappers.direnv.wrap {
        inherit pkgs;
        nix-direnv.enable = false;
      };
    in
    [
      (isDirectory (getDotdir wrapper))
      (notIsFile "${getDotdir wrapper}/lib/nix-direnv.sh")
    ]
  ))
  (test "if mise is enabled then lib/mise.sh should exists" (
    let
      wrapper = self.wrappers.direnv.wrap {
        inherit pkgs;
        mise.enable = true;
      };
    in
    [
      (isDirectory (getDotdir wrapper))
      (isFile "${getDotdir wrapper}/lib/mise.sh")
    ]
  ))
  (test "if mise is disabled then lib/mise.sh should not exist" (
    let
      wrapper = self.wrappers.direnv.wrap {
        inherit pkgs;
        mise.enable = false;
      };
    in
    [
      (isDirectory (getDotdir wrapper))
      (notIsFile "${getDotdir wrapper}/lib/mise.sh")
    ]
  ))
  (test "if a lib-script is set then it should be generated" (
    let
      libScriptFile = "${getDotdir wrapper}/lib/foo.sh";
      libScriptContent = "echo foo";
      wrapper = self.wrappers.direnv.wrap {
        inherit pkgs;
        lib."foo.sh" = libScriptContent;
      };
    in
    [
      (isDirectory (getDotdir wrapper))
      (isFile libScriptFile)
      (fileContains libScriptFile libScriptContent)
    ]
  ))
  (test "if silent mode is enabled then log settings should be set" (
    let
      direnvTomlFile = "${getDotdir wrapper}/direnv.toml";
      wrapper = self.wrappers.direnv.wrap {
        inherit pkgs;
        silent = true;
      };
    in
    [
      (isDirectory (getDotdir wrapper))
      (isFile direnvTomlFile)
      (fileContains direnvTomlFile "log_format")
      (fileContains direnvTomlFile "log_filter")
    ]
  ))
  (test "if extraConfig is working" (
    let
      direnvTomlFile = "${getDotdir wrapper}/direnv.toml";
      wrapper = self.wrappers.direnv.wrap {
        inherit pkgs;
        extraConfig = {
          fooSection.fooKey = "fooValue";
        };
      };
    in
    [
      (isDirectory (getDotdir wrapper))
      (isFile direnvTomlFile)
      (fileContains direnvTomlFile "\\[fooSection\\]")
      (fileContains direnvTomlFile "fooKey.*fooValue")
    ]
  ))
  (test "if direnvrc is working" (
    let
      direnvrcFile = "${getDotdir wrapper}/direnvrc";
      direnvrcContent = "echo foo";

      wrapper = self.wrappers.direnv.wrap {
        inherit pkgs;
        direnvrc = direnvrcContent;
      };
    in
    [
      (isDirectory (getDotdir wrapper))
      (isFile direnvrcFile)
      (fileContains direnvrcFile direnvrcContent)
    ]
  ))
]
