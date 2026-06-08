{
  config,
  lib,
  wlib,
  pkgs,
  ...
}:

let
  inherit (lib)
    mkDefault
    mkIf
    mkOption
    optionalAttrs
    optionalString
    types
    ;

  jsonFormat = pkgs.formats.json { };
  json5 = pkgs.python3Packages.toPythonApplication pkgs.python3Packages.json5;

  isPathLike = value: builtins.isPath value || lib.isStorePath value;

  generatedSettings =
    config.userSettings
    // optionalAttrs (config.extensions != [ ]) {
      auto_install_extensions = lib.genAttrs config.extensions (_: true);
    };

  pathThemes = lib.filterAttrs (_name: value: isPathLike value) config.themes;

  generatedThemes = lib.filterAttrs (_name: value: !(isPathLike value)) config.themes;

  hasGeneratedConfig =
    generatedSettings != { }
    || config.userKeymaps != [ ]
    || config.userTasks != [ ]
    || config.userDebug != [ ]
    || config.themes != { };

  zedConfigDir = "${config.generatedConfig.placeholder}/zed";

  mkJsonFile = relPath: value: {
    inherit relPath;
    content = builtins.toJSON value;
  };

  mkThemeFile = name: value: {
    relPath = "${config.generatedConfig.relPath}/zed/themes/${name}.json";
    content = if builtins.isString value then value else builtins.toJSON value;
  };

