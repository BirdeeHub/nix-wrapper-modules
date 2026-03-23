{
  wlib,
  lib,
  pkgs,
  config,
  ...
}:
{
  imports = [ wlib.modules.default ];
  options = {
    settings = lib.mkOption {
      type =
        with lib.types;
        attrsOf (oneOf [
          bool
          int
          float
          wlib.types.stringable
        ]);

      default = { };

      description = ''
        Default arguments to {command}`swaylock`. An empty set
        disables configuration generation.
      '';

      example = {
        color = "808080";
        font-size = 24;
        indicator-idle-visible = false;
        indicator-radius = 100;
        line-color = "ffffff";
        show-failed-attempts = true;
      };
    };
  };
  config = {
    package = lib.mkDefault pkgs.swaylock;

    constructFiles.generatedConfig = {
      relPath = "${config.binName}-config";
      content = lib.concatStrings (
        lib.mapAttrsToList (
          n: v:
          if v == false then
            ""
          else
            (if v == true then n else n + "=" + (if builtins.isPath v then "${v}" else toString v)) + "\n"
        ) config.settings
      );
    };

    flags = {
      "--config" = config.constructFiles.generatedConfig.path;
    };

    meta.maintainers = [ wlib.maintainers.rachitvrma ];
  };
}
