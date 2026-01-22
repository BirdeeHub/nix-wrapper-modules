{
  config,
  pkgs,
  wlib,
  lib,
  ...
}:
let
  inherit (lib) types;
  luaType =
    types.nullOr (
      types.oneOf [
        types.bool
        types.float
        types.int
        types.path
        types.str
        types.luaInline
        (types.attrsOf luaType)
        (types.listOf luaType)
      ]
    )
    // {
      description = "lua value";
      descriptionClass = "noun";
    };
  hostPropagatedOptions =
    name: hostConfig:
    lib.types.submoduleWith {
      specialArgs = { inherit wlib; };
      modules = [
        {
          imports = [ wlib.modules.makeWrapper ];
          options = {
            # These internal options will allow us to call
            # the regular function from the makeWrapper module for each host,
            # but in the context of the outer wrapped nvim derivation.
            binName = lib.mkOption {
              type = lib.types.str;
              default = "${config.binName}-${name}";
              readOnly = true;
              internal = true;
              description = "placeholder option";
            };
            exePath = lib.mkOption {
              type = lib.types.str;
              default = "";
              readOnly = true;
              internal = true;
              description = "placeholder option";
            };
            meta = lib.mkOption {
              type = lib.types.raw;
              internal = true;
              description = "placeholder option";
            };
            wrapperFunction = lib.mkOption {
              type = lib.types.raw;
              readOnly = true;
              internal = true;
              description = "placeholder option";
            };
            enabled_variable = lib.mkOption {
              type = wlib.types.nonEmptyline;
              default = "${name}_host_prog";
              description = ''
                vim.g.<value> will be set to the path to this wrapped host when the nvim host is enabled
              '';
            };
            disabled_variable = lib.mkOption {
              type = wlib.types.nonEmptyline;
              default = "loaded_${name}_provider";
              description = ''
                vim.g.<value> will be set to 0 when the nvim host is disabled
              '';
            };
            var_path = lib.mkOption {
              type = wlib.types.nonEmptyline;
              default = "${placeholder "out"}/bin/${config.binName}-${name}";
              description = ''
                The path to be added to `vim.g.<enabled_variable>`

                By default, the result of wrapping `nvim-host.package` with the
                other `nvim-host.*` options in the context of the outer neovim wrapper will be used.
              '';
            };
            dontWrap = lib.mkOption {
              type = lib.types.bool;
              default = false;
              description = ''
                If true, do not process any `hosts.*.nvim-host` options for this host other than:

                `nvim-host.enable`,
                `nvim-host.package`,
                `nvim-host.var_path`,
                `nvim-host.enabled_variable`,
                `nvim-host.disabled_variable`
              '';
            };
            package = lib.mkOption {
              type = wlib.types.nonEmptyline;
              default = "${hostConfig.wrapper}/bin/${hostConfig.binName}";
              description = ''
                The full path to be added to the `PATH` alongside the main nvim wrapper.

                By default, the binary from this host wrapper module will be used.

                This is the path which gets wrapped in the context of the nvim wrapper by the nvim-host options

                This allows you to wrap this path in the context of the overall nvim derivation,
                and thus have access to that path via `placeholder "out"`
              '';
            };
            enable = lib.mkOption {
              type = lib.types.bool;
              default = true;
              description = ''
                Enable this nvim host program.

                If enabled it will be added to the path alongside the nvim wrapper.

                It will also propagate options provided in this set to the nvim wrapper.
              '';
            };
          };
        }
      ];
    };
