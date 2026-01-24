{
  config,
  wlib,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib) types;
in
{
  imports = [ wlib.modules.default ];

  options = {
    plugins = lib.mkOption {
      type = types.listOf types.package;
      default = [ pkgs.vimPlugins.vim-sensible ];
      example = lib.literalExpression "[ pkgs.vimPlugins.YankRing-vim ]";
      description = ''
        List of vim plugins to install.

        Loaded on launch.

        To get a list of supported plugins run:
        {command}`nix-env -f '<nixpkgs>' -qaP -A vimPlugins`.
      '';
    };

    optionalPlugins = lib.mkOption {
      type = types.listOf types.package;
      default = [ ];
      example = lib.literalExpression "[ pkgs.vimPlugins.elm-vim ]";
      description = ''
        List of vim plugins to install.

        Manually loadable by calling `:packadd $plugin-name`.

        If a plugin has a dependency that is not explicitly listed in
        {option}`optionalPlugins`, that dependency will always be added to
        {option}`plugins` to avoid confusion.

        To get a list of supported plugins run:
        {command}`nix-env -f '<nixpkgs>' -qaP -A vimPlugins`.
      '';
    };

    vimrc = lib.mkOption {
      type = types.lines;
      default = "";
      example = ''
        set nocompatible
        set nobackup
      '';
      description = ".vimrc config";
    };

    overrides = lib.mkOption {
      type = wlib.types.seriesOf (
        wlib.types.spec {
          config.after = lib.mkDefault [ "makeCustomizable" ];
        }
      );
    };
  };

  config.overrides = [
    {
      name = "makeCustomizable";
      data =
        package:
        wlib.makeCustomizable "customize" { }
          (
            if package ? customize then
              package.customize
            else
              (pkgs.vimUtils.makeCustomizable package).customize
          )
          {
            vimrcConfig = {
              customRC = config.vimrc;
              packages.nix-wrapper-modules.start = config.plugins;
              packages.nix-wrapper-modules.opt = config.optionalPlugins;
            };
          };
    }
  ];

  config.package = lib.mkDefault pkgs.vim-full;
  config.binName = "vim";
  config.exePath = "bin/vim";

  meta.maintainers = [ wlib.maintainers.ameer ];
}
