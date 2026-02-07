{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

  outputs =
    { self, ... }@inputs:
    let
      lib = inputs.pkgs.lib or inputs.nixpkgs.lib or (import "${inputs.nixpkgs or <nixpkgs>}/lib");
      forAllSystems = lib.genAttrs lib.platforms.all;
    in
    {
      templates = import ./templates;
      lib = import ./lib { inherit lib; };
      flakeModules = {
        wrappers = ./parts.nix;
        default = self.flakeModules.wrappers;
      };
      nixosModules = builtins.mapAttrs (name: value: {
        inherit name value;
        _file = value;
        key = value;
        __functor = self.lib.mkInstallModule;
      }) self.lib.wrapperModules;
      homeModules = builtins.mapAttrs (
        _: v:
        v
        // {
          loc = [
            "home"
            "packages"
          ];
        }
      ) self.nixosModules;
      wrappers = lib.mapAttrs (_: v: (self.lib.evalModule v).config) self.lib.wrapperModules;
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
      wrapperModules = lib.mapAttrs (
        _:
        lib.warn ''
          Attention: `inputs.nix-wrapper-modules.wrapperModules` is deprecated, use `inputs.nix-wrapper-modules.wrappers` instead

          Apologies for any inconvenience this has caused. But the title `wrapperModules` should be specific to ones you can import.

          In the future, rather than being removed, this will be replaced by the unevaluated wrapper modules from `wlib.wrapperModules`

          This output will be replaced with module paths on April 30, 2026
        ''
      ) self.wrappers;
      formatter = forAllSystems (
        system:
        (
          if inputs.pkgs.stdenv.hostPlatform.system or null == system then
            inputs.pkgs
          else
            import (inputs.pkgs.path or inputs.nixpkgs or <nixpkgs>) {
              inherit system;
              overlays = inputs.pkgs.overlays or [ ];
            }
        ).nixfmt-tree
      );
    };
}
