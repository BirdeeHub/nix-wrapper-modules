{
  config,
  pkgs,
  wlib,
  lib,
  ...
}:
{
  config.specMods =
    {
      parentSpec ? null,
      ...
    }:
    {
      options.pluginDeps = lib.mkOption {
        default = parentSpec.parentSpec or "startup";
        type = lib.types.enum [
          false
          "startup"
          "lazy"
        ];
        description = ''
          plugins in nixpkgs sometimes have extra plugin dependencies added to
          `.dependencies` attribute. By default they will be added at startup.
        '';
      };
      options.autoconfig = lib.mkOption {
        type = lib.types.bool;
        default = parentSpec.autoconfig or true;
        description = ''
          plugins in nixpkgs sometimes have extra lua config added to
          `.passthru.initLua` attribute for compatibility.

          They will be ran before the nix-provided configuration for their associated plugin, if any
        '';
      };
      options.runtimeDeps = lib.mkOption {
        type = lib.types.enum [
          false
          "prefix"
          "suffix"
        ];
        default = parentSpec.runtimeDeps or "suffix";
        description = ''
          plugins in nixpkgs sometimes have extra dependencies added to
          `.runtimeDeps` attribute. By default they will be appended to the path,
        '';
      };
      options.collateGrammars = lib.mkOption {
        type = lib.types.bool;
        default = parentSpec.collateGrammars or false;
        description = ''
          If this plugin, or any of its dependencies from pluginDeps option,
          are a treesitter grammar passed through `nvim-treesitter.grammarToPlugin`,
          it will be collected into a single treesitter grammar plugin.

          This gives a nice boost in startup time.
        '';
      };
    };
  config.suffixVar =
    let
      autodeps = config.specCollect (
        acc: v: acc ++ lib.optionals (v.runtimeDeps or false == "suffix") (v.data.runtimeDeps or [ ])
      ) [ ];
    in
    lib.optional (autodeps != [ ]) {
      name = "NIXPKGS_AUTODEPS_SUFFIX";
      data = [
        "PATH"
        ":"
        "${lib.makeBinPath autodeps}"
      ];
    };
  config.prefixVar =
    let
      autodeps = config.specCollect (
        acc: v: acc ++ lib.optionals (v.runtimeDeps or false == "prefix") (v.data.runtimeDeps or [ ])
      ) [ ];
    in
    lib.optional (autodeps != [ ]) {
      name = "NIXPKGS_AUTODEPS_PREFIX";
      data = [
        "PATH"
        ":"
        "${lib.makeBinPath autodeps}"
      ];
    };
  config.specMaps = lib.mkOrder 490 [
    {
      name = "NIXPKGS_PLUGIN_DEPS";
      data =
        # [ { name, type, value } ... ]
        list:
        let
          getPluginDeps =
            let
              getPluginDeps' =
                first: plugin:
                (if !first then [ plugin ] else [ ])
                ++ builtins.concatLists (map (getPluginDeps' false) (plugin.dependencies or [ ]));
            in
            getPluginDeps' true;
        in
        lib.pipe list [
          (lib.filter (v: v.value.pluginDeps or false != false && v.value.data or null != null))
          (lib.partition (v: v.value.pluginDeps == "startup"))
          (
            { right, wrong }:
            lib.concatMap (
              v:
              map (data: {
                name = "pluginDepsEager";
                type = "spec";
                value = (v.value or { }) // {
                  lazy = false;
                  name = null;
                  pname = null;
                  type = "lua";
                  enable = true;
                  config = null;
                  info = { };
                  before = [ ];
                  after = [ ];
                  inherit data;
                };
              }) (getPluginDeps v.value.data)
            ) right
            ++ lib.concatMap (
              v:
              map (data: {
                name = "pluginDepsLazy";
                type = "spec";
                value = (v.value or { }) // {
                  lazy = true;
                  name = null;
                  pname = null;
                  type = "lua";
                  enable = true;
                  config = null;
                  info = { };
                  before = [ ];
                  after = [ ];
                  inherit data;
                };
              }) (getPluginDeps v.value.data)
            ) wrong
          )
          (v: v ++ list)
        ];
    }
    {
      name = "NIXPKGS_AUTOCONFIGURE";
      after = [ "NIXPKGS_PLUGIN_DEPS" ];
      data =
        list:
        lib.concatMap (
          v:
          lib.optional (v.value.data.passthru.initLua or null != null && v.value.autoconfig or true) {
            name = v.name;
            type = v.type;
            value = {
              data = null;
              enable = true;
              name = null;
              before = lib.optional (v.value.name or null != null) v.value.name;
              type = "lua";
              config = v.value.data.passthru.initLua;
            };
          }
          ++ [ v ]
        ) list;
    }
    {
      name = "COLLATE_TS_GRAMMARS";
      after = [
        "NIXPKGS_AUTOCONFIGURE"
        "NIXPKGS_PLUGIN_DEPS"
      ];
      data =
        list:
        lib.pipe list [
          (builtins.foldl'
            (
              acc: v:
              let
                isGram =
                  v.value.collateGrammars or false
                  && v.value.data or null != null
                  && !builtins.isString v.value.data
                  && (
                    v.value.data.passthru.isTreesitterGrammar or false == true
                    || v.value.data.passthru.isTreesitterQuery or false == true
                    ||
                      builtins.match "^vimplugin-(nvim-)?treesitter-(grammar|queries)-.*" (lib.getName v.value.data)
                      != null
                  );
              in
              {
                grams = acc.grams ++ lib.optional isGram v.value.data;
                specs =
                  acc.specs
                  ++ (
                    if isGram then
                      [
                        (
                          v
                          // {
                            value = v.value // {
                              data = null;
                            };
                          }
                        )
                      ]
                    else
                      [ v ]
                  );
              }
            )
            {
              grams = [ ];
              specs = [ ];
            }
          )
          (
            { grams, specs }:
            let
              name = "COLLATED_TS_GRAMMARS";
            in
            lib.optional (grams != [ ]) {
              inherit name;
              type = "spec";
              value = {
                inherit name;
                enable = true;
                data = pkgs.symlinkJoin {
                  inherit name;
                  paths = grams;
                };
              };
            }
            ++ specs
          )
        ];
    }
  ];
  config.hosts.python3 =
    {
      config,
      lib,
      wlib,
      pkgs,
      specCollect,
      ...
    }:
    {
      imports = [ wlib.modules.default ];
      options.withPackages = lib.mkOption {
        type = wlib.types.withPackagesType;
        default = pp: [ ];
      };
      config.package = pkgs.python3;
      config.overrides = [
        {
          name = "withPackages";
          data = (
            x:
            x.withPackages (
              pp:
              let
                collected = specCollect (
                  acc: v:
                  acc
                  ++ lib.optionals (builtins.isList (v.data.python3Dependencies or null)) v.data.python3Dependencies
                ) [ ];
              in
              collected ++ config.withPackages pp ++ [ pp.pynvim ]
            )
          );
        }
      ];
      config.unsetVar = [ "PYTHONPATH" ];
    };
  config.hosts.perl =
    {
      config,
      lib,
      wlib,
      pkgs,
      ...
    }:
    {
      imports = [ wlib.modules.default ];
      config.nvim-host.enable = lib.mkDefault false;
      options.withPackages = lib.mkOption {
        type = wlib.types.withPackagesType;
        default = pp: [ ];
      };
      config.package = pkgs.perl;
      config.overrides = [
        {
          name = "withPackages";
          data = (
            x:
            x.withPackages (
              pp:
              config.withPackages pp
              ++ [
                pp.NeovimExt
                pp.Appcpanminus
              ]
            )
          );
        }
      ];
    };
  config.hosts.node =
    {
      config,
      lib,
      wlib,
      pkgs,
      ...
    }:
    {
      imports = [ wlib.modules.default ];
      config.package = pkgs.neovim-node-client or pkgs.nodePackages.neovim;
      # NOTE: nvim runs the thing with `node vim.g.node_host_prog`, we can't wrap it
      # maybe we could replace the shebang with a wrapped node at some point?
      # You can wrap it for when it gets linked into ${placeholder "out"}/bin though
      config.nvim-host.var_path = "${config.package}/${config.exePath}";
    };
  config.hosts.ruby =
    {
      config,
      lib,
      wlib,
      pkgs,
      ...
    }:
    {
      imports = [ wlib.modules.default ];
      config.package = lib.makeOverridable pkgs.bundlerEnv {
        name = "neovim-ruby-host";
        postBuild = "ln -sf ${pkgs.ruby}/bin/* $out/bin";
        gemdir = config.gemdir;
      };
      options.gemdir = lib.mkOption {
        type = wlib.types.stringable;
        default = "${pkgs.path}/pkgs/applications/editors/neovim/ruby_provider";
        description = "The path to the ruby gem directory with the neovim gem as required by `pkgs.bundlerEnv`";
      };
      config.exePath = "bin/neovim-ruby-host";
      config.binName = "neovim-ruby-host";
    };
  config.extraPackages =
    lib.mkIf (config.hosts.ruby.nvim-host.enable || config.hosts.node.nvim-host.enable)
      (
        lib.optional config.hosts.ruby.nvim-host.enable config.hosts.ruby.wrapper
        ++ lib.optional config.hosts.node.nvim-host.enable pkgs.nodejs
      );
  config.env.GEM_HOME = lib.mkIf (config.hosts.ruby.nvim-host.enable) "${config.hosts.ruby.package}/${config.hosts.ruby.package.ruby.gemPath}";
  config.hosts.neovide =
    {
      lib,
      wlib,
      pkgs,
      ...
    }:
    {
      imports = [ wlib.modules.default ];
      config.nvim-host.enable = lib.mkDefault false;
      config.package = pkgs.neovide;
      config.nvim-host.flags."--neovim-bin" = "${placeholder "out"}/bin/${config.binName}";
    };
}
