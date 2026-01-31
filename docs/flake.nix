{
  description = "Generates the website documentation for the nix-wrapper-modules repository";
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  outputs =
    { nixpkgs, ... }:
    let
      inherit (nixpkgs) lib;
      wlib = (import ./.. { inherit nixpkgs; }).lib;
      forAllSystems = lib.genAttrs lib.platforms.all;
    in
    {
      packages = forAllSystems (system: {
        default = wlib.evalPackage [
          ./.
          {
            pkgs = import nixpkgs {
              inherit system;
              config.allowUnfree = true;
            };
          }
        ];
      });
    };
}
