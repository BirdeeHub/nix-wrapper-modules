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
    which contains the files, or you can specify each file directly. These two options can be used
    together, in which case the files from the directory (specified using the `zdotdir` option) are
    sourced before the individually specified files.
  '';
in
{
  imports = [ wlib.modules.default ];

  options = {

    skipGlobalRC = lib.mkOption {
      type = types.bool;
      default = false;
      description = ''
        Set the option for zsh to skip loading system level rc files. The system level zshenv
        file cannot be skipped.
      '';
    };

    zshAliases = lib.mkOption {
      type = types.attrsOf (types.nullOr wlib.types.stringable);
      default = { };
      description = ''
        An attribute set that maps aliases (the top level attribute names in this option) to command
        strings or directly to build outputs. Aliases mapped to null are ignored. 

        These aliases are created before any of the rc file options are sourced, therefore,
        aliases specified in those options will override the aliases specified in this option.
      '';
      example = {
        l = null;
        ll = "ls -l";
      };
    };

    zdotdir = lib.mkOption {
      type = types.nullOr wlib.types.stringable;
      default = null;
      description = ''
        Direct or string path to a directory containing rc files. The following files will be sourced from
        this directory if they exist: `.zshenv`, `.zshrc`, `.zlogin` and `.zlogout`.
      '';
    };

    zshenv = lib.mkOption {
      type = types.nullOr (wlib.types.file pkgs);
      default = null;
      description = ''
        Specifies a file which will be sourced as part of the local `.zshenv` file.

        For details on how to specify the file, see the `file` type description in the wrapper lib.
      '';
    };
    zshrc = lib.mkOption {
      type = types.nullOr (wlib.types.file pkgs);
      default = null;
      description = ''
        Specifies a file which will be sourced as part of the local `.zshrc` file.

        For details on how to specify the file, see the `file` type description in the wrapper lib.
      '';
    };
    zlogin = lib.mkOption {
      type = types.nullOr (wlib.types.file pkgs);
      default = null;
      description = ''
        Specifies a file which will be sourced as part of the local `.zlogin` file.

        For details on how to specify the file, see the `file` type description in the wrapper lib.
      '';
    };
    zlogout = lib.mkOption {
      type = types.nullOr (wlib.types.file pkgs);
      default = null;
      description = ''
        Specifies a file which will be sourced as part of the local `.zlogout` file.

        For details on how to specify the file, see the `file` type description in the wrapper lib.
      '';
    };
  };

  config =
    let
      # Name the dirctory which is created as the zdotdir in the wrapper output
      zdotFilesDirname = "wrapped_zdot";

      zshAliases = builtins.concatStringsSep "\n" (
        lib.mapAttrsToList (k: v: "alias -- ${k}=${lib.escapeShellArg v}") (
          lib.filterAttrs (k: v: v != null) config.zshAliases
        )
      );

      baseZshenv = /* bash */ ''
        # zsh-wrapped zshenv: DO NOT EDIT -- this file has been generated automatically.
        # This file is read for all shells.

        # Ensure this is only run once per shell
        if [[ -v __WRAPPED_ZSHENV_SOURCED ]]; then return; fi
        __WRAPPED_ZSHENV_SOURCED=1

        # Cover some of the work done by zsh NixOS program if it is not installed
        if [[ ! (-v __ETC_ZSHENV_SOURCED) ]]
        then
          HELPDIR="${pkgs.zsh}/share/zsh/$ZSH_VERSION/help"

          # Tell zsh how to find installed completions.
          for p in ''${(z)NIX_PROFILES}; do
              fpath=($p/share/zsh/site-functions $p/share/zsh/$ZSH_VERSION/functions $p/share/zsh/vendor-completions $fpath)
          done
        fi

        # Get zshenv from wrapped options if they exist
        # zdotdir files must be sourced first to maintain documented override rules
        ${lib.optionalString (config.zdotdir != null) /* bash */ ''
          if [[ -f "${config.zdotdir}/.zshenv" ]]
          then
            source "${config.zdotdir}/.zshenv"
          fi
        ''}
        ${lib.optionalString (config.zshenv != null) /* bash */ ''
          if [[ -f "${config.zshenv.path}" ]]
          then
            source "${config.zshenv.path}"
          fi
        ''}
      '';

      baseZshrc = /* bash */ ''
        # zsh-wrapped zshrc: DO NOT EDIT -- this file has been generated automatically.
        # This file is read for all shells.

        # Ensure this is only run once per shell
        if [[ -v __WRAPPED_ZSHRC_SOURCED ]]; then return; fi
        __WRAPPED_ZSHRC_SOURCED=1

        # zsh-wrapped defined aliases
        ${zshAliases}

        # Get zshrc from wrapped options if they exist
        # zdotdir files must be sourced first to maintain documented override rules
        ${lib.optionalString (config.zdotdir != null) /* bash */ ''
          if [[ -f "${config.zdotdir}/.zshrc" ]]
          then
            source "${config.zdotdir}/.zshrc"
          fi
        ''}
        ${lib.optionalString (config.zshrc != null) /* bash */ ''
          if [[ -f "${config.zshrc.path}" ]]
          then
            source "${config.zshrc.path}"
          fi
        ''}
      '';

      baseZlogin = /* bash */ ''
        # zsh-wrapped zlogin: DO NOT EDIT -- this file has been generated automatically.
        # This file is read for all shells.

        # Ensure this is only run once per shell
        if [[ -v __WRAPPED_ZLOGIN_SOURCED ]]; then return; fi
        __WRAPPED_ZLOGIN_SOURCED=1

        # Get zlogin from wrapped options if they exist
        # zdotdir files must be sourced first to maintain documented override rules
        ${lib.optionalString (config.zdotdir != null) /* bash */ ''
          if [[ -f "${config.zdotdir}/.zlogin" ]]
          then
            source "${config.zdotdir}/.zlogin"
          fi
        ''}
        ${lib.optionalString (config.zlogin != null) /* bash */ ''
          if [[ -f "${config.zlogin.path}" ]]
          then
            source "${config.zlogin.path}"
          fi
        ''}
      '';

      baseZlogout = /* bash */ ''
        # zsh-wrapped zlogout: DO NOT EDIT -- this file has been generated automatically.
        # This file is read for all shells.

        # Ensure this is only run once per shell
        if [[ -v __WRAPPED_ZLOGOUT_SOURCED ]]; then return; fi
        __WRAPPED_ZLOGOUT_SOURCED=1

        # Get zlogout from wrapped options if they exist
        # zdotdir files must be sourced first to maintain documented override rules
        ${lib.optionalString (config.zdotdir != null) /* bash */ ''
          if [[ -f "${config.zdotdir}/.zlogout" ]]
          then
            source "${config.zdotdir}/.zlogout"
          fi
        ''}
        ${lib.optionalString (config.zlogout != null) /* bash */ ''
          if [[ -f "${config.zlogout.path}" ]]
          then
            source "${config.zlogout.path}"
          fi
        ''}
      '';
    in
    {
      package = lib.mkDefault pkgs.zsh;

      # Required for shebangs to work on MacOS
      wrapperImplementation = "binary";

      # Allow use as a system/user shell
      passthru.shellPath = "/bin/zsh";

      addFlag = lib.mkIf (config.skipGlobalRC) [ "-d" ];

      drv.buildPhase = ''
        runHook preBuild

        mkdir $out/${zdotFilesDirname}
        cat >$out/${zdotFilesDirname}/.zshenv <<'EOL'
        ${baseZshenv}
        EOL
        cat >$out/${zdotFilesDirname}/.zshrc <<'EOL'
        ${baseZshrc}
        EOL
        cat >$out/${zdotFilesDirname}/.zlogin <<'EOL'
        ${baseZlogin}
        EOL
        cat >$out/${zdotFilesDirname}/.zlogout <<'EOL'
        ${baseZlogout}
        EOL

        runHook postBuild
      '';

      env.ZDOTDIR = "${placeholder "out"}/${zdotFilesDirname}";

      meta.maintainers = [ wlib.maintainers.fluxza ];
      meta.description = {
        pre = descriptionPre;
      };
    };
}
