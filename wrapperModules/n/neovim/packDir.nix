{
  config,
  lib,
  wlib,
  pkgs,
  ...
}:
let
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
        hosts = lib.pipe initial [
          (map (v: {
            name = v.attrname;
            value = {
              bin_path =
                if v ? bin_path then "${placeholder "out"}/bin/${config.binName}-${v.attrname}" else null;
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
                ((import wlib.modules.makeWrapper).wrapMain {
                  inherit wlib;
                  inherit (v) config;
                  inherit (pkgs) callPackage;
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
    hosts
    hostLuaCmd
    hostLinkCmd
    ;
  inherit
    (pkgs.callPackage ./normalize.nix {
      inherit (config.settings) info_plugin_name;
      inherit wlib opt_dir start_dir;
      inherit (config) specs specMaps;
    })
    plugins
    hasFennel
    infoPluginInitMain
    buildPackDir
    mappedSpecs
    ;
  vim_pack_dir = "${placeholder "out"}/${config.binName}-packdir";
  start_dir = "${vim_pack_dir}/pack/myNeovimPackages/start";
  opt_dir = "${vim_pack_dir}/pack/myNeovimPackages/opt";
  info_plugin_path = "${start_dir}/${config.settings.info_plugin_name}";
in
{
  config.drv.manifestLua = hostLuaCmd;
  config.drv.hostLinkCmd = hostLinkCmd;
  config.drv.infoPluginInitMain = infoPluginInitMain;
  config.drv.hasFennel = hasFennel;
  config.drv.buildPackDir = buildPackDir;
  config.specCollect = fn: first: builtins.foldl' fn first mappedSpecs;
  config.drv.infoPluginText = /* lua */ ''
    return setmetatable(${
      lib.generators.toLua { } {
        settings = lib.filterAttrsRecursive (_: v: !builtins.isFunction v) config.settings // {
          nvim_lua_env =
            (config.package.lua.withPackages or pkgs.luajit.withPackages)
              config.settings.nvim_lua_env;
        };
        wrapper_drv = placeholder "out";
        progpath = "${placeholder "out"}/bin/${config.binName}";
        inherit (config) info binName;
        inherit
          plugins
          hosts
          info_plugin_path
          vim_pack_dir
          start_dir
          opt_dir
          ;
      }
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