in
{
  imports = [ wlib.modules.default ];

  options = {
    userSettings = mkOption {
      inherit (jsonFormat) type;
      default = { };
      example = {
        vim_mode = true;
        telemetry = {
          diagnostics = false;
          metrics = false;
        };
        ui_font_family = "JetBrainsMono Nerd Font";
        buffer_font_family = "JetBrainsMono Nerd Font";
      };
      description = ''
        Configuration written to Zed's `settings.json`.

        This is equivalent to Home Manager's
        `programs.zed-editor.userSettings` option.
      '';
    };

    userKeymaps = mkOption {
      inherit (jsonFormat) type;
      default = [ ];
      example = [
        {
          context = "Workspace";
          bindings = {
            ctrl-shift-t = "workspace::NewTerminal";
          };
        }
      ];
      description = ''
        Configuration written to Zed's `keymap.json`.

        This is equivalent to Home Manager's
        `programs.zed-editor.userKeymaps` option.
      '';
    };

    userTasks = mkOption {
      inherit (jsonFormat) type;
      default = [ ];
      example = [
        {
          label = "Format Code";
          command = "nix";
          args = [
            "fmt"
            "$ZED_WORKTREE_ROOT"
          ];
        }
      ];
      description = ''
        Configuration written to Zed's `tasks.json`.

        These are global Zed tasks that can be run from the command palette.
      '';
    };

    userDebug = mkOption {
      inherit (jsonFormat) type;
      default = [ ];
      example = [
        {
          label = "Go (Delve)";
          adapter = "Delve";
          program = "$ZED_FILE";
          request = "launch";
          mode = "debug";
        }
      ];
      description = ''
        Configuration written to Zed's `debug.json`.

        These are global debug configurations for Zed's debugger.
      '';
    };

    extensions = mkOption {
      type = types.listOf types.str;
      default = [ ];
      example = [
        "nix"
        "toml"
      ];
      description = ''
        A list of Zed extensions to install on startup.

        The values are translated into the `auto_install_extensions`
        setting in `settings.json`.
      '';
    };

    themes = mkOption {
      type = types.attrsOf (
        types.oneOf [
          jsonFormat.type
          types.path
          types.lines
        ]
      );
      default = { };
      example = lib.literalExpression ''
        {
          my-theme = {
            name = "My Theme";
            author = "Me";
            themes = [ ];
          };
        }
      '';
      description = ''
        Themes written to `zed/themes/<name>.json`.

        Attribute names become theme file names.
      '';
    };

    configMode = mkOption {
      type = types.enum [
        "copy"
        "xdgConfigHome"
        "none"
      ];
      default = "copy";
      description = ''
        How the generated Zed configuration should be made visible to Zed.

        - `copy`: copy or merge generated files into the user's real
          `$XDG_CONFIG_HOME/zed` directory when Zed starts. This keeps Zed
          mutable and avoids leaking a custom `XDG_CONFIG_HOME` into terminals,
          tasks, and language servers spawned by Zed.
        - `xdgConfigHome`: set `XDG_CONFIG_HOME` to the generated immutable
          config directory in the wrapper derivation.
        - `none`: only expose the generated config through
          `passthru.generatedConfig`; do not apply it automatically.
      '';
    };

    generatedConfig = {
      output = mkOption {
        type = types.str;
        default = config.outputName;
        description = ''
          The derivation output where the generated Zed configuration is placed.
        '';
      };

      relPath = mkOption {
        type = types.str;
        default = "${config.binName}-config";
        description = ''
          Relative path inside the wrapper derivation where generated Zed
          configuration files are placed.
        '';
      };

      placeholder = mkOption {
        type = types.str;
        default = "${placeholder config.generatedConfig.output}/${config.generatedConfig.relPath}";
        readOnly = true;
        description = ''
          Placeholder path to the generated Zed configuration, available inside
          the wrapper derivation build script.
        '';
      };
    };
  };

  config = {
    binName = mkDefault "zeditor";
    package = mkDefault pkgs.zed-editor;

    meta = {
      description = ''
        Wraps Zed with declarative settings, keymaps, tasks, debug
        configurations, themes, extensions, and runtime PATH additions.
      '';

      maintainers = [
        wlib.maintainers.sibaldh
      ];
    };

    constructFiles =
      optionalAttrs (generatedSettings != { }) {
        zedSettings = mkJsonFile "${config.generatedConfig.relPath}/zed/settings.json" generatedSettings;
      }
      // optionalAttrs (config.userKeymaps != [ ]) {
        zedKeymaps = mkJsonFile "${config.generatedConfig.relPath}/zed/keymap.json" config.userKeymaps;
      }
      // optionalAttrs (config.userTasks != [ ]) {
        zedTasks = mkJsonFile "${config.generatedConfig.relPath}/zed/tasks.json" config.userTasks;
      }
      // optionalAttrs (config.userDebug != [ ]) {
        zedDebug = mkJsonFile "${config.generatedConfig.relPath}/zed/debug.json" config.userDebug;
      }
      // lib.mapAttrs' (
        name: value: lib.nameValuePair "zedTheme-${name}" (mkThemeFile name value)
      ) generatedThemes;

    buildCommand.zedPathThemes = mkIf (pathThemes != { }) {
      before = [
        "constructFiles"
        "makeWrapper"
      ];

      data = ''
        mkdir -p ${lib.escapeShellArg "${zedConfigDir}/themes"}
      ''
      + lib.concatMapAttrsStringSep "\n" (name: value: ''
        ln -sfn ${lib.escapeShellArg value} ${lib.escapeShellArg "${zedConfigDir}/themes/${name}.json"}
      '') pathThemes;
    };

    runShell = mkIf (hasGeneratedConfig && config.configMode == "copy") [
      {
        name = "NIX_ZED_SYNC_CONFIG";
        "esc-fn" = wlib.escapeShellArgWithEnv;

        data = ''
          nix_zed_config=${zedConfigDir}
          user_zed_config="''${XDG_CONFIG_HOME:-$HOME/.config}/zed"

          merge_json_file() {
            empty="$1"
            jq_operation="$2"
            target="$3"
            static="$4"

            mkdir -p "$(dirname "$target")"

            if [ ! -e "$target" ]; then
              printf '%s\n' "$empty" > "$target"
            fi

            dynamic="$(${lib.getExe json5} --as-json "$target" 2>/dev/null || printf '%s\n' "$empty")"
            static_content="$(cat "$static")"

            ${lib.getExe pkgs.jq} \
              -n "$jq_operation" \
              --argjson dynamic "$dynamic" \
              --argjson static "$static_content" \
              > "$target.tmp"

            mv "$target.tmp" "$target"
          }

          ${optionalString (generatedSettings != { }) ''
            merge_json_file \
              '{}' \
              '$dynamic * $static' \
              "$user_zed_config/settings.json" \
              "$nix_zed_config/settings.json"
          ''}

          ${optionalString (config.userKeymaps != [ ]) ''
            merge_json_file \
              '[]' \
              '$dynamic + $static | group_by(.context) | map(reduce .[] as $item ({}; . * $item))' \
              "$user_zed_config/keymap.json" \
              "$nix_zed_config/keymap.json"
          ''}

          ${optionalString (config.userTasks != [ ]) ''
            merge_json_file \
              '[]' \
              '$dynamic + $static | group_by(.label) | map(reduce .[] as $item ({}; . * $item))' \
              "$user_zed_config/tasks.json" \
              "$nix_zed_config/tasks.json"
          ''}

          ${optionalString (config.userDebug != [ ]) ''
            merge_json_file \
              '[]' \
              '$dynamic + $static | group_by(.label) | map(reduce .[] as $item ({}; . * $item))' \
              "$user_zed_config/debug.json" \
              "$nix_zed_config/debug.json"
          ''}

          if [ -d "$nix_zed_config/themes" ]; then
            mkdir -p "$user_zed_config/themes"
            for theme in "$nix_zed_config/themes/"*.json; do
              [ -e "$theme" ] || continue
              cp -f "$theme" "$user_zed_config/themes/$(basename "$theme")"
            done
          fi
        '';
      }
    ];

    env = mkIf (hasGeneratedConfig && config.configMode == "xdgConfigHome") {
      XDG_CONFIG_HOME = config.generatedConfig.placeholder;
    };

    passthru.generatedConfig = "${
      config.wrapper.${config.generatedConfig.output}
    }/${config.generatedConfig.relPath}";
  };
}
