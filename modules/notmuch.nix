{ wlib
, lib
, ...
}:
wlib.wrapModule (
  { config, wlib, ... }:
  let
    iniFmt = config.pkgs.formats.ini { };
    writeNotmuchConfig = cfg: iniFmt.generate "notmuch.ini" cfg;
  in
  {
    options = {
      config = lib.mkOption {
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
        default.path = toString (writeNotmuchConfig config.config);
      };
    };
    config.package = config.pkgs.notmuch;
    config.env.NOTMUCH_CONFIG = config.configFile.path;
  }
)
