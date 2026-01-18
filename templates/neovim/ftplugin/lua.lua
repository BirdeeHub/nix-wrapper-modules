-- NOTE: Lazydev will make your Lua LSP stronger for Neovim config
-- we are also using this as an opportunity to show you how to lazy load plugins!
-- This plugin was added to the optionalPlugins section of the main nix file of this template.
-- Thus, it is not loaded and must be packadded.
-- NOTE: Use `=require(vim.g.nix_info_plugin_name).plugins.lazy` to see the names of all lazy plugins downloaded via Nix for packadd.
vim.cmd.packadd('lazydev.nvim')
require('lazydev').setup({
  library = { },
})
