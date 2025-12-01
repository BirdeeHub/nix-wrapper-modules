{
  config,
  lib,
  wlib,
  pkgs,
  ...
}:
{
  imports = [ wlib.modules.default ];
  options = {
    "wezterm.lua" = lib.mkOption {
      type = wlib.types.file pkgs;
      default.content = "return require('nix-info')";
      description = "The wezterm config file. provide `.content`, or `.path`";
    };
    luaInfo = lib.mkOption {
      inherit (pkgs.formats.lua { }) type;
      default = { };
      description = ''
        anything other than uncalled nix functions can be put into this option, 
        within your `"wezterm.lua"`, you will be able to call `require('nix-info')`
        and get the values as lua values

        the default `"wezterm.lua"` value is `return require('nix-info')`

        This means, by default, this will act like your wezterm config file, unless you want to add some lua in between there.
      '';
    };
  };

  config.flagSeparator = "=";
  config.flags = {
    "--config-file" = pkgs.writeText "wezterm.lua" ''
      local wezterm = require 'wezterm'
      package.preload["nix-info"] = function() return ${lib.generators.toLua { } config.luaInfo} end
      return dofile(${builtins.toJSON config."wezterm.lua".path})
    '';
  };

  config.package = lib.mkDefault pkgs.wezterm;

  config.meta.maintainers = [ wlib.maintainers.birdee ];
}
