{
  config,
  wlib,
  lib,
  ...
}:
let
  iniFmt = config.pkgs.formats.ini { };
in
{
  imports = [ wlib.modules.default ];
  options = {
    settings = lib.mkOption {
      type = iniFmt.type;
      default = { };
      description = ''
        Configuration of fuzzel.
        See {manpage}`fuzzel.ini(5)`
      '';
    };
  };
  config.flagSeparator = "=";
  config.flags = {
    "--config" = iniFmt.generate "fuzzel.ini" config.settings;
  };
  config.package = lib.mkDefault config.pkgs.fuzzel;
  config.meta.maintainers = [ lib.maintainers.birdee ];
  config.meta.platforms = lib.platforms.linux;
}
