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
    mkIf
    mkOption
    mkOptionDefault
    types
    ;

  isLinkable = wlib.types.linkable.check;
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
      type = types.attrsOf (types.either wlib.types.linkable types.lines);
      default = { };
    };
  };

  config.package = mkDefault pkgs.quickshell;
  config.flags = {
    "--path" = "${builtins.placeholder config.outputName}/${config.binName}-config";
  };

  config.constructFiles =
    mapAttrs' (
      name: val:
      let
        firstChar = builtins.substring 0 1 name;
        rest = builtins.substring 1 (-1) name;
        capitalizedName = (lib.toUpper firstChar) + rest;
        linkable = isLinkable val;
      in
      {
        name = "${name}Component";
        value = {
          content = mkIf (!linkable) val;
          builder = mkIf linkable ''ln -s ${val} "$2"'';
          relPath = "${config.binName}-config/${capitalizedName}.qml";
        };
      }
    ) config.components
    // {
      generatedConfig = {
        content = config.configFile.content;
        relPath = "${config.binName}-config/shell.qml";
      };
    };

  config.meta.maintainers = [ wlib.maintainers.ormoyo ];
  config.meta.platforms = lib.platforms.linux;
}
