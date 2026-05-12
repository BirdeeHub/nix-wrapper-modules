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
        Configuration of tealdeer.
        See <tealdeer-rs.github.io/tealdeer/config.html>
      '';
    };
  };
  config.flags = {
    "--config-path" = config.constructFiles.generatedConfig.path;
  };
  config.constructFiles.generatedConfig = {
    content = builtins.toJSON config.settings;
    relPath = "${config.binName}-config.toml";
    builder = ''${pkgs.remarshal}/bin/json2toml "$1" "$2"'';
  };
  config.package = lib.mkDefault pkgs.tealdeer;
  meta.maintainers = [ wlib.maintainers.birdee ];
}
