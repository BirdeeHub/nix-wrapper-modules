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
          builtins.toString v;
    } " = ";
  };

  mkBtopTheme =
    name: theme:
    if builtins.isPath theme || lib.isStorePath theme then theme else pkgs.writeText "btop.theme" theme;

  themesDir = "${builtins.placeholder "out"}/themes";
in
{
  imports = [ wlib.modules.default ];

  options = {
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

  config.drv.buildPhase =
    let
      themes = builtins.mapAttrs mkBtopTheme config.themes;
      cpCommands = lib.mapAttrsToList (
        name: theme: "cp ${theme} ${themesDir}/${lib.escapeShellArg name}.theme"
      ) themes;
    in
    ''
      runHook preBuild
      mkdir -p ${themesDir}
      ${lib.concatStringsSep "\n" cpCommands}
      runHook postBuild
    '';

  config.package = lib.mkDefault pkgs.btop;
  config.flags = {
    "--config" = pkgs.writeText "btop.conf" (toBtopConf config.settings);
    "--themes-dir" = themesDir;
  };

  meta.maintainers = [ wlib.maintainers.ameer ];
}
