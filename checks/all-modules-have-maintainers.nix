{
  pkgs,
  self,
}:

let
  # Get all modules and check their maintainers
  # TODO: Isolate maintainers from wrapper module from that of helper module
  # do evalModule here, and use graph and disabledModules to disable the other ones.
  # That way, every wrapper doesnt end up with the same maintainer
  # as its helper module for the purposes of this test.
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
