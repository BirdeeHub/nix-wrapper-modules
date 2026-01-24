{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { self, ... }@inputs:
    let
      fpkgs =
        system:
        if inputs.pkgs.stdenv.hostPlatform.system or null == system then
          inputs.pkgs
        else
          import (inputs.pkgs.path or inputs.nixpkgs or <nixpkgs>) {
            inherit system;
            config.allowUnfree = true;
          };
      lib = inputs.pkgs.lib or inputs.nixpkgs.lib or (import "${inputs.nixpkgs or <nixpkgs>}/lib");
      forAllSystems = lib.genAttrs lib.platforms.all;
    in
    {
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
          checksFromModules = builtins.listToAttrs (
            builtins.filter (v: v.value or null != null) (lib.mapAttrsToList importModuleCheck self.lib.checks)
          );
        in
        checksFromDir // checksFromModules
      );
    };
}
