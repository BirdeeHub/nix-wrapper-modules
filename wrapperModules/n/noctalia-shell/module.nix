{
  wlib,
  lib,
  config,
  pkgs,
  ...
}:
let
  jsonFmt = pkgs.formats.json { };
  conf = jsonFmt.generate "noctalia-config" config.settings;
  plugins = jsonFmt.generate "noctalia-plugins" config.plugins;
  colors = jsonFmt.generate "noctalia-colors" config.colors;
in
{
  imports = [ wlib.modules.default ];
  options = {
    settings = lib.mkOption {
      inherit (jsonFmt) type;
      default = { };
      description = ''
        Settings to write to {file}`settings.json`
      '';
    };
    plugins = lib.mkOption {
      inherit (jsonFmt) type;
      default = { };
      description = ''
        A list of plugins to be enabled.
        Goes into {file}`plugins.json`
      '';
    };
    colors = lib.mkOption {
      inherit (jsonFmt) type;
      default = { };
      description = ''
        The Color theme to use.
        This file affects the color theme
        despite what the `predefinedScheme` is set to.
      '';
    };
  };
  config = {
    package = lib.mkDefault pkgs.noctalia-shell;
    env = {
      XDG_CONFIG_HOME = toString (
        pkgs.linkFarm "noctalia-merged-config" (
          map
            (a: {
              inherit (a) path;
              name = "noctalia/" + a.name;
            })
            (
              let
                entry = name: path: { inherit name path; };
              in
              [
                (entry "settings.json" conf)
                (entry "plugins.json" plugins)
                (entry "colors.json" colors)
              ]
            )
        )
      );
    };
    meta.maintainers = [ wlib.maintainers.rachitvrma ];
  };
}
