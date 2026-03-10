{
  wlib,
  lib,
  pkgs,
  config,
  ...
}:
let
  formatLine =
    n: v:
    let
      formatValue = v: if lib.isBool v then (if v then "true" else "false") else toString v;
    in
    ''set ${n}	"${formatValue v}"'';

  formatMapLine = n: v: "map ${n}   ${toString v}";
in
{
  imports = [ wlib.modules.default ];
  options = {
    options = lib.mkOption {
      type =
        with lib.types;
        attrsOf (oneOf [
          bool
          str
          int
          float
        ]);
      default = { };
      description = ''
        Add {option}`:set` command options to zathura and make
        them permanent. See
        {manpage}`zathurarc(5)`
        for the full list of options.
      '';
    };
    mappings = lib.mkOption {
      type = with lib.types; attrsOf str;
      default = { };
      description = ''
        Add {option}`:map` mappings to zathura and make
        them permanent. See
        {manpage}`zathurarc(5)`
        for the full list of possible mappings.

        You can create a mode-specific mapping by specifying the mode before the key:
        `"[normal] <C-b>" = "scroll left";`
      '';
    };
    plugins = lib.mkOption {
      type = with lib.types; listOf package;
      default = with pkgs.zathuraPkgs; [
        zathura_cb
        zathura_djvu
        zathura_ps
      ];
      description = ''
        Add plugins to zathura runtime.
      '';
    };
  };
  config = {
    package = pkgs.zathura;
    overrides = [
      {
        type = "override";
        name = "zathura_plugins";
        data = {
          plugins = config.plugins;
        };
      }
    ];
    flags = {
      "--config-dir" = "${placeholder config.outputName}/config";
    };
    flagSeparator = "=";
    wrapperVariants.zathura-sandbox = lib.mkIf pkgs.stdenv.hostPlatform.isLinux { };
    drv = {
      renderedRc = lib.concatStringsSep "\n" (
        [ ]
        ++ lib.mapAttrsToList formatLine config.options
        ++ lib.mapAttrsToList formatMapLine config.mappings
      );
      passAsFile = [ "renderedRc" ];
      buildPhase = ''
        runHook preBuild
        mkdir -p "${placeholder config.outputName}/config"
        cp "$renderedRcPath" "${placeholder config.outputName}/config/${config.binName}rc"
        runHook postBuild
      '';
    };
    meta.maintainers = [ wlib.maintainers.rachitvrma ];
  };
}
