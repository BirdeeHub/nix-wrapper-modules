{
  config,
  lib,
  wlib,
  pkgs,
  ...
}:
let
  iniFmt = pkgs.formats.ini { };
  configFile = iniFmt.generate "cava-config" config.settings;
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
      "-p" = configFile;
    };
    meta.maintainers = [ wlib.maintainers.rachitvrma ];
    meta.platforms = [ "x86_64-linux" ];
  };
}
