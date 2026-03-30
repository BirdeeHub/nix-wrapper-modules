{
  config,
  wlib,
  lib,
  pkgs,
  ...
}:
{
  imports = [ wlib.modules.default ];

  options = {
    settings = lib.mkOption {
      description = ''
        Configuration settings for Mango (the wayland compositor).
        Check out <https://mangowm.github.io/docs>
      '';
      default = "";
      type = lib.types.lines;
      example = ''
        # menu and terminal
        bind=Alt,space,spawn,rofi -show drun
        bind=Alt,Return,spawn,foot
      '';
    };
  };

  config = {
    package = lib.mkDefault pkgs.mangowc;
    # Gives an error when using a bad config.
    drv.installPhase = ''
      runHook preInstall
      ${lib.getExe config.package} -c ${config.constructFiles.generatedConfig.path} -p
      runHook postInstall
    '';

    constructFiles.generatedConfig = {
      relPath = "config.conf";
      content = config.settings;
    };

    flags."-c" = config.constructFiles.generatedConfig.path;

    passthru.providedSessions = config.package.passthru.providedSessions;

    meta.maintainers = [ wlib.maintainers.pengolord ];
  };
}
