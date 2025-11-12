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
      description = ''
        INI-style configuration for Notmuch.

        This option defines the contents of the `notmuch.ini` configuration file.
        Use attribute sets to specify sections and key-value pairs.
        Example:
        ```
        settings = {
          user = { name = "Alice"; primary_email = "alice@example.org"; };
          database = { path = "Maildir"; };
        };
        ```
      '';
    };
    configFile = lib.mkOption {
      type = wlib.types.file config.pkgs;
      default.path = toString (writeNotmuchConfig config.settings);
      description = ''
        Path or inline definition of the generated Notmuch configuration file.

        By default, this is automatically created from the `settings` option
        using the INI format generator.
      '';
    };
  };
  config.package = config.pkgs.notmuch;
  config.env.NOTMUCH_CONFIG = config.configFile.path;
  config.meta.maintainers = [ lib.maintainers.birdee ];
}
