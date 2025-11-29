{
  config,
  lib,
  wlib,
  pkgs,
  ...
}:
let
  gitIniFmt = pkgs.formats.gitIni { };
in
{
  imports = [ wlib.modules.default ];
  options = {
    settings = lib.mkOption {
      type = gitIniFmt.type;
      default = { };
      description = ''
        Git configuration settings.
        See {manpage}`git-config(1)` for available options.
      '';
    };

    configFile = lib.mkOption {
      type = wlib.types.file pkgs;
      default.path = gitIniFmt.generate "gitconfig" config.settings;
      description = "Generated git configuration file.";
    };
  };

  config.env.GIT_CONFIG_GLOBAL = config.configFile.path;
  config.package = lib.mkDefault pkgs.git;
  config.meta.maintainers = [ wlib.maintainers.birdee ];
}
