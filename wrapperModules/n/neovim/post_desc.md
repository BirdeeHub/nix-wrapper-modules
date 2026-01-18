## Tips and Tricks:

The main `init.lua` of your config directory is added to the specs DAG under the name `INIT_MAIN`.

By default, the specs will run after it. Add `before = [ "INIT_MAIN" ]` to the spec to run before it.

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

- Use `specMaps` for advanced spec processing only when `specMods` and `specCollect` is not flexible enough

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
