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
      description = ''
        The Nushell environment configuration file.

        Provide either `.content` to inline the file contents or `.path` to reference an existing file.
        This file is passed to Nushell using `--env-config`, and is typically used to define
        environment variables or startup commands that apply to all shells.
      '';
    };
    "config.nu" = lib.mkOption {
      type = wlib.types.file config.pkgs;
      default.content = "";
      description = ''
        The main Nushell configuration file.

        Provide either `.content` to inline the file contents or `.path` to reference an existing file.
        This file is passed to Nushell using `--config`, and controls general shell behavior,
        key bindings, and built-in command settings.
      '';
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
