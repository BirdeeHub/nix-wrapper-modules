{
  config,
  lib,
  wlib,
  pkgs,
  ...
}:
let
  inherit
    (pkgs.callPackage ./normalize.nix {
      inherit (config.settings) info_plugin_name;
      inherit wlib opt-dir start-dir;
      inherit (config) specs specMaps;
    })
    plugins4lua
    hasFennel
    infoPluginInitMain
    buildPackDir
    mappedSpecs
    ;
  inherit
    (
      let
        initial = lib.pipe config.hosts [
          (lib.mapAttrsToList (
            n: v:
            if v.nvim-host.enable then
              {
                attrname = n;
                inherit (v.nvim-host) disabled_variable enabled_variable;
                setvarcmd = "vim.g[ ${builtins.toJSON v.nvim-host.enabled_variable} ] = ${builtins.toJSON v.nvim-host.var_path}";
                bin_path = config.nvim-host.package;
              }
              // lib.optionalAttrs (!v.nvim-host.dontWrap) {
                config = v.nvim-host;
              }
            else
              {
                attrname = n;
                inherit (v.nvim-host) disabled_variable enabled_variable;
                setvarcmd = "vim.g[ ${builtins.toJSON v.nvim-host.disabled_variable} ] = 0";
              }
          ))
        ];
      in
      {
        collectedHosts = lib.pipe initial [
          (map (v: {
            name = v.attrname;
            value = {
              bin_path =
                if v ? bin_path then
                  builtins.toJSON "${placeholder "out"}/bin/${config.binName}-${v.attrname}"
                else
                  null;
              var_path = lib.generators.mkLuaInline "vim.g[ ${builtins.toJSON v.enabled_variable} ]";
              inherit (v) disabled_variable enabled_variable;
            };
          }))
          builtins.listToAttrs
        ];
        hostLuaCmd = lib.concatMapStringsSep "\n" (v: v.setvarcmd) initial;
        hostLinkCmd = lib.pipe initial [
          (builtins.foldl' (
            acc: v:
            if v ? config then
              acc
              ++ [
                (pkgs.callPackage (import wlib.modules.makeWrapper).wrapperFunction {
                  inherit wlib;
                  inherit (v) config;
                })
              ]
            else if v ? bin_path then
              acc
              ++ [
                "ln -s ${lib.escapeShellArg v.bin_path} ${lib.escapeShellArg "${placeholder "out"}/bin/${config.binName}-${v.attrname}"}"
              ]
            else
              acc
          ) [ ])
          (builtins.concatStringsSep "\n")
        ];
      }
    )
    collectedHosts
    hostLuaCmd
    hostLinkCmd
    ;
  final-packdir = "${placeholder "out"}/${config.binName}-packdir";
  start-dir = "${final-packdir}/pack/myNeovimPackages/start";
  opt-dir = "${final-packdir}/pack/myNeovimPackages/opt";
  info-plugin-path = "${start-dir}/${config.settings.info_plugin_name}";
in
{
  config.drv.manifestLua = hostLuaCmd;
  config.drv.hostLinkCmd = hostLinkCmd;
  config.drv.infoPluginInitMain = infoPluginInitMain;
  config.drv.hasFennel = hasFennel;
  config.drv.buildPackDir = buildPackDir;
  config.specCollect = fn: first: builtins.foldl' fn first mappedSpecs;
  config.drv.infoPluginText = /* lua */ ''
    return setmetatable({
      plugins = ${lib.generators.toLua { } plugins4lua},
      settings = ${
        lib.generators.toLua { } (
          config.settings
          // {
            nvim_lua_env =
              (config.package.lua.withPackages or pkgs.luajit.withPackages)
                config.settings.nvim_lua_env;
          }
        )
      },
      wrapper_drv = ${builtins.toJSON "${placeholder "out"}"},
      binName = ${builtins.toJSON config.binName},
      info = ${lib.generators.toLua { } config.info},
      hosts = ${lib.generators.toLua { } collectedHosts},
      info_plugin_path = ${builtins.toJSON info-plugin-path},
      vim_pack_dir = ${builtins.toJSON final-packdir},
      start_dir = ${builtins.toJSON start-dir},
      opt_dir = ${builtins.toJSON opt-dir},
      progpath = ${builtins.toJSON "${placeholder "out"}/bin/${config.binName}"},
    }, {
      __call = function(self, default, ...)
        if select('#', ...) == 0 then return default end
        local tbl = self;
        for _, key in ipairs({...}) do
          if type(tbl) ~= "table" then return default end
          tbl = tbl[key]
        end
        return (tbl ~= nil) and tbl or default
      end
    })
  '';
}
