{
  description = ''
    Will eventually automatically generate
    wrapper modules documentation

    Currently just generates markdown and copies to a target directory

    TODO: make this work in a way that is useful.
  '';
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
