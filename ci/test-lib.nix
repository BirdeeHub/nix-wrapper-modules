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
  runTestWithConfig =
    { name, config ? { } }: assertions: wrapper:
    let
      wrapperWithConfig = wrapper.wrap config;
    in
    ''
      run() {
        ${lib.concatMapStringsSep " && " (a: "(${a})") (lib.toList (assertions wrapperWithConfig))}
      }

      run || (echo 'test "${name}" failed' >&2 && exit 1)
    '';
in
{
  inherit 
    createAssertion
    runTestWithConfig
    ;
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
    settings: tests:
    let
      wrapper = settings.wrapperModule.apply { inherit pkgs; };
      name = settings.name or "${wrapper.binName}-test";
      testsWithWrapper = lib.map (test: test wrapper) tests;
    in
    if builtins.elem stdenv.hostPlatform.system wrapper.meta.platforms then
      lib.trace "Running test!" runCommand name { } ''
        ${lib.concatStringsSep "\n\n" testsWithWrapper}
        touch $out
      ''
    else
      lib.trace "Skipping test..." null;
  runTest =
    nameOrSettings: assertions: wrapper:
    let
      settings = 
        if (lib.isAttrs nameOrSettings) && (nameOrSettings ? name) then
          nameOrSettings
        else if lib.isString nameOrSettings then
          { 
            name = nameOrSettings;
          }
        else
          throw ''
            Invalid argument for `runTest`.
            The first argument must be either a string (the test name) or an attrs
            matching { name, config ? { } }, but got:

            ${lib.toJSON nameOrSettings}
          '';
    in
      runTestWithConfig settings assertions wrapper;

}
