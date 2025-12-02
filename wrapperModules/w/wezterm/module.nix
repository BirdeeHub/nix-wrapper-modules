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
    type =
      let
        inherit (lib.types) package listOf functionTo;
      in
      (functionTo (listOf package))
      // {
        merge =
          loc: defs: arg:
          (listOf package).merge (loc ++ [ "<function body>" ]) (
            map (
              def:
              def
              // {
                value = def.value arg;
              }
            ) defs
          );
      };
    default = (lp: [ ]);
    description = ''
      extra lua packages to add to the lua environment for wezterm

      value is to be a function from `config.lua.pkgs` to list

      `config.lua.withPackages config.luaEnv`

      The result will be added to package.path and package.cpath
    '';
  };
  options."wezterm.lua" = lib.mkOption {
    type = wlib.types.file pkgs;
    default.content = "return require('nix-info')";
    description = "The wezterm config file. provide `.content`, or `.path`";
  };
  options.luaInfo = lib.mkOption {
    inherit (pkgs.formats.lua { }) type;
    default = { };
    description = ''
      anything other than uncalled nix functions can be put into this option, 
      within your `"wezterm.lua"`, you will be able to call `require('nix-info')`
      and get the values as lua values

      the default `"wezterm.lua"`.content value is `return require('nix-info')`

      This means, by default, this will act like your wezterm config file, unless you want to add some lua in between there.

      `''${placeholder "out"}` is useable here and will point to the final wrapper derivation
    '';
  };

  config.drv.passAsFile = [ "nixLuaInit" ];
  config.drv.nixLuaInit =
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
      package.preload["nix-info"] = function() return ${lib.generators.toLua { } config.luaInfo} end
      return dofile(${builtins.toJSON config."wezterm.lua".path})
    '';
  config.drv.buildPhase = ''
    runHook preBuild
    { [ -e "$nixLuaInitPath" ] && cat "$nixLuaInitPath" || echo "$nixLuaInit"; } > ${lib.escapeShellArg "${placeholder "out"}/${config.binName}-rc.lua"}
    runHook postBuild
  '';
  config.flagSeparator = "=";
  config.flags = {
    "--config-file" = {
      data = "${placeholder "out"}/${config.binName}-rc.lua";
      esc-fn = lib.escapeShellArg;
    };
  };

  config.package = lib.mkDefault pkgs.wezterm;

  config.meta.maintainers = [ wlib.maintainers.birdee ];
}
