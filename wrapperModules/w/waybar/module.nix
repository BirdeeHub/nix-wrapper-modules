{
  config,
  wlib,
  lib,
  ...
}:
let
  jsonFmt = config.pkgs.formats.json { };
in
{
  imports = [ wlib.modules.default ];

  options = {
    settings = lib.mkOption {
      type = jsonFmt.type;
      default = { };
      description = ''
        Waybar configuration settings.
        See <https://github.com/Alexays/Waybar/wiki/Configuration>
      '';
      example = {
        position = "top";
        height = 30;
        layer = "top";
        modules-center = [ ];
        modules-left = [
          "niri/workspaces"
          "sway/workspaces"
        ];
      };
    };
    configFile = lib.mkOption {
      type = wlib.types.file config.pkgs;
      default.path = config.constructFiles.generatedConfig.path;
      default.content = "";
      description = ''
        Waybar configuration settings file.
        See <https://github.com/Alexays/Waybar/wiki/Configuration>
      '';
      example.content = ''
        {
          "height": 30,
          "layer": "top",
          "modules-center": [],
          "modules-left": [
            "sway/workspaces",
            "niri/workspaces"
          ]
        }
      '';
    };
    "style.css" = lib.mkOption {
      type = wlib.types.file config.pkgs;
      default.path = config.constructFiles.generatedStyle.path;
      default.content = "";
      description = "CSS style for Waybar.";
    };
  };

  config.package = lib.mkDefault config.pkgs.waybar;
  config.flags = {
    "--config" = config.configFile.path;
    "--style" = config."style.css".path;
  };
  config.constructFiles.generatedStyle = {
    content = config.configFile.content or "";
    relPath = "${config.binName}-style.css";
  };
  config.constructFiles.generatedConfig = {
    content =
      if config.configFile.content or "" != "" then
        config.configFile.content
      else
        builtins.toJSON config.settings;
    relPath = "${config.binName}-config.json";
  };
  config.filesToPatch = [
    "share/systemd/user/waybar.service"
  ];
  config.meta.maintainers = [
    wlib.maintainers.patwid
  ];
  config.meta.platforms = lib.platforms.linux;
}
