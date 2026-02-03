{
  pkgs,
  self,
}:

let
  getModulesWithoutMaintainers =
    module_set:
    pkgs.lib.filter (
      name:
      let
        module = module_set.${name};
        list = (self.lib.evalModule module).config.meta.maintainers;
        check = modpath: pkgs.lib.findFirst (v: toString v.file == toString modpath) null list == null;
      in
      if !pkgs.lib.isStringLike module then false else check module
    ) (builtins.attrNames module_set);

  modulesWithoutMaintainers =
    getModulesWithoutMaintainers self.lib.wrapperModules
    ++ getModulesWithoutMaintainers self.lib.modules;

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
