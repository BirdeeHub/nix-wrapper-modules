# Adding modules!

Please add some modules to the `modules/` directory to help everyone out!

That way, your module can be available for others to enjoy as well!

There are 2 kinds of modules. One kind which defines the `package` option, and one kind which does not.

If you are making a wrapper module, i.e. one which defines the `package` argument, and thus wraps a package,
then you must define a `wrapperModules/<first_letter>/<your_package_name>/wrapper.nix` file.

It must contain a single, unevaluated module. In other words, it must be importable without calling it first to return the module.

If you are making a helper module, i.e. one which does not define the `package` argument, then you must define a `modules/<your_module_name>/module.nix` file.

All options must have descriptions, so that documentation can be generated and people can know how to use it!

All modules must have a `meta.maintainers = [];` entry.

## Guidelines:

When making options for your module, if you are able, please provide both nix-generated, and `wlib.types.file` or `lib.types.lines` options

If you are not able to provide both, default to `wlib.types.file` unless it is `JSON` or something else which does not append nicely, but do try to provide both options.

When you provide a `wlib.types.file` option, you should try to name it as close to the filename as possible, if that makes sense.

Example:

```nix
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
      package.preload["nix-info"] = function() return ${
        lib.generators.toLua { } config.luaInfo
      } end
      return dofile(${builtins.toJSON config."wezterm.lua".path})
    '';
  };

  config.package = lib.mkDefault config.pkgs.wezterm;

  config.meta.maintainers = [ lib.maintainers.birdee ];
}
```

# Formatting

`nix fmt`

# Tests

`nix flake check -Lv .`

# Writing tests

You may also include a `check.nix` file in your module's directory.

It will be provided with the flake `self` value and `pkgs`

Example:

```nix
{
  pkgs,
  self,
}:
let
  weztermWrapped = self.wrapperModules.wezterm.wrap (
    { lib, ... }:
    {
      inherit pkgs;
      luaInfo = {
        keys = [
          {
            key = "F12";
            mods = "SUPER|CTRL|ALT|SHIFT";
            action = lib.generators.mkLuaInline "wezterm.action.Nop";
          }
        ];
      };
      "wezterm.lua".content = # lua
        ''
          local wezterm = require 'wezterm'
          local config = require 'nix-info'
          config.keys[2] = {
            key = 'F13',
            mods = 'SUPER|CTRL|ALT|SHIFT',
            action = wezterm.action.Nop,
          }
          return config
        '';
    }
  );
in
pkgs.runCommand "wezterm-test" { } ''
  res=$("${weztermWrapped}/bin/wezterm" show-keys)
  if ! echo "$res" | grep -q "SHIFT | ALT | CTRL | SUPER   F12"; then
    echo "Wezterm doesn't see custom keybind 1"
    touch $out
    exit 1
  fi
  if ! echo "$res" | grep -q "SHIFT | ALT | CTRL | SUPER   F13"; then
    echo "Wezterm doesn't see custom keybind 2"
    touch $out
    exit 1
  fi
  touch $out
''
```

# Questions?

The github discussions board is open and a great place to find help!
