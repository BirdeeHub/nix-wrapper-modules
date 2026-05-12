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
      type = wlib.types.structuredValueWith { typeName = "YAML 1.1"; };
      default = { };
      description = ''
        Configuration of ov.
        See <https://github.com/noborus/ov/blob/master/ov.yaml>
      '';
    };
  };
  config.flags = {
    "--config" = config.constructFiles.generatedConfig.path;
  };
  config.constructFiles.generatedConfig = {
    content = builtins.toJSON config.settings;
    relPath = "${config.binName}-config.yaml";
    builder = ''${pkgs.remarshal}/bin/json2yaml "$1" "$2"'';
  };
  config.package = lib.mkDefault pkgs.ov;
  config.meta.maintainers = [ wlib.maintainers.rencire ];
}
