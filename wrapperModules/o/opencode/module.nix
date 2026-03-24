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
    envDefault.OPENCODE_CONFIG = config.constructFiles.generatedConfig.path;
    constructFiles.generatedConfig = {
      relPath = "${config.binName}-config.json";
      content = builtins.toJSON config.settings;
    };
  };
}
