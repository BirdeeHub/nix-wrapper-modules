{
  config,
  lib,
  wlib,
  pkgs,
  ...
}:
{
  imports = [ wlib.modules.default ];
  options.lua = lib.mkOption {
    type = lib.types.package;
    default = pkgs.luajit;
    description = "The lua derivation used to evaluate the `luaEnv` option";
  };
  options.luaEnv = lib.mkOption {
    type = wlib.types.withPackagesType;
    default = (lp: [ ]);
    description = ''
      Extra lua packages to add to the lua environment for wezterm.
      These packages will be added to package.path and package.cpath in the lua environment.

      The value must be a function that can be passed to the [`lua.withPackages`](https://nixos.org/manual/nixpkgs/stable/#lua.withpackages-function) function from `nixpkgs`.
      This function should take a single argument, and return a list of packages defined as attributes of the argument (see example).

      Note that for this wrapper, the packages will be taken from `config.lua.pkgs`, so make sure that they are available from the derivation you set for the `lua` option.
    '';
    example = ''
      # String used to prevent function displaying as `<function>`
      luaEnv = (lp: [ lp.luafilesystem ]);
    '';
  };
  options."wezterm.lua" = lib.mkOption {
    type = wlib.types.file {
      path = lib.mkOptionDefault config.constructFiles."wezterm.lua".path;
      content = lib.mkOptionDefault "return require('nix-info')";
    };
    default = { };
    description = ''
      The wezterm config file.

      By default the content of the `luaInfo` option is used and nothing has to be provided here.

      If you wish to use your own file instead, provide either the `.content`, or `.path` attributes to this option.
      You can still use the `luaInfo` option in this case, see its description for details.
    '';
  };
  options.luaInfo = lib.mkOption {
    inherit (pkgs.formats.lua { }) type;
    default = { };
    description = ''
      Defines attributes which are converted to Lua. The converted values are made available to the wezterm config as the result of calling `require('nix-info')`.

      The conversion to Lua uses `lib.generators.toLua` which accepts anything other than uncalled nix functions.

      `''${placeholder config.outputName}` is usable here and will point to the final wrapper derivation

      You may also call `require('nix-info')(defaultval, "path", "to", "item")`. This will help prevent indexing errors when querying nested values which may not exist.

      By default, the result of `require('nix-info')` is used as your wezterm config file, see the "wezterm.lua" option for details.
    '';
  };
  config.constructFiles."wezterm.lua" = {
    relPath = "${config.binName}-init.lua";
    content = config."wezterm.lua".content;
  };
  config.constructFiles.nixLuaInit = {
    relPath = "${config.binName}-rc.lua";
    content =
      let
        withPackages = config.lua.withPackages or pkgs.luajit.withPackages;
        genLuaCPathAbsStr =
          config.lua.pkgs.luaLib.genLuaCPathAbsStr or pkgs.luajit.pkgs.luaLib.genLuaCPathAbsStr;
        genLuaPathAbsStr =
          config.lua.pkgs.luaLib.genLuaPathAbsStr or pkgs.luajit.pkgs.luaLib.genLuaPathAbsStr;
        luaEnv = withPackages config.luaEnv;
      in
      /* lua */ ''
        ${lib.optionalString ((config.luaEnv config.lua.pkgs) != [ ]) /* lua */ ''
          package.path = package.path .. ";" .. ${builtins.toJSON (genLuaPathAbsStr luaEnv)}
          package.cpath = package.cpath .. ";" .. ${builtins.toJSON (genLuaCPathAbsStr luaEnv)}
        ''}
        local wezterm = require 'wezterm'
        package.preload["nix-info"] = function()
          return setmetatable(${lib.generators.toLua { } config.luaInfo}, {
            __call = function(self, default, ...)
              if select('#', ...) == 0 then return default end
              local tbl = self;
              for _, key in ipairs({...}) do
                if type(tbl) ~= "table" then return default end
                tbl = tbl[key]
              end
              return tbl
            end
          })
        end
        return dofile(${builtins.toJSON config."wezterm.lua".path})
      '';
  };
  config.flagSeparator = "=";
  config.flags."--config-file" = config.constructFiles.nixLuaInit.path;
  config.package = lib.mkDefault pkgs.wezterm;

  config.meta.maintainers = [ wlib.maintainers.birdee ];
}
