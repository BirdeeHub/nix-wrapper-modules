## Tips and Tricks:

The main `init.lua` of your config directory is added to the specs DAG under the name `INIT_MAIN`.

By default, the specs will run after it. Add `before = [ "INIT_MAIN" ]` to the spec to run before it.

---

- Your `config.settings.config_directory` can point to an impure path (or lua inline value)

Use this for a quick feedback mode while editing, and then switch it back to the pure path when you are done! (or make an option for it)

---

The wrapper makes a lot of information available to you in your lua config via the info plugin!

```lua
local nixInfo = require(vim.g.nix_info_plugin_name)
local default = nil
local value = nixInfo(default, "path", "to", "value", "in", "plugin")
```

It is just a table! Run `:=require(vim.g.nix_info_plugin_name)` to look at it!

A useful function to see if nix installed a plugin for you is:

```lua
local nixInfo = require(vim.g.nix_info_plugin_name)
local function get_nix_plugin_path(name)
  return nixInfo(nil, "plugins", "lazy", name) or nixInfo(nil, "plugins", "start", name)
end
```

For another example, you might want to tell your info plugin about the top-level specs which you have enabled,
which you can do like this in your module:

```nix
config.info.cats = builtins.mapAttrs (_: v: v.enable) config.specs;
```

And then get it in `lua` with:

```lua
local nixInfo = require(vim.g.nix_info_plugin_name)
local cat_is_present = nixInfo(false, "info", "cats", "<specs_attribute_name>")
```

You could also do similar with

```nix
options.settings.cats = lib.mkOption {
  readOnly = true;
  type = lib.types.attrsOf lib.types.raw;
  default = builtins.mapAttrs (_: v: v.enable) config.specs;
};
# nixInfo(false, "settings", "cats", "<specs_attribute_name>")
```

---

- lazy loading

