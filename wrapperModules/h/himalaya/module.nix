{
  wlib,
  pkgs,
  config,
  lib,
  ...
}:
let
  tomlFmt = pkgs.formats.toml { };
in
{
  imports = [ wlib.modules.default ];

  options = {
    settings = lib.mkOption {
      type = tomlFmt.type;
      default = { };
      description = ''
        Configuration for himalaya mail client CLI
      '';
    };
  };
  config = {
    package = pkgs.himalaya;
    constructFiles = {
      generatedConfig = {
        relPath = "${config.binName}-config.toml";
        content = builtins.toJSON config.settings;
        builder = ''mkdir -p "$(dirname "$2")" && ${pkgs.remarshal}/bin/json2toml "$1" "$2"'';
      };
    };

    flags = {
      "--config" = config.constructFiles.generatedConfig.path;
    };

    env = {
      HIMALAYA_CONFIG = config.constructFiles.generatedConfig.path;
    };
    meta.maintainers = [ wlib.maintainers.rachitvrma ];
  };
}
