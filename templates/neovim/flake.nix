{
  description = "Flake exporting a configured package using wlib.evalModule";
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  inputs.wrappers.url = "github:BirdeeHub/nix-wrapper-modules";
  inputs.wrappers.inputs.nixpkgs.follows = "nixpkgs";
  inputs.nvim-treesitter-textobjects = {
    url = "github:nvim-treesitter/nvim-treesitter-textobjects/main";
    flake = false;
  };
  outputs =
    {
      self,
      nixpkgs,
      wrappers,
      ...
    }@inputs:
    let
      forAllSystems = nixpkgs.lib.genAttrs nixpkgs.lib.platforms.all;
      module = nixpkgs.lib.modules.importApply ./module.nix inputs;
      wrapper = wrappers.lib.evalModule module;
    in
    {
      overlays = {
        default = final: prev: { neovim = wrapper.config.wrap { pkgs = final; }; };
        neovim = self.overlays.default;
      };
      wrapperModules = {
        default = module;
        neovim = self.wrapperModules.default;
      };
      wrappedModules = {
        default = wrapper.config;
        neovim = self.wrappedModules.default;
      };
      packages = forAllSystems (
        system:
        let
          pkgs = import nixpkgs { inherit system; };
        in
        {
          default = wrapper.config.wrap { inherit pkgs; };
          neovim = self.packages.${system}.default;
        }
      );
    };
}
