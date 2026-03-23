{
  config,
  lib,
  wlib,
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
      inherit (tomlFmt) type;
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
    builder = ''mkdir -p "$(dirname "$2")" && ${pkgs.remarshal}/bin/json2toml "$1" "$2"'';
  };
  config.package = lib.mkDefault pkgs.tealdeer;
  meta.maintainers = [ wlib.maintainers.birdee ];
}
