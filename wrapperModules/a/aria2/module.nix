{
  wlib,
  lib,
  pkgs,
  config,
  ...
}:
let
  formatLine =
    n: v:
    let
      formatValue = v: if builtins.isBool v then (if v then "true" else "false") else toString v;
    in
    "${n}=${formatValue v}";
in
{
  imports = [ wlib.modules.default ];
  options = {
    settings = lib.mkOption {
      type =
        with lib.types;
        attrsOf (oneOf [
          bool
          float
          int
          str
        ]);
      default = { };
      description = "Settings to be wrapped with aria2 binary";
    };
  };
  config = {
    package = pkgs.aria2;
    binName = "aria2c";
    outputs = (config.package.outputs or [ "out" ]) ++ [ "conf" ];
    flags."--conf-path" = config.constructFiles.renderedSettings.path;
    constructFiles.renderedSettings = {
      relPath = "${config.binName}-settings.conf";
      output = "conf";
      content = lib.concatStringsSep "\n" (lib.mapAttrsToList formatLine config.settings);
    };
    flagSeparator = "=";
    wrapperVariants.aria2c.outputName = "out";
    meta.maintainers = [ wlib.maintainers.rachitvrma ];
  };
}
