{
  config,
  lib,
  wlib,
  pkgs,
  ...
}:
let
  inherit (lib) types;
  # defined here so that it can double as module documentation
  descriptionPre = ''
    Wrapping zsh involves some complexity regarding the global rc files. If zsh is installed
    on the system, /etc/zshenv will be used no matter what. This should not be impactful as
    system maintainers should keep the file from causing unexpected behaviour. The remaining
    global rc files can be skipped using the `skipGlobalRC` option if they are causing conflicts
    with your local rc files.

    For details regarding the rc files see <https://zsh.sourceforge.io/Doc/Release/Files.html#Startup_002fShutdown-Files>.

    This wrapper provides two methods of defining your local rc files. You can specify a directory
    which contains the files, or you can specify each file directly. These two options cannot be used
    together. If they are both defined, only the directory with its contained files will be used.
  '';
in
{
  imports = [ wlib.modules.default ];

  options = {

    skipGlobalRC = lib.mkOption {
      type = types.bool;
      default = false;
      description = ''
        Don't use the global rc files.
      '';
    };

    zdotdir = lib.mkOption {
      type = types.nullOr (types.either types.path types.str);
      default = null;
      description = ''
        WIP
      '';
    };

    zdotFiles = lib.mkOption {
      default = null;
      type = types.nullOr (
        types.submodule {
          options = {
            zshenv = lib.mkOption {
              type = wlib.types.file pkgs;
              default.content = "";
              description = ''
                WIP
              '';
            };
            zshrc = lib.mkOption {
              type = wlib.types.file pkgs;
              default.content = "";
              description = ''
                WIP
              '';
            };
            zlogin = lib.mkOption {
              type = wlib.types.file pkgs;
              default.content = "";
              description = ''
                WIP
              '';
            };
            zlogout = lib.mkOption {
              type = wlib.types.file pkgs;
              default.content = "";
              description = ''
                WIP
              '';
            };
          };
        }
      );
    };
  };

  config =
    let
      zdotFilesDirname = "wrapped_zdot";
      zdotdirEnv =
        lib.trivial.warnIf (config.zdotdir != null && config.zdotFiles != null)
          "Using both zdotdir and zdotFiles options is not compatible. Only zdotdir will be used."
          (if config.zdotdir != null then config.zdotdir else "${placeholder "out"}/${zdotFilesDirname}");
    in
    {
      package = lib.mkDefault pkgs.zsh;

      # Required for shebangs to work on MacOS
      wrapperImplementation = "binary";

      addFlag = lib.mkIf (config.skipGlobalRC) [ "-d" ];

      drv.installPhase = lib.mkIf (config.zdotFiles != null) ''
        mkdir $out/wrapped_zdot
        cp ${config.zdotFiles.zshenv.path} $out/${zdotFilesDirname}/.zshenv
        cp ${config.zdotFiles.zshrc.path} $out/${zdotFilesDirname}/.zshrc
        cp ${config.zdotFiles.zlogin.path} $out/${zdotFilesDirname}/.zlogin
        cp ${config.zdotFiles.zlogout.path} $out/${zdotFilesDirname}/.zlogout
      '';

      env.ZDOTDIR = zdotdirEnv;

      meta.maintainers = [ wlib.maintainers.fluxza ];
      meta.description = {
        pre = descriptionPre;
      };
    };
}
