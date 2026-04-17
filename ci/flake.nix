{
  description = "Generates the website documentation for the nix-wrapper-modules repository";
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
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

          # Load checks from ci/checks/ directory
          coreAndCiChecks = lib.pipe ./checks [
            builtins.readDir
            builtins.attrNames
            (builtins.filter (name: lib.hasSuffix ".nix" name))
            (map (n: {
              name = lib.removeSuffix ".nix" n;
              value = ./checks + "/${n}";
            }))
            builtins.listToAttrs
          ];

          checksFrom =
            prefix: attrset:
            let
              importModuleCheck =
                name: value:
                let
                  helper = prefix: name: value: {
                    name = "${prefix}-${name}";
                    inherit value;
                  };
                  result = pkgs.callPackage value { inherit self; };
                in
                if result == null then
                  [ ]
                else if result ? outPath then
                  [ (helper prefix name result) ]
                else
                  lib.mapAttrsToList (helper "${prefix}-${name}") (lib.filterAttrs (_: v: v ? outPath) result);
            in
            lib.pipe attrset [
              (lib.mapAttrsToList importModuleCheck)
              builtins.concatLists
              builtins.listToAttrs
            ];
        in
        checksFrom "wlib" coreAndCiChecks
        // checksFrom "module" (wlib.checks.helper or { })
        // checksFrom "wrapperModule" (wlib.checks.wrapper or { })
      );
      formatter = forAllSystems (
        system: (wlib-flake (import nixpkgs { inherit system; })).formatter.${system}
      );
      packages = forAllSystems (system: {
        default = self.packages.${system}.docs.wrap { warningsAreErrors = true; };
        docs = wlib.evalPackage [
          ./docs
          {
            warningsAreErrors = lib.mkDefault false;
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
