{
  wlib,
  lib,
  pkgs,
  config,
  ...
}:
{
  imports = [ wlib.modules.default ];
  options = {
    settings = lib.mkOption {
      type = lib.types.json or (pkgs.formats.json { }).type;
      default = { };
      description = ''
        Configuration passed to fastfetch using `--config` flag
        See <https://github.com/fastfetch-cli/fastfetch/wiki/Json-Schema>
        for the documentation.
      '';
    };
  };
  config = {
    package = lib.mkDefault pkgs.fastfetch;
    constructFiles.generatedConfig = {
      content = builtins.toJSON config.settings;
      relPath = "${config.binName}-settings.json";
    };
    flags = {
      "--config" = config.constructFiles.generatedConfig.path;
    };

    meta.maintainers = [ wlib.maintainers.rachitvrma ];
  };
}
