{
  config,
  lib,
  wlib,
  pkgs,
  ...
}:
{
  imports = [ wlib.modules.default ];
  options = {
    "env.nu" = lib.mkOption {
      type = wlib.types.file pkgs;
      default.content = "";
      default.path = config.constructFiles.generatedEnv.path;
      description = ''
        The Nushell environment configuration file.

        Provide either `.content` to inline the file contents or `.path` to reference an existing file.
        This file is passed to Nushell using `--env-config`, and is typically used to define
        environment variables or startup commands that apply to all shells.
      '';
    };
    "config.nu" = lib.mkOption {
      type = wlib.types.file pkgs;
      default.content = "";
      default.path = config.constructFiles.generatedConfig.path;
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
  config.constructFiles.generatedConfig = {
    content = config."config.nu".content;
    relPath = "${config.binName}-config/config.nu";
  };
  config.constructFiles.generatedEnv = {
    content = config."env.nu".content;
    relPath = "${config.binName}-config/env.nu";
  };
  config.passthru.shellPath = "/bin/nu";

  config.wrapperImplementation = "binary";

  config.package = lib.mkDefault pkgs.nushell;

  config.meta.maintainers = [ wlib.maintainers.birdee ];
}
