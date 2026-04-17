{
  config,
  lib,
  pkgs,
  wlib,
  ...
}:
{
  imports = [ wlib.modules.default ];
  options = {
    settings = lib.mkOption {
      inherit (pkgs.formats.yaml { }) type;
      default = { };
      description = ''
        Configuration for glance.
        See <https://github.com/glanceapp/glance/blob/main/docs/configuration.md>
        for available options.
      '';
    };
  };
  config = {
    constructFiles.generatedConfig = {
      content = lib.generators.toYAML { } config.settings;
      relPath = "${config.binName}.yaml";
    };
    flags."--config" = config.constructFiles.generatedConfig.path;
    package = lib.mkDefault pkgs.glance;

    meta.maintainers = [ wlib.maintainers.jtrrll ];
  };
}
