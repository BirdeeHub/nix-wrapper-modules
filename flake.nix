{
  description = ''
    A Nix library for wrapping programs with their configuration into a single derivation via the nixpkgs module system.
  '';
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  outputs =
    { self, ... }@inputs:
    let
      lib = inputs.pkgs.lib or inputs.nixpkgs.lib or (import "${inputs.nixpkgs or <nixpkgs>}/lib");
      forAllSystems = lib.genAttrs lib.platforms.all;
      getPkgs =
        system:
        if inputs.pkgs.stdenv.hostPlatform.system or null == system then
          inputs.pkgs
        else
          import (inputs.pkgs.path or inputs.nixpkgs or <nixpkgs>) {
            inherit system;
            overlays = inputs.pkgs.overlays or [ ];
            config = inputs.pkgs.config or { };
          };
    in
    {
      templates = import ./templates;
      lib = import ./lib { inherit lib; };
      wrappers = lib.mapAttrs (_: v: (self.lib.evalModule v).config) self.lib.wrapperModules;
      wrapperModules = self.lib.wrapperModules;
      flakeModules = {
        wrappers = ./parts.nix;
        default = self.flakeModules.wrappers;
      };
      nixosModules = builtins.mapAttrs (
        name: value: self.lib.getInstallModule { inherit name value; }
      ) self.lib.wrapperModules;
      homeModules = self.nixosModules;
      hjemModules = self.nixosModules;
      devShells = forAllSystems (system: {
        default = import ./shell.nix { pkgs = getPkgs system; };
      });
      formatter = forAllSystems (system: (getPkgs system).nixfmt-tree);
      wrappedModules = lib.mapAttrs (
        _:
        lib.warn ''
          Attention: `inputs.nix-wrapper-modules.wrappedModules` is deprecated, use `inputs.nix-wrapper-modules.wrappers` instead

          Apologies for any inconvenience this has caused, but they are only the config set of a module, not a module themselves.

          In addition, it was very hard to tell the name apart from its actual module counterpart, and it was longer than convenient.

          This will be the last time these output names are changing, as a flake-parts module has been added for users to import.

          This output will be removed on August 31, 2026
        ''
      ) self.wrappers;
    };
}
