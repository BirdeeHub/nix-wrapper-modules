{
  config,
  lib,
  wlib,
  pkgs,
  ...
}:
{
  imports = [ wlib.modules.default ];
  options = {
    emacsPackage = lib.mkOption {
      default = pkgs.emacs;
      description = "The base emacs package. Defaults to pkgs.emacs";
    };
    emacsPackages = lib.mkOption {
      default = ps: [ ];
      example = lib.literalExpression "epkgs: with epkgs.melpaPackages; [ evil ivy ]";
      description = "Packages for emacs. This value is provided to pkgs.emacs.pkgs.withPackages, so it should
either be a list of emacs packages, or a function that takes a single input and returns a list of packages.
That input provides `.melpaPackages` which contains all packages from Melpa.

Note that this value is used in the default value for config.package. If you want to change the
emacs package, change `config.emacsPackage` or add your emacs packages back in manually.";
    };
    emacsConfig = lib.mkOption {
      type = lib.types.lines;
      default = "";
      example = ''
        (require 'use-package)

        (setq inhibit-startup-message t)
        (set-fringe-mode 10)
      '';
      description = ''
        emacs config file.

        Because of emacs quirks, if `~/.emacs` exists, then it will be used first.
        If you need to work around this, add [ [ "-l" config.constructFiles.init-el.outPath ] "-q" ]
        to config.addFlag.
      '';
    };
    emacsPreConfig = lib.mkOption {
      type = lib.types.lines;
      default = "";
      example = ''
        (setq extra-files-path $${./path/to/extra/files})
      '';
      description = "Prepended to emacsConfig. Recommended to use if you want your emacsConfig to be
a directly imported `.el` file, but want access to placeholder variables.

This is only read if `config.emacsConfig` has been set.";
    };
    userDirectory = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = "~/.emacs.d";
      description = "After loading our config file, `user-emacs-directory` will be set to the value of this
option. If the option is null, `user-emacs-directory` will point to a read-only location in the nix store
(not recommended, since some emacs packages depend on being able to write to .emacs.d).

This is done before config.emacsPreConfig, and is only read if `config.emacsConfig` has been set.";
    };
  };
  config.constructFiles.init = {
    relPath = "emacs.d/init.el";
    content =
      let
        move-emacs-d =
          if null == config.userDirectory then
            ""
          else
            ''
              (setq user-emacs-directory "${config.userDirectory}")
            '';
      in
      move-emacs-d + config.emacsPreConfig + "\n" + config.emacsConfig;
  };
  config.addFlag = lib.mkIf (config.emacsConfig != "") [
    [
      "--init-directory"
      (dirOf config.constructFiles.init.path)
    ]
  ];
  config.package =
    lib.mkDefault (config.emacsPackage config.emacsPackages);
  config.meta.description = "Wrapper for emacs";
  config.meta.platforms = lib.platforms.linux;
  config.meta.maintainers = [ wlib.maintainers.boundless-recursion ];
}
