## Tips and Tricks:

The main `init.lua` of your config directory is added to the specs DAG under the name `INIT_MAIN`.

By default, the specs will run after it. Add `before = [ "INIT_MAIN" ]` to the spec to run before it.

---

- Your `config.settings.config_directory` can point to an impure path (or lua inline value)

Use this for a quick feedback mode while editing, and then switch it back to the pure path when you are done! (or make an option for it)

---

- lazy loading

If you mark a spec as lazy, (or mark a parent spec and don't override the value in the child spec by default),
it will be placed in `pack/myNeovimPackages/opt/<pname>` on the runtime path.

It will not be loaded yet. Use `vim.cmd.packadd("<pname>")` to load it via `lua` (or `vimscript` or `fennel`) at a time of your choosing.

There are great plugins for this.

See [lze](https://github.com/BirdeeHub/lze) and [lz.n](https://github.com/nvim-neorocks/lz.n), which work beautifully with this method of installing plugins.

They also work great with the builtin `neovim` plugin manager, `vim.pack.add`!

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

- To use a different version of neovim, set `config.package` to the version you want to use!

```nix
config.package = inputs.neovim-nightly-overlay.packages.${pkgs.stdenv.hostPlatform.system}.neovim;
```

---

- Make a new host!

```nix
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

- In order to prevent path collisions when installing multiple neovim derivations via home.packages or environment.systemPackages

```nix
# set this to true
config.settings.dont_link = true;
# and make sure these dont share values:
config.binName = "nvim";
config.settings.aliases = [ ];
```

---

- Change defaults and allow parent overrides of the default to propagate default values to child specs:

```nix
config.specMods = { parentSpec, ... }: {
  config.collateGrammars = lib.mkDefault (parentSpec.collateGrammars or true);
};
```

---

- Use `specMaps` for advanced spec processing only when `specMods` and `specCollect` is not flexible enough

---

- building many plugins from outside nixpkgs at once

In your flake inputs, if you named your inputs like so:

```nix
inputs.plugins-treesitter-textobjects = {
  url = "github:nvim-treesitter/nvim-treesitter-textobjects/main";
  flake = false;
};
```

You could identify them and pre-build them as plugins all at once!

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
