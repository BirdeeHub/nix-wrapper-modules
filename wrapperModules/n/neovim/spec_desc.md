Plugins are provided via the `config.specs` option.

It takes a set of plugins, or a set of lists of plugins.

Everything that takes a plugin can instead be a spec 

This means you could pass a direct plugin or a spec with the plugin as its `.data` field.

For the outer attribute set, this means the value or the `.data` field may be a `plugin` (a stringable value), `null`, or a list of specs

And for the contained lists, the values or `.data` fields may be a `plugin` or `null`

Many options when set in the outer set will propagate to the contained lists.

For example, the value for `lazy` does this, allowing you to specify a list of plugins all to be loaded lazily by default.

This is controlled by the `specMods` option.

```nix
# Direct plugin path
config.specs.gitsigns = pkgs.vimPlugins.gitsigns-nvim;

config.specs.treesj = {
  data = pkgs.vimPlugins.treesj;
  config = "require('treesj').setup({})";
};

# Spec with info values (in fennel!)
config.specs.lualine = {
  data = pkgs.vimPlugins.lualine-nvim;
  type = "fnl";
  info = { # mkLuaInline in info still just makes lua even if its fennel type
    theme = lua.mkLuaInline "[[catppuccin]]";
  };
  # but here we can use fennel!
  config = ''
    (local (opts name) ...)
    ((. (require "lualine") setup) {
      :options { :theme info.theme }
    })
  '';
};

# List of specs (DAL inside the DAG)
config.specs.completion-plugins = {
  lazy = true; # lazy will propagate to the contained specs.
  data = [
    {
      name = "blink-cmp";
      data = pkgs.vimPlugins.blink-cmp;
    }
    # values can be specs or plugins here too!
    # some values will propagate from the parent.
    # you can change this, or add your own options via `config.specMods`!
    pkgs.vimPlugins.fzf-lua-nvim;
  ];
};
```

**Built-in Spec Fields**

- `data`: The plugin package to install
- `config`: Configuration code (lua by default, can be vimscript or fennel)
- `info`: Lua values to be accessed in config via `local info, pname, lazy = ...`
- `lazy`: Whether to load the plugin lazily (default: false) Propagates to child specs.
- `type`: Language for config field - `"lua"`, `"vim"`, or `"fnl"` (default: `"lua"`) Propagates to child specs.
- `pname`: Optional package name, accessible in config
- `enable`: Enable or disable this spec (default: true) Propagates to child specs.
- `name`: Allows this spec to be referenced by the `before` and `after` fields of other specs
- `before`: A list of specs which this spec will run its configuration before
- `after`: A list of specs which this spec will run its configuration after

...and also some extra ones set via `specMods` by default.

- `pluginDeps`: Install plugins from `.dependencies` attribute on this plugin Propagates to child specs. Default `"startup"`, allows `"lazy"` and `false` as well.
- `collateGrammars`: Collate the grammars of all plugins in this spec into a single grammar Propagates to child specs. Default `true`.
- `runtimeDeps`: Install values from `.runtimeDeps` attribute on this plugin to the `PATH`. Propagates to child specs. Default `"suffix"`, allows `"prefix"` and `false` as well.
- `autoconfig`: Add configuration code from `.passthru.initLua` attribute on this plugin. Propagates to child specs. Value is of type boolean, with a default of `true`.

*TIP*

The main `init.lua` of your config directory is added to the specs DAG under the name `INIT_MAIN`.

By default, the specs will run after it. Add `before = [ "INIT_MAIN" ]` to the spec to run before it.

**Using specMods for Customization**

The `specMods` option allows you to define extra options and processing for specs.

It receives `parentSpec` and `parentOpts` via `specialArgs`, allowing child specs to access and inherit from their parents.

These values will be `null` if the spec is a parent spec, and contain the `config` and `options` arguments of their parent spec if they are in a contained list instead.

```nix
config.specMods = { parentSpec, ... }: {
  # declare more spec fields you can process either here, or after with other options!
  options.myopt = lib.mkOption {
    type = lib.types.bool;
    default = parentOpts.myopt or false;
    desc = "A description for myopt";
  };
  # Or change a default!
  config.collateGrammars = parentSpec.collateGrammars or true;
  config.type = parentSpec.type or "fnl";
};
```

These extra modules will be provided to the modules argument that creates the specs from `wlib.types.specWith`

You may then need to process the backend of these new options via `config.specMaps` or `config.specCollect`.

This is more complex, with `specCollect` being the next simplest option followed by `specMaps` which is hardest, but it gives amazing flexibility for adding behaviors!