If you mark a spec as lazy, (or mark a parent spec and don't override the value in the child spec by default),
it will be placed in `pack/myNeovimPackages/opt/<pname>` on the runtime path.

It will not be loaded yet. Use `vim.cmd.packadd("<pname>")` to load it via `lua` (or `vimscript` or `fennel`) at a time of your choosing.

There are great plugins for this.

See [lze](https://github.com/BirdeeHub/lze) and [lz.n](https://github.com/nvim-neorocks/lz.n), which work beautifully with this method of installing plugins.

They also work great with the builtin `neovim` plugin manager, `vim.pack.add`!

---

- To use a different version of `neovim`, set `config.package` to the version you want to use!

```nix
config.package = inputs.neovim-nightly-overlay.packages.${pkgs.stdenv.hostPlatform.system}.neovim;
```

---

- In order to prevent path collisions when installing multiple neovim derivations via `home.packages` or `environment.systemPackages`

```nix
# set this to true
config.settings.dont_link = true;
# and make sure these dont share values:
config.binName = "nvim";
config.settings.aliases = [ ];
```

---

- Use `nvim-lib.mkPlugin` to build plugins from sources outside nixpkgs (e.g., git flake inputs)

```nix
inputs.treesj = {
  url = "github:Wansmer/treesj";
  flake = false;
};
```

```nix
config.specs.treesj = config.nvim-lib.mkPlugin "treesj" inputs.treesj;
```

---

- Building many plugins from outside `nixpkgs` at once

In your flake inputs, if you named your inputs like so:

```nix
inputs.plugins-treesitter-textobjects = {
  url = "github:nvim-treesitter/nvim-treesitter-textobjects/main";
  flake = false;
};
```

You could identify them and build them as plugins all at once!

Here is a useful module to import which gives you a helper function
in `config.nvim-lib` for that!

```nix
{ config, lib, ... }: {
  options.nvim-lib.pluginsFromPrefix = lib.mkOption {
    type = lib.types.raw;
    readOnly = true;
    default =
      prefix: inputs:
      lib.pipe inputs [
        builtins.attrNames
        (builtins.filter (s: lib.hasPrefix prefix s))
        (map (
          input:
          let
            name = lib.removePrefix prefix input;
          in
          {
            inherit name;
            value = config.nvim-lib.mkPlugin name inputs.${input};
          }
        ))
        builtins.listToAttrs
      ];
  };
}
```

And then you have access to the plugins like this!:

```nix
inputs:
{ config, ... }: let
  neovimPlugins = config.nvim-lib.pluginsFromPrefix "plugins-" inputs;
in {
  imports = [ ./the_above_module.nix ];
  specs.treesitter-textobjects = neovimPlugins.treesitter-textobjects;
}
```

---

- Change defaults and allow parent values to propagate default values to child specs:

```nix
config.specMods = { parentSpec, ... }: {
  config.collateGrammars = lib.mkDefault (parentSpec.collateGrammars or false);
};
```

You have full control over them via the module system! This module will apply to the `wlib.types.spec` type of both specs in both the outer set and inner lists!

In the outer set, `parentSpec` is `null` and in the inner lists, it receives the `config` argument from the outer set!

It also receives `parentOpts`, which contains the `options` argument, and `parentName` with the name argument of the outer spec.

It also receives the normal module arguments, like `config` from the current module.

---

- You may want to move the installation of things like language servers into your specs. You can do that!

```nix
{ config, lib, wlib, ... }: {
  config.specMods = {
    options.extraPackages = lib.mkOption {
      type = lib.types.listOf wlib.types.stringable;
      default = [ ];
      description = "a extraPackages spec field to put packages to suffix to the PATH";
    };
  };
  config.extraPackages = config.specCollect (acc: v: acc ++ (v.extraPackages or [ ])) [ ];
}
```

---

- Use `specMaps` for advanced spec processing only when `specMods` and `specCollect` is not flexible enough.

`specMaps` has free-reign to modify the whole structure of specs provided as desired after the module evaluation,
before `specCollect` runs, and before the wrapper evaluates the builtin fields of the specs.

Be careful with this option, but an advanced user might use this to preprocess the items in truly amazing ways!

This also means items in `specCollect` may occasionally be missing fields, do not rely on them being there when using it! Use `or` to catch indexing errors.

---

- Make a new host!

```nix
# an attribute set of wrapper modules
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
    # also offers nvim-host wrapper arguments which run in the context of the final nvim drv!
    config.nvim-host.flags."--neovim-bin" = "${placeholder "out"}/bin/${config.binName}";
  };

  # This one is included!
  # To add a wrapped $out/bin/${config.binName}-neovide to the resulting neovim derivation
  config.hosts.neovide.nvim-host.enable = true;
```

---

- Non-nix compatibility:

If you always use the fetcher function form to access items in the plugin from nix,
then this mostly takes care of non-nix compatibility. Non-nix compatibility meaning,
trying to use the same config directory without using nix to install it.

```lua
do
  local ok = pcall(require, vim.g.nix_info_plugin_name)
  if not ok then
    package.loaded[vim.g.nix_info_plugin_name] = setmetatable({}, {
      __call = function (_, default) return default end
    })
  end
  require(vim.g.nix_info_plugin_name).isNix = vim.g.nix_info_plugin_name ~= nil
end
```

You would have to have a file that installs the plugins with `vim.pack.add` if not using nix,
and install the lsps some other way as well.

As a reminder, the fetcher function form is:

```lua
local nixInfo = require(vim.g.nix_info_plugin_name)
local default = nil
local value = nixInfo(default, "path", "to", "value", "in", "plugin")
```

---

- Stylix colorscheme integration (requires somewhere with stylix installed to get the colors from):

```nix
{ pkgs, ... }: {
  config.specs.base16 = {
    # install a plugin to handle the colors
    data = pkgs.vimPlugins.mini-base16;
    # run before the main init.lua
    before = [ "INIT_MAIN" ];

    # get the colors from your system and pass it
    info = pkgs.lib.filterAttrs (
      k: v: builtins.match "base0[0-9A-F]" k != null
    ) your-system-config.lib.stylix.colors.withHashtag;

    # call the plugin with the colors
    config = /* lua */ ''
      local info, pname, lazy = ...
      require("mini.base16").setup({
        palette = info,
      })
    '';
  };
}
```
