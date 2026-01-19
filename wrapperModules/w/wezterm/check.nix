{
  pkgs,
  self,
}:
let
  weztermWrapped = self.wrappedModules.wezterm.wrap (
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
  res=$(${weztermWrapped}/bin/wezterm show-keys)
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
