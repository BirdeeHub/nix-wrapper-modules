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
    settings = lib.mkOption {
      type = wlib.types.structuredValueWith {
        nullable = false;
        typeName = "TOML";
      };
      default = { };
      description = ''
        Configuration passed to `btm` using `--config_location` flag.

        See <https://github.com/ClementTsang/bottom/blob/master/sample_configs/default_config.toml>
        for the default configuration.
      '';
    };
  };
  config = {
    package = pkgs.bottom;
    flags = {
      "--config_location" = config.constructFiles.generatedConfig.path;
    };
    constructFiles.generatedConfig = {
      content = builtins.toJSON config.settings;
      relPath = "${config.binName}-config.toml";
      builder = ''${pkgs.remarshal}/bin/json2toml "$1" "$2"'';
    };
    meta.maintainers = [ wlib.maintainers.rachitvrma ];
  };
}
