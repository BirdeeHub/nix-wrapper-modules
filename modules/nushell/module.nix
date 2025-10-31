{
  wlib,
  lib,
  ...
}:
wlib.wrapModule (
  { config, wlib, ... }:
  {
    options = {
      "env.nu" = lib.mkOption {
        type = wlib.types.file config.pkgs;
        default.content = "";
      };
      "config.nu" = lib.mkOption {
        type = wlib.types.file config.pkgs;
        default.content = "";
      };
    };

    config.flagSeparator = "=";
    config.flags = {
      "--config" = config."config.nu".path;
      "--env-config" = config."env.nu".path;
    };

    config.package = lib.mkDefault config.pkgs.nushell;
  }
)
