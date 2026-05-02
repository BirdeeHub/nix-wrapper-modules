{
  config,
  wlib,
  lib,
  pkgs,
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
        Atuin configuration options.
      '';
    };
  };

  config = {
    package = lib.mkDefault pkgs.atuin;
    env.ATUIN_CONFIG_DIR = "${placeholder "out"}/${config.binName}-config";
    constructFiles.generatedConfig = {
      content = builtins.toJSON config.settings;
      relPath = "${config.binName}-config/config.toml";
      builder = ''mkdir -p "$(dirname "$2")" && ${pkgs.remarshal}/bin/json2toml "$1" "$2"'';
    };
    meta.maintainers = [ wlib.maintainers.appleptree ];
  };
}
