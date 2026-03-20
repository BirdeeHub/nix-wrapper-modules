{
  wlib,
  lib,
  pkgs,
  config,
  ...
}:
let
  toConfig = lib.generators.toINI { };
in
{
  imports = [ wlib.modules.default ];
  options = {
    settings = lib.mkOption {
      type =
        with lib.types;
        (attrsOf (
          attrsOf (oneOf [
            int
            bool
            str
          ])
        ));
      default = { };
      description = ''
        Configuration options for imv. See
        {manpage}`imv(5)`.
      '';
      example = lib.literalExpression ''
        {
          options.background = "ffffff";
          aliases.x = "close";
        }
      '';
    };
  };

  config = {
    package = lib.mkDefault pkgs.imv;
    env."imv_config" = config.constructFiles.imvconfig.path;
    constructFiles.imvconfig = {
      relPath = "${config.binName}_config";
      content = toConfig config.settings;
    };
    meta.maintainers = [ wlib.maintainers.rachitvrma ];
  };
}