in
{
  imports = [
    wlib.modules.makeWrapper
    ./packDir.nix
    ./default-config.nix
  ];
  config.package = lib.mkOptionDefault pkgs.neovim-unwrapped;
  config.builderFunction = lib.mkDefault (import ./symlinkScript.nix);
  config.wrapperFunction = lib.mkOverride 999 (import ./makeWrapper);
  config.meta.maintainers = [ wlib.maintainers.birdee ];
  config.meta.description = {
    pre = builtins.readFile ./pre_desc.md;
    post = builtins.readFile ./post_desc.md;
  };
  options = {
    hosts = lib.mkOption {
      default = { };
      description = ''
        This option takes a set of wrapper modules.

        Neovim has "remote plugin hosts" which allow plugins in other languages.

        You can wrap such a host and pass them here.

        The resulting wrapped package will also be added to the PATH alongside nvim

        In fact, some defaults have been provided!

        You can `hosts.python3.nvim-host.enable = true;`
        and you can do the same with `node` and `ruby`

        You can also wrap things that are not remote plugin hosts.
        For example `neovide`! This allows you to keep the configuration for these in sync

        You can also `hosts.neovide.nvim-host.enable = true;`

        Each wrapper module in the set is given a `nvim-host` option, and evaluated,
        with the result being accesible via `config.hosts.<name>.<wrapper, nvim-host, binName, etc...>`

        the `nvim-host` option provides all the options of the `wlib.modules.makeWrapper` module again.

        However these options are evaluated in the scope of the **neovim wrapper**, not the host wrapper.

        In addition to the `wlib.modules.makeWrapper` options, it also adds the following options, which control how the host is added to neovim:

        `nvim-host.enable`,
        `nvim-host.package`,
        `nvim-host.var_path`,
        `nvim-host.enabled_variable`,
        `nvim-host.disabled_variable`
        `nvim-host.dontWrap`

        This allows you to do things like

        ```nix
        hosts.neovide.nvim-host.flags."--neovim-bin" = "''${placeholder "out"}/bin/''${config.binName}";
        ```

        If you do `hosts.neovide.nvim-host.enable = true;` it will do that for you.
      '';
      type = lib.types.attrsOf (
        wlib.types.subWrapperModuleWith {
          specialArgs = { inherit (config) specCollect; };
          modules = [
            (
              { name, config, ... }:
              {
                config.pkgs = pkgs;
                # NOTE: default required for docgen
                config.package = lib.mkOptionDefault (pkgs.${name} or pkgs.hello);
                options.nvim-host = lib.mkOption {
                  type = hostPropagatedOptions name config;
                  description = ''
                    Gives access to the full `wlib.modules.makeWrapper` options,
                    but ran in the context of the nvim host, not this sub wrapper module.

                    Also adds the following options, which control how the host is added to neovim:

                    `nvim-host.enable`,
                    `nvim-host.package`,
                    `nvim-host.var_path`,
                    `nvim-host.enabled_variable`,
                    `nvim-host.disabled_variable`
                    `nvim-host.dontWrap`
                  '';
                };
                config.nvim-host._module.args = {
                  inherit pkgs;
                  inherit (config) specCollect;
                };
              }
            )
          ];
        }
      );
    };
    specs = lib.mkOption {
      type = lib.types.attrsOf (
        wlib.types.specWith {
          specialArgs = {
            parentSpec = null;
            parentOpts = null;
            parentName = null;
          };
          modules =
            let
              inherit (config) specMods;
            in
            [
              (
                {
                  config,
                  options,
                  name,
                  ...
                }:
                {
                  options.data = lib.mkOption {
                    description = ''
                      A list of specs or plugins, or a plugin, or null

                      A plugin can be a derivation,
                      or an impure string path for testing!
                    '';
                    type = types.nullOr (
                      lib.types.either wlib.types.stringable (
                        types.listOf (
                          wlib.types.specWith {
                            specialArgs = {
                              parentSpec = config;
                              parentOpts = options;
                              parentName = name;
                            };
                            modules = [
                              {
                                options.data = lib.mkOption {
                                  type = types.nullOr wlib.types.stringable;
                                  description = ''
                                    A plugin (or null)

                                    A plugin can be a derivation,
                                    or an impure string path for testing!
                                  '';
                                };
                              }
                              specMods
                            ];
                          }
                        )
                      )
                    );
                  };
                }
              )
              specMods
            ];
        }
      );
      default = { };
      description = builtins.readFile ./spec_desc.md;
    };
    info = lib.mkOption {
      default = { };
      type = luaType;
      description = ''
        This wrapper module generates an info plugin.

        Add items here to populate `require('nix-info').info`

        You can change the name `nix-info` with `settings.info_plugin_name`

        You may get the value of `settings.info_plugin_name` in lua with

        `vim.g.nix_info_plugin_name`

        The info plugin also has a safe indexing helper function.

        ```lua
        require(vim.g.nix_info_plugin_name)(
          null, -- default value
          "info", -- start indexing!
          "path",
          "to",
          "nested",
          "info",
          "value" -- will return the value, or the specified default
        )
        ```
      '';
    };
    settings = lib.mkOption {
      default = { };
      description = ''
        settings for the neovim derivation.

        You may pass extra values just like config.info

        These will be made available in neovim via

        ```lua
        require('nix-info').settings
        require('nix-info')("default_value", "settings", "path", "to", "item")
        require(vim.g.nix_info_plugin_name).settings
        ```
      '';
      type = types.submodule {
        freeformType = luaType;
        options = {
          nvim_lua_env = lib.mkOption {
            type = wlib.types.withPackagesType;
            default = lp: [ ];
            description = ''
              A function that will be supplied to config.package.lua.withPackages

              `lp: [ lp.inspect ];`
            '';
          };

          config_directory = lib.mkOption {
            type = types.either wlib.types.stringable types.luaInline;
            default = lib.generators.mkLuaInline "vim.fn.stdpath('config')";
            description = ''
              The directory to use as the new config directory.

              May be a `wlib.types.stringable` or a `types.luaInline`
            '';
          };

          block_normal_config = lib.mkOption {
            type = types.bool;
            default = true;
            description = ''
              By default, we block the config in `vim.fn.stdpath('config')`.

              The default `settings.config_directory` is `vim.fn.stdpath('config')`
              so we don't need to run it twice, and when you wrap it,
              you usually won't want config from other sources.

              But you may make this false, and if you do so,
              the normal config directory will still be added to the runtimepath.

              However, the `init.lua` of the normal config directory will not be ran.
            '';
          };

          info_plugin_name = lib.mkOption {
            type = lib.types.addCheck wlib.types.nonEmptyline (v: !lib.hasInfix "." v);
            default = "nix-info";
            description = ''
              The name to use to require the info plugin

              May not be empty, may not contain dots or newlines.
            '';
          };
          dont_link = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = ''
              Don't link extra paths from the neovim derivation to the final output.

              This, in conjunction with `binName` option, allows you to install multiple
              neovims via `home.packages` or `environment.systemPackages` without path collisions.
            '';
          };
          aliases = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [ ];
            description = "Aliases for the package to also be added to the PATH";
          };
        };
      };
    };
    specMods = lib.mkOption {
      default = { };
      description = ''
        extra module for the plugin spec submodules (provided to `wlib.types.specWith`)

        These modules recieve some `specialArgs`!

        `parentSpec`, `parentOpts`, and `parentName`

        If the spec is a parent, these will be `null`

        If the spec is a child, `parentSpec` will be the `config` argument of the parent spec.

        Likewise, `parentOpts` will be the `options` argument and `parentName` the name argument.

        You may use this to change defaults and allow parent overrides of the default to propagate default values to child specs.

        ```nix
        config.specMods = {
          parentSpec, config, parentOpts, options, parentName, ...
        }: {
          config.collateGrammars = lib.mkDefault (parentSpec.collateGrammars or false);
        };
        ```

        You could also declare entirely new items for the spec to process with `specMaps` and `specCollect`.
      '';
      type = types.deferredModuleWith {
        staticModules = [
          (
            {
              config,
              options,
              parentSpec ? null,
              parentOpts ? null,
              parentName ? null,
              name,
              ...
            }:
            {
              # NOTE: for docgen
              config._module.args.parentName = lib.mkOptionDefault null;
              config._module.args.parentSpec = lib.mkOptionDefault null;
              config._module.args.parentOpts = lib.mkOptionDefault null;
              options = {
                enable = lib.mkOption {
                  type = types.bool;
                  default = parentSpec.enable or true;
                  description = ''
                    Enable the value

                    If this is in the inner list, then the default value from the parent spec will be used.
                  '';
                };
                name = lib.mkOption {
                  type = types.nullOr types.str;
                  default = if parentName != null then null else name;
                  description = ''
                    The name of this spec in the DAG of specs

                    May differ from the name of the plugin,
                    which is controlled by the `pname` option.
                  '';
                };
                before = lib.mkOption {
                  type = with types; listOf str;
                  default = [ ];
                  description = ''
                    Sort this spec before the list of spec names
                  '';
                };
                after = lib.mkOption {
                  type = types.listOf types.str;
                  default = [ ];
                  description = ''
                    Sort this spec after the list of spec names
                  '';
                };
                pname = lib.mkOption {
                  type = types.nullOr types.str;
                  default = null;
                  description = ''
                    Can be received in `.config` with `local _, pname, _ = ...`
                  '';
                };
                type = lib.mkOption {
                  type = types.enum [
                    "lua"
                    "fnl"
                    "vim"
                  ];
                  default = parentSpec.type or "lua";
                  description = ''
                    The language for the config field of this spec.
                    (Only applies to the `config` field, not the `info` field)

                    If this is in the inner list, then the default value from the parent spec will be used.
                  '';
                };
                config = lib.mkOption {
                  type = types.nullOr types.lines;
                  default = null;
                  description = ''
                    A snippet of config for this spec.
                  '';
                };
                info = lib.mkOption {
                  type = luaType;
                  default = { };
                  description = ''
                    Can be received in `.config` with `local info, _, _ = ...`
                  '';
                };
                lazy = lib.mkOption {
                  type = types.bool;
                  default = parentSpec.lazy or false;
                  description = ''
                    Can be received in `.config` with `local _, _, lazy = ...`

                    If this is in the inner list, then the default value from the parent spec will be used.
                  '';
                };
              };
            }
          )
        ];
      };
    };
    specMaps = lib.mkOption {
      default = [ ];
      type =
        (
          wlib.types.dalOf
          // {
            modules = [
              {
                options.enable = lib.mkOption {
                  default = true;
                  type = types.bool;
                  description = "Enable the function to run on the full list of specs";
                };
              }
            ];
          }
        )
          (types.functionTo (types.listOf (types.attrsOf types.raw)));
      description = ''
        supply a DAL list of functions

        Each function recieves the WHOLE final list of specs, in a particular format.

        Each one recieves `[ { name = "attrName"; type = "spec" | "parent"; value = spec; } /* ... */ ]`

        Each one returns the same structure, but with your alterations.

        The returned list will REPLACE the original list for the next function in `specMaps`, and then for the wrapper for sorting.

        `specCollect` gets the final specs after this has ran and everything has been sorted.

        You can only have at most 1 parent per attribute name or it errors.

        Be VERY careful with this option.

        However, this is your chance to have full control to process options you added via `specMods`

        `config.specCollect` can only collect, and while it is easier and safer than this option, this option has MUCH more control.

        This option gets *and* returns a list of sets with meta info and the spec for each value in `config.specs`.
      '';
    };
    specCollect = lib.mkOption {
      type = types.functionTo (types.functionTo (types.listOf types.raw));
      readOnly = true;
      description = ''
        contains a function which takes 2 arguments.

        ```nix
        config.specCollect = fn: first: builtins.foldl' fn first mappedSpecs;
        ```

        `mappedSpecs` in the above snippet is the result after all `config.specMaps` have been applied.

        You will recieve JUST the specs, unlike `config.specMaps`, which recieves specs wrapped in an outer set with more info

        This function offered by this option allows you to use items collected from the final specs, to provide them to other options.
      '';
    };
    nvim-lib.mkPlugin = lib.mkOption {
      readOnly = true;
      type = lib.types.functionTo (lib.types.functionTo lib.types.package);
      default =
        pname: src:
        pkgs.vimUtils.buildVimPlugin {
          inherit pname src;
          doCheck = false;
          version = toString (src.lastModifiedDate or "master");
        };
      description = ''
        A function used to build plugins not in nixpkgs!

        If you had a flake input like:

        ```nix
        inputs.treesj = {
          url = "github:Wansmer/treesj";
          flake = false;
        };
        ```

        You could install it like:

        ```nix
        config.specs.treesj = {
          data = config.nvim-lib.mkPlugin "treesj" inputs.treesj;
          info = { };
          config = "local info = ...; require('treesj').setup(info);";
        };
        ```

        Or, if you wanted to do the config in your main lua files, just install it:

        ```nix
          config.specs.treesj = config.nvim-lib.mkPlugin "treesj" inputs.treesj;
        ```

        You can use any fetcher, not just flake inputs, but flake inputs are tracked for you!
      '';
    };
  };
}
