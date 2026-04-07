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
      output = lib.mkOverride 0 config.constructFiles.yuck.output;
      relPath = lib.mkOverride 0 "${dirOf config.constructFiles.yuck.relPath}/eww.${config.styleFormat}";
    };

    flags."--config" = dirOf config.constructFiles.yuck.path;

    passthru.generatedConfig = dirOf config.constructFiles.yuck.outPath;

    meta.maintainers = [ wlib.maintainers.clay53 ];
  };
}
