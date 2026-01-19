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
      "--option" = lib.attrsets.mapAttrsToList (name: value: "${name}=${value}") config.settings;
    };

    # These tools are symlinks to the atool executable, and atool determines
    # which one to run by the program basename. When atool is wrapped, the wrapper
    # script executes the original atool such that the basename is always atool, which
    # breaks these shortcuts. In order to keep these shortcuts functional, the symlinks
    # are replaced by wrapper scripts based on the atool wrapper which executes the
    # symlink from the wrapped package.
    drv.postBuild = ''
      rm $out/bin/acat $out/bin/adiff $out/bin/als $out/bin/apack $out/bin/arepack $out/bin/aunpack
      sed 's/\/bin\/atool/\/bin\/acat/' $out/bin/atool > $out/bin/acat
      sed 's/\/bin\/atool/\/bin\/adiff/' $out/bin/atool > $out/bin/adiff
      sed 's/\/bin\/atool/\/bin\/als/' $out/bin/atool > $out/bin/als
      sed 's/\/bin\/atool/\/bin\/apack/' $out/bin/atool > $out/bin/apack
      sed 's/\/bin\/atool/\/bin\/arepack/' $out/bin/atool > $out/bin/arepack
      sed 's/\/bin\/atool/\/bin\/aunpack/' $out/bin/atool > $out/bin/aunpack
      chmod +x $out/bin/acat $out/bin/adiff $out/bin/als $out/bin/apack $out/bin/arepack $out/bin/aunpack
    '';

    meta.maintainers = [ wlib.maintainers.jomarm ];
  };
}
