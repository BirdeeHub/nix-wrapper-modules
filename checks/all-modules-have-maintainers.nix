{
  pkgs,
  self,
}:

let
  # Get all modules and check their maintainers
  modulesWithoutMaintainers = pkgs.lib.filter (
    name: self.wrapperModules.${name}.meta.maintainers == [ ]
  ) (builtins.attrNames self.wrapperModules);

  hasMissingMaintainers = modulesWithoutMaintainers != [ ];

in
pkgs.runCommand "module-maintainers-test" { } ''
  echo "Checking that all modules have at least one maintainer..."

  ${
    if hasMissingMaintainers then
      ''
        echo "FAIL: The following modules are missing maintainers:"
        ${pkgs.lib.concatMapStringsSep "\n" (name: ''echo "  - ${name}"'') modulesWithoutMaintainers}
        exit 1
      ''
    else
      ''
        echo "SUCCESS: All modules have at least one maintainer"
      ''
  }

  touch $out
''
