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
      type = wlib.types.structuredValueWith {
        nullable = false;
        typeName = "TOML";
      };
      default = { };
      description = ''
        Configuration for jujutsu.
        See <https://jj-vcs.github.io/jj/latest/config/>
      '';
    };
  };

  config = {
    package = lib.mkDefault pkgs.jujutsu;
    env = {
      JJ_CONFIG = config.constructFiles.generatedConfig.path;
    };
    constructFiles.generatedConfig = {
      content = builtins.toJSON config.settings;
      relPath = "${config.binName}-config.toml";
      builder = ''${pkgs.remarshal}/bin/json2toml "$1" "$2"'';
    };

    meta.maintainers = [ wlib.maintainers.birdee ];
  };
}
