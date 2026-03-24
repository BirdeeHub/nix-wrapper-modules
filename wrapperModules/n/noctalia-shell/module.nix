{
  config,
  lib,
  wlib,
  pkgs,
  ...
}:
let
  hasOtherFiles =
    config.colors != { }
    || config.plugins != { }
    || config.user-templates != { }
    || config.pluginSettings != { }
    || config.preInstalledPlugins != { };
in
{
  config.meta.description = ''
    `noctalia-shell` has a gui settings interface that edits the config files, rather than implementing a merging mechanism for runtime settings.

    When provisioning from the nix store, this causes a few challenges.

    To solve this, there are 3 ways to use this wrapper module.

    1. If you only supply `settings`, and do not choose somewhere for `outOfStoreConfig` then it will only generate and set `NOCTALIA_SETTINGS_FILE`

    2. If you leave `outOfStoreConfig == null` as it is by default, and you supply more then just `settings`, it will set `NOCTALIA_CONFIG_DIR` to the generated location IN THE NIX STORE. This means noctalia will not be able to edit any of its configuration files or install plugins at runtime.

    3. If you do `outOfStoreConfig = "/some/path/somewhere";` and `/some/path/somewhere` does not yet exist, it will copy it there at runtime when you start `noctalia-shell` and set `NOCTALIA_CONFIG_DIR` to that location instead.

    This wrapper module also provides by default an extra executable in the bin directory called `dump-noctalia-shell`

    It will return the current settings and state of noctalia in nix code format.

    It also exports the path to the generated configuration directory from the package via passthru.

    `wrapped-noctalia-shell.generatedConfig`

    And likewise for the dump script (if it was enabled)

    `wrapped-noctalia-shell.dump-noctalia-shell`

    Hopefully one day, `outOfStoreConfig` will become just a handy feature, rather than a necessary option.
  '';
  config.meta.platforms = lib.platforms.linux;
  config.meta.maintainers = [
    wlib.maintainers.rachitvrma
    wlib.maintainers.birdee
  ];
  imports = [ wlib.modules.default ];
  options = {
    generatedConfigDirname = lib.mkOption {
      type = lib.types.str;
      default = "${config.binName}-config";
      description = "Name of the directory which is created as the NOCTALIA_CONFIG_DIR in the wrapper output";
      apply = x: lib.removePrefix "/" (lib.removeSuffix "/" x);
    };
    configDrvOutput = lib.mkOption {
      type = lib.types.str;
      default = config.outputName;
      description = "Name of the derivation output where the generated NOCTALIA_CONFIG_DIR is output to.";
    };
    configPlaceholder = lib.mkOption {
      type = lib.types.str;
      default = "${placeholder config.configDrvOutput}/${config.generatedConfigDirname}";
      readOnly = true;
      description = ''
        The placeholder for the generated config directory.

        Use this inside the module to place files in an ad-hoc manner within it.

        Outside of the module, you should instead use `wrapped-noctalia-shell.generatedConfig` to get the path.
      '';
    };
    autoCopyConfig = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        If `true` and `outOfStoreConfig` was provided, will automatically copy missing config from the store on startup.
      '';
    };
    outOfStoreConfig = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = ''
        If provided, creates a copy script which copies the generated configuration to this location.

        It can be ran via `copy-noctalia-shell-config` command

        It also uses this location for `NOCTALIA_CONFIG_DIR`.

        Any files existing in that location will NOT be overridden.

        If `autoCopyConfig` is `true`, it will also run this script automatically on startup.
      '';
    };
    enableDumpScript = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Whether to generate a script to `bin/dump-noctalia-shell` in the wrapper output which will dump the current configuration and state of noctalia to stdout as nix code.
      '';
    };
    settings = lib.mkOption {
      type = lib.types.json;
      default = { };
      example = lib.literalExpression ''
        {
          bar = {
            position = "bottom";
            floating = true;
            backgroundOpacity = 0.95;
          };
          general = {
            animationSpeed = 1.5;
            radiusRatio = 1.2;
          };
          colorSchemes = {
            darkMode = true;
            useWallpaperColors = true;
          };
        }
      '';
      description = ''
        Noctalia shell configuration settings as an attribute set,
        to be written to `~/.config/noctalia/settings.json`.
      '';
    };

    colors = lib.mkOption {
      type = lib.types.json;
      default = { };
      example = lib.literalExpression ''
         {
           mError = "#dddddd";
           mOnError = "#111111";
           mOnPrimary = "#111111";
           mOnSecondary = "#111111";
           mOnSurface = "#828282";
           mOnSurfaceVariant = "#5d5d5d";
           mOnTertiary = "#111111";
           mOutline = "#3c3c3c";
           mPrimary = "#aaaaaa";
           mSecondary = "#a7a7a7";
           mShadow = "#000000";
           mSurface = "#111111";
           mSurfaceVariant = "#191919";
           mTertiary = "#cccccc";
        }
      '';
      description = ''
        Noctalia shell color configuration as an attribute set,
        to be written to `~/.config/noctalia/colors.json`.
      '';
    };

    user-templates = lib.mkOption {
      default = { };
      type = (pkgs.formats.toml { }).type;
      example = lib.literalExpression ''
        {
          templates = {
            neovim = {
              input_path = "~/.config/noctalia/templates/template.lua";
              output_path = "~/.config/nvim/generated.lua";
              post_hook = "pkill -SIGUSR1 nvim";
            };
          };
        }
      '';
      description = ''
        Template definitions for Noctalia, to be written to ~/.config/noctalia/user-templates.toml.

        This option accepts a Nix attrset (converted to TOML automatically)
      '';
    };

    plugins = lib.mkOption {
      type = lib.types.json;
      default = { };
      example = lib.literalExpression ''
        {
          sources = [
            {
              enabled = true;
              name = "Noctalia Plugins";
              url = "https://github.com/noctalia-dev/noctalia-plugins";
            }
          ];
          states = {
            catwalk = {
              enabled = true;
              sourceUrl = "https://github.com/noctalia-dev/noctalia-plugins";
            };
          };
          version = 2;
        }
      '';
      description = ''
        Noctalia shell plugin configuration as an attribute set,
        to be written to `~/.config/noctalia/plugins.json`.
      '';
    };

    pluginSettings = lib.mkOption {
      type = with lib.types; attrsOf json;
      default = { };
      example = lib.literalExpression ''
        {
          catwalk = {
            minimumThreshold = 25;
            hideBackground = true;
          };
        }
      '';
      description = ''
        Each plugin’s settings as an attribute set,
        to be written to `~/.config/noctalia/plugins/plugin-name/settings.json`.
      '';
    };
    preInstalledPlugins = lib.mkOption {
      description = ''
        When using a `NOCTALIA_CONFIG_DIR` which is in the store,
        `noctalia-shell` WILL NOT be able to install plugins for you.

        You may use these options to install them manually via `nix`

        If you set `outOfStoreConfig`, `noctalia-shell` WILL be able to install plugins for you.
        But these options may still be used to pre install the plugins via nix.

        These options get mapped to their proper places in the files
        created by the `config.plugins` and `config.pluginSettings` options
      '';
      default = { };
      type = lib.types.attrsOf (
        lib.types.submodule {
          options = {
            enabled = lib.mkOption {
              type = lib.types.bool;
              default = true;
              description = ''
                `enabled` value for the `.states` set in `$NOCTALIA_CONFIG_DIR/plugins.json`

                Also controls if the plugin is installed.
              '';
            };
            sourceUrl = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = ''
                `sourceUrl` for the `.states` set in `$NOCTALIA_CONFIG_DIR/plugins.json`
              '';
            };
            src = lib.mkOption {
              type = wlib.types.stringable;
              description = ''
                The full path to the plugin source directory

                You should fetch the plugin using `pkgs.fetchFromGitHub`
                or another similar function.

                For example, in flake inputs:

                ```nix
                inputs.noctalia-plugins.url = "github:noctalia-dev/noctalia-plugins";
                inputs.noctalia-plugins.flake = false;
                ```

                To install the plugin, you would then supply

                ```nix
                preInstalledPlugins.pomodoro.src = "''${inputs.noctalia-plugins.outPath}/pomodoro";
                ```

                MUST BE A NIX STORE PATH
              '';
            };
            settings = lib.mkOption {
              type = lib.types.json;
              default = { };
              description = ''
                Settings to add to `$NOCTALIA_CONFIG_DIR/plugins/plugin-name/settings.json`
              '';
            };
          };
        }
      );
    };
  };
  config.runShell = lib.mkIf (config.outOfStoreConfig != null && config.autoCopyConfig) [
    {
      name = "COPY_GENERATED_CONFIG";
      data = ''
        ${config.constructFiles.copy-noctalia-shell-config.path}
      '';
    }
  ];
  config.passthru = {
    ${if config.enableDumpScript then "dump-noctalia-shell" else null} =
      config.constructFiles.dump-noctalia-shell.outPath;
    generatedConfig = "${config.wrapper.${config.configDrvOutput}}/${config.generatedConfigDirname}";
    ${if config.outOfStoreConfig != null then "copy-noctalia-shell-config" else null} =
      config.constructFiles.copy-noctalia-shell-config.outPath;
  };
  config.package = lib.mkDefault pkgs.noctalia-shell;
  config.env.NOCTALIA_SETTINGS_FILE = lib.mkIf (
    config.outOfStoreConfig == null && config.settings != { } && !hasOtherFiles
  ) config.constructFiles.settings.path;
  config.env.NOCTALIA_CONFIG_DIR = lib.mkIf (hasOtherFiles || config.outOfStoreConfig != null) (
    if config.outOfStoreConfig != null then
      # they have some kind of bug where we NEEED the final /
      if lib.hasSuffix "/" config.outOfStoreConfig then
        config.outOfStoreConfig
      else
        "${config.outOfStoreConfig}/"
    else
      "${config.configPlaceholder}/"
  );
  config.buildCommand.symlinkPlugins = lib.pipe config.preInstalledPlugins [
    (lib.filterAttrs (_: plugin: plugin.enabled))
    (lib.mapAttrsToList (
      name: plugin: ''
        mkdir -p ${lib.escapeShellArg "${config.configPlaceholder}/plugins/${name}"}
        ${pkgs.lndir}/bin/lndir -silent ${lib.escapeShellArg plugin.src} ${lib.escapeShellArg "${config.configPlaceholder}/plugins/${name}"}
      ''
    ))
    (v: [ "mkdir -p ${lib.escapeShellArg "${config.configPlaceholder}/plugins"}" ] ++ v)
    (lib.concatStringsSep "\n")
  ];
  config.constructFiles = {
    dump-noctalia-shell = lib.mkIf config.enableDumpScript {
      key = "dumpNoctaliaShell";
      relPath = "bin/dump-noctalia-shell";
      builder = ''mkdir -p "$(dirname "$2")" && cp "$1" "$2" && chmod +x "$2"'';
      content = ''
        #!${pkgs.bash}/bin/bash
        ${config.wrapperPaths.placeholder} ipc call state all > /tmp/noctalia.json && \
        ${lib.getExe pkgs.nix} eval --impure --expr 'builtins.fromJSON (builtins.readFile /tmp/noctalia.json)'
      '';
    };
    copy-noctalia-shell-config = lib.mkIf (config.outOfStoreConfig != null) {
      key = "copyNoctaliaShellConfig";
      relPath = "bin/copy-noctalia-shell-config";
      builder = ''mkdir -p "$(dirname "$2")" && cp "$1" "$2" && chmod +x "$2"'';
      content = ''
        #!${pkgs.bash}/bin/bash
        mkdir -p ${config.outOfStoreConfig} && \
        cp -rn ${config.configPlaceholder}/. ${config.outOfStoreConfig} && \
        find ${config.outOfStoreConfig} ! -perm -u+w -exec chmod u+w {} +
      '';
    };
    settings = lib.mkIf (config.settings != { }) {
      # mkOverride 0 to make sure the files are always grouped in the generated dir correctly
      relPath = lib.mkOverride 0 "${config.generatedConfigDirname}/settings.json";
      output = lib.mkOverride 0 config.configDrvOutput;
      content = builtins.toJSON config.settings;
    };
    colors = lib.mkIf (config.colors != { }) {
      relPath = lib.mkOverride 0 "${config.generatedConfigDirname}/colors.json";
      output = lib.mkOverride 0 config.configDrvOutput;
      content = builtins.toJSON config.colors;
    };
    plugins = lib.mkIf (config.plugins != { } || config.preInstalledPlugins != { }) {
      relPath = lib.mkOverride 0 "${config.generatedConfigDirname}/plugins.json";
      output = lib.mkOverride 0 config.configDrvOutput;
      content = builtins.toJSON (
        config.plugins
        // {
          states =
            config.plugins.states or { }
            // builtins.mapAttrs (_: v: { inherit (v) enabled sourceUrl; }) config.preInstalledPlugins;
        }
      );
    };
    user-templates = lib.mkIf (config.user-templates != { }) {
      key = "userTemplates";
      relPath = lib.mkOverride 0 "${config.generatedConfigDirname}/user-templates.toml";
      output = lib.mkOverride 0 config.configDrvOutput;
      content = builtins.toJSON config.user-templates;
      builder = ''mkdir -p "$(dirname "$2")" && ${pkgs.remarshal}/bin/json2toml "$1" "$2"'';
    };
  }
  // lib.pipe config.preInstalledPlugins [
    (lib.filterAttrs (_: plugin: plugin.enabled && plugin.settings != { }))
    (lib.mapAttrs (_: plugin: plugin.settings))
    (v: lib.recursiveUpdate v config.pluginSettings)
    (wlib.mapAttrsToList0 (
      i: name: value:
      lib.nameValuePair name {
        key = "plugin_${toString i}";
        relPath = lib.mkOverride 0 "${config.generatedConfigDirname}/plugins/${name}/settings.json";
        output = lib.mkOverride 0 config.configDrvOutput;
        content = builtins.toJSON value;
        builder = ''mkdir -p "$(dirname "$2")" && cp -f "$1" "$2"'';
      }
    ))
    builtins.listToAttrs
  ];
}
