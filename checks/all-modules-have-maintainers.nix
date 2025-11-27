{
  pkgs,
  self,
}:

let
  # Get all modules and check their maintainers
  modulesWithoutMaintainers = pkgs.lib.filter (
    name:
    let
      module = self.lib.wrapperModules.${name};
      list = (self.lib.evalModule module).config.meta.maintainers;
    in
    pkgs.lib.findFirst (v: toString v.file == toString module) null list == null
  ) (builtins.attrNames self.lib.wrapperModules);

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
