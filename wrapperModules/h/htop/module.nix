{
  config,
  wlib,
  lib,
  pkgs,
  ...
}:
let
  mkValueString =
    value:
    if builtins.isList value then
      builtins.concatStringsSep " " (map mkValueString value)
    else if builtins.isString value then
      value
    else if builtins.isBool value then
      if value then "1" else "0"
    else if builtins.isInt value then
      toString value
    else
      throw "Unrecognized type ${builtins.typeOf value} in htop settings";

  mkKeyValue = lib.generators.mkKeyValueDefault { inherit mkValueString; } "=";
  toHtopConf = lib.generators.toKeyValue { inherit mkKeyValue; };

  configPath = "${placeholder config.outputName}/${config.binName}rc";
  htopConfig = lib.concatLines [
    # header_layout must be the first in file (or at least just above) so column_meter* parameters can work
    (toHtopConf (lib.filterAttrs (n: _: n == "header_layout") config.settings))
    (toHtopConf (lib.filterAttrs (n: _: n != "header_layout") config.settings))
  ];
in
{
  imports = [ wlib.modules.default ];

  options = {
    settings = lib.mkOption {
      type =
        with lib.types;
        attrsOf (oneOf [
          str
          int
          bool
          (listOf (oneOf [
            str
            int
            bool
          ]))
        ]);
      default = { };
      example = {
        hide_kernel_threads = true;
        hide_userland_threads = true;
      };
      description = ''
        Options to add to HTOPRC
      '';
    };
  };

  config.package = lib.mkDefault pkgs.htop;

  config.drv.htopConfig = htopConfig;
  config.drv.passAsFile = [ "htopConfig" ];
  config.envDefault.HTOPRC = configPath;
  config.drv.buildPhase = ''
    runHook preBuild
    cp "$htopConfigPath" ${configPath}
    runHook postBuild
  '';

  meta.maintainers = [ wlib.maintainers.alexlov ];
}
