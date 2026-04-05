{
  config,
  wlib,
  lib,
  pkgs,
  ...
}:
let
  types = lib.types;
  toBtopConf = lib.generators.toKeyValue {
    mkKeyValue = lib.generators.mkKeyValueDefault {
      mkValueString =
        v:
        if builtins.isBool v then
          (if v then "True" else "False")
        else if builtins.isString v then
          ''"${v}"''
        else
          toString v;
    } " = ";
  };
in
{
  imports = [ wlib.modules.default ];

  options = {
    configDrvOutput = lib.mkOption {
      type = types.str;
      default = config.outputName;
      description = ''
        The derivation output name the generated configuration will be output to.
      '';
    };
    themesDir = lib.mkOption {
      type = types.str;
      readOnly = true;
      default = "${placeholder config.configDrvOutput}/${config.binName}-themes";
      description = ''
        The placeholder for the location of the themes directory.
      '';
    };
    settings = lib.mkOption {
      type = types.attrsOf (
        types.oneOf [
          types.bool
          types.float
          types.int
          types.str
        ]
      );
      default = { };
      example = {
        vim_keys = true;
        color_theme = "ayu";
      };
      description = ''
        Options to add to {file}`btop.conf` file.
        See <https://github.com/aristocratos/btop#configurability>
        for options.
      '';
    };

    themes = lib.mkOption {
      type = types.lazyAttrsOf (types.either types.path types.lines);
      default = { };
      example = {
        my-theme = ''
          theme[main_bg]="#282a36"
          theme[main_fg]="#f8f8f2"
          theme[title]="#f8f8f2"
          theme[hi_fg]="#6272a4"
          theme[selected_bg]="#ff79c6"
          theme[selected_fg]="#f8f8f2"
          theme[inactive_fg]="#44475a"
          theme[graph_text]="#f8f8f2"
          theme[meter_bg]="#44475a"
          theme[proc_misc]="#bd93f9"
          theme[cpu_box]="#bd93f9"
          theme[mem_box]="#50fa7b"
          theme[net_box]="#ff5555"
          theme[proc_box]="#8be9fd"
          theme[div_line]="#44475a"
          theme[temp_start]="#bd93f9"
          theme[temp_mid]="#ff79c6"
          theme[temp_end]="#ff33a8"
          theme[cpu_start]="#bd93f9"
          theme[cpu_mid]="#8be9fd"
          theme[cpu_end]="#50fa7b"
          theme[free_start]="#ffa6d9"
          theme[free_mid]="#ff79c6"
          theme[free_end]="#ff33a8"
          theme[cached_start]="#b1f0fd"
          theme[cached_mid]="#8be9fd"
          theme[cached_end]="#26d7fd"
          theme[available_start]="#ffd4a6"
          theme[available_mid]="#ffb86c"
          theme[available_end]="#ff9c33"
          theme[used_start]="#96faaf"
          theme[used_mid]="#50fa7b"
          theme[used_end]="#0dfa49"
          theme[download_start]="#bd93f9"
          theme[download_mid]="#50fa7b"
          theme[download_end]="#8be9fd"
          theme[upload_start]="#8c42ab"
          theme[upload_mid]="#ff79c6"
          theme[upload_end]="#ff33a8"
          theme[process_start]="#50fa7b"
          theme[process_mid]="#59b690"
          theme[process_end]="#6272a4"
        '';
      };
      description = ''
        Custom Btop themes.
      '';
    };
  };
  config.package = lib.mkDefault pkgs.btop;
  config.flags = {
    "--config" = lib.mkIf (config.settings != { }) config.constructFiles.generatedConfig.path;
    "--themes-dir" = lib.mkIf (config.themes != { }) config.themesDir;
  };
  config.passthru = {
    ${if config.settings != { } then "generatedConfig" else null} =
      config.constructFiles.generatedConfig.outPath;
    ${if config.themes != { } then "generatedThemes" else null} = "${
      config.wrapper.${config.configDrvOutput}
    }/${config.binName}-themes";
  };
  config.constructFiles = {
    generatedConfig = lib.mkIf (config.settings != { }) {
      content = toBtopConf config.settings;
      relPath = "${config.binName}-config.conf";
      output = config.configDrvOutput;
    };
  }
  // builtins.mapAttrs (n: v: {
    key = "theme_${n}";
    relPath = lib.mkOverride 0 "${config.binName}-themes/${n}.theme";
    output = lib.mkOverride 0 config.configDrvOutput;
    ${if builtins.isPath v || lib.isStorePath v then null else "content"} = v;
    ${if builtins.isPath v || lib.isStorePath v then "builder" else null} =
      ''mkdir -p "$(dirname "$2")" && cp ${v} "$2"'';
  }) config.themes;

  meta.maintainers = [ wlib.maintainers.ameer ];
}
