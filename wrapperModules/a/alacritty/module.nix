{
  config,
  lib,
  wlib,
  ...
}:
let
  tomlFmt = config.pkgs.formats.toml { };
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
  config.package = lib.mkDefault config.pkgs.alacritty;
  config.meta.maintainers = [ lib.maintainers.birdee ];
}
