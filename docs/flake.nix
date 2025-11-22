{
  description = "Generates the website documentation for the nix-wrapper-modules repository";
  # TODO: make the options expandable sections
  # TODO: allow filtering/sorting of options by module
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  inputs.nixdoc.url = "github:nix-community/nixdoc";
  outputs =
    {
      self,
      nixpkgs,
      nixdoc,
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
          default = pkgs.callPackage ./collect.nix {
            inherit wlib;
            nixdoc = nixdoc.packages.${system}.default;
          };
        }
      );
    };
}
