{
  self,
  lib,
  runCommand,
  stdenv,
  pkgs,
  ...
}:
let
  createAssertion =
    { cond, message }:
    ''
      (${cond}) || (echo "${message}" >&2; return 1)
    '';
in
{
  inherit createAssertion;
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
    wrapperModule: tests:
    let
      wrapper = wrapperModule.apply { inherit pkgs; };
      testsWithWrapper = lib.map (test: test wrapper) tests;
    in
    if builtins.elem stdenv.hostPlatform.system wrapper.meta.platforms then
      lib.trace "Running test!" runCommand "${wrapper.binName}-test" { } ''
        ${lib.concatStringsSep "\n\n" testsWithWrapper}
        touch $out
      ''
    else
      lib.trace "Skipping test..." null;
  runTest =
    name: config: assertions: wrapper:
    let
      wrapperWithConfig = wrapper.wrap config;
    in
    ''
      run() {
        ${lib.concatMapStringsSep " && " (a: "(${a})") (lib.toList (assertions wrapperWithConfig))}
      }

      run || (echo 'test "${name}" failed' >&2 && exit 1)
    '';
}
