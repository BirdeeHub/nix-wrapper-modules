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
    let
      isShort = builtins.stringLength name == 1;
      prefix = if isShort then "-" else "--";
    in
    if lib.isBool value then
      if value then
        "${prefix}${name}"
      else if isShort then
        ""
      else
        "--no-${name}"
    else
      "${prefix}${name} ${toString value}";

  renderSettings =
    settings:
    lib.pipe settings [
      (lib.mapAttrsToList (
        name: value:
        if lib.isList value then
          (map (renderSingleOption name) value)
        else
          [ (renderSingleOption name value) ]
      ))
      builtins.concatLists
      (lib.remove "")
      (lib.concatStringsSep "\n")
    ];
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
      "--config-location" = "${placeholder "out"}/${config.binName}-settings.conf";
    };
    drv = {
      renderedSettings = renderSettings config.settings;
      passAsFile = [ "renderedSettings" ];
      buildPhase = ''
        runHook preBuild
        cp $renderedSettingsPath "$out/${config.binName}-settings.conf"
        runHook postBuild
      '';
    };
    meta.maintainers = [ wlib.maintainers.rachitvrma ];
  };
}
