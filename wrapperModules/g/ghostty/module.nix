{
  config,
  wlib,
  lib,
  pkgs,
  ...
}:
{
  imports = [ wlib.modules.default ];

  options = {
    settings = lib.mkOption {
      inherit (pkgs.formats.keyValue { }) type;
      default = { };
      description = ''
        Configuration for the Ghostty terminal emulator.
        See <https://ghostty.org/docs/config/reference>
      '';
    };
  };

  config.package = lib.mkDefault pkgs.ghostty;

  config.flagSeparator = "=";
  config.flags = {
    "--config-default-files" = "false";
    "--config-file" = config.constructFiles.cfg.path;
  };

  config.constructFiles.cfg = {
    content = lib.generators.toKeyValue { } config.settings;
    relPath = "${config.binName}.conf";
  };

  config.filesToPatch = [
    "share/applications/*.desktop"
    "share/dbus-1/services/com.mitchellh.ghostty.service"
    "share/systemd/user/app-com.mitchellh.ghostty.service"
  ];

  config.meta = {
    maintainers = [ wlib.maintainers.nouritsu ];
    platforms = lib.platforms.linux;
  };
}
