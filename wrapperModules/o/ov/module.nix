{
  config,
  lib,
  wlib,
  pkgs,
  ...
}:
let
  yamlFmt = pkgs.formats.yaml { };
in
{
  imports = [ wlib.modules.default ];
  options = {
    settings = lib.mkOption {
      type = yamlFmt.type;
      default = { };
      description = ''
        Configuration of ov.
        See <https://github.com/noborus/ov/blob/master/ov.yaml>
      '';
    };
  };
  config.flags = {
    "--config-file" = yamlFmt.generate "ov.yaml" config.settings;
  };
  config.package = lib.mkDefault pkgs.ov;
  config.meta.maintainers = [ wlib.maintainers.rencire ];
}
