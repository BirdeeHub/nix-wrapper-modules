{
  wlib,
  pkgs,
  config,
  lib,
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
        Configuration for himalaya mail client CLI
      '';
    };
  };
  config = {
    package = lib.mkDefault pkgs.himalaya;
    constructFiles = {
      generatedConfig = {
        relPath = "${config.binName}-config.toml";
        content = builtins.toJSON config.settings;
        builder = ''${pkgs.remarshal}/bin/json2toml "$1" "$2"'';
      };
    };

    flags = {
      "--config" = lib.mkIf (config.settings != { }) config.constructFiles.generatedConfig.path;
    };

    meta.maintainers = [ wlib.maintainers.rachitvrma ];
  };
}
