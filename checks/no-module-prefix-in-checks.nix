{
  pkgs,
  self,
}:

let
  # Get all check files in checks/ directory
  checkFiles = builtins.readDir ./.;

  # Filter for .nix files that start with "module-"
  checksWithModulePrefix = pkgs.lib.filter (
    name: pkgs.lib.hasPrefix "module-" name && pkgs.lib.hasSuffix ".nix" name
  ) (builtins.attrNames checkFiles);

  hasInvalidChecks = checksWithModulePrefix != [ ];

in
pkgs.runCommand "no-module-prefix-in-checks-test" { } ''
  echo "Checking that no checks in checks/ directory start with 'module-'..."

  ${
    if hasInvalidChecks then
      ''
        echo "FAIL: The following checks have invalid 'module-' prefix:"
        ${pkgs.lib.concatMapStringsSep "\n" (name: ''echo "  - ${name}"'') checksWithModulePrefix}
        echo ""
        echo "Checks starting with 'module-' are reserved for module-specific checks (modules/*/check.nix)."
        echo "Please rename these checks to avoid namespace collision."
        exit 1
      ''
    else
      ''
        echo "SUCCESS: No checks start with 'module-' prefix"
      ''
  }

  touch $out
''
