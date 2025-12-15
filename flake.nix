{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { self, ... }@inputs:
    let
      fpkgs =
        system:
        if inputs.pkgs.stdenv.hostPlatform.system or null == system then
          inputs.pkgs
        else if inputs.nixpkgs.legacyPackages ? "${system}" then
          inputs.nixpkgs.legacyPackages.${system}
        else
          import (inputs.pkgs.path or inputs.nixpkgs or <nixpkgs>) { inherit system; };
      lib = inputs.pkgs.lib or inputs.nixpkgs.lib or (import "${inputs.nixpkgs or <nixpkgs>}/lib");
      forAllSystems = lib.genAttrs lib.platforms.all;
    in
    {
      lib = import ./lib { inherit lib; };
      wrapperModules = lib.mapAttrs (_: v: (self.lib.evalModule v).config) self.lib.wrapperModules;
      formatter = forAllSystems (system: (fpkgs system).nixfmt-tree);
      templates = import ./templates;
      checks = forAllSystems (
        system:
        let
          pkgs = fpkgs system;

          # Load checks from checks/ directory
          checkFiles = builtins.readDir ./checks;
          importCheck = name: {
            name = lib.removeSuffix ".nix" name;
            value = import (./checks + "/${name}") {
              inherit pkgs;
              self = self;
            };
          };
          checksFromDir = builtins.listToAttrs (
            map importCheck (builtins.filter (name: lib.hasSuffix ".nix" name) (builtins.attrNames checkFiles))
          );

          importModuleCheck = name: value: {
            name = "module-${name}";
            value = import value {
              inherit pkgs;
              self = self;
            };
          };
          checksFromModules = builtins.listToAttrs (lib.mapAttrsToList importModuleCheck self.lib.checks);
        in
        checksFromDir // checksFromModules
      );
    };
}
