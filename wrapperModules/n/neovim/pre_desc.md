Please see the template for an introductory example usage!

To initialize it, run `nix flake init -t github:BirdeeHub/nix-wrapper-modules#neovim`

If you are using `zsh`, you may need to escape the `#` character with a backslash.

The first thing to notice is `config.settings.config_directory`

Set it to an in-store, out-of-store, or `lib.generators.mkLuaInline` value!

It will be loaded just like a normal neovim configuration directory.

Plugins are provided via the `config.specs` option.

It takes a set of plugins, or a set of lists of plugins.

Each item that accepts a plugin may also be a `spec` with the plugin as its `.data` field,
which may optionally be customized by `config.specMods` and then further processed by `config.specCollect` (not too hard) and `config.specMaps` (advanced).

The spec forms offer the ability to provide plugins, configuration (in `lua`, `vimscript`, or `fennel`),
along with automatically translated lua values in a finely controlled order.

A plugin may be an in-store or out-of-store path, but may not be a lua inline value.

Optionally supports the ability to avoid path collisions when installing multiple configured neovim packages!

You may do this via a combination of `config.binName` and `config.settings.dont_link` options.

Fully supports remote plugin hosts,
and allows arbitrary other items to be bundled into the context of your nvim derivation, such as `neovide`,
via an option which accepts wrapper modules for maximum flexibility.

That is also why there are so many options listed. Skip past the `hosts` options to get to the good stuff.

## All Options:
