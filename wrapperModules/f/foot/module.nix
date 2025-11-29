{
  config,
  wlib,
  lib,
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
      inherit (iniFmt) type;
      default = { };
      description = ''
        Configuration of foot terminal.
        See {manpage}`foot.ini(5)`
      '';
    };
  };
  config.flags = {
    "--config" = iniFmt.generate "foot.ini" config.settings;
  };
  config.package = lib.mkDefault pkgs.foot;
  config.meta.maintainers = [ wlib.maintainers.birdee ];
  config.meta.platforms = lib.platforms.linux;
}
