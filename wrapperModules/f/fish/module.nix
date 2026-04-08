{
  wlib,
  lib,
  pkgs,
  config,
  ...
}:
let
  inherit (lib)
    attrValues
    concatStringsSep
    foldl'
    mapAttrsToList
    literalExpression
    mkDefault
    mkOption
    optionalString
    partition
    types
    ;

  cfg = config;

  abbreviationModule =
    { name, ... }:
    {
      options = {
        word = lib.mkOption {
          type = lib.types.str;
          default = name;
          description = "The word to be replaced";
        };
        expansion = mkOption {
          type = types.str;
          description = "The expansion to replace the word with";
        };
        position = mkOption {
          type = types.enum [
            "anywhere"
            "command"
          ];
          default = "anywhere";
          description = ''
            The scope of the abbreviation.

            "anywhere": The abbreviation may expand anywhere in the command line

            "command": The abbreviation would only expand if it is positioned as a command
          '';
        };
        regex = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "Special regex to expand instead of a word";
        };
        command = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "The abbreviation will only expand if it is used as an argument to this command";
        };
        function = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "When the abbreviation matches, this function will be called with the matching token as an argument";
        };
        cursor = mkOption {
          type = types.either types.bool types.str;
          default = false;
          description = "The cursor is moved to the first occurrence of this in the expansion, or to \"%\" if set to true";
        };
      };
    };
  completionType = types.submoduleWith {
    modules = [
      # Getting the module inside the wlib.types.file type
      # and merging it with my own module
      (builtins.elemAt (wlib.types.file pkgs).getSubModules 0)
      (
        { name, ... }:
        {
          options.command = mkOption {
            type = types.str;
            default = name;
            description = "The command to apply the completion for";
          };
        }
      )
    ];
  };
  pluginType = types.either types.package (
    types.submodule {
      options = {
        src = mkOption {
          type = types.package;
          description = "The package which contains the plugin";
        };
        configDirs = mkOption {
          type = types.listOf types.str;
          default = cfg.pluginConfigDirs;
          description = "The directories which will be checked for config files";
        };
        completionDirs = mkOption {
          type = types.listOf types.str;
          default = cfg.pluginCompletionDirs;
          description = "The directories which will be checked for config files";
        };
      };
    }
  );
