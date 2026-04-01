{
  config,
  lib,
  wlib,
  pkgs,
  ...
}:
let
  jsonFormat = pkgs.formats.json { };
in
{
  imports = [ wlib.modules.default ];
  options = {
    settings = lib.mkOption {
      type = jsonFormat.type;
      default = { };
      description = "JSON config for HyFetch";
      example = lib.literalExpression ''
        {
          preset = "rainbow";
          mode = "rgb";
          color_align = {
            mode = "horizontal";
          };
        }
      '';
    };
    configFile = lib.mkOption {
      type = wlib.types.stringable;
      default = config.constructFiles.generatedConfig.path;
      description = ''
        The path to the config file. Can be anywhere.

         By default points to `config.constructFiles.generatedConfig.path`, which contains the generated result of `config.settings`
      '';
    };
  };

  config = {
    package = lib.mkDefault pkgs.hyfetch;
    constructFiles.generatedConfig = {
      relPath = "${config.binName}-settings.json";
      content = builtins.toJSON config.settings;
    };
    flags."--config-file" = config.configFile;
    meta.maintainers = [ wlib.maintainers.ricardomaps ];
  };
}
