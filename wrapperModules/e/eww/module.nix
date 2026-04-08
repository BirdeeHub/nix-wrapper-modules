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
      description = ''
        The CSS or SCSS style file to use for eww.
      '';
      default = { };
      type = lib.types.submodule {
        options = {
          path = lib.mkOption {
            type = lib.types.nullOr wlib.types.stringable;
            default = null;
            description = ''
              Path to an existing file.
              Takes precedence over `content` if both are set.
            '';
          };
          content = lib.mkOption {
            type = lib.types.nullOr lib.types.lines;
            default = null;
            description = ''
              Inline css/scss file content.
              Used when `path` is null.
            '';
          };
          format = lib.mkOption {
            type = lib.types.enum [
              "css"
              "scss"
            ];
            default = "scss";
            description = ''
              File type extension of the style file.
            '';
          };
        };
      };
    };
  };

  config = {
    package = lib.mkDefault pkgs.eww;

    constructFiles.yuck = {
      content = config.yuck;
      relPath = "${config.binName}-config/eww.yuck";
    };

    constructFiles.style = {
      content = if builtins.isString (config.style.content or null) then config.style.content else "";
      output = lib.mkOverride 0 config.constructFiles.yuck.output;
      relPath = lib.mkOverride 0 "${dirOf config.constructFiles.yuck.relPath}/eww.${config.style.format}";
      ${if config.style.path or null != null then "builder" else null} =
        ''mkdir -p "$(dirname "$2")" && ln -s "${config.style.path}" "$2"'';
    };

    flags."--config" = dirOf config.constructFiles.yuck.path;

    passthru.generatedConfig = dirOf config.constructFiles.yuck.outPath;

    meta.maintainers = [ wlib.maintainers.clay53 ];
  };
}
