{
  config,
  lib,
  wlib,
  ...
}:
let
  iniFmt = config.pkgs.formats.ini { };
  writeNotmuchConfig = cfg: iniFmt.generate "notmuch.ini" cfg;
in
{
  imports = [ wlib.modules.default ];
  options = {
    settings = lib.mkOption {
      type = iniFmt.type;
      default = {
        database = {
          path = "Maildir";
          mail_root = "Maildir";
        };
      };
    };
    configFile = lib.mkOption {
      type = wlib.types.file config.pkgs;
      default.path = toString (writeNotmuchConfig config.settings);
    };
  };
  config.package = config.pkgs.notmuch;
  config.env.NOTMUCH_CONFIG = config.configFile.path;
  config.meta.maintainers = [ lib.maintainers.birdee ];
}
