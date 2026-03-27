{
  config,
  lib,
  wlib,
  pkgs,
  ...
}:
let
  cfg = config;

  tomlFmt = pkgs.formats.toml { };
  direnvToml = tomlFmt.generate "direnv.toml" config.extraConfig;
in
{
  imports = [ wlib.modules.default ];
  options = {
    configDirname = lib.mkOption {
      type = lib.types.str;
      default = "${config.binName}-dot-dir";
      description = "Name of the directory which is created as the dotdir in the wrapper output";
    };
    silent = lib.mkEnableOption "silent mode, that is, disabling direnv logging";
    direnvrc = lib.mkOption {
      type = lib.types.lines;
      description = ''
        Content of $DIRENV_CONFIG/direnv.toml
      '';
      default = "";
    };
    nix-direnv = {
      enable = lib.mkEnableOption "nix-direnv integration";
      package = lib.mkPackageOption pkgs "nix-direnv" { };
    };
    lib = lib.mkOption {
      type = with lib.types; attrsOf lines;
      default = { };
    };
    extraConfig = lib.mkOption {
      inherit (tomlFmt) type;
      default = { };
      description = ''
        Configuration of direnv.toml.
        See <https://direnv.net/man/direnv.toml.1.html>
      '';
    };
  };
  config = {
    package = lib.mkDefault pkgs.direnv;
    env = {
      # **IMPORTANT** DIRENV_CONFIG needs to be explicitly set in your shells environment
      # because right now, direnv will use the `direnv` binary directly in its shell
      # hook and not the wrapper (in which $DIRENV_CONFIG got injected).
      # Hence the wrapped config will not be picked up unless you explicitly reference
      # this variable and set it.
      #
      # If the PR below will ever be merged, this issue can be fixed by setting:
      #
      # env.DIRENV_EXE_PATH = "${placeholder "out"}/bin/direnv";
      #
      # This would make the direnv hook use the wrapper instead of the original binary.
      #
      # https://github.com/direnv/direnv/pull/1564

      # **IMPORTANT** Using `placeholder "out"` here seems to cause issues if this wrapper issue
      # built inside a subWrapperModule (for example within the zshWrapper) as it refers
      # to the build zsh output in that context. The passthru variants seems to solve this issue.
      # DIRENV_CONFIG = "${placeholder "out"}/${config.configDirname}";
    };
    passthru.DIRENV_CONFIG = "${config.wrapper.${config.outputName}}/${config.configDirname}";
    lib."nix-direnv.sh" =
      lib.mkIf (config.nix-direnv.enable) "source ${cfg.nix-direnv.package}/share/nix-direnv/direnvrc";
    extraConfig = {
      global = lib.mkIf (config.silent) {
        log_format = "-";
        log_filter = "^$";
      };
    };
    constructFiles = {
      direnvToml = {
        content = builtins.readFile direnvToml;
        relPath = "${config.configDirname}/direnv.toml";
      };
      direnvRc = {
        content = config.direnvrc;
        relPath = "${config.configDirname}/direnvrc";
      };
    }
    //
      # TODO: As of now, construcFiles does not accept keys like 'nix-direnv.sh'.
      # This hack somehow avoids the issue. Find out if this needs to be fixed in
      # `constructFiles`.
      lib.mapAttrs (name: value: {
        key = builtins.replaceStrings [ "." "-" ] [ "" "" ] name;
        content = value;
        relPath = "${config.configDirname}/lib/${name}";
      }) config.lib;
    meta.maintainers = [ wlib.maintainers.zenoli ];
  };
}
