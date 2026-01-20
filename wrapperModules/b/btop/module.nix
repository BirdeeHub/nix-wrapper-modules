{
  config,
  wlib,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib.types)
    attrsOf
    oneOf
    bool
    float
    int
    str
    ;

  toBtopConf = lib.generators.toKeyValue {
    mkKeyValue = lib.generators.mkKeyValueDefault {
      mkValueString =
        v:
        if builtins.isBool v then
          (if v then "True" else "False")
        else if builtins.isString v then
          ''"${v}"''
        else
          builtins.toString v;
    } " = ";
  };
in
{
  imports = [ wlib.modules.default ];

  options = {
    settings = lib.mkOption {
      type = attrsOf (oneOf [
        bool
        float
        int
        str
      ]);
      default = { };
      example = {
        vim_keys = true;
        color_theme = "ayu";
      };
      description = ''
        Options to add to {file}`btop.conf` file.
        See <https://github.com/aristocratos/btop#configurability>
        for options.
      '';
    };
  };

  config.package = lib.mkDefault pkgs.btop;
  config.flags = {
    "--config" = pkgs.writeText "btop.conf" (toBtopConf config.settings);
  };

  meta.maintainers = [ wlib.maintainers.ameer ];
}
