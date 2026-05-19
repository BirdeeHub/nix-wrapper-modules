{
  config,
  lib,
  wlib,
  pkgs,
  ...
}:
let
  inherit (lib)
    mapAttrs'
    mkDefault
    mkOption
    mkOptionDefault
    types
    ;
in
{
  imports = [ wlib.modules.default ];
  options = {
    configFile = mkOption {
      type = wlib.types.file {
        path = mkOptionDefault config.constructFiles.generatedConfig.path;
      };
      default = { };
    };
    components = mkOption {
      type = types.attrsOf (
        wlib.types.file (
          { name, ... }:
          {
            path = mkOptionDefault config.constructFiles."${name}Component".path;
          }
        )
      );
      default = { };
    };
  };

  config.package = mkDefault pkgs.quickshell;
  config.flags = {
    "--path" = "${builtins.placeholder config.outputName}/config";
  };

  config.constructFiles =
    mapAttrs' (
      name: val:
      let
        firstChar = builtins.substring 0 1 name;
        rest = builtins.substring 1 (-1) name;
        capitalizedName = (lib.toUpper firstChar) + rest;
      in
      {
        name = "${name}Component";
        value = {
          content = val.content;
          relPath = "config/${capitalizedName}.qml";
        };
      }
    ) config.components
    // {
      generatedConfig = {
        content = config.configFile.content;
        relPath = "config/shell.qml";
      };
    };

  config.meta.maintainers = [ wlib.maintainers.ormoyo ];
  config.meta.platforms = lib.platforms.linux;
}
