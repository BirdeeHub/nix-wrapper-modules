{
  config,
  lib,
  wlib,
  pkgs,
  ...
}:
let
  gitconfigPath = "${placeholder config.outputName}/${config.binName}config";
in
{
  imports = [ wlib.modules.default ];
  options = {
    settings = lib.mkOption {
      inherit (pkgs.formats.gitIni { }) type;
      default = { };
      description = ''
        Git configuration settings.
        See {manpage}`git-config(1)` for available options.
      '';
    };

    configFile = lib.mkOption {
      type = wlib.types.file pkgs;
      default.path = gitconfigPath;
      default.content = "";
      description = "Generated git configuration file.";
    };
  };

  config.env.GIT_CONFIG_GLOBAL = config.configFile.path;
  config.package = lib.mkDefault pkgs.git;
  config.drv = {
    gitconfig = lib.generators.toGitINI config.settings + "\n" + config.configFile.content;
    passAsFile = [ "gitconfig" ];
    buildPhase = ''
      runHook preBuild
      cp "$gitconfigPath" ${lib.escapeShellArg gitconfigPath}
      runHook postBuild
    '';
  };
  config.meta.maintainers = [ wlib.maintainers.birdee ];
  config.meta.description = ''
    Nix uses git for all sorts of things. Including fetching flakes!

    So if you put this one in an overlay, name it something other than `pkgs.git`!

    Otherwise you will probably get infinite recursion.

    The vast majority of other packages do not have this issue. And,
    due to the passthrough of `.override` and `.overrideAttrs`,
    most other packages are safe to replace with their wrapped counterpart in overlays directly.
  '';
}
