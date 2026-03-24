{
  config,
  lib,
  wlib,
  pkgs,
  ...
}:
let
  iniFmt = pkgs.formats.ini { };
in
{
  imports = [ wlib.modules.default ];
  options = {
    settings = lib.mkOption {
      type = iniFmt.type;
      default = { };
      description = ''
        Configuration for Cava
        See https://github.com/karlstav/cava#configuration for all available options.
      '';
    };
  };
  config = {
    package = lib.mkDefault pkgs.cava;
    flags = {
      "-p" = config.constructFiles.generatedConfig.path;
    };
    constructFiles.generatedConfig = {
      content = lib.generators.toINI { } config.settings;
      relPath = "${config.binName}.ini";
    };
    meta.maintainers = [ wlib.maintainers.rachitvrma ];
    meta.platforms = lib.platforms.linux;
  };
}
