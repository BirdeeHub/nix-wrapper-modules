{
  config,
  pkgs,
  wlib,
  lib,
  ...
}:
let
  types = lib.types;
  tomlFmtType = wlib.types.structuredValueWith {
    nullable = false;
    typeName = "TOML";
  };
  isLinkable = wlib.types.linkable.check;
in
{
  imports = [ wlib.modules.default ];
  options = {
    settings = lib.mkOption {
      type = tomlFmtType;
      default = { };
      description = "Television configuration options.";
    };
    channels = lib.mkOption {
      type = types.lazyAttrsOf (types.either wlib.types.linkable tomlFmtType);
      default = { };
      description = "Television channels to install.";
    };
    channelsDir = lib.mkOption {
      type = types.str;
      readOnly = true;
      default = "${placeholder config.configDrvOutput}/${config.binName}-channels";
      description = ''
        The placeholder for the location of the channels directory.
      '';
    };
    themes = lib.mkOption {
      type = types.lazyAttrsOf (types.either wlib.types.linkable tomlFmtType);
      default = { };
      description = "Themes of television to install.";
    };
    themesDir = lib.mkOption {
      type = types.str;
      readOnly = true;
      default = "${placeholder config.configDrvOutput}/${config.binName}-themes";
      description = ''
        The placeholder for the location of the themes directory.
      '';
    };
    configDrvOutput = lib.mkOption {
      type = types.str;
      default = config.outputName;
      description = ''
        The derivation output name the generated configuration will be output to.
      '';
    };
  };
  config = {
    package = lib.mkDefault pkgs.television;
    passthru.generatedThemesDir = "${
      config.wrapper.${config.configDrvOutput}
    }/${baseNameOf config.themesDir}";
    passthru.generatedChannelsDir = "${
      config.wrapper.${config.configDrvOutput}
    }/${baseNameOf config.channelsDir}";
    flags = {
      "--config-file" = lib.mkIf (config.settings != { }) config.constructFiles.generatedConfig.path;
      "--cable-dir" = lib.mkIf (config.channels != { }) config.channelsDir;
    };
    constructFiles = {
      generatedConfig = {
        relPath = "${config.binName}-config.toml";
        content = builtins.toJSON config.settings;
        builder = ''${pkgs.remarshal}/bin/json2toml "$1" "$2"'';
        output = config.configDrvOutput;
      };
    }
    // builtins.mapAttrs (n: v: {
      key = "channel_${n}";
      relPath = lib.mkOverride 0 "${config.binName}-channels/${n}.toml";
      output = lib.mkOverride 0 config.configDrvOutput;
      ${if isLinkable v then null else "content"} = builtins.toJSON v;
      "builder" =
        if isLinkable v then ''ln -s ${v} "$2"'' else ''${pkgs.remarshal}/bin/json2toml "$1" "$2"'';
    }) config.channels
    // builtins.mapAttrs (n: v: {
      key = "theme_${n}";
      relPath = lib.mkOverride 0 "${config.binName}-themes/${n}.toml";
      output = lib.mkOverride 0 config.configDrvOutput;
      ${if isLinkable v then null else "content"} = builtins.toJSON v;
      "builder" =
        if isLinkable v then ''ln -s ${v} "$2"'' else ''${pkgs.remarshal}/bin/json2toml "$1" "$2"'';
    }) config.themes;
    meta.maintainers = [ wlib.maintainers.allen-liaoo ];
  };
}
