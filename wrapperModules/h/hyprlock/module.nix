{
  config,
  wlib,
  lib,
  pkgs,
  ...
}:
let
  /*
    from:
    https://github.com/nix-community/home-manager/blob/8a423e444b17dde406097328604a64fc7429e34e/modules/lib/generators.nix
  */
  toHyprconf =
    {
      attrs,
      indentLevel ? 0,
      importantPrefixes ? [ "$" ],
    }:
    let
      inherit (lib)
        all
        concatMapStringsSep
        concatStrings
        concatStringsSep
        filterAttrs
        foldl
        generators
        hasPrefix
        isAttrs
        isList
        mapAttrsToList
        replicate
        attrNames
        ;

      initialIndent = concatStrings (replicate indentLevel "  ");

      toHyprconf' =
        indent: attrs:
        let
          isImportantField =
            n: _: foldl (acc: prev: if hasPrefix prev n then true else acc) false importantPrefixes;
          importantFields = filterAttrs isImportantField attrs;
          withoutImportantFields = fields: removeAttrs fields (attrNames importantFields);

          allSections = filterAttrs (_n: v: isAttrs v || isList v) attrs;
          sections = withoutImportantFields allSections;

          mkSection =
            n: attrs:
            if isList attrs then
              let
                separator = if all isAttrs attrs then "\n" else "";
              in
              (concatMapStringsSep separator (a: mkSection n a) attrs)
            else if isAttrs attrs then
              ''
                ${indent}${n} {
                ${toHyprconf' "  ${indent}" attrs}${indent}}
              ''
            else
              toHyprconf' indent { ${n} = attrs; };

          mkFields = generators.toKeyValue {
            listsAsDuplicateKeys = true;
            inherit indent;
          };

          allFields = filterAttrs (_n: v: !(isAttrs v || isList v)) attrs;
          fields = withoutImportantFields allFields;
        in
        mkFields importantFields
        + concatStringsSep "\n" (mapAttrsToList mkSection sections)
        + mkFields fields;
    in
    toHyprconf' initialIndent attrs;
in
{
  imports = [ wlib.modules.default ];

  options = {
    settings = lib.mkOption {
      /*
        from:
        https://github.com/nix-community/home-manager/blob/8a423e444b17dde406097328604a64fc7429e34e/modules/programs/hyprlock.nix
      */
      type =
        with lib.types;
        let
          valueType =
            nullOr (oneOf [
              bool
              int
              float
              str
              path
              (attrsOf valueType)
              (listOf valueType)
            ])
            // {
              description = "Hyprlock configuration value";
            };
        in
        valueType;
      default = { };
      example = lib.literalExpression ''
        {
          general = {
            grace = 5;
            hide_cursor = true;
            ignore_empty_input = true;
          };

          background = [
            {
              path = "screenshot";
              blur_passes = 3;
              blur_size = 8;
            }
          ];

          input-field = [
            {
              size = "200, 50";
              position = "0, -80";
              monitor = "";
              dots_center = true;
              fade_on_empty = false;
            }
          ];
        }
      '';
      description = ''
        Configuration for Hyprlock.
        See <https://wiki.hypr.land/Hypr-Ecosystem/hyprlock>
      '';
    };

    "hyprlock.conf" = lib.mkOption {
      type = wlib.types.file {
        path = lib.mkOptionDefault config.constructFiles.generatedConfig.path;
        content = (
          lib.optionalString (config.settings != { }) (toHyprconf {
            inherit (config) importantPrefixes;
            attrs = config.settings;
          })
          + lib.optionalString (config.extraConfig != "") config.extraConfig
        );
      };
      default = { };
      description = ''
        Hyprlock configuration file.
      '';
    };

    extraConfig = lib.mkOption {
      type = lib.types.lines;
      default = "";
      example = ''
        source = /path/to/extra.conf
      '';
      description = ''
        Extra configuration lines appended to the end of
        the Hyprlock configuration file.
      '';
    };

    importantPrefixes = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "$"
        "bezier"
        "monitor"
        "size"
      ];
      example = [
        "$"
        "bezier"
      ];
      description = ''
        List of prefix strings whose matching configuration entries
        are placed at the top of the generated configuration file.
      '';
    };
  };

  config.package = lib.mkDefault pkgs.hyprlock;
  config.flags."--config" = config."hyprlock.conf".path;

  config.constructFiles.generatedConfig = {
    content = config."hyprlock.conf".content;
    relPath = "${config.binName}.conf";
  };

  config.meta = {
    maintainers = [ wlib.maintainers.nouritsu ];
    platforms = lib.platforms.linux;
  };
}
