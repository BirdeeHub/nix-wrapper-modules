{
  config,
  lib,
  wlib,
  ...
}:
{
  imports = [ wlib.modules.default ];
  options = {
    scripts = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [ ];
      description = ''
        A list of MPV user scripts to include via package override.

        Each entry should be a derivation providing a Lua script or plugin
        compatible with MPV’s `scripts/` directory.
        These are appended to MPV’s build with `pkgs.mpv.override`.
      '';
    };
    "mpv.input" = lib.mkOption {
      type = wlib.types.file config.pkgs;
      default.content = "";
      description = ''
        The MPV input configuration file.

        Provide `.content` to inline bindings or `.path` to use an existing `input.conf`.
        This file defines custom key bindings and command mappings.
        It is passed to MPV using `--input-conf`.
      '';
    };
    "mpv.conf" = lib.mkOption {
      type = wlib.types.file config.pkgs;
      default.content = "";
      description = ''
        The main MPV configuration file.

        Provide `.content` to inline configuration options or `.path` to reference an existing `mpv.conf`.
        This file controls playback behavior, default options, video filters, and output settings.
        It is included by MPV using the `--include` flag.
      '';
    };
  };
  config.flagSeparator = "=";
  config.flags = {
    "--input-conf" = config."mpv.input".path;
    "--include" = config."mpv.conf".path;
  };
  config.package = lib.mkDefault (
    config.pkgs.mpv.override {
      scripts = config.scripts;
    }
  );
  config.meta.maintainers = [ lib.maintainers.birdee ];
}
