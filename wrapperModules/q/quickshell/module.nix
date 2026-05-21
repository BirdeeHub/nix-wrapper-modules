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
    types
    ;

  isLinkable = wlib.types.linkable.check;
  makeForce = lib.mkOverride 0;
in
{
  imports = [ wlib.modules.default ];
  options = {
    configFile = mkOption {
      type = types.either wlib.types.linkable types.lines;
      default = "";
      description = ''
        The quickshell shell.qml configuration file.

        Provide either inlined configuration or reference an external file.
        It is used by quickshell using `--path`.
      '';
    };
    components = mkOption {
      type = types.attrsOf (types.either wlib.types.linkable types.lines);
      default = { };
      description = "Quickshell components to include in the configuration";
    };
    generated.output = mkOption {
      type = types.str;
      default = config.outputName;
      description = "The constructed file's output";
    };
    generated.placeholder = mkOption {
      type = types.str;
      readOnly = true;
      default = "${placeholder config.generated.output}/${config.binName}-config";
      description = "A placeholder for the generated config dir";
    };
  };

  config.package = mkDefault pkgs.quickshell;
  config.flags."--path" = config.generated.placeholder;

  config.passthru.generatedConfigDir = "${
    config.wrapper.${config.generated.output}
  }/${config.binName}-config";

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
          output = makeForce config.generated.output;
          relPath = makeForce "${config.binName}-config/${capitalizedName}.qml";
        };
      }
    ) config.components
    // {
      generatedConfig = {
        content = mkIf (!isLinkable config.configFile) config.configFile;
        builder = mkIf (isLinkable config.configFile) ''ln -s ${config.configFile} "$2"'';
        output = makeForce config.generated.output;
        relPath = makeForce "${config.binName}-config/shell.qml";
      };
    };

  config.meta.maintainers = [ wlib.maintainers.ormoyo ];
  config.meta.platforms = lib.platforms.linux;
}
