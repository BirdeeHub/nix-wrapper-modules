{ lib, runCommand, ... }: 
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
    name: scripts:
    runCommand name { } ''
      ${lib.concatStringsSep "\n\n" scripts}
      touch $out
    '';

  runTest = name: assertions: ''
    run() {
      ${lib.concatMapStringsSep " && " (a: "(${a})") (lib.toList assertions)}
    }

    run || (echo 'test "${name}" failed' >&2 && exit 1)
  '';
}
