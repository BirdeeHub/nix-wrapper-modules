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
      formatValue = v: if lib.isBool v then (if v then "true" else "false") else toString v;
    in
    ''set ${n}	"${formatValue v}"'';

  formatMapLine = n: v: "map ${n}   ${toString v}";
in
{
  imports = [ wlib.modules.default ];
  options = {
    options = lib.mkOption {
      type =
        with lib.types;
        attrsOf (oneOf [
          bool
          str
          int
          float
        ]);
      default = { };
    };
    mappings = lib.mkOption {
      type = with lib.types; attrsOf str;
      default = { };
    };
  };
  config = {
    package = pkgs.zathura;
    flags = {
      "--config-dir" = "${placeholder "out"}/config";
    };
    flagSeparator = "=";
    drv = {
      renderedRc = lib.concatStringsSep "\n" (
        [ ]
        ++ lib.mapAttrsToList formatLine config.options
        ++ lib.mapAttrsToList formatMapLine config.mappings
      );
      passAsFile = [ "renderedRc" ];
      buildPhase = ''
        runHook preBuild
        mkdir -p "$out/config"
        cp "$renderedRcPath" "$out/config/${config.binName}rc"
        runHook postBuild
      '';
    };
    meta.maintainers = [ wlib.maintainers.rachitvrma ];
  };
}
