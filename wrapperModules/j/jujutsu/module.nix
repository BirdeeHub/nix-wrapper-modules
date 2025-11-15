{
  config,
  wlib,
  lib,
  ...
}:
let
  tomlFmt = config.pkgs.formats.toml { };
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
    package = lib.mkDefault config.pkgs.jujutsu;
    env = {
      JJ_CONFIG = builtins.toString (tomlFmt.generate "jujutsu.toml" config.settings);
    };

    meta.maintainers = [ lib.maintainers.birdee ];
  };
}
