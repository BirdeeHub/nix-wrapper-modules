{
  config,
  lib,
  wlib,
  ...
}:
{
  imports = [ wlib.modules.default ];
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

  config.meta.maintainers = [ lib.maintainers.birdee ];
}
