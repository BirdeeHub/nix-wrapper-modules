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
      wrappedModules = lib.mapAttrs (_: v: (self.lib.evalModule v).config) self.lib.wrapperModules;
      wrapperModules = lib.mapAttrs (
        _: v:
        lib.warn ''
          Attention: `wrapperModules` is deprecated, use `wrappedModules` instead

          Apologies for any inconvenience this has caused. But the title `wrapperModules` should be specific to ones you can import.

          In the future, rather than being removed, this will be replaced by the unevaluated wrapper modules from `wlib.wrapperModules`
        '' (self.lib.evalModule v).config
      ) self.lib.wrapperModules;
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
