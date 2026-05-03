{
  wlib,
  lib,
  config,
  pkgs,
  ...
}:
let
  jsonFmt = pkgs.formats.json { };

  themeKey = "theme";
  fileKey = "file";
  settingsKey = "settings";

  defaultOrder = [
    themeKey
    fileKey
    settingsKey
  ];
in
{
  imports = [ wlib.modules.default ];

  options = {
    settings = lib.mkOption {
      inherit (jsonFmt) type;
      default = { };
      description = ''
        Pure nix configuration oh-my-posh.
        See <https://ohmyposh.dev/docs/configuration/general>
      '';
      example = {
        console_title_template = "{{ .Folder }}";
      };
    };
    configFile = lib.mkOption {
      type = with lib.types; nullOr (either path package);
      default = null;
      description = ''
        Path to an oh-my-posh configuration file.
        Supported formats are JSON (`.json`), TOML (`.toml`), and YAML (`.yaml`, `.yml`).
        See <https://ohmyposh.dev/docs/configuration/general>
      '';
      example = lib.literalExpression "./config.yaml";
    };
    theme = lib.mkOption {
      type = with lib.types; either str (listOf str);
      default = [ ];
      apply = lib.toList;
      description = ''
        One or more built-in oh-my-posh themes to use as configuration.
        When a list is provided, they will be merged by chaining them with 
        [`.extends`](https://ohmyposh.dev/docs/configuration/general#extends).
        Themes later in the list take precedence.

        See <https://ohmyposh.dev/docs/themes/>.
      '';
      example = [
        "1_shell"
        "agnoster"
      ];
    };
    order = lib.mkOption {
      type = with lib.types; wlib.types.fixedList 3 (enum defaultOrder);
      default = defaultOrder;
      description = ''
        The order in which the specified settings are merged.
        Values later in the list will take precedence.

        The allowed keys are:

        - "${themeKey}": Settings from the the specified theme (`config.theme`)
        - "${fileKey}": Settings from the specified config file (`config.configFile`)
        - "${settingsKey}": Settings specified as a nix attrs (`config.settings`)
      '';
    };
  };

  config =
    let
      nixSettingsFile = pkgs.writeText "settings.json" (builtins.toJSON config.settings);

      stripStoreHash =
        name:
        let
          m = builtins.match "[a-z0-9]{32}-(.*)" name;
        in
        if m != null then builtins.head m else name;

      normalizedConfigFile =
        if config.configFile == null then
          null
        else
          let
            path = toString config.configFile;
            baseName = stripStoreHash (baseNameOf path);
            isJson = lib.hasSuffix ".json" baseName;
            isToml = lib.hasSuffix ".toml" baseName;
            isYaml = lib.hasSuffix ".yaml" baseName || lib.hasSuffix ".yml" baseName;
            configFileName =
              lib.pipe baseName [
                (lib.removeSuffix ".toml")
                (lib.removeSuffix ".yaml")
                (lib.removeSuffix ".yml")
              ]
              + ".json";
          in
          if isJson then
            config.configFile
          else if isToml || isYaml then
            pkgs.runCommand configFileName { } ''
              ${pkgs.yq-go}/bin/yq -o=json '.' ${lib.escapeShellArg "${config.configFile}"} > $out
            ''
          else
            throw "oh-my-posh: configFile must have a .json, .toml, .yaml, or .yml extension, got: ${path}";

      # List of { srcPath, name } in precedence order (lowest to highest)
      orderedConfigs = lib.concatMap (
        key:
        {
          ${themeKey} = map (p: {
            srcPath = "${config.package}/share/oh-my-posh/themes/${p}.omp.json";
            name = "${p}.omp.json";
          }) config.theme;
          ${fileKey} = lib.optional (config.configFile != null) {
            srcPath = "${normalizedConfigFile}";
            name = stripStoreHash (baseNameOf (toString normalizedConfigFile));
          };
          ${settingsKey} = lib.optional (config.settings != { }) {
            srcPath = "${nixSettingsFile}";
            name = "settings.json";
          };
        }
        .${key}
      ) config.order;

      jq = "${pkgs.jq}/bin/jq";

      # Build constructFile entries for the config chain.
      #
      # `curr`: the current (higher-precedence) config being processed.
      # `configs`: remaining configs in descending precedence order.
      #
      # The builder for `curr` will add an ".extends" key to the json which will
      # point to the next (lower-precedence) entry in the `configs` list
      generateConstructFileEntries =
        curr: configs:
        let
          relPath = "config-chain/${curr.name}";
          prev = builtins.head configs;

          # If currPath already has an "extends" key, symlink it as-is.
          # Otherwise, add prevPath as the "extends" value.
          generateBuilderScript = currPath: prevPath: ''
            mkdir -p "$(dirname "$2")"
            if [ "$(${jq} 'has("extends")' ${lib.escapeShellArg currPath})" = "true" ]; then
              ln -s ${lib.escapeShellArg currPath} "$2"
            else
              ${jq} --arg ext ${lib.escapeShellArg prevPath} '. + {extends: $ext}' ${lib.escapeShellArg currPath} > "$2"
            fi
          '';

        in
        if builtins.length configs == 1 then
          # Base: prev is the lowest-precedence config — point directly to its source
          {
            ${relPath} = {
              inherit relPath;
              builder = generateBuilderScript curr.srcPath prev.srcPath;
            };
          }
        else
          # Recursive: prev will itself be a generated file in config-chain
          {
            ${relPath} = {
              inherit relPath;
              builder = generateBuilderScript curr.srcPath "${placeholder "out"}/config-chain/${prev.name}";
            };
          }
          // generateConstructFileEntries prev (builtins.tail configs);

      n = builtins.length orderedConfigs;

      constructFiles =
        if n == 0 then
          { }
        else if n == 1 then
          let
            cfg = builtins.head orderedConfigs;
          in
          {
            "config.json" = {
              relPath = "config.json";
              builder = ''
                mkdir -p "$(dirname "$2")"
                ln -s ${lib.escapeShellArg cfg.srcPath} "$2"
              '';
            };
          }
        else
          let
            reversed = lib.reverseList orderedConfigs;
            lastConfig = lib.last orderedConfigs;
          in
          generateConstructFileEntries (builtins.head reversed) (builtins.tail reversed)
          // {
            "config.json" = {
              relPath = "config.json";
              builder =
                let
                  chainDir = "${placeholder "out"}/config-chain";
                  lastConfigPath = "${chainDir}/${lastConfig.name}";
                in
                ''
                  # Follow the extends chain and remove files in config-chain that are
                  # no longer reachable (cut off by a config that already had "extends")
                  declare -A reachable
                  current=${lib.escapeShellArg lastConfigPath}
                  while [ -f "$current" ]; do
                    reachable["$current"]=1
                    ext=$(${jq} -r '.extends // empty' "$current")
                    [[ "$ext" == ${lib.escapeShellArg chainDir}/* ]] || break
                    current="$ext"
                  done
                  for f in ${lib.escapeShellArg chainDir}/*; do
                    [ -v 'reachable[$f]' ] || rm "$f"
                  done
                  rmdir ${lib.escapeShellArg chainDir} 2>/dev/null || true

                  mkdir -p "$(dirname "$2")"
                  ln -s ${lib.escapeShellArg lastConfigPath} "$2"
                '';
            };
          };
    in
    {
      inherit constructFiles;
      package = lib.mkDefault pkgs.oh-my-posh;
      flags."--config" = lib.mkIf (n > 0) config.constructFiles."config.json".path;
      meta = {
        maintainers = with wlib.maintainers; [
          zenoli
        ];
        description = ''
          Wrapper Module for the [Oh-My-Posh Prompt](https://ohmyposh.dev/).

          Oh-My-Posh is configured via a [JSON/YAML/TOML file](https://ohmyposh.dev/docs/configuration/general).
          This module provides three ways to do this:

          - By specifying one (or many) of the [built-in themes](https://ohmyposh.dev/docs/themes/).
          - By pointing to a JSON, TOML, or YAML configuration file.
          - By using pure Nix to write an attribute set that gets converted to JSON.

          These options are not mutually exclusive. If multiple are defined,
          they will be merged according to the order specified in `config.order`.

          Merging is done using Oh-My-Posh's native
          [extends](https://ohmyposh.dev/docs/configuration/general#extends) mechanic,
          which allows a configuration file to inherit from another and override individual values.

          Configs will be modified during build-time to add an `.extends` key
          pointing to the next config in the list. If a config already has an `.extends` key present,
          it is used as-is and the remaining lower-precedence configs are ignored.

          **Example**

          ```nix
          theme = "jandedobbeleer";
          configFile = ./my-config.yaml;
          settings.console_title_template = "{{ .Folder }}";
          ```

          With the default order (`theme < file < settings`), this produces the chain:

          ```
          settings.json  →  my-config.json  →  jandedobbeleer.omp.json
          (highest precedence)                  (lowest precedence)
          ```

          `settings.json` has an `extends` key pointing to `my-config.json`,
          which in turn extends `jandedobbeleer.omp.json`.

          If `my-config.yaml` already contains an `extends` key (e.g. pointing to another theme),
          it is left unchanged and the chain stops there:

          ```
          settings.json  →  my-config.json  -x-  jandedobbeleer.omp.json
          (highest precedence)    ↓
                           (its own extends)
          ```

          `jandedobbeleer.omp.json` is dropped entirely — `my-config.yaml`'s own `extends` takes over as the base.
        '';
      };
    };
}
