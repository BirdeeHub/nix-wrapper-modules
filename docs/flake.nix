{
  description = "Generates the website documentation for the nix-wrapper-modules repository";
  # TODO: make the options expandable sections
  # TODO: allow filtering/sorting of options by module
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  outputs =
    {
      self,
      nixpkgs,
      ...
    }@inputs:
    let
      inherit (nixpkgs) lib;
      wlib = (import ./.. { inherit nixpkgs; }).lib;
      forAllSystems = lib.genAttrs lib.platforms.all;
    in
    {
      packages = forAllSystems (
        system:
        let
          pkgs = import nixpkgs { inherit system; };
        in
        {
          default = pkgs.callPackage ./. {
            inherit wlib;
          };
        }
      );
    };
}
