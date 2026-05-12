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
        Configuration of alacritty.
        See {manpage}`alacritty(5)` or <https://alacritty.org/config-alacritty.html>
      '';
    };
  };
  config.flags."--config-file" = config.constructFiles.generatedConfig.path;
  config.constructFiles.generatedConfig = {
    content = builtins.toJSON config.settings;
    relPath = "${config.binName}-config.toml";
    builder = ''${pkgs.remarshal}/bin/json2toml "$1" "$2"'';
  };
  config.package = lib.mkDefault pkgs.alacritty;
  config.meta.maintainers = [ wlib.maintainers.birdee ];
}
