# Neovim module

This is a demonstration of the [neovim module](https://birdeehub.github.io/nix-wrapper-modules/neovim.html)

It makes use of the tips in the [tips and tricks](https://birdeehub.github.io/nix-wrapper-modules/neovim.html#tips-and-tricks) section of the documentation.

It uses [lze](https://github.com/BirdeeHub/lze) for lazy loading of the configuration.

It is by no means a perfect, complete configuration.

However, it is plenty to start on, and covers some interesting ways to use the module (and `lze`).

This configuration is 1 `lua` file, however the whole set of directories from a normal `neovim` configuration directory are available.

To see what directories you can put stuff in, see: [:help 'rtp'](https://neovim.io/doc/user/options.html#'rtp')

The main reason it is in 1 file is that, it is following the style of [kickstart.nvim](https://github.com/nvim-lua/kickstart.nvim).

The other reason it is in 1 file, is that it makes it a cleaner experience to init this template into an existing configuration.

To initialize this template into the current directory, run:

```bash
nix flake init -t github:BirdeeHub/nix-wrapper-modules#neovim
```

If you are using `zsh` you may need to escape the `#`
