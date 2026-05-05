{
  config,
  wlib,
  lib,
  pkgs,
  ...
}:
{
  imports = [ wlib.modules.default ];

  options.flake = lib.mkOption {
    type = lib.types.str;
    default = "/etc/nixos";
    description = "Preferred path/reference to a directory containing your flake.nix used by NH when running flake-based commands";
  };

  config = {
    package = pkgs.nh;
    env = {
      "NH_FLAKE" = {
        data = "${config.flake}";
        esc-fn = toString;
      };
    };

    meta.maintainers = [ wlib.maintainers.nakibrayane ];
  };
}
