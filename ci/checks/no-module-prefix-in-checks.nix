{
  pkgs,
  self,
}:

let
  # Get all check files in checks/ directory
  checkFiles = builtins.readDir ./.;

  # Filter for .nix files that start with "module-"
  checksWithPrefix =
    prefix:
    pkgs.lib.filter (name: pkgs.lib.hasPrefix prefix name && pkgs.lib.hasSuffix ".nix" name) (
      builtins.attrNames checkFiles
    );

  invalidChecksMod = checksWithPrefix "module-";
  invalidChecksWrap = checksWithPrefix "wrapperModule-";

in
pkgs.runCommand "no-module-prefix-in-checks-test" { } ''
  echo "Checking that no checks in ci/checks/ directory start with 'module-' or 'wrapperModule-'..."

  ${
    if invalidChecksMod != [ ] then
      ''
        echo "FAIL: The following checks have invalid 'module-' prefix:"
        ${pkgs.lib.concatMapStringsSep "\n" (name: ''echo "  - ${name}"'') invalidChecksMod}
        echo ""
        echo "Checks starting with 'module-' are reserved for module-specific checks (modules/*/check.nix)."
        echo "Please rename these checks to avoid namespace collision."
        exit 1
      ''
    else if invalidChecksWrap != [ ] then
      ''
        echo "FAIL: The following checks have invalid 'wrapperModule-' prefix:"
        ${pkgs.lib.concatMapStringsSep "\n" (name: ''echo "  - ${name}"'') invalidChecksWrap}
        echo ""
        echo "Checks starting with 'wrapperModule-' are reserved for wrapperModule-specific checks (wrapperModules/*/*/check.nix)."
        echo "Please rename these checks to avoid namespace collision."
        exit 1
      ''
    else
      ''
        echo "SUCCESS: No checks start with 'module-' or 'wrapperModule-' prefixes"
      ''
  }

  touch $out
''
