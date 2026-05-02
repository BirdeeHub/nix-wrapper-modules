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
      type = iniFmt.type;
      default = { };
      description = ''
        Configuration of wl-kbptr.
        See `wl-kbptr --help-config`
      '';
    };
  };

  config.package = lib.mkDefault pkgs.wl-kbptr;

  config = {
    flagSeparator = "=";
    flags."--config" = config.constructFiles.generatedConfig.path;
    constructFiles.generatedConfig = {
      content = lib.generators.toINI { } config.settings;
      relPath = "${config.binName}.ini";
    };
    meta = {
      maintainers = [ wlib.maintainers.nouritsu ];
      platforms = lib.platforms.linux;
    };
  };
}
