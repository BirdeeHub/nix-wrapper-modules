inputs:
{
  config,
  wlib,
  lib,
  pkgs,
  ...
}:
{
  imports = [ wlib.wrapperModules.neovim ];
  # choose a directory for your config.
  # this can be a string, for if you don't want nix to manage it right now.
  # but be careful, it also doesn't get provisioned by nix if it isnt in the store.
  config.settings.config_directory = ./.;

  # The makeWrapper options are available
  config.extraPackages = with pkgs; [
    lazygit
    lua-language-server
    tree-sitter
    stylua
    nixd
    alejandra
  ];
  # your config/plugin specifications
  # a set of plugins or specs, which can contain a list of plugins or specs if desired.
  config.specs.general = with pkgs.vimPlugins; [
    {
      # These can be specs too!
      data = snacks-nvim;
      # maybe you want to do something like this?

      # lazy = false | true;
      # type = "lua" | "fnl" | "vim";
      # info = { /* some opts from nix to the config */ };
      # config = ''
      #   local info, pname, lazy = ...
      #   -- run snacks bigfile or something
      # '';

      # before = [ "INIT_MAIN" ];
      # putting before = [ "INIT_MAIN" ] here will run this before the main init

      # things can target any spec that has a name.
      name = "snacks-spec";
      # now something else can be after = [ "snacks-spec" ]
      # the spec name is not the plugin name.
      # to override the plugin name, use `pname`
    }
    onedark-nvim
    vim-sleuth
    mini-ai
    mini-icons
    mini-pairs
    nvim-lspconfig
    vim-startuptime
    blink-cmp
    lualine-nvim
    lualine-lsp-progress
    gitsigns-nvim
    which-key-nvim
    nvim-lint
    conform-nvim
    nvim-dap-ui
    nvim-dap-virtual-text
    # building a plugin from a source outside of nixpkgs
    (config.nvim-lib.mkPlugin "treesitter-textobjects" inputs.nvim-treesitter-textobjects)
    # treesitter + grammars
    nvim-treesitter.withAllGrammars
    # This is for if you only want some of the grammars
    # (nvim-treesitter.withPlugins (
    #   plugins: with plugins; [
    #     nix
    #     lua
    #   ]
    # ))
  ];

  # you can name these whatever you want. These ones are named `general` and `lazy`
  # You can use the before and after fields to run them before or after other specs or spec of lists of specs
  config.specs.lazy = {
    # this `lazy = true` definition will transfer to specs in the contained DAL, if there is one.
    # This is because the definition of lazy in `config.specMods` checks `parentSpec.lazy or false`
    # the submodule type for `config.specMods` gets `parentSpec` as a `specialArg`.
    # you can define options like this too!
    lazy = true;
    # here we chose a DAL of plugins, but we can also pass a single plugin, or null
    # plugins are of type wlib.types.stringable
    data = with pkgs.vimPlugins; [
      lazydev-nvim
    ];
    # top level specs don't need to declare their dag name to be targetable.
    # so we can target general here, without adding name = "general" in the `general` spec above.
    # in fact, we didn't even need to give `general` a spec, its just a list!
    after = [ "general" ];
  };

  # These specMods are modules which modify your specs in config.specs
  # you can override defaults, or make your own options.
  config.specMods =
    { parentSpec, ... }:
    {
      config.collateGrammars = lib.mkDefault (parentSpec.collateGrammars or true);
    };
  # or, if you dont care about propagating parent values:
  # config.specMods.collateGrammars = lib.mkDefault true;

  # There are some default hosts!
  # python, ruby, and node are enabled by default
  # perl and neovide are not.

  # To add a wrapped $out/bin/${config.binName}-neovide to the resulting neovim derivation
  # config.hosts.neovide.nvim-host.enable = true;

  # If you want to install multiple neovim derivations via home.packages or environment.systemPackages
  # in order to prevent path collisions:

  # set this to true:
  # config.settings.dont_link = true;

  # and make sure these dont share values:
  # config.binName = "nvim";
  # config.settings.aliases = [ ];
}
