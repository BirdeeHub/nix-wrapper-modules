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
    flags = {
      "--conf-path" = "${placeholder "conf"}/${config.binName}-settings.conf";
    };
    flagSeparator = "=";
    drv = {
      renderedSettings = lib.concatStringsSep "\n" (lib.mapAttrsToList formatLine config.settings);
      passAsFile = [ "renderedSettings" ];

      buildPhase = ''
        runHook preBuild
        mkdir -p $conf
        cp $renderedSettingsPath "$conf/${config.binName}-settings.conf"
        rm $bin/bin/aria2c
        cp $out/bin/aria2c $bin/bin
        runHook postBuild
      '';
    };
    meta.maintainers = [ wlib.maintainers.rachitvrma ];
  };
}
