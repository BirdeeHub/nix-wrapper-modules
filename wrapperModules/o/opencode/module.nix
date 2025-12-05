{
  config,
  pkgs,
  wlib,
  lib,
  ...
}:
{
  imports = [ wlib.modules.default ];
  options.settings = lib.mkOption {
    type = (pkgs.formats.json { }).type;
    default = { };
    description = "Sets OPENCODE_CONFIG for github:sst/opencode";
  };
  config = {
    meta.maintainers = [ wlib.maintainers.birdee ];
    package = lib.mkDefault pkgs.opencode;
    envDefault = {
      OPENCODE_CONFIG = pkgs.writeText "OPENCODE_CONFIG.json" (builtins.toJSON config.settings);
    };
  };
}
