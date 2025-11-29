{
  config,
  lib,
  wlib,
  pkgs,
  ...
}:
let
  tomlFmt = pkgs.formats.toml { };
  conf =
    let
      base = tomlFmt.generate "helix-config" config.settings;
    in
    if config.extraSettings != "" then
      pkgs.concatText "helix-config" [
        base
        (pkgs.writeText "extraSettings" config.extraSettings)
      ]
    else
      base;
  langs = tomlFmt.generate "helix-languages-config" config.languages;
  ignore = pkgs.writeText "helix-ignore" (lib.strings.concatLines config.ignores);
  themes = lib.mapAttrsToList (
    name: value:
    let
      fname = "helix-theme-${name}";
    in
    {
      name = "themes/${name}.toml";
      path = if lib.isString value then pkgs.writeText fname value else (tomlFmt.generate fname value);
    }
  ) config.themes;
in
{
  imports = [ wlib.modules.default ];
  options = {
    settings = lib.mkOption {
      type = tomlFmt.type;
      description = ''
        General settings
        See <https://docs.helix-editor.com/configuration.html> 
      '';
      default = { };
    };
    extraSettings = lib.mkOption {
      type = lib.types.lines;
      default = "";
      description = ''
        Extra lines appended to the config file.
        This can be used to maintain order for settings.
      '';
    };
    languages = lib.mkOption {
      type = tomlFmt.type;
      description = ''
        Language specific settings
        See <https://docs.helix-editor.com/languages.html>
      '';
      default = { };
    };
    themes = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.oneOf [
          tomlFmt.type
          lib.types.lines
        ]
      );
      description = ''
        Themes to add to config.
        See <https://docs.helix-editor.com/themes.html>
      '';
      default = { };
    };
    ignores = lib.mkOption {
      type = lib.types.listOf lib.types.nonEmptyStr;
      default = [ ];
      description = ''
        List of paths to be ignored by the file-picker.
        The format is the same as in .gitignore.
      '';
    };
  };
  config.package = lib.mkDefault pkgs.helix;
  config.env = {
    XDG_CONFIG_HOME = builtins.toString (
      pkgs.linkFarm "helix-merged-config" (
        map
          (a: {
            inherit (a) path;
            name = "helix/" + a.name;
          })
          (
            let
              entry = name: path: { inherit name path; };
            in
            [
              (entry "config.toml" conf)
              (entry "languages.toml" langs)
              (entry "ignore" ignore)
            ]
            ++ themes
          )
      )
    );
  };
  config.meta.maintainers = [ wlib.maintainers.birdee ];
}
