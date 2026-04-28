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
    sourcedFiles = lib.mkOption {
      type = lib.types.listOf wlib.types.stringable;
      description = ''
        Paths to files that will be sourced at the top of the generated config file.
      '';
      default = [ ];
      example = ''
        [
          ./config.conf
          ./binds.conf
          ./theme.conf
        ]
      '';
    };

    configFile = lib.mkOption {
      type = wlib.types.file {
        path = lib.mkOptionDefault config.constructFiles.generatedConfig.path;
      };
      default = { };
      description = ''
        Config file that mango will set as its config file.

        Note: If configFile.path or configFile.content is set, it will overwrite the effects of the `sourcedFiles` and `extraContent` options.
      '';
      example = ''
        {
          path = ./config.conf;
          # or
          content = ''''
            # menu and terminal
            bind=Alt,space,spawn,rofi -show drun
            bind=Alt,Return,spawn,foot
          '''';
        }
      '';
    };

    extraContent = lib.mkOption {
      type = lib.types.lines;
      description = ''
        Configurations that will be appended to the end of the generated configuration file.
      '';
      default = "";
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
      ${lib.getExe config.package} -c ${config.configFile.path} -p
      runHook postInstall
    '';

    constructFiles.generatedConfig = {
      relPath = "config.conf";
      content =
        if config.configFile.content or "" != "" then
          config.configFile.content
        else
          let
            isImpurePath = s: builtins.isString s && !builtins.hasContext s;
            sourcedFileToSourceExpression =
              sourcedFile:
              if isImpurePath sourcedFile then "source-optional=${sourcedFile}" else "source=${sourcedFile}";
          in
          (lib.strings.concatMapStringsSep "\n" sourcedFileToSourceExpression config.sourcedFiles)
          + "\n"
          + config.extraContent;
    };

    flags."-c" = config.configFile.path;

    passthru.providedSessions = config.package.passthru.providedSessions;

    meta.platforms = lib.platforms.linux;
    meta.maintainers = [ wlib.maintainers.pengolord ];
  };
}
