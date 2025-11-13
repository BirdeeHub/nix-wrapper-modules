{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { self, nixpkgs }:
    let
      forAllSystems = nixpkgs.lib.genAttrs nixpkgs.lib.platforms.all;
    in
    {
      lib = import ./lib { inherit (nixpkgs) lib; };
      wrapperModules = nixpkgs.lib.mapAttrs (
        _: v: (self.lib.evalModule v).config
      ) self.lib.wrapperModules;
      formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.nixfmt-tree);
      templates = import ./templates;
      checks = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};

          # Load checks from checks/ directory
          checkFiles = builtins.readDir ./checks;
          importCheck = name: {
            name = nixpkgs.lib.removeSuffix ".nix" name;
            value = import (./checks + "/${name}") {
              inherit pkgs;
              self = self;
            };
          };
          checksFromDir = builtins.listToAttrs (
            map importCheck (
              builtins.filter (name: nixpkgs.lib.hasSuffix ".nix" name) (builtins.attrNames checkFiles)
            )
          );

          importModuleCheck = name: value: {
            name = "module-${name}";
            value = import value {
              inherit pkgs;
              self = self;
            };
          };
          checksFromModules = builtins.listToAttrs (
            nixpkgs.lib.mapAttrsToList importModuleCheck self.lib.checks
          );
        in
        checksFromDir // checksFromModules
      );
    };
}
