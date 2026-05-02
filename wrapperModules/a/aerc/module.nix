{
  config,
  lib,
  wlib,
  pkgs,
  ...
}:
let
  iniFmt = pkgs.formats.ini { };
  iniWithGlobalFmt = pkgs.formats.iniWithGlobalSection { };
in
{
  imports = [ wlib.modules.default ];
  options = {
    settings = lib.mkOption {
      type = iniFmt.type;
      default = { };
      description = ''
        Aerc main configuration file.
        See {manpage}`aerc-config(5)`
      '';
    };
    keybinds = lib.mkOption {
      type = iniWithGlobalFmt.type;
      default = { };
      description = ''
        Aerc keybinds configuration file.
        See {manpage}`aerc-binds(5)`
      '';
    };
    accounts = lib.mkOption {
      type = iniFmt.type;
      default = { };
      description = ''
        Aerc accounts configuration file.
        Should not contain any plaintext secrets, as it's copied to nix store.
        Use `outgoing-cred-cmd` and `source-cred-cmd` instead.
        See {manpage}`aerc-accounts(5)`
      '';
    };
    stylesets = lib.mkOption {
      type = lib.types.attrsOf iniWithGlobalFmt.type;
      default = { };
      description = ''
        Stylesets (themes) for aerc.
        See {manpage}`aerc-stylesets(5)`
      '';
    };
  };
  config =
    let
      stylesets-content = lib.mapAttrs (
        name: value: lib.generators.toINIWithGlobalSection { } value
      ) config.stylesets;
      stylesets-constructFiles = lib.concatMapAttrs (name: value: {
        "stylesets-${name}" = {
          content = value;
          relPath = "stylesets/${name}";
        };
      }) stylesets-content;
      stylesets-dir = "${placeholder "out"}/stylesets";
      aerc-config =
        if config.settings ? ui && config.settings.ui ? stylesets-dirs then
          lib.recursiveUpdate config.settings {
            ui.stylesets-dirs = "${config.settings.ui.stylesets-dirs},${stylesets-dir}";
          }
        else
          lib.recursiveUpdate config.settings {
            ui.stylesets-dirs = stylesets-dir;
          };
    in
    {
      constructFiles = {
        aercConfig = {
          content = lib.generators.toINI { } aerc-config;
          relPath = "${config.binName}.conf";
        };
        keybindsConfig = {
          content = lib.generators.toINIWithGlobalSection { } config.keybinds;
          relPath = "${config.binName}-keybinds.conf";
        };
        accountsConfig = {
          content = lib.generators.toINI { } config.accounts;
          relPath = "${config.binName}-accounts.conf";
        };
      }
      // stylesets-constructFiles;
      flags = {
        "--aerc-conf" = config.constructFiles.aercConfig.path;
        "--binds-conf" = config.constructFiles.keybindsConfig.path;
        "--accounts-conf" = config.constructFiles.accountsConfig.path;
      };
      package = lib.mkDefault pkgs.aerc;
    };
}
