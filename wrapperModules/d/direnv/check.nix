{
  pkgs,
  self,
}:

let
  lib = pkgs.lib;
  createAssertion =
    { cond, message }:
    ''
      (${cond}) || (echo "${message}" >&2; return 1)
    '';

  isDirectory =
    path:
    createAssertion {
      cond = ''[ -d "${path}" ]'';
      message = "No such directory ${path}";
    };
  isFile =
    path:
    createAssertion {
      cond = ''[ -f "${path}" ]'';
      message = "No such file ${path}";
    };
  notIsFile =
    path:
    createAssertion {
      cond = ''[ ! -f "${path}" ]'';
      message = "File ${path} should not exist";
    };

  fileContains =
    file: pattern:
    createAssertion {
      cond = ''grep -q '${pattern}' "${file}"'';
      message = "Pattern '${pattern}' not found in ${file}";
    };

  runTests =
    name: scripts:
    pkgs.runCommand name { } ''
      ${lib.concatStringsSep "\n\n" scripts}
      touch $out
    '';

  runTest = name: assertions: ''
    run() {
      ${lib.concatMapStringsSep " && " (a: "(${a})") (lib.toList assertions)}
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
    [
      (isDirectory (getDotdir wrapper))
      (isFile "${getDotdir wrapper}/lib/nix-direnv.sh")
    ]
  ))
  (runTest "if nix-direnv is disabled then lib/nix-direnv.sh should not exist" (
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
  (runTest "if a lib-script is set then it should be generated" (
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
  (runTest "if silent mode is enabled then log settings should be set" (
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
    [
      (isDirectory (getDotdir wrapper))
      (isFile direnvTomlFile)
      (fileContains direnvTomlFile "\\[fooSection\\]")
      (fileContains direnvTomlFile "fooKey.*fooValue")

    ]
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
    [
      (isDirectory (getDotdir wrapper))
      (isFile direnvrcFile)
      (fileContains direnvrcFile direnvrcContent)

    ]
  ))
]
