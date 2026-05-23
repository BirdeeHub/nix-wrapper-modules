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

  componentModule =
    { name, config, ... }:
    {
      options = {
        name = mkOption {
          type = types.str;
          default =
            let
              firstChar = builtins.substring 0 1 name;
              rest = builtins.substring 1 (-1) name;
            in
            if (isLinkable config.data) then
              (builtins.baseNameOf config.data)
            else
              (lib.toUpper firstChar) + rest + ".qml";
          description = "The name of this component (either filename or directory name)";
        };
        data = mkOption {
          type = types.either wlib.types.linkable types.lines;
          description = "The component's inlined text or path";
        };
        module = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "The component's module, to be imported by `import qs.<module>`";
        };
      };
    };
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
      type = types.attrsOf (wlib.types.spec componentModule);
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
    mapAttrs' (name: val: {
      name = "${name}Component";
      value = {
        content = mkIf (!isLinkable val.data) val.data;
        builder = mkIf (isLinkable val.data) ''ln -s ${val.data} "$2"'';
        output = makeForce config.generated.output;
        relPath = makeForce "${config.binName}-config/${
          if val.module != null then "${lib.replaceString "." "/" val.module}/" else ""
        }${val.name}";
      };
    }) config.components
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
