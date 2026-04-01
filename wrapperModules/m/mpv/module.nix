{
  config,
  lib,
  wlib,
  pkgs,
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
    scriptFiles = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      description = ''
        Additional files to be included in the MPV config directory.

        By using this option, mpv will no longer look for script-opts in the default
        $XDG_CONFIG_HOME/mpv/script-opts location, and all additional files will have
        to be specified in this option.

        Each entry of the attrset is the relative path to the file and their content respectively.
      '';
      example = lib.literalMD ''
        ```nix
        {
          "script-opts/modernz.conf" = '''
            window_top_bar=no
            seekbarfg_color=#FFFFFF
          ''';
        };
      '';
    };
    "mpv.input" = lib.mkOption {
      type = wlib.types.file pkgs;
      default.path = config.constructFiles.generatedInput.path;
      default.content = "";
      description = ''
        The MPV input configuration file.

        Provide `.content` to inline bindings or `.path` to use an existing `input.conf`.
        This file defines custom key bindings and command mappings.
        It is passed to MPV using `--input-conf`.
      '';
    };
    "mpv.conf" = lib.mkOption {
      type = wlib.types.file pkgs;
      default.path = config.constructFiles.generatedConfig.path;
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
  config.flags =
    if config.scriptFiles == { } then
      {
        "--config-dir" = "${placeholder config.outputName}/${config.binName}-config";
      }
    else
      {
        "--input-conf" = config."mpv.input".path;
        "--include" = config."mpv.conf".path;
      };

  config.constructFiles = (
    {
      generatedConfig = {
        relPath = "${config.binName}-config/mpv.conf";
        content = config."mpv.conf".content;
      };
      generatedInput = {
        relPath = "${config.binName}-config/input.conf";
        content = config."mpv.input".content;
      };
    }
    // (lib.mapAttrs' (
      relPath: content:
      lib.nameValuePair relPath {
        inherit content;
        relPath = "${config.binName}-config/${relPath}";
      }
    ) config.scriptFiles)
  );

  config.overrides = [
    {
      name = "MPV_SCRIPTS";
      type = "override";
      data = prev: {
        scripts = (prev.scripts or [ ]) ++ config.scripts;
      };
    }
  ];
  config.package = lib.mkDefault pkgs.mpv;
  config.meta.maintainers = [ wlib.maintainers.birdee ];
}
