{
  config,
  lib,
  wlib,
  ...
}:
let
  inherit (lib)
    filterAttrs
    isAttrs
    isString
    types
    ;

  mkValueString =
    value:
    if lib.isBool value then
      if value then "true" else "false"
    else if lib.isInt value then
      toString value
    else if (value._type or "") == "literal" then
      value.value
    else if isString value then
      ''"${value}"''
    else if lib.isList value then
      "[ ${lib.strings.concatStringsSep "," (map mkValueString value)} ]"
    else
      abort "Unhandled value type ${builtins.typeOf value}";

  mkKeyValue =
    {
      sep ? ": ",
      end ? ";",
    }:
    name: value: "${name}${sep}${mkValueString value}${end}";

  mkRasiSection =
    name: value:
    if isAttrs value then
      let
        toRasiKeyValue = lib.generators.toKeyValue { mkKeyValue = mkKeyValue { }; };
        # Remove null values so the resulting config does not have empty lines
        configStr = toRasiKeyValue (filterAttrs (_: v: v != null) value);
      in
      ''
        ${name} {
        ${configStr}}
      ''
    else
      (mkKeyValue {
        sep = " ";
        end = "";
      } name value)
      + "\n";

  toRasi =
    attrs:
    lib.concatStringsSep "\n" (
      lib.concatMap (lib.mapAttrsToList mkRasiSection) [
        (filterAttrs (n: _: n == "@theme") attrs)
        (filterAttrs (n: _: n == "@import") attrs)
        (removeAttrs attrs [
          "@theme"
          "@import"
        ])
      ]
    );

  rasiLiteral =
    types.submodule {
      options = {
        _type = lib.mkOption {
          type = types.enum [ "literal" ];
          internal = true;
        };

        value = lib.mkOption {
          type = types.str;
          internal = true;
        };
      };
    }
    // {
      description = "Rasi literal string";
    };

  primitive =
    with types;
    (oneOf [
      str
      int
      bool
      rasiLiteral
    ]);

  # Either a `section { foo: "bar"; }` or a `@import/@theme "some-text"`
  configType = with types; (either (attrsOf (either primitive (listOf primitive))) str);

  themeType = with types; attrsOf configType;

  theme =
    if (isAttrs config.theme) then
      builtins.toPath (
        config.pkgs.writeTextFile {
          name = "rofi-theme";
          text = toRasi config.theme;
        }
      )
    else
      config.theme;
in
{
  imports = [ wlib.modules.default ];
  options = {
    "config.rasi" = lib.mkOption {
      type = wlib.types.file config.pkgs;
      default.content =
        toRasi {
          configuration = config.settings;
        }
        + (lib.optionalString (theme != null) (toRasi {
          "@theme" = theme;
        }));
      description = ''
        The main Rofi configuration file (`config.rasi`).

        Provide either `.content` to inline the generated Rasi text or `.path` to reference an external file.
        By default this file is auto-generated from the values in `settings` and the selected `theme`.
        It is passed to Rofi using `-config`.
      '';
    };

    settings = lib.mkOption {
      type = configType;
      default = {
        location = 0;
        xoffset = 0;
        yoffset = 0;
      };
      description = "Configuration settings for rofi.";
    };
    plugins = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [ ];
      description = "List of rofi plugins to be installed";
    };
    theme = lib.mkOption {
      type =
        with lib.types;
        nullOr (oneOf [
          str
          path
          themeType
        ]);
      default = null;
      description = ''
        The Rofi theme specification.

        Can be:
        - a string or path to an existing `.rasi` theme file,
        - or an attribute set describing Rasi sections and key/value pairs.

        When an attribute set is provided, it is rendered to Rasi syntax automatically.
        The theme is included in `"config.rasi"` via an `@theme` directive.
      '';
    };

  };

  config.flags = {
    "-config" = config."config.rasi".path;
  };

  config.package = lib.mkDefault (
    config.pkgs.rofi.override (old: {
      plugins = (old.plugins or [ ]) ++ config.plugins;
    })
  );

  config.meta.maintainers = [ lib.maintainers.birdee ];
  config.meta.platforms = lib.platforms.linux;
}
