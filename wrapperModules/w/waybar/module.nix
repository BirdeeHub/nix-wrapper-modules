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
      default.path = jsonFmt.generate "waybar-config" config.settings;
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
      default.content = "";
      description = "CSS style for Waybar.";
    };
  };

  config.package = lib.mkDefault config.pkgs.waybar;
  config.flags = {
    "--config" = toString config.configFile.path;
    "--style" = toString config."style.css".path;
  };
  config.filesToPatch = [
    "share/systemd/user/waybar.service"
  ];
  config.meta.maintainers = [
    {
      name = "Patrick Widmer";
      github = "patwid";
      githubId = 1428207;
    }
  ];
  config.meta.platforms = lib.platforms.linux;
}
