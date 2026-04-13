{
  config,
  wlib,
  lib,
  pkgs,
  ...
}:
let
  yamlFmt = pkgs.formats.yaml { };
in
{
  imports = [ wlib.modules.default ];

  options = {
    configPath = lib.mkOption {
      type = wlib.types.stringable;
      default = config.constructFiles.cfg.path;
      description = "Path to YAML configuration file.";
    };

    settings = lib.mkOption {
      type = yamlFmt.type;
      default = { };
      description = ''
        Configuration for wlr-which-key.
        See <https://github.com/MaxVerevkin/wlr-which-key>
      '';
    };

    initialKeys = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = ''
        Space separated key sequence to execute after launching menu.
      '';
    };
  };

  config.package = lib.mkDefault pkgs.wlr-which-key;

  config.flags."--initial-keys" = lib.mkIf (config.initialKeys != "") config.initialKeys;
  config.addFlag = [ config.configPath ];

  config.constructFiles.cfg = {
    content = lib.generators.toYAML { } config.settings;
    relPath = "${config.binName}.yaml";
  };

  config.meta = {
    maintainers = [ wlib.maintainers.nouritsu ];
    platforms = lib.platforms.linux;
  };
}
