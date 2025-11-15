{
  config,
  lib,
  wlib,
  ...
}:
{
  imports = [ wlib.modules.default ];
  options = {
    "wezterm.lua" = lib.mkOption {
      type = wlib.types.file config.pkgs;
      default.content = "return require('nix-info')";
      description = "The wezterm config file. provide `.content`, or `.path`";
    };
    luaInfo = lib.mkOption {
      type = lib.types.attrsOf lib.types.anything;
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
    "--config-file" = config.pkgs.writeText "wezterm.lua" ''
      local wezterm = require 'wezterm'
      package.preload["nix-info"] = function() return ${lib.generators.toLua { } config.luaInfo} end
      return dofile(${builtins.toJSON config."wezterm.lua".path})
    '';
  };

  config.package = lib.mkDefault config.pkgs.wezterm;

  config.meta.maintainers = [ lib.maintainers.birdee ];
}
