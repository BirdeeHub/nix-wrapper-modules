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
      type = wlib.types.file {
        path = lib.mkOptionDefault config.constructFiles.generatedEnv.path;
      };
      default = { };
      description = ''
        The Nushell environment configuration file.

        Provide either `.content` to inline the file contents or `.path` to reference an existing file.

        The configuration directory of Nushell is set to a directory containing this file via
        the XDG_CONFIG_HOME environment variable.
      '';
    };
    "config.nu" = lib.mkOption {
      type = wlib.types.file {
        path = lib.mkOptionDefault config.constructFiles.generatedConfig.path;
      };
      default = { };
      description = ''
        The main Nushell configuration file.

        Provide either `.content` to inline the file contents or `.path` to reference an existing file.

        The configuration directory of Nushell is set to a directory containing this file via
        the XDG_CONFIG_HOME environment variable.

        You probably want to set $env.config.history.path here to prevent Nushell from trying to write
        the history file to the Nix store.
      '';
    };
    "login.nu" = lib.mkOption {
      type = wlib.types.file {
        path = lib.mkOptionDefault config.constructFiles.generatedConfig.path;
      };
      default = { };
      description = ''
        The Nushell login configuration file.

        Provide either `.content` to inline the file contents or `.path` to reference an existing file.

        The configuration directory of Nushell is set to a directory containing this file via
        the XDG_CONFIG_HOME environment variable.
      '';
    };
  };

  config.env.XDG_CONFIG_HOME = "${placeholder config.outputName}/${config.binName}-config";

  config.constructFiles.generatedConfig = {
    content = config."config.nu".content;
    relPath = "${config.binName}-config/nushell/config.nu";
  };
  config.constructFiles.generatedEnv = {
    content = config."env.nu".content;
    relPath = "${config.binName}-config/nushell/env.nu";
  };
  config.constructFiles.generatedLogin = {
    content = config."login.nu".content;
    relPath = "${config.binName}-config/nushell/login.nu";
  };

  config.passthru.shellPath = "/bin/nu";

  config.wrapperImplementation = "binary";

  config.package = lib.mkDefault pkgs.nushell;

  config.meta.maintainers = [ wlib.maintainers.birdee ];
}
