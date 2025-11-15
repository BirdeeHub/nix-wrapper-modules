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
      inherit (tomlFmt) type;
      default = { };
      description = ''
        Configuration of tealdeer.
        See <tealdeer-rs.github.io/tealdeer/config.html>
      '';
    };
  };
  config.flags = {
    "--config-path" = tomlFmt.generate "tealdeer.toml" config.settings;
  };
  config.package = lib.mkDefault config.pkgs.tealdeer;
  meta.maintainers = [ lib.maintainers.birdee ];
}
