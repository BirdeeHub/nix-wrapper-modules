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
    server-settings = lib.mkOption {
      type = tomlFmt.type;
      default = { };
      description = ''
        Atuin server configuration options.
      '';
    };
  };

  config = {
    package = lib.mkDefault pkgs.atuin;
    env.ATUIN_CONFIG_DIR = dirOf config.constructFiles.generatedConfig.path;
    passthru.ATUIN_CONFIG_DIR = "${config.wrapper.out}/${config.binName}-config";
    constructFiles = {
      generatedConfig = {
        content = builtins.toJSON config.settings;
        relPath = "${config.binName}-config/config.toml";
        builder = ''mkdir -p "$(dirname "$2")" && ${pkgs.remarshal}/bin/json2toml "$1" "$2"'';
      };
      generatedServerConfig = {
        content = builtins.toJSON config.server-settings;
        output = lib.mkOverride 0 config.constructFiles.generatedConfig.output;
        relPath = lib.mkOverride 0 "${dirOf config.constructFiles.generatedConfig.relPath}/server.toml";
        builder = ''mkdir -p "$(dirname "$2")" && ${pkgs.remarshal}/bin/json2toml "$1" "$2"'';
      };
    };
    wrapperVariants.atuin-server = { };
    meta.maintainers = [ wlib.maintainers.appleptree ];
  };
}
