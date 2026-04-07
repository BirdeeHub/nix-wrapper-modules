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
      type = lib.types.str;
      default = "";
    };
    style = lib.mkOption {
      type = lib.types.str;
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

    flags."--config" = config.outputs;
    
    meta.maintainers = [ wlib.maintainers.clay53 ];
  };
}
