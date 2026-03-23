{
  config,
  wlib,
  lib,
  pkgs,
  ...
}:
let
  tomlFmt = pkgs.formats.toml { };
in
{
  imports = [ wlib.modules.default ];
  options = {
    settings = lib.mkOption {
      type = tomlFmt.type;
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
      builder = ''mkdir -p "$(dirname "$2")" && ${pkgs.remarshal}/bin/json2toml "$1" "$2"'';
    };

    meta.maintainers = [ wlib.maintainers.birdee ];
  };
}
