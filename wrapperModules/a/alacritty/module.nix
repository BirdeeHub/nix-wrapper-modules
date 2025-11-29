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
      type = tomlFmt.type;
      default = { };
      description = ''
        Configuration of alacritty.
        See {manpage}`alacritty(5)` or <https://alacritty.org/config-alacritty.html>
      '';
    };
  };
  config.flags = {
    "--config-file" = tomlFmt.generate "alacritty.toml" config.settings;
  };
  config.package = lib.mkDefault pkgs.alacritty;
  config.meta.maintainers = [ wlib.maintainers.birdee ];
}
