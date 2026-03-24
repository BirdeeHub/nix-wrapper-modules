{
  wlib,
  lib,
  config,
  pkgs,
  ...
}:
let
  tomlFmt = pkgs.formats.toml { };

  presetKey = "preset";
  settingsKey = "settings";

  defaultOrder = [
    presetKey
    settingsKey
  ];
in
{
  imports = [ wlib.modules.default ];

  options = {
    settings = lib.mkOption {
      inherit (tomlFmt) type;
      default = { };
      description = ''
        Pure nix configuration of starship.toml.
        See <https://starship.rs/config/>
      '';
      example = {
        directory.format = "[ $path ]($style)";
      };
    };
    preset = lib.mkOption {
      type = with lib.types; either str (listOf str);
      default = [ ];
      apply = lib.toList;
      description = ''
        One or more built-in starship presets to use as configuration.
        When a list is provided, presets later in the list take precedence.
        See <https://starship.rs/presets/>.
      '';
      example = [
        "nerd-font-symbols"
        "tokyo-night"
      ];
    };
    order = lib.mkOption {
      type = with lib.types; wlib.types.fixedList 2 (enum defaultOrder);
      default = defaultOrder;
      description = ''
        The order in which the specified settings are merged.
        Values later in the list will take precedence.

        The allowed keys are:

        - "${presetKey}": Settings from the the specified preset (`config.preset`)
        - "${settingsKey}": Settings specified as a nix attrs (`config.settings`)
      '';
    };
  };
  config = {
    package = lib.mkDefault pkgs.starship;
    constructFiles."starship.toml" = {
      content = builtins.toJSON config.settings;
      relPath = "starship.toml";
      builder =
        let
          # Holds the bash variable name to be used inside the builder script
          nixSettingsTomlPathVar = "nix_settings_toml";
          orderedSettings =
            let
              tomlSettingsMap = {
                ${presetKey} = map (
                  p: lib.escapeShellArg "${config.package}/share/starship/presets/${p}.toml"
                ) config.preset;
                ${settingsKey} = lib.optional (config.settings != { }) "\$${nixSettingsTomlPathVar}";
              };
            in
            lib.concatMap (key: tomlSettingsMap.${key}) config.order;
        in
        # Builds the nix settings TOML file and stores the path in the
        # bash variable named `${nixSettingsTomlPathVar}`
        lib.optionalString (config.settings != { }) ''
          ${nixSettingsTomlPathVar}="$(mktemp)"
          mkdir -p "$(dirname ''$${nixSettingsTomlPathVar})"
          ${pkgs.remarshal}/bin/json2toml "$1" "''$${nixSettingsTomlPathVar}"
        ''
        # Merges all specified presets TOML files and the TOML file generated
        # from nix settings using tomlq
        + ''
          mkdir -p "$(dirname "$2")"
          ${pkgs.yq}/bin/tomlq -s -t 'reduce .[] as $item ({}; . * $item)' \
          ${lib.concatStringsSep " " orderedSettings} > "$2"
        '';
    };
    env.STARSHIP_CONFIG = config.constructFiles."starship.toml".path;
    meta = {
      maintainers = with wlib.maintainers; [
        birdee
        zenoli
      ];
      description = ''
        Wrapper Module for the [Starship Prompt](https://starship.rs/).

        Starship is configured via a [TOML file](https://starship.rs/config/).
        This module provides two ways to do this:

        - By specifying one (or many) of the built-in preset configurations.
        - By using pure Nix to write an attribute set that gets converted to TOML.

        These two options are not mutually exclusive. If both are defined,
        they will be merged according to the order specified in `config.order`.
      '';
    };
  };
}
