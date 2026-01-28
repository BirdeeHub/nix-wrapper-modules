{
  config,
  pkgs,
  lib,
  wlib,
  ...
}:
{
  imports = [ wlib.modules.default ];

  options = {
    settings = lib.mkOption {
      type = with lib.types; attrsOf (either str bool);
      default = { };
      description = ''
        Configuration options of atool via the --option flag.
        See {manpage}`atool(1)`
      '';
    };
    tools = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = ''
          Enable managing which tool paths atool will use.
        '';
      };
      paths = {
        tar = lib.mkOption {
          type = lib.types.str;
          default = "${pkgs.gnutar}/bin/tar";
          description = ''
            Path to the `tar` executable.
          '';
        };
        zip = lib.mkOption {
          type = lib.types.str;
          default = "${pkgs.zip}/bin/zip";
          description = ''
            Path to the `zip` execeutable.
          '';
        };
        unzip = lib.mkOption {
          type = lib.types.str;
          default = "${pkgs.unzip}/bin/unzip";
          description = ''
            Path to the `unzip` execeutable.
          '';
        };
        gzip = lib.mkOption {
          type = lib.types.str;
          default = "${pkgs.gzip}/bin/gzip";
          description = ''
            Path to the `gzip` execeutable.
          '';
        };
        bzip2 = lib.mkOption {
          type = lib.types.str;
          default = "${pkgs.bzip2}/bin/bzip2";
          description = ''
            Path to the `bzip2` execeutable.
          '';
        };
        lzma = lib.mkOption {
          type = lib.types.str;
          default = "${pkgs.xz}/bin/lzma";
          description = ''
            Path to the `lzma` execeutable.
          '';
        };
        rar = lib.mkOption {
          type = lib.types.str;
          # Avoiding using unfree package by default
          default = "rar";
          description = ''
            Path to the `rar` executable.
          '';
        };
        unrar = lib.mkOption {
          type = lib.types.str;
          # Avoiding using unfree package by default
          default = "unrar";
          description = ''
            Path to the `lzma` execeutable.
          '';
        };
        "7z" = lib.mkOption {
          type = lib.types.str;
          default = "${pkgs.p7zip}/bin/7z";
          description = ''
            Path to the `7z` executable.
          '';
        };
        arj = lib.mkOption {
          type = lib.types.str;
          default = "${pkgs.arj}/bin/arj";
          description = ''
            Path to the `arj` executable.
          '';
        };
        rpm = lib.mkOption {
          type = lib.types.str;
          default = "${pkgs.rpm}/bin/rpm";
          description = ''
            Path to the `rpm` executable.
          '';
        };
        rpm2cpio = lib.mkOption {
          type = lib.types.str;
          default = "${pkgs.rpm}/bin/rpm2cpio";
          description = ''
            Path to the `rpm2cpio` executable.
          '';
        };
        dpkg_deb = lib.mkOption {
          type = lib.types.str;
          default = "${pkgs.dpkg}/bin/dpkg-deb";
          description = ''
            Path to the `dpkg-deb` executable.
          '';
        };
        cabextract = lib.mkOption {
          type = lib.types.str;
          default = "${pkgs.cabextract}/bin/cabextract";
          description = ''
            Path to the `cabextract` executable.
          '';
        };
        lzop = lib.mkOption {
          type = lib.types.str;
          default = "${pkgs.lzop}/bin/lzop";
          description = ''
            Path to the `lzop` executable.
          '';
        };
        rzip = lib.mkOption {
          type = lib.types.str;
          default = "${pkgs.rzip}/bin/rzip";
          description = ''
            Path to the `rzip` executable.
          '';
        };
        lrzip = lib.mkOption {
          type = lib.types.str;
          default = "${pkgs.lrzip}/bin/lrzip";
          description = ''
            Path to the `lrzip` executable.
          '';
        };
        cpio = lib.mkOption {
          type = lib.types.str;
          default = "${pkgs.cpio}/bin/cpio";
          description = ''
            Path to the `cpio` executable.
          '';
        };
      };
    };
  };

  config = {
    package = lib.mkDefault pkgs.atool;
    settings = lib.mkIf config.tools.enable (
      lib.mapAttrs' (name: value: lib.nameValuePair "path_${name}" value) config.tools.paths
    );
    flags = {
      # Alternatively, config options can be set in a config file specified with --config
      "--option" = {
        sep = "=";
        data = lib.attrsets.mapAttrsToList (name: value: "${name}=${value}") config.settings;
      };
    };

    # These tools are symlinks to the atool executable, and atool determines
    # which one to run by the program basename. When atool is wrapped, the wrapper
    # script executes the original atool such that the basename is always atool, which
    # breaks these shortcuts. In order to keep these shortcuts functional, we wrap each one
    wrapperVariants = {
      acat = { };
      adiff = { };
      als = { };
      apack = { };
      arepack = { };
      aunpack = { };
    };
    meta.maintainers = [ wlib.maintainers.jomarm ];
  };
}
