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
        Configuration passed to `btm` using `--config_location` flag.

        See <https://github.com/ClementTsang/bottom/blob/master/sample_configs/default_config.toml>
        for the default configuration.
      '';
    };
  };
  config = {
    package = pkgs.bottom;
    flags = {
      "--config_location" = tomlFmt.generate "bottom-config.toml" config.settings;
    };
    meta.maintainers = [ wlib.maintainers.rachitvrma ];
  };
}
