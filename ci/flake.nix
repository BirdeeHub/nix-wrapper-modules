{
  description = "Generates the website documentation for the nix-wrapper-modules repository";
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/master";
  outputs =
    { nixpkgs, self, ... }:
    let
      inherit (nixpkgs) lib;
      forAllSystems = lib.genAttrs lib.platforms.all;
      wlib-flake =
        pkgs: if pkgs == null then import ./.. { inherit nixpkgs; } else import ./.. { inherit pkgs; };
      wlib-flake-nofmt = removeAttrs (wlib-flake null) [ "formatter" ];
      wlib = wlib-flake-nofmt.lib;
    in
    wlib-flake-nofmt
    // {
      checks = forAllSystems (
        system:
        let
          pkgs = import nixpkgs {
            inherit system;
            config.allowUnfree = true;
          };

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

          importModuleCheck = prefix: name: value: {
            name = "${prefix}-${name}";
            value = import value {
              inherit pkgs;
              self = self;
            };
          };
          checksFromModules = builtins.listToAttrs (
            builtins.filter (v: v.value or null != null) (
              lib.mapAttrsToList (importModuleCheck "module") (wlib.checks.helper or { })
            )
          );
          checksFromWrapperModules = builtins.listToAttrs (
            builtins.filter (v: v.value or null != null) (
              lib.mapAttrsToList (importModuleCheck "wrapperModule") (wlib.checks.wrapper or { })
            )
          );
        in
        checksFromDir // checksFromModules // checksFromWrapperModules
      );
      formatter = forAllSystems (
        system: (wlib-flake (import nixpkgs { inherit system; })).formatter.${system}
      );
      packages = forAllSystems (system: {
        default = self.packages.${system}.docs;
        docs = wlib.evalPackage [
          ./docs
          {
            pkgs = import nixpkgs {
              inherit system;
              config = {
                # note: we want the name
                # so that config.binName and config.package and config.exePath look nice in docs
                # Nothing should build. This is fine...
                allowUnfree = true;
                allowBroken = true;
                allowUnsupportedSystem = true;
              };
            };
          }
        ];
      });
    };
}
