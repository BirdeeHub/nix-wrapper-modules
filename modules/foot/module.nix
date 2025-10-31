{
  wlib,
  lib,
}:
wlib.wrapModule (
  { config, wlib, ... }:
  let
    iniFmt = config.pkgs.formats.ini { };
  in
  {
    options = {
      settings = lib.mkOption {
        inherit (iniFmt) type;
        default = { };
        description = ''
          Configuration of foot terminal.
          See {manpage}`foot.ini(5)`
        '';
      };
      extraFlags = lib.mkOption {
        type = lib.types.attrsOf lib.types.unspecified; # TODO add list handling
        default = { };
        description = "Extra flags to pass to foot.";
      };
    };
    config.flags = {
      "--config" = iniFmt.generate "foot.ini" config.settings;
    }
    // config.extraFlags;
    config.package = lib.mkDefault config.pkgs.foot;
  }
)
