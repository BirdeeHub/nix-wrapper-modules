{
  wlib,
  lib,
  pkgs,
  config,
  ...
}:
let
  inherit (lib) mkOption types;
  configAtom =
    with types;
    oneOf [
      bool
      int
      str
    ];

  renderSingleOption =
    name: value:
    if lib.isBool value then
      if value then "--${name}" else "--no-${name}"
    else
      "--${name} ${toString value}";

  renderSettings = lib.mapAttrsToList (
    name: value:
    if lib.isList value then
      lib.concatStringsSep "\n" (map (renderSingleOption name) value)
    else
      renderSingleOption name value
  );

  renderedSettings = pkgs.writeText "yt-dlp.conf" (
    lib.concatStringsSep "\n" (lib.remove "" (renderSettings config.settings)) + "\n"
  );
in
{
  imports = [ wlib.modules.default ];
  options = {
    settings = mkOption {
      type = with types; attrsOf (either configAtom (listOf configAtom));
      default = { };
      description = "Settings to wrap with the yt-dlp package";
    };
  };

  config = {
    package = pkgs.yt-dlp;
    flags = {
      "--config-location" = renderedSettings;
    };
    meta.maintainers = [ wlib.maintainers.rachitvrma ];
  };
}
