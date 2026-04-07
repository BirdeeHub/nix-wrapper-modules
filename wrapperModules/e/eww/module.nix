{
  config,
  lib,
  wlib,
  pkgs,
  ...
}:
{
  imports = [ wlib.modules.default ];
  options = {
    yuck = lib.mkOption {
      type = lib.types.lines;
      default = "";
    };
    style = lib.mkOption {
      type = lib.types.lines;
      default = "";
    };
    styleFormat = lib.mkOption {
      type = lib.types.enum [
        "css"
        "scss"
      ];
      default = "scss";
    };
  };

  config = {
    package = lib.mkDefault pkgs.eww;

    constructFiles.yuck = {
      content = config.yuck;
      relPath = "${config.binName}-config/eww.yuck";
    };

    constructFiles.style = {
      content = config.style;
      relPath = "${config.binName}-config/eww.${config.styleFormat}";
    };

    flags."--config" = "${placeholder "out"}/${config.binName}-config";

    meta.maintainers = [ wlib.maintainers.clay53 ];
  };
}
