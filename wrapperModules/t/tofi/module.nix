{
  wlib,
  lib,
  pkgs,
  config,
  ...
}:
{
  imports = [ wlib.modules.default ];
  options = {
    settings = lib.mkOption {
      type =
        with lib.types;
        attrsOf (oneOf [
          bool
          int
          float
          wlib.types.stringable
        ]);
      default = { };
      description = ''
        Settings for {command}`tofi`.
        See {manpage}`tofi(5)` for available options.
      '';
      example = {
        width = "100%";
        height = "100%";
        num-results = 5;
        border-width = 0;
        outline-width = 0;
        padding-left = "35%";
        padding-top = "35%";
        result-spacing = 25;
        background-color = "#000A";
      };
    };
  };
  config = {
    package = lib.mkDefault pkgs.tofi;

    constructFiles.generatedConfig = {
      relPath = "${config.binName}-config";
      content =
        let
          valueToString =
            v:
            if builtins.isBool v then
              lib.boolToString v
            else if builtins.isPath v then
              "${v}"
            else
              toString v;
          keyValueToLine = k: v: "${k} = ${valueToString v}\n";
          settingsWithoutInclude = builtins.removeAttrs config.settings [ "include" ];
          lines = lib.mapAttrsToList keyValueToLine settingsWithoutInclude;
          # If set the "include" option should be last so that included options are not overwritten
          includeLine = lib.optional (config.settings ? include) (
            keyValueToLine "include" config.settings.include
          );
        in
        lib.concatStrings (lines ++ includeLine);
    };

    flags = {
      "--config" = config.constructFiles.generatedConfig.path;
    };

    meta.maintainers = [ wlib.maintainers.nikitawootten ];
  };
}
