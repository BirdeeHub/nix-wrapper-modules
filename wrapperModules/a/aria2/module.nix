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

  configFile = pkgs.writeText "aria2Wrapped.conf" (
    lib.concatStringsSep "\n" (lib.mapAttrsToList formatLine config.settings)
  );
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
      description = ''
        Settings to be wrapped with aria2 binary.
        See {manpage}'aria2c(1)' 
      '';
    };
  };
  config = {
    package = pkgs.aria2;
    flags = {
      "--conf-path" = configFile;
    };
    flagSeparator = "=";
    drv = {
      buildPhase = ''
        runHook preBuild
        rm $bin/bin/aria2c
        cp $out/bin/aria2c $bin/bin
        runHook postBuild
      '';
    };
    meta.maintainers = [ wlib.maintainers.rachitvrma ];
  };

}