in
{
  imports = [ wlib.modules.default ];
  options = {
    "config.fish" = mkOption {
      type = wlib.types.file pkgs;
      default = {
        content = "";
        path = config.constructFiles.generatedConfig.path;
      };
      description = ''
        The main fish configuration file.

        Provide either `.content` to inline shell configuration or `.path` to reference an external file.
        By default this file is generated from the configuration options declared in this module.
        It is sourced by fish using `--init-command`.

        `configFiles.<name>` should be used instead.
      '';
    };

    abbreviations = mkOption {
      type = types.attrsOf (wlib.types.spec abbreviationModule);
      default = { };
      description = "Abbreviations to be included in the shell";
      example = literalExpression ''
        {
          lshome = "ls ~/";
          find-extension = {
            word = "ext";
            expansion = "~/ -name \"*.%\"";
            command = "find";
            cursor = true;
          };
          please = {
            expansion = "sudo";
            position = "command";
          };
        }
      '';
    };
    shellAliases = mkOption {
      type = types.attrsOf types.str;
      default = { };
      description = "Aliases to be included in the shell";
      example = {
        ls = "ls -a";
        ll = "ls -l";
      };
    };
    completionFiles = mkOption {
      type = types.attrsOf completionType;
      default = { };
      description = "Completions to be included in the shell";
    };
    configFiles = mkOption {
      type = types.attrsOf (wlib.types.file pkgs);
      default = { };
      description = "Configuration files to be sourced by the shell";
    };
    functionFiles = mkOption {
      type = types.attrsOf (wlib.types.file pkgs);
      default = { };
      description = "Function files to be sourced by the shell";
    };

    plugins = mkOption {
      type = types.listOf pluginType;
      default = [ ];
      apply = map (
        plugin:
        # Convert package type to submodule
        if (!plugin ? configDirs) then
          {
            src = plugin;
            configDirs = cfg.pluginConfigDirs;
            completionDirs = cfg.pluginCompletionDirs;
          }
        else
          plugin
      );
      description = "List of fish plugins to install";
      example = literalExpression ''
        [
          pkgs.fishPlugins.hydro
          {
            src = pkgs.fishPlugins.fzf-fish;
            configDirs = [ "share/fish/vendor_conf.d" ];
            completionDirs = [ "completions" ];
          }
        ]
      '';
    };
    pluginConfigDirs = mkOption {
      type = types.listOf types.str;
      default = [
        "share/fish/vendor_functions.d"
        "etc/fish/functions"
        "share/fish/vendor_conf.d"
        "etc/fish/conf.d"
      ];
      description = "The default directories to check for configs in plugins";
    };
    pluginCompletionDirs = mkOption {
      type = types.listOf types.str;
      default = [
        "share/fish/vendor_completions.d"
        "share/fish/completions"
      ];
      description = "The default directories to check for completion files in plugins";
    };
  };

  config.package = mkDefault pkgs.fish;
  config.buildCommand.completionFiles.data = optionalString (cfg.completionFiles != [ ]) ''
    mkdir -p ${placeholder config.outputName}/completions
    ${concatStringsSep "\n" (
      mapAttrsToList (
        _: c: "cp ${c.path} ${placeholder config.outputName}/completions/${c.command}"
      ) cfg.completionFiles
    )}
  '';

  config.flags = {
    "--no-config" = mkDefault true;
    "--init-command" = {
      sep = "=";
      data = [
        "source ${config.constructFiles.generatedConfig.path}"
      ];
    };
  };

  config.constructFiles.generatedConfig = {
    relPath = "${config.binName}-config.fish";
    content =
      let
        # The plugins with the default config and completion directories will be sourced in a shell loop
        # and the others will be sourced individually
        configurationPlugins = partition (p: p.configDirs == cfg.pluginConfigDirs) cfg.plugins;
        completionPlugins = partition (p: p.completionDirs == cfg.pluginCompletionDirs) cfg.plugins;

        mapPluginsToString =
          {
            plugins,
            dirList,
            functor,
            multiple ? true,
          }:
          let
            pluginLines =
              if (builtins.isFunction dirList) then
                map (plugin: map functor (dirList plugin)) plugins
              else
                map functor dirList;
            toString = plugins: builtins.toString (map (p: p.src) plugins);
          in
          optionalString (plugins != [ ]) ''
            set plugin${optionalString multiple "_list"} ${toString plugins}
            ${optionalString multiple "for plugin_dir in $plugin_list"}
              ${concatStringsSep "\n  " pluginLines}
            ${optionalString multiple "end"}
            set -e plugin${optionalString multiple "_list"}
          '';

        pluginSources = mapPluginsToString {
          plugins = configurationPlugins.right;
          dirList = cfg.pluginConfigDirs;
          functor = dir: ''
            for plugin in $plugin_dir/${dir}/*.fish
              source $plugin
            end
          '';
        };
        pluginCompletions = mapPluginsToString {
          plugins = completionPlugins.right;
          dirList = cfg.pluginCompletionDirs;
          functor = dir: ''
            if test -d $plugin_dir/${dir}
              set -a fish_complete_path $plugin_dir/${dir}
            end
          '';
        };

        customPluginSources = mapPluginsToString {
          plugins = configurationPlugins.wrong;
          dirList = plugin: plugin.configDirs;
          multiple = false;
          functor = dir: ''
            for plugin in $plugin/${dir}/*.fish
              source $plugin
            end
          '';
        };
        customPluginCompletions = mapPluginsToString {
          plugins = completionPlugins.wrong;
          dirList = plugin: plugin.configDirs;
          multiple = false;
          functor = dir: ''
            if test -d $plugin/${dir}
              set -a fish_complete_path $plugin/${dir}
            end
          '';
        };

        mkAbbrArg = attr: abbr: optionalString (abbr.${attr} != null) "--${attr} ${abbr.${attr}}";
        abbrArgs = [
          "position"
          "regex"
          "command"
          "function"
        ];

        mkCursorArg =
          abbr:
          optionalString (
            abbr.cursor != false
          ) "--set-cursor${optionalString (builtins.isString abbr.cursor) "=${abbr.cursor}"}";

        mkAbbrStr =
          abbr:
          (foldl' (
            acc: elem: acc + " " + (mkAbbrArg elem abbr)
          ) "abbr --add ${abbr.word} ${mkCursorArg abbr}" abbrArgs)
          + " "
          + "\"${abbr.expansion}\"";

        abbrs = concatStringsSep "\n" (map mkAbbrStr (attrValues cfg.abbreviations));
        aliases = concatStringsSep "\n" (
          mapAttrsToList (name: value: "alias ${name}=\"${value}\"") cfg.shellAliases
        );

        configs =
          let
            confs = (attrValues cfg.configFiles) ++ (attrValues cfg.functionFiles);
          in
          ''
            set configs ${toString (map (conf: conf.path) confs)}
            for config in $configs
              source $config
            end
            set -e configs
          '';

        completions = "set -a fish_complete_path ${placeholder config.outputName}/completions";
      in
      (concatStringsSep "\n" [
        pluginSources
        pluginCompletions
        customPluginSources
        customPluginCompletions
        aliases
        abbrs
        configs
        completions
      ]);
  };

  config.meta.maintainers = [ wlib.maintainers.ormoyo ];
  config.meta.platforms = lib.platforms.linux;
}
