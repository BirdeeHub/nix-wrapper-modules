{
  wlib,
  lib,
  ...
}:
wlib.wrapModule (
  { config, wlib, ... }:
  {
    options = {
      scripts = lib.mkOption {
        type = lib.types.listOf lib.types.package;
        default = [ ];
        description = "Scripts to add to mpv via override.";
      };
      "mpv.input" = lib.mkOption {
        type = wlib.types.file config.pkgs;
        default.content = "";
      };
      "mpv.conf" = lib.mkOption {
        type = wlib.types.file config.pkgs;
        default.content = "";
      };
      extraFlags = lib.mkOption {
        type = lib.types.attrsOf lib.types.unspecified; # TODO add list handling
        default = { };
        description = "Extra flags to pass to mpv.";
      };
    };
    config.flagSeparator = "=";
    config.flags = {
      "--input-conf" = config."mpv.input".path;
      "--include" = config."mpv.conf".path;
    }
    // config.extraFlags;
    config.package = lib.mkDefault (
      config.pkgs.mpv.override {
        scripts = config.scripts;
      }
    );
  }
)
