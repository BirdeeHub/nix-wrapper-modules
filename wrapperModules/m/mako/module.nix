{
  config,
  wlib,
  lib,
  ...
}:
let
  iniFormat = config.pkgs.formats.iniWithGlobalSection { };
  iniAtomType = iniFormat.lib.types.atom;
in
{
  imports = [ wlib.modules.default ];
  options = {
    "--config" = lib.mkOption {
      type = wlib.types.file config.pkgs;
      default.path = iniFormat.generate "mako-settings" { globalSection = config.settings; };
      description = ''
        Path to the generated Mako configuration file.

        The file is built automatically from the `settings` option using the
        `iniWithGlobalSection` formatter. You can override this path to use a
        custom configuration file instead.

        Example:
          --config=/etc/mako/config
      '';
    };

    settings = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.oneOf [
          iniAtomType
          (lib.types.attrsOf iniAtomType)
        ]
      );
      default = { };
      description = ''
        Configuration settings for mako. Can include both global settings and sections.
        All available options can be found here:
        <https://github.com/emersion/mako/blob/master/doc/mako.5.scd>.
      '';
    };
  };

  config.flagSeparator = "=";
  config.flags = {
    "--config" = config."--config".path;
  };
  config.drv.phases = [
    "buildPhase"
    "checkPhase"
    "installPhase"
    "installCheckPhase"
    # "fixupPhase" # mako doesnt like fixupPhase
    "distPhase"
  ];

  config.package = lib.mkDefault config.pkgs.mako;

  config.meta.maintainers = [ lib.maintainers.birdee ];
  config.meta.platforms = lib.platforms.linux;
}
